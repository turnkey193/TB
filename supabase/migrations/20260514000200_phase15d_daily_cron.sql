-- Phase 15d: 特休週年制 — 每日自動維護 SQL function + pg_cron 排程

-- ===== Helper: 算員工從 hire_date 到 until_date 應該有的所有 periods =====
CREATE OR REPLACE FUNCTION hr.compute_annual_leave_periods(p_hire_date date, p_until date)
RETURNS TABLE (
  period_start date,
  period_end date,
  months_of_service int,
  entitled_days int
) AS $$
DECLARE
  table_setting jsonb;
  six_month date;
  ps date;
  pe date;
  years int := 1;
BEGIN
  SELECT value INTO table_setting FROM hr.payroll_settings WHERE key = 'annual_leave_table';
  IF table_setting IS NULL THEN RETURN; END IF;

  -- 第一筆：滿半年
  six_month := p_hire_date + INTERVAL '6 months';
  IF six_month > p_until THEN RETURN; END IF;

  period_start := six_month;
  period_end := (p_hire_date + INTERVAL '1 year')::date - 1;
  months_of_service := 6;
  SELECT COALESCE(MAX((d->>'days')::int), 0)
    INTO entitled_days
    FROM jsonb_array_elements(table_setting) d
    WHERE (d->>'min_months')::int <= 6;
  RETURN NEXT;

  -- 之後每滿一週年
  LOOP
    ps := (p_hire_date + (years || ' years')::interval)::date;
    EXIT WHEN ps > p_until;
    pe := (p_hire_date + ((years + 1) || ' years')::interval)::date - 1;
    period_start := ps;
    period_end := pe;
    months_of_service := years * 12;
    SELECT COALESCE(MAX((d->>'days')::int), 0)
      INTO entitled_days
      FROM jsonb_array_elements(table_setting) d
      WHERE (d->>'min_months')::int <= years * 12;
    RETURN NEXT;
    years := years + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql STABLE;

-- ===== 每日維護：建新 period + 標過期 + queue 到期通知 =====
CREATE OR REPLACE FUNCTION hr.daily_annual_leave_maintenance()
RETURNS json AS $$
DECLARE
  today_tw date := (now() AT TIME ZONE 'Asia/Taipei')::date;
  notify_window date := today_tw + INTERVAL '120 days';
  emp record;
  p record;
  last_unused numeric := 0;
  used_days numeric;
  unused numeric;
  daily_wage numeric;
  expired_count int := 0;
  notif_count int := 0;
  emp_count int := 0;
BEGIN
  -- 1. 對每位在職員工，建出 hire_date 起算所有 periods（idempotent）
  FOR emp IN
    SELECT id, hire_date, monthly_salary, base_salary, meal_allowance, attendance_bonus, position_allowance
      FROM hr.employees
      WHERE is_active = true AND hire_date IS NOT NULL
  LOOP
    emp_count := emp_count + 1;
    last_unused := 0;

    FOR p IN
      SELECT * FROM hr.compute_annual_leave_periods(emp.hire_date, today_tw)
      ORDER BY period_start
    LOOP
      -- 計算該 period 內已核准特休天數
      SELECT COALESCE(SUM(total_hours), 0) / 8
        INTO used_days
        FROM hr.leave_requests
        WHERE employee_id = emp.id
          AND leave_type_code = 'annual'
          AND status = 'approved'
          AND start_at >= (p.period_start::text || 'T00:00:00+08:00')::timestamptz
          AND start_at <= (p.period_end::text   || 'T23:59:59+08:00')::timestamptz;

      INSERT INTO hr.annual_leave_balances
        (employee_id, year, period_start, period_end, entitled_days, carried_over_days, used_days, expired_days, notes, updated_at)
      VALUES
        (emp.id, EXTRACT(YEAR FROM p.period_start)::int, p.period_start, p.period_end, p.entitled_days, last_unused, ROUND(used_days, 1), 0, 'daily-cron', now())
      ON CONFLICT (employee_id, period_start)
      DO UPDATE SET
        period_end = EXCLUDED.period_end,
        entitled_days = EXCLUDED.entitled_days,
        carried_over_days = EXCLUDED.carried_over_days,
        used_days = EXCLUDED.used_days,
        updated_at = now();

      last_unused := GREATEST(0, p.entitled_days + last_unused - used_days);
    END LOOP;
  END LOOP;

  -- 2. 標過期：expire_at < today 且還沒折發
  FOR p IN
    SELECT b.id, b.employee_id, b.entitled_days, b.carried_over_days, b.used_days,
           e.monthly_salary, e.base_salary, e.meal_allowance, e.attendance_bonus, e.position_allowance
      FROM hr.annual_leave_balances b
      JOIN hr.employees e ON e.id = b.employee_id
      WHERE b.expire_at < today_tw
        AND b.payout_payslip_id IS NULL
        AND (b.expired_days = 0 OR b.expired_days IS NULL OR b.payout_amount IS NULL)
  LOOP
    unused := GREATEST(0, p.entitled_days + COALESCE(p.carried_over_days, 0) - COALESCE(p.used_days, 0));
    CONTINUE WHEN unused <= 0;
    daily_wage := COALESCE(NULLIF(p.monthly_salary, 0),
                           COALESCE(p.base_salary,0) + COALESCE(p.meal_allowance,0) + COALESCE(p.attendance_bonus,0) + COALESCE(p.position_allowance,0))
                  / 30;
    UPDATE hr.annual_leave_balances
      SET expired_days = unused,
          payout_amount = ROUND(unused * daily_wage)
      WHERE id = p.id;
    expired_count := expired_count + 1;
  END LOOP;

  -- 3. queue 120 天內到期的通知（每張 balance row 只推一次）
  FOR p IN
    SELECT b.id, b.employee_id, b.period_start, b.period_end, b.expire_at,
           b.entitled_days, b.carried_over_days, b.used_days
      FROM hr.annual_leave_balances b
      WHERE b.expire_at >= today_tw
        AND b.expire_at <= notify_window
        AND b.last_notified_at IS NULL
        AND b.payout_payslip_id IS NULL
  LOOP
    unused := GREATEST(0, p.entitled_days + COALESCE(p.carried_over_days, 0) - COALESCE(p.used_days, 0));
    CONTINUE WHEN unused <= 0;

    BEGIN
      INSERT INTO hr.notifications (employee_id, kind, payload, channel, dedup_key)
      VALUES (
        p.employee_id,
        'annual_leave_expiring',
        jsonb_build_object(
          'period_start', p.period_start,
          'period_end', p.period_end,
          'expire_at', p.expire_at,
          'unused_days', unused,
          'days_left', (p.expire_at - today_tw)
        ),
        'line',
        'annual_leave_expire:' || p.id
      );
      UPDATE hr.annual_leave_balances SET last_notified_at = now() WHERE id = p.id;
      notif_count := notif_count + 1;
    EXCEPTION WHEN unique_violation THEN
      -- dedup_key 重複 → 已通知過，標記 last_notified_at 避免之後再嘗試
      UPDATE hr.annual_leave_balances SET last_notified_at = now() WHERE id = p.id;
    END;
  END LOOP;

  RETURN json_build_object(
    'employees_processed', emp_count,
    'expired_marked', expired_count,
    'notifications_queued', notif_count,
    'ran_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION hr.daily_annual_leave_maintenance() TO service_role;

-- ===== 排程：每日台北時間 00:30 跑（= UTC 16:30 前一天）=====
DO $$
BEGIN
  -- 移除舊 job（如果存在），重建
  PERFORM cron.unschedule('hr-annual-leave-maintenance')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'hr-annual-leave-maintenance');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'hr-annual-leave-maintenance',
  '30 16 * * *',  -- 台北 00:30 = UTC 16:30
  $$ SELECT hr.daily_annual_leave_maintenance() $$
);

COMMENT ON FUNCTION hr.daily_annual_leave_maintenance() IS '每日跑：建新週年 balance + 標過期折發 + queue 120 天內到期通知';

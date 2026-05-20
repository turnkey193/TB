# TB 子系統 SSO 接入合約（給未來新子系統照抄）

> 適用於：tb-quotation、tb-cases、未來新 TB 子系統
> 參考實作：[`tb-meeting/server.js`](../../tb-meeting/server.js)（最完整）
> 上一份協調備忘：[`COORDINATION_tb_meeting_sso_phase1_2026-05-19.md`](COORDINATION_tb_meeting_sso_phase1_2026-05-19.md)

---

## 1. portal JWT shape（你會收到的 token）

portal `/api/exchange?to=<your-subsystem-id>` 簽發的 JWT，5 分鐘有效：

```js
{
  sub: number,         // hr.employees.id
  code: string,        // hr.employees.employee_code
  role: string,        // hr.employees.role (employee/manager/admin/hr/...)
  name: string,        // hr.employees.full_name
  tb_user_id?: uuid,   // hr.employees.tb_user_id（如果有對應 tb_users）
  sys: string[],       // 該員工被授權的子系統 id 陣列（defense-in-depth）
  iat, exp             // jwt 標準欄位
}
```

## 2. 共用 env vars（必設）

```env
JWT_SECRET=                # 跟所有 TB 子系統相同；至少 32 字元
COOKIE_NAME=tb<XX>_sess    # 各子系統自選短 prefix；tb-meeting 是 tbm_sess
SESSION_DAYS=30            # SSO session 持續天數
NODE_ENV=production        # ⚠️ Dockerfile 內顯式設，不要靠平台
SUPABASE_URL=
SUPABASE_SERVICE_KEY=sb_secret_*   # 不要再用 anon key 或 legacy JWT key
```

## 3. 必備 endpoint

### `GET /auth/exchange?token=<jwt>`

portal 跳轉進來時 hit 這個。流程：

1. 驗 `jwt.verify(token, JWT_SECRET)` — 失敗 redirect `/?login_failed=invalid_or_expired`
2. 驗 `payload.sys?.includes('<your-subsystem-id>')` — 失敗 redirect `/?login_failed=no_access`
3. 用 `payload.tb_user_id`（優先）或 `payload.sub` 找你子系統內部的 user row
4. 找不到 → auto-provision（為該 employee 建一筆內部 user）或 redirect `/?login_failed=no_user`
5. `setSessionCookie(res, sessionPayload)` → `res.redirect('/')`

**錯誤 redirect 統一格式**：`/?login_failed=<reason>`，常見 reason：`sso_disabled / invalid_or_expired / no_access / no_user / no_token`。

### `GET /auth/me`

讀目前 cookie session，回 `{ ok: true, ...sessionPayload }` 或 401。

### `POST /auth/logout`

`clearSessionCookie(res)` + 回 `{ ok: true }`。

> ⚠️ tb-meeting 用 `/auth/logout`、tb-portal/tb-hr/tb-org 用 `/api/auth/logout`。**新子系統建議用 `/auth/logout`**（跟其他 auth endpoint 同 prefix），未來看是否要統一其他子系統。

## 4. Cookie 規範

```js
res.cookie(COOKIE_NAME, token, {
  httpOnly: true,
  secure: isProd,    // NODE_ENV==='production' 才開
  sameSite: 'lax',
  maxAge: SESSION_DAYS * 24 * 60 * 60 * 1000,
  path: '/',
});
```

`app.set('trust proxy', 1)` 必加，否則 Zeabur HTTPS 後 `secure` cookie 判斷會錯。

## 5. requireAuth / requireAdmin middleware

```js
function requireAuth(req, res, next) {
  const sess = readSession(req);
  if (!sess) return res.status(401).json({ ok: false, message: 'unauthorized' });
  req.user = sess;
  next();
}
function requireAdmin(req, res, next) {
  if (req.user?.role !== 'admin') return res.status(403).json({ ok: false, message: 'admin only' });
  next();
}
```

**所有 `/api/admin/*` 必須 `requireAuth, requireAdmin`，不能只靠 frontend 隱藏 UI**（這是真實安全洞，不是理論風險）。

業務 routes 也應該 `requireAuth`（除非有明確理由不鎖，例如 webhook 進來的 `/api/intake`）。

## 6. Frontend fetch 必須帶 cookie

最簡單做法（複製到 `main.jsx` 第一行）：

```js
if (typeof window !== 'undefined' && !window.__fetchPatched) {
  const orig = window.fetch.bind(window);
  window.fetch = (input, init = {}) => {
    const url = typeof input === 'string' ? input : input?.url;
    const sameOrigin = url && (url.startsWith('/') || url.startsWith(window.location.origin));
    return sameOrigin ? orig(input, { credentials: 'include', ...init }) : orig(input, init);
  };
  window.__fetchPatched = true;
}
```

這樣所有 same-origin fetch 自動帶 cookie，業務 code 不用每次寫 `credentials: 'include'`。

對應後端：`app.use(cors({ origin: true, credentials: true }))`（origin 白名單之後再做）。

## 7. SSO_ENABLED gate（推薦）

```js
const SSO_ENABLED = JWT_SECRET.length >= 32;
if (!SSO_ENABLED) console.warn('[startup] SSO 停用：JWT_SECRET 未設或太短');
```

`/auth/*` endpoint 在 SSO_DISABLED 時應回 503 / redirect `?login_failed=sso_disabled`，但 legacy `/api/login` 不受影響。

## 8. 新子系統的 portal 端配置

接入完成後，要：

1. 在 Supabase `hr.portal_subsystems` 插 row（`id`、`name`、`description`、`icon`、`color`、`sort_order`）
2. 在 tb-portal Zeabur env 加 `SUBSYS_TB_<XXX>=https://your-subsystem.zeabur.app`
3. （**自動**）DB trigger `hr.provision_tb_user_on_access()` 目前只處理 `tb-meeting`；如果新子系統也要「portal 勾選就預建內部 user」，要擴充這個 trigger 或為新子系統寫一個對應的

## 9. 對 hr.employees / employment_status 的處理

- `employment_status='internal'` — 正式員工
- `employment_status='external'` — 加盟商/分店主管暫時佔位（**未來會轉 internal**）
- `employment_status='store_shared'` — 分店共用帳號（非自然人）

子系統的處理建議：
- 薪資/勞健保查詢應 filter `WHERE employment_status = 'internal'`
- 一般功能（打卡、週會、看案件）可以包含 external + store_shared

## 10. 不要做的事

- ❌ 把 JWT token 放 URL hash fragment（會留瀏覽器 history + referrer）
- ❌ 把員工敏感欄位（薪資、身分證）放 token payload
- ❌ 只在 frontend 控制 admin 權限（後端必須 requireAdmin）
- ❌ 把 SUPABASE_SERVICE_KEY 寫進 frontend 程式或 git
- ❌ 用 anon key 或 legacy JWT API key（2026-04-21 已停用）

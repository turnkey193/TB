// 一次性腳本：將 tb_users 的明碼 password 用 bcrypt hash 後寫入 password_hash
// 執行方式：
//   node scripts/hash-existing-passwords.mjs
//
// 特性：
// - 冪等：已經有 password_hash 的使用者會跳過（便於重跑）
// - 保留 password 欄位：讓你可以驗證登入 OK 後再由 migration 刪除
// - 透過 service_role key 直接讀寫 tb_users，繞過 RLS

import 'dotenv/config';
import bcrypt from 'bcrypt';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('缺少 SUPABASE_URL 或 SUPABASE_SERVICE_KEY（檢查 .env）');
  process.exit(1);
}

const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
};

async function main() {
  const listRes = await fetch(
    `${SUPABASE_URL}/rest/v1/tb_users?select=id,username,password,password_hash`,
    { headers },
  );
  const users = await listRes.json();
  if (!Array.isArray(users)) {
    console.error('讀取 tb_users 失敗：', users);
    process.exit(1);
  }

  console.log(`共 ${users.length} 位使用者`);

  let hashed = 0;
  let skipped = 0;
  let failed = 0;

  for (const u of users) {
    if (u.password_hash) {
      console.log(`  [跳過] ${u.username} 已有 password_hash`);
      skipped++;
      continue;
    }
    if (!u.password) {
      console.warn(`  [警告] ${u.username} 沒有明碼密碼可 hash`);
      failed++;
      continue;
    }
    try {
      const hash = await bcrypt.hash(u.password, 10);
      const patch = await fetch(`${SUPABASE_URL}/rest/v1/tb_users?id=eq.${u.id}`, {
        method: 'PATCH',
        headers: { ...headers, Prefer: 'return=minimal' },
        body: JSON.stringify({ password_hash: hash }),
      });
      if (!patch.ok) {
        const err = await patch.text();
        console.error(`  [失敗] ${u.username}: ${patch.status} ${err}`);
        failed++;
        continue;
      }
      console.log(`  [完成] ${u.username}`);
      hashed++;
    } catch (e) {
      console.error(`  [錯誤] ${u.username}: ${e.message}`);
      failed++;
    }
  }

  console.log('\n結果：');
  console.log(`  hashed  = ${hashed}`);
  console.log(`  skipped = ${skipped}`);
  console.log(`  failed  = ${failed}`);

  if (failed > 0) {
    console.error('有使用者處理失敗，請檢查上方 log');
    process.exit(1);
  }
}

main();

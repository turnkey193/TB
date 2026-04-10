const { google } = require('googleapis');
const path = require('path');

async function listFiles() {
  const auth = new google.auth.GoogleAuth({
    keyFile: path.join(__dirname, 'key', 'huaaibot-key.json'),
    scopes: [
      'https://www.googleapis.com/auth/drive.readonly',
      'https://www.googleapis.com/auth/spreadsheets.readonly',
    ],
  });

  const client = await auth.getClient();
  const drive = google.drive({ version: 'v3', auth: client });

  // 列出所有這個帳號能存取的檔案
  const res = await drive.files.list({
    pageSize: 100,
    fields: 'files(id, name, mimeType, webViewLink, createdTime)',
    orderBy: 'modifiedTime desc',
  });

  const files = res.data.files;

  if (!files || files.length === 0) {
    console.log('❌ 這個 Service Account 目前沒有被共用任何檔案。');
    console.log('\n請到你的 Google Sheet，點「共用」，加入：');
    console.log('  huaaibot@sage-ripple-483908-m4.iam.gserviceaccount.com');
    return;
  }

  console.log(`✅ 找到 ${files.length} 個檔案：\n`);
  files.forEach((file, i) => {
    const type = file.mimeType.includes('spreadsheet') ? '📊 試算表'
      : file.mimeType.includes('folder') ? '📁 資料夾'
      : file.mimeType.includes('document') ? '📄 文件'
      : '📎 其他';
    console.log(`${i + 1}. ${type}  ${file.name}`);
    console.log(`   ID: ${file.id}`);
    if (file.webViewLink) console.log(`   連結: ${file.webViewLink}`);
    console.log('');
  });
}

listFiles().catch(err => console.error('❌ 錯誤:', err.message));

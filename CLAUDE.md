# TB project 母資料夾

統包先生（TB）公司的固定 workspace。所有 TB 相關專案都放在這裡。

## 工作區結構規範

> 完整規範記在 `~/.claude/projects/.../memory/workspace_mother_subproject_convention.md`

- **母資料夾 = 一家公司**：TB project、dw project 各自獨立，不混
- **子專案 = 獨立 git repo**：每個子專案自帶 `.git/` + 自己的 GitHub remote
- **外層 `.gitignore`** 把子專案資料夾排除，母 git 不追蹤子專案內容
- **Claude 設定三層**：`~/.claude/`（全域）、此資料夾 `.claude/`（TB 公司共用）、子專案 `.claude/`（子專案專用）

## 目前的內容

### 🏗 主系統：週會管理系統（歷史原因放在母根層，綁母 `.git/`）

前後端 + 部署設定都在母資料夾根層，推到 `github.com/turnkey193/TB`、Zeabur project `tb-meeting`。

- `server.js` — Express 後端
- `src/` — React 19 + Vite 前端
- `index.html`、`vite.config.js`、`package.json`
- `Dockerfile`、`zbpack.json` — Zeabur 部署
- `.env` / `.env.example` — Supabase keys

> 未來想改成正統子專案結構時，要：
> 1. 新建 `tb-meeting/` 子資料夾，移入上述檔案
> 2. 子資料夾 `git init` + 新 GitHub remote
> 3. 更新 Zeabur 部署來源路徑
> 4. 母 `.gitignore` 加 `tb-meeting/`

### 📁 共用層（母資料夾，跨子專案用）

| 路徑 | 用途 |
|---|---|
| `.claude/` | Claude settings、skills、agents（TB 全公司共用） |
| `.mcp.json` | MCP server 設定（Supabase、Zeabur 等） |
| `docs/schema/` | Supabase schema 文件、ADR、pre-transfer snapshot |
| `scripts/` | 一次性腳本（如 `hash-existing-passwords.mjs`） |
| `supabase/migrations/` | 本地 SQL migration 鏡像（跟 Supabase 端同步） |
| `key/` | Service account / API key 檔案（**在 .gitignore 外，不進 git**） |

### 🔧 工具類資料夾

| 路徑 | 用途 |
|---|---|
| `drive工具/drive-explorer/` | Google Drive 目錄樹工具（目前**例外**被母 git 追蹤，Zeabur project `tb-drive`） |
| `會計工具/` | 會計對帳腳本（獨立功能、未進母 git） |
| `dev腳本/` | 讀 Google Sheets 的測試/除錯腳本 |

### 📚 資料與參考

| 路徑 | 用途 |
|---|---|
| `勞健保資料/` | 員工勞健保帳單、下載腳本 `download_bills.py` |
| `UI UX 參考資料/` | 設計參考 `DESIGN.md` |
| `archive/` | 舊 debug 截圖 / log，保留備查 |

### 🚧 子專案（規劃中）

| 路徑 | 狀態 | 用途 |
|---|---|---|
| `人資薪資打卡系統/` | 空資料夾，待 Phase 5 啟動 | 員工 GPS 打卡 + 薪資計算 |

### 🚫 自動忽略

這些不進 git，由 `.gitignore` 處理：

- `node_modules/`、`dist/`、`.playwright-mcp/`（build / cache）
- `.env`、`key/`（密碼金鑰）
- 所有未在 whitelist 的檔案（目前 `.gitignore` 是白名單模式）

## 開新子專案 SOP

```bash
cd "c:/Users/名御/Desktop/TB project"
mkdir 新子專案/
cd 新子專案/
git init
# 在 GitHub 建 repo
git remote add origin https://github.com/turnkey193/新子專案.git
# 在母資料夾的 .gitignore 不用改（已經是白名單模式，自動排除）
# 但為防未來有人改成黑名單，也可以顯式 ignore：
cd ..
echo "新子專案/" >> .gitignore    # 只有黑名單模式才需要
```

## 相關 Supabase 專案

- **Project ref**: `obgobetnlecbmypvfnsq`
- **Org**: `17310a3-png's Org`（FREE plan）
- **URL**: `https://obgobetnlecbmypvfnsq.supabase.co`
- Schema 細節見 `docs/schema/public.md`

## 重要 Zeabur 專案

- `tb-meeting`（service: tb-meeting）— 週會管理系統主站
- `tb-drive`（service: explorer）— Drive Explorer 工具

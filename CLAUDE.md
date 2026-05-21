# TB project 母資料夾

統包先生（TB）公司的固定 workspace。所有 TB 相關專案都放在這裡。

## 工作區結構規範

> 完整規範記在 `~/.claude/projects/.../memory/workspace_mother_subproject_convention.md`

- **母資料夾 = 一家公司**：TB project、dw project 各自獨立，不混
- **子專案 = 獨立 git repo**：每個子專案自帶 `.git/` + 自己的 GitHub remote（owner 統一 `17310a3-png`）
- **母 `.gitignore`** 是白名單模式：只放行 `CLAUDE.md`、`supabase/`、`docs/`、`drive工具/`，其餘全擋
- **Claude 設定三層**：`~/.claude/`（全域）、此資料夾 `.claude/`（TB 公司共用）、子專案 `.claude/`（子專案專用）

母 `.git/` 現在追蹤的只剩：母 CLAUDE.md / .gitignore / docs/ / supabase/migrations/ / drive工具/。

## 子專案總覽

### 已上線（Zeabur deployed）

| 資料夾 | GitHub | Zeabur project | 帳號表 / 用途 |
|---|---|---|---|
| `tb-meeting/` | `17310a3-png/TB-meeting` | `tb-meeting` | 週會管理 / `public.tb_users`（SSO 已接 Phase 1~3a） |
| `tb-org-dashboard/` | `17310a3-png/tb-org-dashboard` | `tb-org` | 組織儀表板 / `hr.employees`（SSO 已接） |
| `人資薪資打卡系統/` | `17310a3-png/TB-HR` | `tb-hr` | 人資打卡 / `hr.employees`（SSO 已接）⚠️ **資料夾名跟 service name 不一致**，但實質是 tb-hr |
| `tb-portal/` | `17310a3-png/tb-portal` | `tb-portal` | SSO 統一登入入口 + 權限矩陣 admin / `hr.employees` |
| `工作管理表小工具/` | `17310a3-png/TB-gantt` | `tb-gantt` | 甘特圖 / Google Sheets ⚠️ **資料夾名跟 service name 不一致** |
| `drive工具/drive-explorer/` | （在母 git，例外） | `tb-drive` | Google Drive 目錄樹工具 |

### 規劃中（有 GitHub repo 或已建 schema，但未部署）

| 資料夾 | GitHub | Schema | 狀態 |
|---|---|---|---|
| `線上報價單/` | `17310a3-png/tb-quotation` | `quotation`（476 品項已有資料）| Phase 0 開發中 |
| `專案-案件追蹤表/` | `17310a3-png/tb-cases` | `cases`（schema 已建、主表 0 筆）| Phase 0 完成、Phase 1.1 schema 已套 |

### 未版控的工具 / 資料夾

| 資料夾 | 用途 |
|---|---|
| `會計工具/` | 會計對帳腳本（獨立功能、未進 git） |
| `dev腳本/` | 讀 Google Sheets 的測試/除錯腳本（tb-meeting 相關，待整理） |
| `debug/` | 一次性 debug 腳本 |
| `企業組織/` | 設計稿 / zip 壓縮檔 |
| `入取通知書/` | 錄取通知書文件 |
| `表單自動化/` | n8n / Make 流程原資料 |

## 共用層（母資料夾，跨子專案用）

| 路徑 | 用途 |
|---|---|
| `.claude/` | Claude settings、skills、agents（TB 全公司共用） |
| `.claude/references/` | 設計/動畫/簡報品味守則（見下方〈設計指引〉） |
| `.mcp.json` | MCP server 設定（Supabase、Zeabur 等） |
| `docs/` | 跨專案文件（含 `HANDOFF_SSO_2026-05-20.md` SSO 接入移交說明） |
| `docs/schema/` | Supabase schema 文件、ADR、跨專案協調備忘 |
| `scripts/` | 一次性腳本（如 `hash-existing-passwords.mjs`） |
| `supabase/migrations/` | 本地 SQL migration 鏡像（跟 Supabase 端同步） |
| `key/` | Service account / API key 檔案（**在 .gitignore 外，不進 git**） |

## 資料與參考

| 路徑 | 用途 |
|---|---|
| `勞健保資料/` | 員工勞健保帳單、下載腳本 `download_bills.py` |
| `UI UX 參考資料/` | 設計參考 `DESIGN.md` |
| `archive/` | 舊 debug 截圖 / log，保留備查 |
| `google 表單/` | Google Forms 相關 |

## 設計指引（UI / 簡報 / 動畫 / 資訊圖）

做任何視覺交付物前，**先讀** `.claude/references/` 下相對應的檔案：

- `huashu-content-guidelines.md` — 字體禁用清單（Inter/Roboto/Arial 等）+ 冷門替代名單、字號層級、oklch 色彩
- `huashu-design-styles.md` — 20 種設計流派 DNA。用編號溝通最快（例：「走 17 號 Takram 風」勝於「走科技感」）
- `huashu-animation-pitfalls.md` — 動畫/錄影 14 條黃金律（做影片或互動原型前必查）

來源：手動精選自 [alchaincyf/huashu-design](https://github.com/alchaincyf/huashu-design) 的 `references/`，未裝整個 skill。

## 開新子專案 SOP

```bash
cd "c:/Users/名御/Desktop/TB project"
mkdir 新子專案/
cd 新子專案/
git init
# 在 GitHub 用 17310a3-png 帳號建 private 空 repo（不勾 README/gitignore/license）
git remote add origin https://github.com/17310a3-png/新子專案.git
# 母 .gitignore 是白名單模式，子資料夾自動被擋，不用改
```

新子專案接入 SSO 的合約規範見 `docs/schema/SSO_EXCHANGE_CONTRACT.md`（如果該檔已建立）。

## 相關 Supabase 專案

- **Project ref**: `obgobetnlecbmypvfnsq`
- **Org**: `17310a3-png's Org`（FREE plan）
- **URL**: `https://obgobetnlecbmypvfnsq.supabase.co`
- **使用中的 schema**:
  - `public` — tb-meeting 用（tb_users, tb_regions, tb_weekly_notes 等）
  - `hr` — tb-hr / tb-org / tb-portal 共用（employees, payslips, punches, employee_subsystem_access 等）
  - `cases` — tb-cases 規劃中
  - `quotation` — tb-quotation 規劃中

## 重要 Zeabur 專案

| Project | Service | 用途 |
|---|---|---|
| `tb-portal` | tb-portal | SSO 統一登入入口 |
| `tb-meeting` | tb-meeting | 週會管理系統 |
| `tb-hr` | tb-hr | 人資打卡 |
| `tb-org` | tb-org | 組織儀表板 |
| `tb-gantt` | tb-gantt | 甘特圖（資料夾名「工作管理表小工具」）|
| `tb-drive` | explorer | Drive Explorer |

## SSO 跨專案配置

所有子系統共用：
- 同一個 `JWT_SECRET`（在各 Zeabur service env vars）
- 同一個 `SUPABASE_SERVICE_KEY`（`sb_secret_*` 格式；legacy keys 2026-04-21 已停用）
- 同一個 Supabase project (`obgobetnlecbmypvfnsq`)

SSO 接入歷程與當前狀態見 `docs/HANDOFF_SSO_2026-05-20.md`。

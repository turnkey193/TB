# Database Schema Documentation

Supabase 專案：`obgobetnlecbmypvfnsq`

## Schema 總覽

| Schema | 用途 | 文件 |
|---|---|---|
| `public` | TB project 主系統（分店、使用者、案件、週會、請款、簽約、業績目標） | [public.md](public.md) |
| `hr` | 人資薪資打卡系統（Phase 5 建立，目前尚未存在） | [hr.md](hr.md) |

## 整理計畫

目前 `public` schema 有明顯的結構與安全問題。整理計畫在 `C:\Users\名御\.claude\plans\a-majestic-pixel.md`，分五個 Phase：

- **Phase 0**：Migration 追蹤與 schema 文件（← 目前）
- **Phase 1**：嚴重安全修復（金鑰、密碼）
- **Phase 2**：Region 正規化
- **Phase 3**：Enums + Timestamps
- **Phase 4**：RLS 政策

## 決策記錄

每個 Phase 做的關鍵決策記錄在 [decisions/](decisions/) 資料夾。

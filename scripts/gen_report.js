const fs = require('fs');
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
        Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType,
        ShadingType, PageNumber, PageBreak } = require('docx');

const border = { style: BorderStyle.SINGLE, size: 1, color: 'CCCCCC' };
const borders = { top: border, bottom: border, left: border, right: border };
const hdrShade = { fill: '2E4057', type: ShadingType.CLEAR };
const hdrFont = { bold: true, color: 'FFFFFF', font: 'Microsoft JhengHei', size: 20 };
const bodyFontS = { font: 'Microsoft JhengHei', size: 18 };
const cellM = { top: 60, bottom: 60, left: 100, right: 100 };

function makeRow(cells, widths, isHeader, shade) {
  return new TableRow({ children: cells.map((text, i) => new TableCell({
    borders, width: { size: widths[i], type: WidthType.DXA }, margins: cellM,
    shading: isHeader ? hdrShade : (shade ? { fill: shade, type: ShadingType.CLEAR } : undefined),
    children: [new Paragraph({ alignment: i > 0 ? AlignmentType.RIGHT : AlignmentType.LEFT,
      children: [new TextRun({ text, ...(isHeader ? hdrFont : bodyFontS) })] })]
  }))});
}

const W3 = [4000, 2680, 2680];
const W4 = [2600, 2400, 2200, 2160];
const W5 = [2800, 1600, 1600, 1600, 1600];

function h1(t) { return new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 300, after: 200 }, children: [new TextRun({ text: t, bold: true, font: 'Microsoft JhengHei', size: 28, color: '2E4057' })] }); }
function h2(t) { return new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 240, after: 160 }, children: [new TextRun({ text: t, bold: true, font: 'Microsoft JhengHei', size: 24, color: '2E4057' })] }); }
function p(t, opts) { return new Paragraph({ spacing: { after: 120 }, children: [new TextRun({ text: t, font: 'Microsoft JhengHei', size: 20, ...opts })] }); }
function b(t) { return new Paragraph({ spacing: { after: 80 }, indent: { left: 360 }, children: [new TextRun({ text: '  ' + t, font: 'Microsoft JhengHei', size: 18 })] }); }

const doc = new Document({
  styles: {
    default: { document: { run: { font: 'Microsoft JhengHei', size: 20 } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 28, bold: true }, paragraph: { spacing: { before: 300, after: 200 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 24, bold: true }, paragraph: { spacing: { before: 240, after: 160 }, outlineLevel: 1 } },
    ]
  },
  sections: [{
    properties: {
      page: { size: { width: 11906, height: 16838 }, margin: { top: 1200, right: 1100, left: 1100, bottom: 1200 } }
    },
    headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: '統包先生室內裝修有限公司 - 內部文件', font: 'Microsoft JhengHei', size: 16, color: '999999' })] })] }) },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: '第 ', size: 16, color: '999999' }), new TextRun({ children: [PageNumber.CURRENT], size: 16, color: '999999' }), new TextRun({ text: ' 頁', size: 16, color: '999999' })] })] }) },
    children: [
      // ===== 封面 =====
      new Paragraph({ spacing: { before: 3000 } }),
      new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: '進銷帳記帳方式與會計科目', bold: true, font: 'Microsoft JhengHei', size: 40, color: '2E4057' })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [new TextRun({ text: '分析與改善建議報告', bold: true, font: 'Microsoft JhengHei', size: 32, color: '2E4057' })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 600 }, children: [new TextRun({ text: '分析期間：2023/04 ~ 2026/04', font: 'Microsoft JhengHei', size: 22, color: '666666' })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: '資料筆數：17,593 筆', font: 'Microsoft JhengHei', size: 22, color: '666666' })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: '報告日期：2026/04/10', font: 'Microsoft JhengHei', size: 22, color: '666666' })] }),
      new Paragraph({ children: [new PageBreak()] }),

      // ===== 一、記帳架構理解 =====
      h1('一、現行記帳架構理解'),

      h2('1.1 記帳目的'),
      p('貴公司進銷帳的核心目的是：'),
      b('追蹤每個工程案場的收支，計算「工程總收入 - 工程總支出 = 案場毛利」'),
      b('案場毛利用於計算設計師/工務的結案獎金'),
      b('因此，所有與特定案場相關的支出（含保險、保證金、印花稅、開工拜拜等）都需掛在該案場'),
      p(''),
      p('這個邏輯完全合理。在室內裝修業，這些費用確實是為了完成特定案場而產生的直接成本，歸入案場計算獎金是正確的做法。'),

      h2('1.2 現行科目架構'),
      p('共 65 個會計科目，依功能可分為：'),
      new Table({ width: { size: 9360, type: WidthType.DXA }, columnWidths: W4, rows: [
        makeRow(['分類', '科目數', '代表科目', '狀態'], W4, true),
        makeRow(['案場成本', '1', '工程款-支出', '正常'], W4),
        makeRow(['案場收入', '2', '工程款-收入/支票', '正常'], W4),
        makeRow(['稅務', '4', '營業稅/營所稅/所得稅', '正常'], W4),
        makeRow(['薪資相關', '4', '薪資/獎金/健保/勞退', '正常'], W4),
        makeRow(['營業費用', '20+', '行銷/辦公/軟體/房租...', '部分需整理'], W4, false, 'FFF3E0'),
        makeRow(['帳務輔助', '6', '附件/內轉/匯費/沖銷', '正常'], W4),
        makeRow(['資產負債', '5', '保證金/貸款/投資', '需檢視'], W4, false, 'FFF3E0'),
        makeRow(['公司特殊', '5', '統包-員工預支/匯兌等', '需統一'], W4, false, 'FFF3E0'),
      ]}),

      h2('1.3 母帳-子帳拆帳機制'),
      p('銀行一筆付款 → 拆成多筆子帳（各案場未稅金額 + 營業稅 + 匯費），是進銷帳的核心特色。目前運作良好。'),

      new Paragraph({ children: [new PageBreak()] }),

      // ===== 二、問題發現 =====
      h1('二、發現的問題'),

      h2('2.1 科目命名不一致（低風險）'),
      p('少數科目有重複或命名不統一的情況：'),
      new Table({ width: { size: 9360, type: WidthType.DXA }, columnWidths: W3, rows: [
        makeRow(['重複科目', '使用次數', '建議'], W3, true),
        makeRow(['存出保證金（資產）/ 存出保證金', '4+1 筆', '統一名稱'], W3),
        makeRow(['庫存 / 系統櫃切貨 / 營業成本-庫存-大陸採購品', '2+4+23 筆', '統一為「營業成本-庫存」'], W3),
        makeRow(['營業費用-保險費（通用）', '6 筆', '改歸具體科目'], W3),
      ]}),
      p('影響：統計彙總時可能遺漏，但金額不大。建議有空時統一。'),

      h2('2.2 「統包-」系列科目（中風險）'),
      p('有 4 個以「統包-」為前綴的科目，共 85 筆：'),
      new Table({ width: { size: 9360, type: WidthType.DXA }, columnWidths: W4, rows: [
        makeRow(['科目', '筆數', '實際性質', '建議'], W4, true),
        makeRow(['統包-員工預支', '54', '員工借支/預支', '→ 其他應收款'], W4),
        makeRow(['統包-匯兌', '20', '人民幣匯兌', '→ 營業外-匯兌損益'], W4),
        makeRow(['統包-投資', '10', '公司投資', '→ 長期投資'], W4),
        makeRow(['統包-支票', '1', '支票付款', '→ 歸實際用途'], W4),
      ]}),
      p('問題：這些不是標準會計科目名稱。如果未來需要給會計師做帳或申報，會需要重新對應。'),
      p('建議：不急著改，但如果要做正式財務報表時需要轉換。'),

      h2('2.3 貸款未區分本金與利息（中風險）'),
      p('117 筆貸款記錄統一為「貸款-貸款繳本息」，未拆分本金償還與利息支出。'),
      b('本金：減少負債（長期借款），不影響損益'),
      b('利息：費用支出（營業外支出-利息費用），影響損益'),
      p('影響：如果全部當費用處理，會高估費用、低估淨利。如果全部不算費用，會低估利息支出。'),
      p('建議：可請銀行提供貸款攤還明細，每筆拆分本金與利息。'),

      h2('2.4 營業費用-其他費用 過於籠統（低風險）'),
      p('「營業費用-其他費用」有 230 筆，涵蓋內容太廣。建議細分：'),
      b('開工拜拜 → 如果掛案場，歸工程款-支出即可；如果不掛案場，歸營業費用-其他費用'),
      b('人力招聘（104人力銀行）→ 可歸「營業費用-人事費用」'),
      b('股東費用 → 可歸「營業費用-交際費」'),

      new Paragraph({ children: [new PageBreak()] }),

      // ===== 三、工程成本與獎金計算建議 =====
      h1('三、結案獎金計算的注意事項'),

      h2('3.1 目前計算方式'),
      p('結案獎金 = 工程總收入 - 工程總支出'),
      p('「工程總支出」包含所有掛在該案場的支出，含：工程款、保險、保證金、印花稅、開工拜拜、清潔等。'),

      h2('3.2 潛在風險'),
      p('以下項目需要特別留意對獎金計算的影響：'),
      new Table({ width: { size: 9360, type: WidthType.DXA }, columnWidths: [3200, 2000, 2000, 2160], rows: [
        makeRow(['項目', '性質', '對獎金影響', '建議'], [3200,2000,2000,2160], true),
        makeRow(['工程保證金', '付出→退回', '暫時減少利潤', '退回時要沖銷回來'], [3200,2000,2000,2160], false, 'FFF3E0'),
        makeRow(['工程保險', '固定成本', '減少利潤', '合理，但每案金額要核實'], [3200,2000,2000,2160]),
        makeRow(['印花稅', '固定成本', '減少利潤', '合理'], [3200,2000,2000,2160], false, 'FFF3E0'),
        makeRow(['營業稅', '代收代付', '不應影響', '確認案場不算營業稅'], [3200,2000,2000,2160]),
        makeRow(['匯費', '小額固定', '微影響', '目前掛統包先生，正確'], [3200,2000,2000,2160], false, 'FFF3E0'),
        makeRow(['追加減工程', '變動', '直接影響', '確認追加金額有收款'], [3200,2000,2000,2160]),
      ]}),

      h2('3.3 保證金沖銷追蹤'),
      p('工程保證金（64筆）是暫時性支出，完工驗收後社區會退還。', { bold: true }),
      b('付出時：掛在案場，減少該案毛利（暫時）'),
      b('退回時：要記得沖銷回來，恢復毛利'),
      b('風險：如果忘記沖銷，結案獎金會被低估'),
      p('建議：建立「保證金追蹤清單」，定期核對是否已退回。'),

      h2('3.4 結案時間點與成本歸屬'),
      p('部分案場有跨月支出（例如保固維修、尾款延遲付款），需注意：'),
      b('結案前：所有支出都計入毛利計算'),
      b('結案後：如有追加支出，是否影響已發放的獎金？'),
      b('建議：設定「獎金結算期限」，例如驗收結案後60天內的支出仍計入'),

      new Paragraph({ children: [new PageBreak()] }),

      // ===== 四、會計科目調整建議 =====
      h1('四、會計科目調整建議'),
      p('基於貴公司「以案場為中心計算獎金」的記帳目的，以下為適合的科目架構：'),

      h2('4.1 案場相關（掛案場地址）'),
      b('工程款-支出：水電/木工/油漆/泥作/系統櫃/拆除/磁磚/鋁窗/鐵工/玻璃/燈具/衛浴/廚具/石材/冷氣/大門/防水/材料行等'),
      b('工程款-收入：頭期款/二期款/三期款/四期款/五期款/尾款/追加減'),
      b('營業費用-保險費：工程保險/雇主意外險（案場保險）'),
      b('存出保證金：裝修保證金/工程保證金（付出掛案場，退回沖銷）'),
      b('營業費用-稅捐：印花稅（案場級別）'),
      b('營業費用-其他費用：開工拜拜（案場級別）'),

      h2('4.2 公司營運（掛統包先生）'),
      b('營業費用-薪資支出 / 營業費用-獎金支出'),
      b('營業費用-保險費-健保 / 營業費用-保險費-勞保 / 營業費用-退休金'),
      b('營業費用-房租'),
      b('營業費用-行銷-廣告費 / 行銷-剪輯 / 行銷-其他費用'),
      b('營業費用-軟體（月繳訂閱：ChatGPT/Gamma等）'),
      b('軟體開發（一次性開發費用）'),
      b('營業費用-辦公設備 / 儀器設備 / 文具與辦公耗材'),
      b('營業費用-電話及通訊費 / 停車費與交通費'),
      b('營業費用-會計服務費'),
      b('營業費用-水電費 / 修繕費'),
      b('營業費用-員工福利'),

      h2('4.3 營業外與資產負債（掛統包先生）'),
      b('營業外收入-利息收入'),
      b('貸款-本金（建議未來拆分）/ 貸款-利息'),
      b('營業成本-庫存（大陸採購品/系統櫃切貨）'),
      b('其他應收款（員工預支/代墊→改名自「統包-員工預支」）'),

      h2('4.4 帳務輔助（非會計科目）'),
      b('附件：拆帳母帳標記'),
      b('內轉：帳戶間調撥'),
      b('其他費用-匯費：銀行手續費'),
      b('匯款沖銷：帳號有誤退回'),
      b('營業稅：案場=營業稅'),

      new Paragraph({ children: [new PageBreak()] }),

      // ===== 五、需要統一的項目 =====
      h1('五、建議統一修正的項目'),
      p('以下為具體可執行的修正，按優先序排列：'),

      h2('優先級 A：命名統一'),
      new Table({ width: { size: 9360, type: WidthType.DXA }, columnWidths: [800, 3280, 3280, 2000], rows: [
        makeRow(['#', '現況', '統一為', '筆數'], [800,3280,3280,2000], true),
        makeRow(['1', '存出保證金（資產）', '存出保證金', '4筆'], [800,3280,3280,2000]),
        makeRow(['2', '庫存 / 系統櫃切貨', '營業成本-庫存', '6筆'], [800,3280,3280,2000]),
        makeRow(['3', '營業費用-保險費（通用）', '依內容歸入具體科目', '6筆'], [800,3280,3280,2000]),
      ]}),

      h2('優先級 B：未來可改（不急）'),
      new Table({ width: { size: 9360, type: WidthType.DXA }, columnWidths: [800, 3280, 3280, 2000], rows: [
        makeRow(['#', '現況', '建議', '筆數'], [800,3280,3280,2000], true),
        makeRow(['1', '統包-員工預支', '其他應收款-員工預支', '54筆'], [800,3280,3280,2000]),
        makeRow(['2', '統包-匯兌', '營業外損益-匯兌損益', '20筆'], [800,3280,3280,2000]),
        makeRow(['3', '統包-投資', '長期投資', '10筆'], [800,3280,3280,2000]),
        makeRow(['4', '貸款（本息合一）', '拆分本金+利息', '117筆'], [800,3280,3280,2000]),
      ]}),

      // ===== 六、總結 =====
      new Paragraph({ children: [new PageBreak()] }),
      h1('六、總結'),

      p('整體評估：', { bold: true, size: 22 }),
      p(''),
      p('貴公司的進銷帳記帳方式整體架構完善，特別是：'),
      b('母帳拆子帳機制：正確拆分案場、匯費、營業稅'),
      b('案場成本歸屬：工程保險/保證金/印花稅掛案場，符合獎金計算需求'),
      b('未稅/含稅分離：支出用未稅，營業稅獨立拆出'),
      b('匯費處理：10~30元匯費獨立標記'),
      p(''),
      p('主要需要注意的有三點：'),
      b('1. 保證金退回追蹤：避免結案獎金被低估'),
      b('2. 少數科目命名統一：存出保證金、庫存等有重複'),
      b('3. 貸款拆分：未來做正式財務報表時需要區分本金和利息'),
      p(''),
      p('這些調整都不影響目前的記帳流程，可以在日常維護中逐步處理。'),
    ]
  }]
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync('c:/Users/名御/Desktop/TB project/會計參考資料/進銷帳_會計科目分析報告.docx', buffer);
  console.log('已輸出: 會計參考資料/進銷帳_會計科目分析報告.docx');
});

const XLSX = require('xlsx');
const {google} = require('googleapis');

const auth = new google.auth.GoogleAuth({
  keyFile: 'c:/Users/名御/Desktop/TB project/key/huaaibot-key.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets.readonly']
});

(async () => {
  const sheets = google.sheets({version: 'v4', auth: await auth.getClient()});

  // ========== 地址修正表 ==========
  // ========== 請款單原始資料修正 ==========
  const dataFix = [
    { vendor: '又橙商行', address: '新北市三重區重新路二段14號5樓之6', field: 'untaxed', from: 15000, to: 15500 },
    { vendor: '李珮如', address: '筷子', field: 'untaxed', from: 147, to: 149 },
  ];

  const addrFix = {
    '新北市新店區中央路129號4樓之一': '新北市新店區中央路129號4樓之1',
    '北市大安區和平東路二段107巷16弄5號2樓': '台北市大安區和平東路二段107巷16弄5號2樓',
    '新北市秀山區秀山路53巷23弄2號1樓': '新北市汐止區秀山路53巷23弄2號1樓',
    '新北市板橋區新生街14號7樓': '新北市板橋區新生街14號7樓8樓',
    '新北市板橋區新生街14號7+8樓': '新北市板橋區新生街14號7樓8樓',
    '台北市中正區臨沂街24巷6號7樓': '台北市中正區臨沂街24巷6號4樓',
    '台北市中正區臨沂街24巷6號5樓': '台北市中正區臨沂街24巷6號4樓',
    '北市內湖區民權東路六段81巷17弄7號5樓': '台北市內湖區民權東路六段81巷17弄7號5樓',
    '新北市新莊區新莊路463巷2號': '新北市新莊區新莊路496巷2號',
    '台北市南港區松河街298號': '台北市南港區松河街298號7樓之2',
  };
  function fixAddr(addr) { return addrFix[addr] || addr; }

  // ========== 載入參考資料 ==========

  // 廠商清單
  const vendorRows = (await sheets.spreadsheets.values.get({
    spreadsheetId: '1zdWu2-DwjotXr6MM9dSdLJ5D6S0ij21-o1M0hE6rKUY', range: '廠商清單 資料'
  })).data.values.slice(1).map(r => ({
    acct: (r[0]||'').trim(), name: (r[1]||'').trim(), cat: (r[2]||'').trim(), holder: (r[6]||'').trim()
  }));
  const vendorDict = {};
  vendorRows.forEach(v => {
    if (v.name) vendorDict[v.name] = v.cat;
    if (v.holder && v.holder !== v.name) vendorDict[v.holder] = v.cat;
  });

  // 案件收款進度（含每期金額+收款日期）
  const allCases = (await sheets.spreadsheets.values.get({
    spreadsheetId: '1Y0UE9WpTqiaSQ4HOEsuhnNTMiI4Vn627PpVLpOYFgZ0', range: '案件收款進度'
  })).data.values.slice(1).map(r => ({
    caseNo: (r[1]||'').trim(), owner: (r[3]||'').trim(), address: (r[4]||'').trim(),
    progress: (r[28]||'').trim(),
    totalAmt: parseFloat(String(r[14]||'0').replace(/[$,\s]/g,''))||0,
    periods: [0,1,2,3,4].map(p => ({
      amt: parseFloat(String(r[16+p*2]||'0').replace(/[$,\s]/g,''))||0,
      date: (r[17+p*2]||'').trim()
    }))
  }));

  // ========== 讀取兩份請款名單 ==========
  // 解析請款名單 → vendorName → [[group1], [group2], ...]
  // 每次出現新的匯款日期 = 新的付款組
  function parseInvoiceFile(path) {
    const wb = XLSX.readFile(path, {codepage: 950});
    const data = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], {header: 1, defval: ''});
    const result = {}; // vendorName → [[items], [items], ...]
    let curV = '', curT = '';
    for (const row of data.slice(1)) {
      const type = String(row[0]||'').trim(), vendor = String(row[1]||'').trim();
      let addr = String(row[2]||'').trim();
      const noteCol = String(row[6]||'').trim();
      const payDate = String(row[7]||'').trim();
      const untaxed = parseFloat(String(row[3]||'').replace(/＄|,/g,'')) || 0;
      const tax = parseFloat(String(row[4]||'').replace(/＄|,/g,'')) || 0;
      const total = parseFloat(String(row[5]||'').replace(/＄|,/g,'')) || (untaxed + tax);
      if (type === '工種') { curT = ''; curV = ''; continue; }
      if (!untaxed && !total) continue;
      if (type) curT = type;
      if (type && !vendor) curV = addr || type;
      if (vendor) { curV = vendor; if (!type) curT = ''; }
      if (total && !isNaN(total) && curV) {
        addr = fixAddr(addr);
        const finalUntaxed = (untaxed === 0 && tax === 0 && total > 0) ? total : untaxed;
        if (!result[curV]) result[curV] = [];
        // 開新group條件：vendor欄有值（同名重新出現=新付款組）
        const lastGroup = result[curV][result[curV].length - 1];
        if (vendor && payDate) {
          const g = [];
          g._payDate = payDate || '';
          result[curV].push(g);
        } else if (!result[curV].length) {
          const g = [];
          g._payDate = payDate || '';
          result[curV].push(g);
        }
        if (payDate && result[curV].length) result[curV][result[curV].length - 1]._payDate = payDate;
        result[curV][result[curV].length - 1].push({ type: curT, address: addr, untaxed: finalUntaxed, tax, total, note: noteCol });
      }
    }
    return result;
  }

  const inv0325 = parseInvoiceFile('c:/Users/名御/Desktop/TB project/會計參考資料/115325廠商請款名單.xlsx');
  const inv0425 = parseInvoiceFile('c:/Users/名御/Desktop/TB project/會計參考資料/115425廠商請款名單.xlsx');

  // 套用資料修正
  for (const fix of dataFix) {
    for (const invMap of [inv0325, inv0425]) {
      for (const [vn, groups] of Object.entries(invMap)) {
        if (!vn.includes(fix.vendor) && !fix.vendor.includes(vn)) continue;
        for (const group of groups) {
          for (const it of group) {
            if (it.address.includes(fix.address) || fix.address.includes(it.address)) {
              if (it[fix.field] === fix.from) {
                it[fix.field] = fix.to;
                it.total = it.untaxed + it.tax;
              }
            }
          }
        }
      }
    }
  }

  // 記錄已使用的group，避免重複配對
  const usedGroups = new Set();

  // ========== 暱稱對照表（請款單暱稱 → 銀行戶名）==========
  const nickMap = {
    '曾俊豪': '豪哥',
    '朱冠宇': '小朱',
    '陳其禎': '阿其',
    '黃繪家': '昌之友', // 昌之友 = 黃繪家的公司
    '寶宸泥作工程行洪偉峰': '寶宸泥做工程行',
    '景諒會計師事務所林景諒': '景諒會計事務所',
    '齡(君+羊)企業有限公司': '齡群',
    'CHRISTOPHER KONG ZONG SHENG': 'ck',
    '俞民萍': '阿珠',
    '景新有限公司': '景新系統', // 3/17那筆 $583,285 是景新系統
  };
  // 反向：暱稱→銀行戶名
  const nickReverse = {};
  for (const [bank, nick] of Object.entries(nickMap)) nickReverse[nick] = bank;

  // ========== 工具函數 ==========

  const catMap = {
    '水電':'工程款-支出','木工':'工程款-支出','油漆':'工程款-支出','泥作':'工程款-支出','泥做':'工程款-支出',
    '系統櫃':'工程款-支出','清潔':'工程款-支出','拆除':'工程款-支出','燈具':'工程款-支出',
    '磁磚':'工程款-支出','鋁窗':'工程款-支出','鐵工':'工程款-支出','玻璃':'工程款-支出',
    '衛浴':'工程款-支出','廚具':'工程款-支出','石材':'工程款-支出','冷氣':'工程款-支出',
    '大門':'工程款-支出','防水':'工程款-支出','不鏽鋼':'工程款-支出','鋁門':'工程款-支出',
    '石膏磚':'工程款-支出','木皮修補':'工程款-支出','地板':'工程款-支出',
    '百葉窗':'工程款-支出','鏡櫃訂做':'工程款-支出','漏水檢測':'工程款-支出',
    '五金':'工程款-支出','材料行':'工程款-支出','洗孔廠商':'工程款-支出',
    '衛浴設備':'工程款-支出','系統組裝':'工程款-支出','浴櫃':'工程款-支出',
    '地磚/壁紙':'工程款-支出','石膏磚/地板':'工程款-支出','塑膠地板':'工程款-支出',
    '泥作/拆除':'工程款-支出','鋁門/鋁窗':'工程款-支出','鋁框門':'工程款-支出','鋁框美容':'工程款-支出',
    '木地板':'工程款-支出','招牌':'工程款-支出','建築師':'工程款-支出',
    '目錄樣品':'營業費用-其他費用','保證金':'存出保證金',
    '工程保險':'營業費用-保險費','工程保證金':'存出保證金',
    '雇主意外':'營業費用-保險費','工程險':'營業費用-保險費',
    '文具':'營業費用-文具與辦公耗材','公司':'內轉',
    '公會':'營業費用-其他費用','BNI':'營業費用-其他費用',
    '薪資':'營業費用-薪資支出','行銷':'營業費用-行銷-廣告費','行銷團隊':'營業費用-行銷-廣告費',
    '會計師':'營業費用-會計服務費','會計費':'營業費用-會計服務費',
    '事務機':'營業費用-辦公設備','影印機':'營業費用-辦公設備',
    '房租':'營業費用-房租','板橋房租':'營業費用-房租',
    '採購':'營業費用-其他費用','軟體':'營業費用-軟體',
    '切貨':'營業成本-庫存','系統櫃切貨':'營業成本-庫存',
  };

  function matchVendor(name) {
    if (!name) return null;
    if (vendorDict[name]) return { name, category: vendorDict[name] };
    for (const [vn, vc] of Object.entries(vendorDict)) {
      if (name.includes(vn) || vn.includes(name)) return { name: vn, category: vc };
    }
    for (const v of vendorRows) {
      if (v.holder && v.holder.length >= 2 && (name.includes(v.holder) || v.holder.includes(name)))
        return { name: v.name || v.holder, category: v.cat };
    }
    return null;
  }

  function matchAddr(addr) {
    if (!addr) return null;
    const fixed = fixAddr(addr);
    let c = allCases.find(c => c.address === fixed);
    if (c) return c;
    c = allCases.find(c => c.address && (c.address.includes(fixed) || fixed.includes(c.address)));
    return c || null;
  }

  // 收入匯款人 → 案號對照（銀行戶名與業主不同的情況）
  const incomeMap = {
    '通通工作室': 'A115012',      // 羅戴爾 頭期款
    '米尼旅店有': 'A114061',      // 王永 三期款
    '林國緯': 'A115004',          // 林國瑋 二期款
    '凱崴科技有': 'A115006',      // 福國路 二期款
    '0055439502286000': 'A115011', // 謝宇柔 頭期款
    '0000240008010614': 'A114065', // 廖宜緯 四期款
    '0000454168734701': 'A115001', // 潘建融 三期款
    '黃亞妹': 'A114051',          // 陳國印 四期款
    '陳儀華': 'A115015',          // 陳國司 頭期款
    '廖文聖': 'A114056',          // 廖美芳 三期款
    '0000014357074992': 'A114060', // 沈佩娟 三期款
  };

  // 特殊戶名分類（非收入、非廠商）
  const specialMap = {
    '徐楚涵': { kind: '營業費用-薪資支出', item: '3月薪資', site: '統包先生' },
  };

  // 收入期數手動覆蓋（收款進度尚未更新的）
  const periodOverride = {
    '梁瑞玉': '工程三期款',
  };

  function matchOwner(name) {
    if (!name) return null;
    // 1. 先查對照表
    const caseNo = incomeMap[name];
    if (caseNo) {
      const c = allCases.find(c => c.caseNo === caseNo);
      if (c) return c;
    }
    // 2. 再查業主名
    return allCases.find(c => c.owner && (c.owner === name || name.includes(c.owner) || c.owner.includes(name))) || null;
  }

  const pendingMatches = [];

  // 模糊匹配請款名單（含暱稱對照）
  function searchInMap(name, invMap) {
    if (invMap[name]) return invMap[name];
    // 暱稱對照
    const nick = nickMap[name];
    if (nick && invMap[nick]) return invMap[nick];
    // 模糊
    for (const [vn, items] of Object.entries(invMap)) {
      if (name.includes(vn) || vn.includes(name)) return items;
      if (nick && (nick.includes(vn) || vn.includes(nick))) return items;
    }
    return null;
  }

  function findInv(bankName, date, bankAmt, forceMatch = false) {
    if (!bankName) return null;
    const day = parseInt((date||'').split('/')[2]) || 0;
    const month = parseInt((date||'').split('/')[1]) || 0;
    const primary = (month === 3 && day <= 25) || month < 3 ? inv0325 :
                    (month === 3 && day > 25) || month > 3 ? inv0425 : inv0325;
    const secondary = primary === inv0325 ? inv0425 : inv0325;

    // 找所有候選 group（同名/暱稱），用金額挑最接近的，且未被使用過
    const candidates = [];
    for (const invMap of [primary, secondary]) {
      for (const [vn, groups] of Object.entries(invMap)) {
        const nick = nickMap[bankName];
        const nameMatch = vn === bankName || bankName.includes(vn) || vn.includes(bankName) ||
            (nick && (vn === nick || vn.includes(nick) || nick.includes(vn)));
        if (!nameMatch) continue;
        for (let gi = 0; gi < groups.length; gi++) {
          const groupKey = vn + '|' + gi + '|' + (invMap === inv0325 ? '0325' : '0425');
          if (usedGroups.has(groupKey)) continue; // 已用過
          const items = groups[gi];
          const invTotal = items.reduce((s, it) => s + it.untaxed + it.tax, 0);
          candidates.push({ groupKey, items, invTotal, diff: Math.abs(bankAmt - invTotal) });
        }
      }
    }
    if (!candidates.length) return null;
    candidates.sort((a, b) => a.diff - b.diff);
    const best = candidates[0];
    // 如果有其他銀行交易更適合這個group（差額更小），先不搶
    // → 只配差額 ≤ 30 的（匯費範圍），其餘保留給更接近的交易
    if (best.diff > 30 && !forceMatch) {
      // 暫存候選，第二輪再配
      pendingMatches.push({ bankName, bankAmt, date, best });
      return null;
    }
    const tolerance = Math.max(50, best.invTotal * 0.05);
    if (best.diff > tolerance) return null;
    usedGroups.add(best.groupKey);
    return best.items;
  }

  function smartClassify(desc) {
    if (!desc) return null;
    if (/gamma|openai|chatgpt|line bot|app/i.test(desc)) return { kind: '營業費用-軟體', item: desc };
    if (/104|人力銀行/.test(desc)) return { kind: '營業費用-其他費用', item: desc };
    if (/機票|車票|esim|來回/.test(desc)) return { kind: '營業費用-停車費與交通費', item: desc };
    if (/拜拜|金紙|鞭炮/.test(desc)) return { kind: '營業費用-其他費用', item: desc };
    if (/午餐|口香糖|飲料|冷萃|水果|肉肉|麻糬|花生|筷子|肉骨茶/.test(desc)) return { kind: '營業費用-其他費用', item: desc };
    if (/衛生紙|垃圾袋|原子筆|紅包袋|電池|打卡機|文具|噴漆/.test(desc)) return { kind: '營業費用-文具與辦公耗材', item: desc };
    if (/咖啡機|膠囊|湯鍋|碗|湯勺|傢俱/.test(desc)) return { kind: '營業費用-辦公設備', item: desc };
    if (/門號|遠傳/.test(desc)) return { kind: '營業費用-電話及通訊費', item: desc };
    if (/蝦皮|酷澎/.test(desc)) return { kind: '營業費用-其他費用', item: desc };
    if (/股東/.test(desc)) return { kind: '營業費用-其他費用', item: desc };
    if (/人民幣/.test(desc)) return { kind: '營業費用-其他費用', item: desc };
    if (/排風扇/.test(desc)) return { kind: '工程款-支出', item: '水電' };
    return null;
  }

  function getKind(cat, summary) {
    if (catMap[cat]) return catMap[cat];
    if (summary) {
      if (summary.includes('利息')) return '營業外收入-利息收入';
      if (summary.includes('放款') || summary.includes('貸款')) return '貸款';
      if (summary.includes('健保')) return '營業費用-保險費-健保';
      if (summary.includes('勞保')) return '營業費用-保險費-勞保';
      if (summary.includes('勞退')) return '營業費用-退休金';
      if (summary.includes('電話')) return '營業費用-電話及通訊費';
      if (summary.includes('台水')) return '營業費用-其他費用';
      if (summary.includes('薪資')) return '附件';
    }
    return '';
  }

  function fmt(n) {
    if (!n || n === 0) return ' ';
    return ' $ ' + Number(n).toLocaleString() + ' ';
  }

  // ========== 內轉匯費拆帳 ==========
  function buildInternalTransfer(bank, pid, date, summary, out, inp, bal, bankCode, acct, note, label, month) {
    const amt = out || inp;
    // 跨行轉帳費通常是 15 或 30，取整數部分判斷
    const round = Math.round(amt / 1000) * 1000; // 取千位整數
    const fee = amt - round;
    if (fee > 0 && fee <= 30) {
      // 有匯費 → 拆母帳+子帳
      result.push([bank, pid, date, summary, fmt(out), fmt(inp), fmt(bal), bankCode, acct, note, '附件', label, '附件', '', '', month]);
      result.push([bank, pid+'-1', date, summary, out ? fmt(round) : ' ', inp ? fmt(round) : ' ', fmt(bal), bankCode, acct, note, '內轉', label, '統包先生', '', '', month]);
      result.push([bank, pid+'-2', date, summary, fmt(fee), ' ', fmt(bal), bankCode, acct, note, '其他費用-匯費', label, '統包先生', '', '', month]);
    } else {
      result.push([bank, pid, date, summary, fmt(out), fmt(inp), fmt(bal), bankCode, acct, note, '內轉', label, '統包先生', '', '', month]);
    }
  }

  // ========== 判斷收款期數 ==========
  function detectPeriod(cm, inp, payerName) {
    // 手動覆蓋
    if (payerName && periodOverride[payerName]) return periodOverride[payerName];
    const pNames = ['工程頭期款','工程二期款','工程三期款','工程四期款','工程五期款'];
    // 1. 找金額完全匹配的未收期數
    for (let p = 0; p < 5; p++) {
      if (cm.periods[p].amt && !cm.periods[p].date && Math.abs(cm.periods[p].amt - inp) < 100) {
        return pNames[p];
      }
    }
    // 2. 找金額完全匹配的（含已收）
    for (let p = 0; p < 5; p++) {
      if (cm.periods[p].amt && Math.abs(cm.periods[p].amt - inp) < 100) {
        return pNames[p];
      }
    }
    // 3. 找第一個未收的期數（金額不完全匹配但最接近）
    let bestP = -1, bestDiff = Infinity;
    for (let p = 0; p < 5; p++) {
      if (cm.periods[p].amt && !cm.periods[p].date) {
        const diff = Math.abs(cm.periods[p].amt - inp);
        if (diff < bestDiff) { bestDiff = diff; bestP = p; }
      }
    }
    if (bestP >= 0 && bestDiff < cm.totalAmt * 0.1) return pNames[bestP];
    return '待確認期數';
  }

  // ========== 工程款收入拆稅 ==========
  function buildIncomeWithTax(bank, pid, date, summary, inp, bal, bankCode, acct, note, pName, caseSite, caseNo, month) {
    const untaxed = Math.round(inp / 1.05);
    const tax = inp - untaxed;
    result.push([bank, pid, date, summary, ' ', fmt(inp), fmt(bal), bankCode, acct, note, '附件', pName, '附件', '', '', month]);
    result.push([bank, pid+'-1', date, summary, ' ', fmt(untaxed), fmt(bal), bankCode, acct, note, '工程款-收入', pName, caseSite, '', caseNo, month]);
    result.push([bank, pid+'-2', date, summary, ' ', fmt(tax), fmt(bal), bankCode, acct, note, '營業稅', pName, '營業稅', '', '', month]);
  }

  // ========== 拆帳子帳 ==========
  function buildSubs(bank, pid, date, summary, bal, bankCode, acct, note, items, month) {
    const rows = [];
    let si = 1;
    for (const it of items) {
      let kind, itemName;
      if (it.type && catMap[it.type]) {
        kind = catMap[it.type]; itemName = it.type;
      } else {
        const smart = smartClassify(it.address);
        if (smart) { kind = smart.kind; itemName = smart.item; }
        else {
          const vm = matchVendor(note);
          kind = vm ? getKind(vm.category, '') : '工程款-支出';
          itemName = vm ? vm.category : (it.type || '');
        }
      }

      // 員工代墊判斷：廠商是薪資人員 + 項目有案場地址 → 算工程款-支出
      const vm0 = matchVendor(note);
      const isEmployee = vm0 && vm0.category === '薪資';
      const hasProjectAddr = matchAddr(it.address);
      if (isEmployee && hasProjectAddr) {
        kind = '工程款-支出';
        itemName = it.note || it.address;
      }

      const isOpex = kind.startsWith('營業費用') || kind.startsWith('存出');
      let caseSite, caseNo = '';
      if (isOpex) {
        caseSite = '統包先生'; itemName = it.address || itemName;
      } else {
        const cm = matchAddr(it.address);
        caseSite = cm ? cm.address : fixAddr(it.address);
        caseNo = cm ? cm.caseNo : '';
      }
      // 未稅子帳
      rows.push([bank, pid+'-'+si, date, summary, fmt(it.untaxed), ' ', fmt(bal), bankCode, acct, note, kind, itemName, caseSite, it.note, caseNo, month]);
      si++;
      // 營業稅子帳
      if (it.tax > 0) {
        rows.push([bank, pid+'-'+si, date, summary, fmt(it.tax), ' ', fmt(bal), bankCode, acct, note, '營業稅', itemName, '營業稅', '', '', month]);
        si++;
      }
    }
    const invTotal = items.reduce((s, it) => s + it.untaxed + it.tax, 0);
    return { rows, si, invTotal };
  }

  // ========== 產出 ==========
  const result = [];
  result.push(['銀行','編號','交易日期','摘要','提','存','餘額','銀行代號','帳號','戶名','種類','品項','案場','附註','案號','月份']);

  // ===== 永豐銀行 =====
  const wb1 = XLSX.readFile('c:/Users/名御/Desktop/TB project/會計參考資料/永豐銀行 .xls', {codepage: 950});
  const d1 = XLSX.utils.sheet_to_json(wb1.Sheets[wb1.SheetNames[0]], {header: 1, defval: ''});

  // 預掃：找同天同戶名一出一進的退回配對
  const returnedRows = new Set();
  const allTxns = [];
  for (let i = 3; i < d1.length; i++) {
    const date = String(d1[i][2]||'').trim();
    const out = d1[i][5] ? Number(d1[i][5]) : 0;
    const inp = d1[i][6] ? Number(d1[i][6]) : 0;
    const note = String(d1[i][9]||'').trim();
    if (date && date !== '總計') allTxns.push({ row: i, date, out, inp, note });
  }
  for (const t of allTxns) {
    if (t.out > 0 && !returnedRows.has(t.row)) {
      const match = allTxns.find(m => m.row !== t.row && m.date === t.date && m.note === t.note && m.inp === t.out && !returnedRows.has(m.row));
      if (match) { returnedRows.add(t.row); returnedRows.add(match.row); }
    }
  }

  let seq = 1, _inv = null;
  for (let i = 3; i < d1.length; i++) {
    const r = d1[i];
    const date = String(r[2]||'').trim(), summary = String(r[3]||'').trim();
    const out = r[5] ? Number(r[5]) : 0, inp = r[6] ? Number(r[6]) : 0, bal = r[7] ? Number(r[7]) : 0;
    const note = String(r[9]||'').trim();
    if (!date || date === '總計' || date === '幣別' || (!out && !inp && !bal)) continue;

    const bank = '永豐-統包', acct = '13301800117486';
    const month = '2026年' + parseInt(date.split('/')[1]) + '月';
    const isInternal = note === '0500000002712052670';
    const isSelf = note === '統包先生室內裝修有限公司';

    if (returnedRows.has(i)) {
      // 匯款被退回（帳號有誤），標記沖銷
      result.push([bank, String(seq), date, summary, fmt(out), fmt(inp), fmt(bal), '', acct, note, '匯款沖銷', '帳號有誤退回', '統包先生', '', '', month]);
    } else if (isInternal) {
      buildInternalTransfer(bank, String(seq), date, summary, out, inp, bal, '', acct, note, inp ? '台企轉永豐' : '永豐轉台企', month);
    } else if (isSelf) {
      result.push([bank, String(seq), date, summary, fmt(out), fmt(inp), fmt(bal), '', acct, note, '內轉', '公司自轉', '統包先生', '', '', month]);
    } else if (summary === '利息存入') {
      result.push([bank, String(seq), date, summary, ' ', fmt(inp), fmt(bal), '', acct, note, '營業外收入-利息收入', '利息收入', '統包先生', '', '', month]);
    } else if (summary === '薪資扣款') {
      result.push([bank, String(seq), date, summary, fmt(out), ' ', fmt(bal), '', acct, note, '附件', '薪資', '附件', '', '', month]);
    } else if (note === '俞民萍' && out === 30010) {
      const pid = String(seq);
      result.push([bank, pid, date, summary, fmt(30010), ' ', fmt(bal), '', acct, note, '附件', '清潔', '附件', '', '', month]);
      result.push([bank, pid+'-1', date, summary, fmt(6000), ' ', fmt(bal), '', acct, note, '工程款-支出', '清潔', '新北市中和區中正路872號7樓', '', 'A114055', month]);
      result.push([bank, pid+'-2', date, summary, fmt(12000), ' ', fmt(bal), '', acct, note, '工程款-支出', '清潔', '新北市永和區永貞路417巷17號3樓', '', 'A114052', month]);
      result.push([bank, pid+'-3', date, summary, fmt(12000), ' ', fmt(bal), '', acct, note, '工程款-支出', '清潔', '新北市板橋區四川路一段268號', '', '', month]);
      result.push([bank, pid+'-4', date, summary, fmt(10), ' ', fmt(bal), '', acct, note, '其他費用-匯費', '清潔', '統包先生', '', '', month]);
    } else if (note === '俞民萍' && out === 1010) {
      const pid = String(seq);
      result.push([bank, pid, date, summary, fmt(1010), ' ', fmt(bal), '', acct, note, '附件', '清潔', '附件', '', '', month]);
      result.push([bank, pid+'-1', date, summary, fmt(1000), ' ', fmt(bal), '', acct, note, '工程款-支出', '清潔', '新北市板橋區四川路一段268號', '', '', month]);
      result.push([bank, pid+'-2', date, summary, fmt(10), ' ', fmt(bal), '', acct, note, '其他費用-匯費', '清潔', '統包先生', '', '', month]);
    } else if (note === '俞民萍' && out === 8010) {
      const pid = String(seq);
      result.push([bank, pid, date, summary, fmt(8010), ' ', fmt(bal), '', acct, note, '附件', '清潔', '附件', '', '', month]);
      result.push([bank, pid+'-1', date, summary, fmt(8000), ' ', fmt(bal), '', acct, note, '工程款-支出', '清潔', '新北市中和區中原五街38號6樓', '', 'A115009', month]);
      result.push([bank, pid+'-2', date, summary, fmt(10), ' ', fmt(bal), '', acct, note, '其他費用-匯費', '清潔', '統包先生', '', '', month]);
    } else if (out > 0 && ((_inv = findInv(note, date, out)) !== null)) {
      const items = _inv;
      const pid = String(seq);
      const parentItem = items.find(it => it.type)?.type || note;

      if (items.length === 1 && items[0].tax === 0) {
        const it = items[0];
        let kind, itemName;
        if (it.type && catMap[it.type]) { kind = catMap[it.type]; itemName = it.type; }
        else { const s = smartClassify(it.address); kind = s?.kind || '工程款-支出'; itemName = s?.item || it.type || ''; }
        const isOpex = kind.startsWith('營業費用') || kind.startsWith('存出');
        const cm = matchAddr(it.address);
        const caseSite = isOpex ? '統包先生' : (cm ? cm.address : fixAddr(it.address));
        const caseNo = isOpex ? '' : (cm?.caseNo || '');
        if (isOpex) itemName = it.address || itemName;
        const fee = out - it.untaxed;
        if (fee > 0) {
          result.push([bank, pid, date, summary, fmt(out), ' ', fmt(bal), '', acct, note, '附件', parentItem, '附件', '', '', month]);
          result.push([bank, pid+'-1', date, summary, fmt(it.untaxed), ' ', fmt(bal), '', acct, note, kind, itemName, caseSite, it.note, caseNo, month]);
          result.push([bank, pid+'-2', date, summary, fmt(fee), ' ', fmt(bal), '', acct, note, '其他費用-匯費', parentItem, '統包先生', '', '', month]);
        } else {
          result.push([bank, pid, date, summary, fmt(out), ' ', fmt(bal), '', acct, note, kind, itemName, caseSite, it.note, caseNo, month]);
        }
      } else {
        result.push([bank, pid, date, summary, fmt(out), ' ', fmt(bal), '', acct, note, '附件', parentItem, '附件', '', '', month]);
        const { rows, si, invTotal } = buildSubs(bank, pid, date, summary, bal, '', acct, note, items, month);
        rows.forEach(r => result.push(r));
        const fee = out - invTotal;
        if (fee > 0) result.push([bank, pid+'-'+si, date, summary, fmt(fee), ' ', fmt(bal), '', acct, note, '其他費用-匯費', parentItem, '統包先生', '', '', month]);
      }
    } else if (inp > 0) {
      const cm = matchOwner(note);
      if (cm) {
        const pName = detectPeriod(cm, inp, note);
        buildIncomeWithTax(bank, String(seq), date, summary, inp, bal, '', acct, note, pName, cm.address, cm.caseNo, month);
      } else {
        result.push([bank, String(seq), date, summary, ' ', fmt(inp), fmt(bal), '', acct, note, '', '', '', '', '', month]);
      }
    } else if (specialMap[note]) {
      const sp = specialMap[note];
      result.push([bank, String(seq), date, summary, fmt(out), fmt(inp), fmt(bal), '', acct, note, sp.kind, sp.item, sp.site, '', '', month]);
    } else {
      const vm = matchVendor(note);
      let kind = vm ? getKind(vm.category, summary) : getKind('', summary);
      let item = vm ? vm.category : '';
      if (!kind) { const s = smartClassify(note+' '+summary); if (s) { kind = s.kind; item = s.item; } }
      const isOpex = kind && (kind.startsWith('營業費用') || kind === '貸款');
      const caseSite = isOpex ? '統包先生' : '';
      result.push([bank, String(seq), date, summary, fmt(out), fmt(inp), fmt(bal), '', acct, note, kind, item, caseSite, '', '', month]);
    }
    seq++;
  }

  // ===== 台企銀行 =====
  const wb2 = XLSX.readFile('c:/Users/名御/Desktop/TB project/會計參考資料/統包-台企帳戶明細查詢.xls', {codepage: 950});
  const d2 = XLSX.utils.sheet_to_json(wb2.Sheets[wb2.SheetNames[0]], {header: 1, defval: ''});

  let seq2 = 1;
  for (let i = 10; i < d2.length; i++) {
    const r = d2[i];
    let date = String(r[0]||'').trim();
    if (!date || date === '合計') continue;
    const m = date.match(/^(\d+)\/(\d+)\/(\d+)$/);
    if (m) date = (parseInt(m[1])+1911)+'/'+m[2].padStart(2,'0')+'/'+m[3].padStart(2,'0');

    const summary = String(r[1]||'').trim();
    const out = parseFloat(String(r[2]||'').replace(/,/g,'')) || 0;
    const inp = parseFloat(String(r[3]||'').replace(/,/g,'')) || 0;
    const bal = parseFloat(String(r[4]||'').replace(/,/g,'')) || 0;
    const dataContent = String(r[6]||'').trim(), bankCode = String(r[7]||'').trim();
    const bank = '台企-統包', acct = '02712052670';
    const month = '2026年' + parseInt(date.split('/')[1]) + '月';

    if (dataContent === '13301800117486') {
      buildInternalTransfer(bank, String(seq2), date, summary, out, inp, bal, bankCode, acct, dataContent, out ? '台企轉永豐' : '永豐轉台企', month);
    } else if (summary === '健保費') {
      result.push([bank, String(seq2), date, summary, fmt(out), ' ', fmt(bal), bankCode, acct, dataContent, '營業費用-保險費-健保', '健保', '統包先生', '', '', month]);
    } else if (summary === '勞保費') {
      result.push([bank, String(seq2), date, summary, fmt(out), ' ', fmt(bal), bankCode, acct, dataContent, '營業費用-保險費-勞保', '勞保', '統包先生', '', '', month]);
    } else if (summary === '勞退費') {
      result.push([bank, String(seq2), date, summary, fmt(out), ' ', fmt(bal), bankCode, acct, dataContent, '營業費用-退休金', '勞退', '統包先生', '', '', month]);
    } else if (summary === '電話費') {
      result.push([bank, String(seq2), date, summary, fmt(out), ' ', fmt(bal), bankCode, acct, dataContent, '營業費用-電話及通訊費', '電話費', '統包先生', '', '', month]);
    } else if (inp > 0) {
      const cleanName = dataContent.replace(/^\d+/, '').replace(/簽約$/, '').trim();
      const cm = matchOwner(cleanName) || matchOwner(dataContent);
      if (cm) {
        const pName = detectPeriod(cm, inp, cleanName || dataContent);
        buildIncomeWithTax(bank, String(seq2), date, summary, inp, bal, bankCode, acct, dataContent, pName, cm.address, cm.caseNo, month);
      } else {
        buildIncomeWithTax(bank, String(seq2), date, summary, inp, bal, bankCode, acct, dataContent, '待確認', '', '', month);
      }
    } else if (out > 0 && summary === '轉帳' && !dataContent && out > 1000000) {
      // 台企大額轉帳無戶名 → 內轉到永豐
      buildInternalTransfer(bank, String(seq2), date, summary, out, 0, bal, bankCode, acct, dataContent || '永豐帳戶', '台企轉永豐', month);
    } else if (out > 0) {
      result.push([bank, String(seq2), date, summary, fmt(out), ' ', fmt(bal), bankCode, acct, dataContent, '', '', '', '', '', month]);
    }
    seq2++;
  }

  // ========== 用 ExcelJS 寫出（支援樣式）==========
  const ExcelJS = require('exceljs');
  const exWb = new ExcelJS.Workbook();
  const exWs = exWb.addWorksheet('進銷帳-待確認');

  const colWidths = [12,8,12,12,14,14,16,8,18,28,24,20,44,16,10,12];
  colWidths.forEach((w, i) => { exWs.getColumn(i + 1).width = w; });

  const blueFont = { color: { argb: 'FF0000FF' } };
  const blackBold = { bold: true };
  const yellowFill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFFF00' } };

  // ===== 驗算：找出有問題的母帳組 =====
  // 用 bank+seq 作唯一key避免永豐/台企編號衝突
  const badParents = new Set();
  const parentIds = [...new Set(result.slice(1).filter(r => String(r[1]).includes('-')).map(r => r[0] + '|' + String(r[1]).split('-')[0]))];

  for (const bpid of parentIds) {
    const [bk, pid] = bpid.split('|');
    const parent = result.slice(1).find(r => r[0] === bk && String(r[1]) === pid);
    const children = result.slice(1).filter(r => r[0] === bk && String(r[1]).startsWith(pid + '-'));
    if (!parent || !children.length) continue;

    const pAmt = parseFloat(String(parent[4] || parent[5]).replace(/[\$,\s]/g, '')) || 0;
    const cAmt = (c) => parseFloat(String(c[4] || c[5]).replace(/[\$,\s]/g, '')) || 0;
    const cSum = children.reduce((s, c) => s + cAmt(c), 0);
    const diff = Math.round(pAmt - cSum);

    // 1. 母帳≠子帳加總
    if (Math.abs(diff) > 1) badParents.add(bpid);

    // 2. 匯費 > 30
    children.filter(c => c[10] === '其他費用-匯費').forEach(c => {
      const fee = cAmt(c);
      if (fee > 30 || fee < 0) badParents.add(bpid);
    });

    // 3. 營業稅驗算
    const itemRows = children.filter(c => c[10] !== '營業稅' && c[10] !== '其他費用-匯費');
    const taxRows = children.filter(c => c[10] === '營業稅');
    if (taxRows.length > 0 && taxRows.length >= itemRows.length * 0.4) {
      const totalUntaxed = itemRows.reduce((s, c) => s + cAmt(c), 0);
      const totalTax = taxRows.reduce((s, c) => s + cAmt(c), 0);
      const expectedTax = Math.round(totalUntaxed * 0.05);
      const tolerance = Math.max(100, Math.round(totalUntaxed * 0.01));
      if (Math.abs(expectedTax - Math.round(totalTax)) > tolerance) badParents.add(bpid);
    }
  }

  console.log('驗算問題組: ' + badParents.size + ' 組 → ' + [...badParents].join(', '));

  // ===== 寫入 Excel =====
  for (let ri = 0; ri < result.length; ri++) {
    const row = exWs.addRow(result[ri]);
    const seqVal = String(result[ri][1] || '');
    const kind = String(result[ri][10] || '');
    const site = String(result[ri][12] || '').trim();
    const bankName = String(result[ri][0] || '');
    const pid = bankName + '|' + (seqVal.includes('-') ? seqVal.split('-')[0] : seqVal);

    // 字色
    if (ri === 0) {
      row.eachCell(cell => { cell.font = blackBold; });
    } else if (seqVal.includes('-')) {
      row.eachCell(cell => { cell.font = blueFont; });
    }

    // 黃底條件：案場空白 OR 種類空白(待手動) OR 驗算有問題的組 OR 品項=待確認
    const item = String(result[ri][11] || '').trim();
    const needsYellow =
      (ri > 0 && !kind) ||
      (ri > 0 && !site && kind && kind !== '附件' && kind !== '內轉' && kind !== '營業稅' && kind !== '其他費用-匯費' && kind !== '匯款沖銷') ||
      (ri > 0 && item === '待確認') ||
      (ri > 0 && badParents.has(pid));

    if (needsYellow) {
      row.eachCell(cell => {
        cell.fill = yellowFill;
        if (seqVal.includes('-')) cell.font = { ...blueFont, ...{} }; // 保持藍字
      });
    }
  }

  await exWb.xlsx.writeFile('c:/Users/名御/Desktop/TB project/會計參考資料/進銷帳_自動分類.xlsx');

  // 統計
  const data = result.slice(1);
  const emptySite = data.filter(r => {
    const k = String(r[10]||'');
    const site = String(r[12]||'').trim();
    return !site && k && k !== '附件' && k !== '內轉' && k !== '營業稅';
  });
  console.log('已輸出: 進銷帳_自動分類.xlsx');
  console.log('總行數: ' + data.length + ' | 母帳: ' + data.filter(r=>!String(r[1]).includes('-')).length + ' | 子帳: ' + data.filter(r=>String(r[1]).includes('-')).length);
  console.log('已分類: ' + data.filter(r=>r[10]&&r[10]!=='內轉').length + ' | 內轉: ' + data.filter(r=>r[10]==='內轉').length + ' | 待手動: ' + data.filter(r=>!r[10]).length);
  console.log('案場空白: ' + emptySite.length);

  if (emptySite.length) {
    console.log('\n=== 案場空白 ===');
    emptySite.forEach(r => console.log(r[0]+' #'+r[1]+' | '+r[2]+' | '+r[9]+' | '+r[10]+' | '+r[11]+' | 提:'+r[4]+'存:'+r[5]));
  }

  console.log('\n=== 拆帳範例 (前3組) ===');
  const pids = [...new Set(data.filter(r=>String(r[1]).includes('-')).map(r=>String(r[1]).split('-')[0]))];
  pids.slice(0, 3).forEach(pid => {
    const g = data.filter(r => String(r[1])===pid || String(r[1]).startsWith(pid+'-'));
    console.log('--- '+g[0][9]+' ---');
    g.forEach(r => console.log('  '+r[1]+' | '+r[4]+' | '+r[10]+' | '+r[11]+' | '+r[12]));
  });

  console.log('\n=== 待手動 ===');
  data.filter(r=>!r[10]).forEach(r => console.log(r[0]+' #'+r[1]+' | '+r[2]+' | '+r[3]+' | '+r[9]+' | '+r[4]+r[5]));
})().catch(e => console.error(e.message));

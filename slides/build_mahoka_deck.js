// Builds the Mahoka briefing deck (15 slides, 16:9) from the "Disaster Alert & Rescue" Slides artifact.
// Run: node build_mahoka_deck.js [--th] [--gslides] [--force] [--check]   (needs pptxgenjs in ./node_modules)
//   --th       Thai-language deck (same layout, all slide text and speaker notes in Thai)
//   --gslides  for Google Slides import: Thai uses Noto Sans Thai (served by Google Fonts) instead of Tahoma
//   --check    run the text-fit estimate only, write nothing
const path = require("path");
const fs = require("fs");
const pptxgen = require("pptxgenjs");

const TH = process.argv.includes("--th");
const GSLIDES = process.argv.includes("--gslides");
const L = (en, th) => (TH ? th : en); // pick the string for the deck's language
const OUT = path.join(__dirname, `Mahoka_Briefing${TH ? "_TH" : ""}${GSLIDES ? "_GoogleSlides" : ""}.pptx`);
if (fs.existsSync(OUT) && !process.argv.includes("--force") && !process.argv.includes("--check")) {
  console.error("Refusing to overwrite " + OUT + " (pass --force).");
  process.exit(1);
}

// ---------- palette & type ----------
const C = {
  navy: "0E1B2C", navy2: "17283D", navyLine: "2A4160", glow: "1F4068",
  cream: "F4F1EA", ink: "14213D", muted: "4A5568", mutedDark: "B8C4D4",
  amber: "FFB02E", teal: "3BC6C0", rust: "C2410C", white: "FFFFFF", line: "D9D4C7",
  safe: "3FA66B", watch: "E0B02E", warning: "F2662F", danger: "E5484D",
};
const F = { head: "Space Grotesk", body: "Inter", mono: "JetBrains Mono", thai: GSLIDES ? "Noto Sans Thai" : "Tahoma", emoji: "Segoe UI Emoji" };

// ---------- grid ----------
const W = 13.333, M = 0.6, CW = W - 2 * M;   // content width 12.133"
const Y = { eyebrow: 0.37, title: 0.84, bar: 1.72, top: 1.95, bottom: 6.55, footer: 6.95 };
const TOTAL = 15;

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5
pres.title = L("Mahoka · มโหฆะ: Project briefing", "Mahoka · มโหฆะ: สรุปโครงการ");

const THAI_RE = /[฀-๿]/;
// Split a string into runs so every Thai character (U+0E00–U+0E7F, incl. ฿) uses the Thai font.
function runs(str, opt = {}) {
  const parts = String(str).split(/([฀-๿]+)/).filter((s) => s.length);
  return parts.map((p) => ({
    text: p,
    options: { ...opt, fontFace: THAI_RE.test(p) ? F.thai : opt.fontFace || F.body },
  }));
}
// lines: array of strings or [{t, o}] → one paragraph per line
function para(lines, base) {
  const out = [];
  lines.forEach((ln, i) => {
    const t = typeof ln === "string" ? ln : ln.t;
    const o = typeof ln === "string" ? {} : ln.o || {};
    const rs = runs(t, { ...base, ...o });
    rs[rs.length - 1].options.breakLine = i < lines.length - 1;
    out.push(...rs);
  });
  return out;
}
// No renderer is available, so estimate fit. Latin glyph ≈ 0.55 em (0.62 for mono/bold heads),
// Thai base glyph ≈ 0.62 em (vowel and tone marks take no width), Thai has no spaces between
// words so long runs may break anywhere. Line ≈ 1.2 em (1.4 em with Thai) × lineSpacingMultiple,
// plus 10% width slack for substituted fonts.
let CUR = 0; const FIT = [];
const ZERO_W = /[ัิ-ฺ็-๎]/;
function fitCheck(lines, w, h, o) {
  const pt = o.size || 20, latinEm = o.font === F.mono || o.font === F.head || o.bold ? 0.62 : 0.55;
  const cw = (ch) => (ZERO_W.test(ch) ? 0 : (THAI_RE.test(ch) ? 0.62 : latinEm) * pt / 72);
  const width = (s) => [...s].reduce((a, ch) => a + cw(ch), 0);
  const lineW = w / 1.1, spaceW = cw(" ");
  let n = 0, thai = false;
  lines.forEach((s) => {
    if (THAI_RE.test(s)) thai = true;
    let cur = 0, l = 1;
    for (const tok of s.split(" ")) {
      const tw = width(tok), sp = cur ? spaceW : 0;
      if (cur + sp + tw <= lineW) cur += sp + tw;
      else if (tw <= lineW) { l++; cur = tw; }
      else { const rem = tw - Math.max(0, lineW - cur - sp); l += Math.ceil(rem / lineW); cur = rem % lineW || lineW; }
    }
    n += l;
  });
  const need = n * pt * (thai ? 1.4 : 1.2) * (o.lh || 1.1) / 72 + (lines.length - 1) * (o.gap || 0) / 72;
  if (need > h * 0.98) FIT.push(`slide ${CUR}: needs ${need.toFixed(2)}" > box ${h.toFixed(2)}" (${n} lines): ${lines[0].slice(0, 40)}`);
}
function text(slide, content, x, y, w, h, o = {}) {
  const base = { fontSize: o.size || 20, color: o.color, bold: o.bold, fontFace: o.font || F.body, charSpacing: o.cs };
  fitCheck((Array.isArray(content) ? content : [content]).map((l) => (typeof l === "string" ? l : l.t)), w, h, o);
  const body = Array.isArray(content) ? para(content, base) : runs(content, base);
  slide.addText(body, {
    x, y, w, h, margin: o.margin ?? 0, valign: o.valign || "top", align: o.align || "left",
    paraSpaceAfter: o.gap ?? 0, lineSpacingMultiple: o.lh || 1.1,
  });
}
// one line made of differently styled segments: [[text, opts], ...]
function line(slide, segs, x, y, w, h, o = {}) {
  fitCheck([segs.map((s) => s[0]).join("")], w, h, o);
  const body = segs.flatMap(([t, so]) => runs(t, { fontSize: o.size || 20, fontFace: F.body, ...so }));
  slide.addText(body, { x, y, w, h, margin: 0, valign: o.valign || "middle" });
}
const shadow = () => ({ type: "outer", blur: 10, offset: 3, angle: 90, color: "000000", opacity: 0.18 });
function card(slide, x, y, w, h, fill, o = {}) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h, rectRadius: 0.14, fill: { color: fill },
    line: o.line ? { color: o.line, width: o.lineW || 1.5, dashType: o.dash || "solid" } : { type: "none" },
    shadow: o.shadow ? shadow() : undefined, // off by default: keeps each slide at ≤5 decorative elements
  });
}
function arrow(slide, x, y, w, color) {
  slide.addShape(pres.shapes.RIGHT_ARROW, { x, y, w, h: 0.32, fill: { color }, line: { type: "none" } });
}
function emoji(slide, ch, x, y, size) {
  slide.addText(ch, { x, y, w: size / 60, h: size / 60, fontFace: F.emoji, fontSize: size, margin: 0, valign: "middle", align: "center" });
}

// Shared frame: background, soft corner shape, eyebrow, title, amber bar, footer.
function frame(n, { dark, eyebrow, title, notes }) {
  CUR = n;
  const s = pres.addSlide();
  s.background = { color: dark ? C.navy : C.cream };
  s.addShape(pres.shapes.OVAL, {
    x: 10.4, y: -2.2, w: 5.2, h: 5.2, line: { type: "none" },
    fill: { color: dark ? C.glow : "E7E1D3", transparency: dark ? 45 : 30 },
  });
  // letter-spacing pulls Thai vowel and tone marks away from their consonants, so Thai eyebrows get none
  if (eyebrow) text(s, eyebrow.toUpperCase(), M, Y.eyebrow, CW, 0.46, { font: F.mono, size: 20, color: dark ? C.amber : C.rust, cs: THAI_RE.test(eyebrow) ? 0 : 2 });
  if (title) text(s, title, M, Y.title, CW, 0.8, { font: F.head, size: 36, bold: true, color: dark ? C.cream : C.ink, valign: "middle" });
  s.addShape(pres.shapes.RECTANGLE, { x: M, y: Y.bar, w: 1.1, h: 0.07, fill: { color: C.amber }, line: { type: "none" } });
  const fc = dark ? C.mutedDark : C.muted;
  text(s, "Mahoka · มโหฆะ", M, Y.footer, 5, 0.46, { size: 20, color: fc, valign: "middle" });
  text(s, `${n} / ${TOTAL}`, W - M - 2, Y.footer, 2, 0.46, { size: 20, color: fc, align: "right", valign: "middle", font: F.mono });
  s.addNotes(notes);
  return s;
}

// ================= 1 · cover =================
{
  const s = frame(1, {
    dark: true, eyebrow: L("Project briefing · Nov 2026", "สรุปโครงการ · พ.ย. 2569"),
    notes: L(
      "Open with the one-liner: a phone app that tells people in Thailand how dangerous it is where they stand, and what to do. Today it is a working prototype with mock sensors, and the real alert plumbing is built and tested but not yet connected to a live feed. Keep this slide short, about 20 seconds.\n" +
      "Figures: '41 tests green' in the source is kept as '41 tests passing'. The tagline is the source's own line; it says nothing about what the name Mahoka means.",
      "เปิดด้วยประโยคเดียว: แอปบนมือถือที่บอกคนในประเทศไทยว่าตรงที่เขายืนอยู่อันตรายแค่ไหน และควรทำอะไร ตอนนี้เป็นต้นแบบที่ใช้งานได้ ใช้เซนเซอร์จำลอง ระบบรับส่งประกาศจริงสร้างและทดสอบแล้ว แต่ยังไม่ได้เชื่อมกับฟีดจริง สไลด์นี้ให้สั้น ประมาณ 20 วินาที\n" +
      "ตัวเลข: '41 tests green' ในต้นฉบับ คงไว้เป็น 'ผ่านการทดสอบ 41 รายการ' สโลแกนแปลจากประโยคในต้นฉบับ ไม่ได้อ้างถึงความหมายของชื่อ Mahoka"),
  });
  // focal: the name, Latin and Thai side by side
  s.addText(
    [
      { text: "Mahoka", options: { fontFace: F.head, bold: true, color: C.cream } },
      { text: "  ", options: { fontFace: F.head } },
      { text: "มโหฆะ", options: { fontFace: F.thai, bold: true, color: C.amber } },
    ],
    { x: M, y: 2.0, w: CW, h: 1.5, fontSize: 80, margin: 0, valign: "middle" }
  );
  text(s, L(["One calm screen for when the water rises.", "Built to work when the signal does not."],
            ["หน้าจอเดียวที่สงบ ในวันที่น้ำกำลังขึ้น", "ออกแบบให้ใช้ได้ แม้สัญญาณจะหายไป"]), M, 3.6, CW, 1.3,
    { size: 28, color: C.mutedDark, lh: 1.1 });
  const pills = L([["Flutter · Dart 3", 3.15], ["Offline-first", 2.7], ["CAP alerts", 2.2], ["41 tests passing", 3.15]],
                  [["Flutter · Dart 3", 3.15], ["ใช้ออฟไลน์ได้", 2.4], ["ประกาศแบบ CAP", 2.6], ["ผ่านเทสต์ 41 รายการ", 3.3]]);
  let x = M;
  pills.forEach(([t, w], i) => {
    const hi = i === 3;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x, y: 5.0, w, h: 0.6, rectRadius: 0.3, fill: { color: hi ? C.amber : C.navy2 },
      line: hi ? { type: "none" } : { color: C.navyLine, width: 1.5 },
    });
    text(s, t, x, 5.0, w, 0.6, { font: F.mono, size: 20, color: hi ? C.navy : C.cream, align: "center", valign: "middle", bold: hi });
    x += w + 0.2;
  });
  text(s, L("Working prototype · mock sensors · not yet on a live alert feed",
            "ต้นแบบที่ใช้งานได้ · เซนเซอร์จำลอง · ยังไม่เชื่อมฟีดประกาศจริง"), M, 5.9, CW, 0.5, { size: 20, color: C.mutedDark });
}

// ================= 2 · problem =================
{
  const s = frame(2, {
    dark: false, eyebrow: L("The problem", "ปัญหา"), title: L("Warnings exist. Timing is hard.", "คำเตือนมีอยู่แล้ว แต่มักมาไม่ทัน"),
    notes: L(
      "Set up the why. The official warning layer is strong, but it is spread across channels and assumes a working network. Mahoka is a helper beside those warnings, not a replacement.\n" +
      "Figures: four channels named in the source (Cell Broadcast, DDPM, NDWC, TMD); agencies use 4 to 5 levels each (from our source research). Told as problem → impact → fix so the room follows one thread instead of three facts. 'Warnings reach people too late' restates the source's 'reaching people in time is the hard part'.",
      "ปูเหตุผลว่าทำไมต้องมีแอปนี้ ระบบเตือนภัยทางการแข็งแรงอยู่แล้ว แต่กระจายอยู่หลายช่องทาง และต้องพึ่งเครือข่ายที่ใช้งานได้ Mahoka เป็นผู้ช่วยที่ใช้คู่กับคำเตือนเหล่านั้น ไม่ใช่สิ่งที่มาแทนที่\n" +
      "ตัวเลข: ต้นฉบับระบุสี่ช่องทาง (Cell Broadcast, DDPM, NDWC, TMD) และแต่ละหน่วยงานใช้ 4 ถึง 5 ระดับ (จากการค้นคว้าของเรา) เล่าแบบ ปัญหา → ผลกระทบ → ทางแก้ เพื่อให้ผู้ฟังตามเรื่องเดียว ไม่ใช่ข้อเท็จจริงสามข้อแยกกัน 'คำเตือนไปถึงคนช้าเกินไป' เรียบเรียงจาก 'การเข้าถึงคนให้ทันเวลาคือส่วนที่ยาก' ในต้นฉบับ"),
  });
  const cols = [
    { h: L("Problem", "ปัญหา"), icon: "📡", fill: C.white, ink: C.ink, sub: C.muted, lines: L([
      "Four channels, four warning styles.",
      "Floods cut power and network.",
      "Each agency uses 4–5 levels." ], [
      "สี่ช่องทาง เตือนกันคนละแบบ",
      "น้ำท่วมทำไฟดับ เครือข่ายล่ม",
      "แต่ละหน่วยงานใช้ 4–5 ระดับ" ]) },
    { h: L("Impact", "ผลกระทบ"), icon: "⏳", fill: C.white, ink: C.ink, sub: C.muted, lines: L([
      "Warnings reach people too late.",
      "Online-only apps fail when needed.",
      "Mixed words leave people unsure." ], [
      "คำเตือนไปถึงคนช้าเกินไป",
      "แอปที่ต้องใช้เน็ตล่มตอนจำเป็น",
      "คำที่ต่างกันทำให้คนสับสน" ]) },
    { h: L("Mahoka's fix", "วิธีของ Mahoka"), icon: "✅", fill: C.navy, ink: C.cream, sub: C.mutedDark, lines: L([
      "One clear four-level scale.",
      "Works offline from a saved copy.",
      "Sits beside official warnings." ], [
      "ระดับเดียว ชัดเจน สี่ขั้น",
      "ใช้ออฟไลน์ได้จากข้อมูลที่บันทึกไว้",
      "ใช้คู่กับคำเตือนทางการ" ]) },
  ];
  const gap = 0.45, w = (CW - 2 * gap) / 3;
  cols.forEach((c, i) => {
    const x = M + i * (w + gap);
    card(s, x, Y.top + 0.1, w, 4.4, c.fill, { line: i < 2 ? C.line : null });
    emoji(s, c.icon, x + 0.3, Y.top + 0.45, 24);
    text(s, c.h, x + 0.8, Y.top + 0.38, w - 0.95, 0.56, { font: F.head, size: 24, bold: true, color: i === 2 ? C.amber : c.ink, valign: "middle" });
    text(s, c.lines, x + 0.3, Y.top + 1.15, w - 0.6, 3.2, { size: 20, color: c.sub, gap: 12, lh: 1.1 });
    if (i < 2) arrow(s, x + w + 0.04, Y.top + 2.1, 0.37, C.rust);
  });
}

// ================= 3 · speed (before / after) =================
{
  const s = frame(3, {
    dark: true, eyebrow: L("The pain point", "จุดที่เจ็บที่สุด"), title: L("Warnings wait in line for approval.", "คำเตือนต้องรอคิวอนุมัติ"),
    notes: L(
      "This is the owner's core reason for the project. Official warnings lose time in the approval chain, not in the sending. We skip that by showing facts early with their source, e.g. \"water at Bridge X is 40 cm over its line and rising\". Risks: false alarms, handled with range checks, two sensors agreeing and a human check on community reports; and the legal question of who may issue warnings in Thailand, which counsel must check.\n" +
      "Figures: the source shows a 5-step chain (sensor → analysis → decision → approval → send) against 2 steps (sensor → app, 'in seconds'). No minutes saved are claimed: the source gives no measured time saving, so none is shown. The 'in seconds' path depends on sensors and a backend that are still planned, so the card is labelled 'the Mahoka plan'.",
      "นี่คือเหตุผลหลักของเจ้าของโครงการ คำเตือนทางการเสียเวลาที่สายการอนุมัติ ไม่ใช่ตอนส่ง เราข้ามขั้นนั้นด้วยการแสดงข้อเท็จจริงตั้งแต่เนิ่น ๆ พร้อมแหล่งที่มา เช่น \"น้ำที่สะพาน X สูงเกินเส้น 40 ซม. และยังสูงขึ้น\" ความเสี่ยง: สัญญาณเตือนผิดพลาด รับมือด้วยการตรวจช่วงค่า ให้เซนเซอร์สองตัวยืนยันตรงกัน และให้คนตรวจรายงานจากชุมชน และคำถามทางกฎหมายว่าใครมีสิทธิ์ออกคำเตือนในประเทศไทย ซึ่งต้องให้ที่ปรึกษากฎหมายตรวจสอบ\n" +
      "ตัวเลข: ต้นฉบับแสดงสายงาน 5 ขั้น (เซนเซอร์ → วิเคราะห์ → ตัดสินใจ → อนุมัติ → ส่ง) เทียบกับ 2 ขั้น (เซนเซอร์ → แอป 'ในไม่กี่วินาที') ไม่ได้อ้างว่าประหยัดเวลากี่นาที เพราะต้นฉบับไม่มีตัวเลขที่วัดจริง เส้นทาง 'ในไม่กี่วินาที' ต้องอาศัยเซนเซอร์และแบ็กเอนด์ที่ยังอยู่ในแผน จึงติดป้ายว่า 'แผนของ Mahoka'"),
  });
  const y0 = Y.top + 0.05, h = 3.4, w = 5.9;
  // BEFORE — muted, long chain
  card(s, M, y0, w, h, C.navy2, { line: C.navyLine });
  text(s, L("BEFORE · TODAY", "ก่อน · วันนี้"), M + 0.35, y0 + 0.3, 4, 0.45, { font: F.mono, size: 20, bold: true, color: C.danger });
  // the long chain, written out so its length is felt
  text(s, L(["sensor → analysis → decision", "→ approval → send"], ["เซนเซอร์ → วิเคราะห์ → ตัดสินใจ", "→ อนุมัติ → ส่ง"]), M + 0.35, y0 + 0.8, w - 0.6, 0.9,
    { size: 20, color: C.mutedDark, lh: 1.05 });
  text(s, L(["It waits for an approval.", "Small floods get no warning.", "Map apps notice them late."],
            ["ต้องรอการอนุมัติก่อน", "น้ำท่วมเล็ก ๆ ไม่มีคำเตือน", "แอปแผนที่รู้ตัวช้า"]),
    M + 0.35, y0 + 1.8, w - 0.6, 1.5, { size: 20, color: C.cream, gap: 6 });
  // AFTER — bright, short chain
  const xa = M + w + 0.33;
  card(s, xa, y0, w, h, C.amber);
  text(s, L("AFTER · THE MAHOKA PLAN", "หลัง · แผนของ Mahoka"), xa + 0.35, y0 + 0.3, 5.3, 0.45, { font: F.mono, size: 20, bold: true, color: C.navy });
  [[L("sensor", "เซนเซอร์"), 0], [L("app", "แอป"), 2.1]].forEach(([t, dx]) => {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: xa + 0.35 + dx, y: y0 + 0.85, w: 1.4, h: 0.5, rectRadius: 0.1, fill: { color: C.navy }, line: { type: "none" } });
    text(s, t, xa + 0.35 + dx, y0 + 0.85, 1.4, 0.5, { size: 20, color: C.amber, align: "center", valign: "middle", font: F.mono, bold: true });
  });
  arrow(s, xa + 1.85, y0 + 0.94, 0.5, C.navy);
  text(s, L("in seconds", "ในไม่กี่วินาที"), xa + 3.95, y0 + 0.85, 1.85, 0.5, { size: 20, color: C.navy, valign: "middle" });
  text(s, L(["We show what's observed, street by street.", "From sensors, official data, checked reports."],
            ["แสดงสิ่งที่ตรวจพบจริง ทีละถนน", "จากเซนเซอร์ ข้อมูลทางการ และรายงานที่ตรวจแล้ว"]),
    xa + 0.35, y0 + 1.6, w - 0.6, 1.7, { size: 20, color: C.navy, gap: 6 });
  text(s, L(["Observations, not evacuation orders. Never instead of official warnings.",
             "Sensors are mock today, and no live feed is connected.",
             "Still open: who may legally issue warnings in Thailand."],
            ["เป็นข้อมูลที่ตรวจพบ ไม่ใช่คำสั่งอพยพ และไม่แทนคำเตือนทางการ",
             "วันนี้เซนเซอร์ยังเป็นข้อมูลจำลอง และยังไม่เชื่อมฟีดจริง",
             "ยังไม่มีข้อสรุป: ใครมีสิทธิ์ออกคำเตือนในไทยตามกฎหมาย"]),
    M, 5.5, CW, 1.4, { size: 20, color: C.mutedDark, gap: 2, lh: 1.0 });
}

// ================= 4 · tiers =================
{
  const s = frame(4, {
    dark: true, eyebrow: L("The answer", "คำตอบ"), title: L("Four levels. One glance.", "สี่ระดับ มองแวบเดียวก็รู้"),
    notes: L(
      "This is the heart of the design. A tired or stressed reader should get the level from the icon and word even if they are colour-blind or the screen is in sunlight. In the app the icons are check, eye, triangle and octagon; here they are approximated with emoji. The Warning wording is a draft and must be replaced by the owner.\n" +
      "Figures: 4 tiers, each with its own icon, word and colour. No analogy used; the tier words and advice lines are the source's own.",
      "นี่คือหัวใจของการออกแบบ คนที่เหนื่อยหรือเครียดต้องรู้ระดับได้จากไอคอนและคำ แม้จะตาบอดสีหรือจอโดนแดดจ้า ในแอปไอคอนคือ เครื่องหมายถูก ดวงตา สามเหลี่ยม และแปดเหลี่ยม ในสไลด์นี้ใช้อีโมจิแทนโดยประมาณ คำแนะนำระดับเตือนภัยยังเป็นร่าง เจ้าของโครงการต้องเขียนฉบับจริง\n" +
      "ตัวเลข: 4 ระดับ แต่ละระดับมีไอคอน คำ และสีของตัวเอง คำภาษาไทยของแต่ละระดับ (ปลอดภัย เฝ้าระวัง เตือนภัย อันตราย) เป็นคำแปลที่เสนอสำหรับสไลด์นี้ แอปยังไม่มีฉบับภาษาไทย จึงคงคำภาษาอังกฤษ (SAFE, WATCH, WARNING, DANGER) ไว้ใต้คำไทย"),
  });
  const tiers = [
    ["✅", "SAFE", "ปลอดภัย", C.safe, L("No action needed.", "ไม่ต้องทำอะไร")],
    ["👁️", "WATCH", "เฝ้าระวัง", C.watch, L("Stay alert and get ready to move.", "ติดตามข่าว และเตรียมพร้อมย้าย")],
    ["⚠️", "WARNING", "เตือนภัย", C.warning, L("Prepare to leave. Follow official instructions.", "เตรียมออกจากพื้นที่ ทำตามคำสั่งทางการ")],
    ["🛑", "DANGER", "อันตราย", C.danger, L("Evacuate to a shelter now!", "อพยพไปศูนย์พักพิงทันที!")],
  ];
  const gap = 0.2, w = (CW - 3 * gap) / 4;
  tiers.forEach(([ic, word, thWord, col, adv], i) => {
    const x = M + i * (w + gap), y = Y.top + 0.05;
    card(s, x, y, w, 3.65, C.navy2, { line: col, lineW: 2.5 });
    emoji(s, ic, x + 0.22, y + 0.3, 48);
    if (TH) {
      // Thai word leads; the English tier word stays underneath so the tier keeps its own word
      text(s, thWord, x + 0.22, y + 1.12, w - 0.3, 0.82, { font: F.head, size: 36, bold: true, color: col, valign: "middle" });
      text(s, word, x + 0.22, y + 1.9, w - 0.3, 0.4, { font: F.mono, size: 20, bold: true, color: col, valign: "middle" });
      text(s, adv, x + 0.22, y + 2.35, w - 0.4, 1.25, { size: 20, color: C.cream, lh: 1.0 });
    } else {
      text(s, word, x + 0.22, y + 1.25, w - 0.3, 0.7, { font: F.head, size: 36, bold: true, color: col, valign: "middle" });
      text(s, adv, x + 0.22, y + 2.0, w - 0.4, 1.6, { size: 20, color: C.cream, lh: 1.1 });
    }
  });
  text(s, L(["Icon, word and colour together, so colour is never the only clue.",
             "The Warning advice line is a draft. The owner writes the final wording."],
            ["ไอคอน คำ และสี ไปด้วยกัน จึงไม่ต้องพึ่งสีอย่างเดียว",
             "คำแนะนำระดับเตือนภัยยังเป็นร่าง เจ้าของโครงการจะเขียนฉบับจริง"]),
    M, 5.8, CW, 0.95, { size: 20, color: C.mutedDark, gap: 2, lh: 1.0 });
}

// ================= 5 · tour =================
{
  const s = frame(5, {
    dark: false, eyebrow: L("The app today", "แอปในวันนี้"), title: L("Five tabs and one big red button.", "ห้าแท็บ กับปุ่มแดงใหญ่หนึ่งปุ่ม"),
    notes: L(
      "Walk the tabs quickly. Home is the main screen. SOS needs a press-and-hold so it cannot fire in a pocket, then offers call buttons, an SMS draft and a share sheet. 191 is still marked unconfirmed until we find an official source. Sensors and shelters are invented mock data around Bangkok.\n" +
      "Figures: 5 tabs plus SOS; numbers 1669, 1784 and 191 (191 unconfirmed in the source, so it is shown as 'still being confirmed').",
      "ไล่ดูแต่ละแท็บอย่างเร็ว หน้าหลักคือจอหลัก ปุ่ม SOS ต้องกดค้างจึงไม่เผลอทำงานในกระเป๋า จากนั้นมีปุ่มโทร ร่าง SMS และเมนูแชร์ เบอร์ 191 ยังระบุว่ารอการยืนยันจนกว่าจะพบแหล่งข้อมูลทางการ ข้อมูลเซนเซอร์และศูนย์พักพิงเป็นข้อมูลจำลองรอบกรุงเทพฯ\n" +
      "ตัวเลข: 5 แท็บ และปุ่ม SOS เบอร์ 1669, 1784 และ 191 (ต้นฉบับระบุว่า 191 ยังไม่ยืนยัน จึงแสดงว่า 'ยังรอการยืนยัน') ชื่อแท็บภาษาไทยเป็นคำแปลสำหรับสไลด์นี้ แอปตอนนี้ยังแสดงเป็นภาษาอังกฤษ"),
  });
  const tabs = L([
    ["Home", "Your level, water meter and official alerts."],
    ["Sensors", "Water readings. Mock data for now."],
    ["Map", "Shelters and stations on OpenStreetMap."],
    ["Report", "Photo, GPS and a note, saved on the phone."],
    ["Guide", "First aid and evacuation steps."],
  ], [
    ["หน้าหลัก", "ระดับของคุณ มาตรวัดน้ำ และประกาศทางการ"],
    ["เซนเซอร์", "ค่าระดับน้ำ ตอนนี้เป็นข้อมูลจำลอง"],
    ["แผนที่", "ศูนย์พักพิงและสถานี บน OpenStreetMap"],
    ["รายงาน", "รูปภาพ GPS และบันทึก เก็บไว้ในเครื่อง"],
    ["คู่มือ", "ปฐมพยาบาลและขั้นตอนการอพยพ"],
  ]);
  const rw = 7.0, rh = 0.8;
  tabs.forEach(([n, d], i) => {
    const y = Y.top + 0.05 + i * (rh + 0.12);
    card(s, M, y, rw, rh, C.white, { line: C.line });
    text(s, n, M + 0.3, y, 1.75, rh, { font: F.head, size: 24, bold: true, color: C.ink, valign: "middle" });
    text(s, d, M + 2.1, y, rw - 2.25, rh, { size: 20, color: C.muted, valign: "middle", lh: TH ? 1.0 : 1.1 });
  });
  // focal: SOS
  const x = M + rw + 0.45, w = CW - rw - 0.45, y = Y.top + 0.05, h = 4.48;
  card(s, x, y, w, h, C.rust);
  emoji(s, "🆘", x + 0.35, y + 0.45, 24);
  text(s, L("Hold for SOS", "กดค้างเพื่อ SOS"), x + 0.95, y + 0.35, w - 1.2, 0.6, { font: F.head, size: 24, bold: true, color: "FFF8F0", valign: "middle" });
  text(s, L(["Hold it down, so pockets can't fire it.", "Reads GPS, then call, text or share.", "Calls 1669 or 1784.", "191 is still being confirmed."],
            ["ต้องกดค้าง จึงไม่เผลอกดในกระเป๋า", "อ่าน GPS แล้วโทร ส่งข้อความ หรือแชร์", "โทร 1669 หรือ 1784", "เบอร์ 191 ยังรอการยืนยัน"]),
    x + 0.35, y + 1.1, w - 0.6, 3.1, { size: 20, color: "FFF8F0", gap: 8, lh: 1.1 });
}

// ================= 6 · architecture =================
{
  const s = frame(6, {
    dark: true, eyebrow: L("Under the hood", "เบื้องหลังการทำงาน"), title: L("One saved snapshot, even offline.", "สแนปช็อตเดียว ใช้ได้แม้ออฟไลน์"),
    notes: L(
      "This is the key architecture slide. Phone side is built and tested: AlertService downloads, caches in shared_preferences and tracks age; AlertRules decides what is visible. The poller and hosting are not built yet and are blocked on the hosting decision. Nothing is deployed.\n" +
      "Figures: none in the source; the four boxes are the source's own (TMD CAP → Poller → JSON → Phone). Dashed = planned, as in the source.",
      "นี่คือสไลด์สถาปัตยกรรมที่สำคัญที่สุด ฝั่งโทรศัพท์สร้างและทดสอบแล้ว: AlertService ดาวน์โหลด เก็บแคชใน shared_preferences และติดตามอายุข้อมูล ส่วน AlertRules ตัดสินว่าประกาศไหนแสดงได้ ตัว poller และโฮสติ้งยังไม่ได้สร้าง เพราะรอการตัดสินใจเรื่องโฮสติ้ง ยังไม่มีอะไรเปิดใช้งานจริง\n" +
      "ตัวเลข: ต้นฉบับไม่มีตัวเลข กล่องทั้งสี่มาจากต้นฉบับ (TMD CAP → Poller → JSON → โทรศัพท์) เส้นประหมายถึงอยู่ในแผน เหมือนต้นฉบับ"),
  });
  const boxes = [
    ["TMD CAP", L("Official feed, public domain", "ฟีดทางการ เป็นสาธารณสมบัติ"), C.navyLine, "solid", C.mutedDark],
    ["Poller", L("Planned, not built yet", "อยู่ในแผน ยังไม่ได้สร้าง"), C.amber, "dash", C.amber],
    ["JSON", L("One clean snapshot, over HTTPS", "สแนปช็อตเดียว ส่งผ่าน HTTPS"), C.navyLine, "solid", C.mutedDark],
    [L("Phone", "โทรศัพท์"), L("Saves it, applies rules, shows banner", "บันทึกไว้ ใช้กฎ และแสดงแบนเนอร์"), C.teal, "solid", C.mutedDark],
  ];
  const aw = 0.42, ag = 0.14, w = (CW - 3 * (aw + 2 * ag)) / 4, y = Y.top + 0.15, h = 2.55;
  boxes.forEach(([t, d, ln, dash, dc], i) => {
    const x = M + i * (w + aw + 2 * ag);
    card(s, x, y, w, h, i === 1 ? C.navy : C.navy2, { line: ln, dash, lineW: 2 });
    text(s, t, x + 0.25, y + 0.25, w - 0.4, 0.55, { font: F.mono, size: 24, bold: true, color: C.cream });
    text(s, d, x + 0.25, y + 0.85, w - 0.4, 1.6, { size: 20, color: dc, lh: TH ? 1.0 : 1.1 });
    if (i < 3) arrow(s, x + w + ag, y + h / 2 - 0.16, aw, C.amber);
  });
  text(s, L(["📵  The phone never talks to agency servers directly.",
             "The phone side is built and tested. It keeps the last copy and its age.",
             "Not yet connected to a live feed. Nothing is deployed."],
            ["📵  โทรศัพท์ไม่ติดต่อเซิร์ฟเวอร์ของหน่วยงานโดยตรง",
             "ฝั่งโทรศัพท์สร้างและทดสอบแล้ว เก็บสำเนาล่าสุดพร้อมอายุข้อมูล",
             "ยังไม่เชื่อมฟีดจริง และยังไม่มีอะไรเปิดใช้งานจริง"]),
    M, 4.9, CW, 1.6, { size: 20, color: C.cream, gap: 4, lh: TH ? 1.0 : 1.1 });
}

// ================= 7 · rules =================
{
  const s = frame(7, {
    dark: false, eyebrow: L("The smart part", "ส่วนที่ฉลาด"), title: L("Is this alert about where you are?", "ประกาศนี้เกี่ยวกับที่ที่คุณอยู่ไหม?"),
    notes: L(
      "Plain Dart, no network, fully unit tested. The pseudo-code on the left mirrors the real AlertRules functions. The ray-casting point-in-polygon test is the standard algorithm. The coordinate-order note matters because CAP polygons are lat,lon while GeoJSON is lon,lat; a mix-up would put alerts in the wrong place.\n" +
      "Figures: default expiry of 6 hours when an alert gives none (kept exactly as 'six hours'). No analogy needed.",
      "เป็น Dart ล้วน ไม่ต้องใช้เครือข่าย และมี unit test ครบ โค้ดจำลองด้านซ้ายสะท้อนฟังก์ชันจริงใน AlertRules การทดสอบจุดในรูปหลายเหลี่ยมแบบ ray casting เป็นอัลกอริทึมมาตรฐาน เรื่องลำดับพิกัดสำคัญ เพราะรูปหลายเหลี่ยมใน CAP เป็น lat,lon ส่วน GeoJSON เป็น lon,lat ถ้าสลับกัน ประกาศจะไปอยู่ผิดที่\n" +
      "ตัวเลข: ถ้าประกาศไม่ระบุเวลาหมดอายุ ถือว่า 6 ชั่วโมง (คงไว้ตรงตามนั้น) ไม่ต้องใช้การเปรียบเทียบ โค้ดคงไว้เป็นภาษาอังกฤษเพราะเป็นชื่อฟังก์ชันจริง"),
  });
  const y = Y.top + 0.05, w = 5.7, h = 4.3;
  card(s, M, y, w, h, C.navy);
  text(s, [
    { t: "visible(alerts, now)", o: { color: C.teal } },
    { t: "  status == Actual", o: { color: C.cream } },
    { t: "  not cancelled, not expired", o: { color: C.cream } },
    { t: " ", o: {} },
    { t: "levelAt(alerts, gps, now)", o: { color: C.teal } },
    { t: "  contains(polygon, gps)", o: { color: C.cream } },
    { t: "  // ray casting", o: { color: C.amber } },
  ], M + 0.4, y + 0.4, w - 0.7, h - 0.7, { font: F.mono, size: 20, lh: 1.3 });
  const items = L([
    "Test alerts never reach people.",
    "Updates and cancels replace the older alert.",
    "No end time given? We treat it as six hours.",
    "Handles both lat,lon and lon,lat orders.",
  ], [
    "ประกาศทดสอบไม่ไปถึงผู้ใช้",
    "ประกาศอัปเดตหรือยกเลิก จะแทนที่ฉบับเก่า",
    "ไม่ระบุเวลาหมดอายุ? ถือว่าอยู่ 6 ชั่วโมง",
    "รองรับทั้งลำดับ lat,lon และ lon,lat",
  ]);
  const xr = M + w + 0.5, wr = CW - w - 0.5;
  items.forEach((t, i) => {
    const yy = y + 0.2 + i * 1.03;
    card(s, xr, yy, wr, 0.88, C.white, { line: C.line });
    text(s, t, xr + 0.3, yy, wr - 0.5, 0.88, { size: 20, color: C.ink, valign: "middle", lh: 1.1 });
  });
}

// ================= 8 · offline =================
{
  const s = frame(8, {
    dark: true, eyebrow: L("Offline is normal", "ออฟไลน์เป็นเรื่องปกติ"), title: L("When data gets old, Mahoka says so.", "เมื่อข้อมูลเก่า Mahoka จะบอกคุณ"),
    notes: L(
      "This slide shows the product principle: offline is a normal state, not an error. The banner wording in the mock matches the real app text. The 30 minute limit is a constant in AlertService and can be tuned. This is tested: one test fetches, goes offline, and still shows the cached alert.\n" +
      "Figures: 30 minutes without a refresh before the stale banner shows. 'Half an hour' is an exact restatement, chosen because people think in half hours, not minutes.",
      "สไลด์นี้แสดงหลักการของผลิตภัณฑ์: ออฟไลน์เป็นสถานะปกติ ไม่ใช่ข้อผิดพลาด ข้อความบนแบนเนอร์ในภาพจำลองเป็นคำแปลของข้อความภาษาอังกฤษในแอปจริง ('Alerts last updated 14:05. They may be out of date.') ค่า 30 นาทีเป็นค่าคงที่ใน AlertService ปรับได้ และมีการทดสอบแล้ว: เทสต์หนึ่งดึงข้อมูล ตัดเน็ต แล้วยังแสดงประกาศที่แคชไว้ได้\n" +
      "ตัวเลข: 30 นาทีที่ไม่มีการรีเฟรช ก่อนแบนเนอร์ข้อมูลเก่าจะแสดง 'ครึ่งชั่วโมง' เป็นการพูดซ้ำที่ตรงตัว เลือกใช้เพราะคนคิดเป็นครึ่งชั่วโมงมากกว่าเป็นนาที"),
  });
  const y = Y.top + 0.15;
  text(s, "30", M, y, 3.6, 1.9, { font: F.head, size: 120, bold: true, color: C.amber, valign: "middle", lh: 0.9 });
  text(s, L("minutes, or half an hour, without fresh data. Then a banner warns you.",
            "นาที หรือครึ่งชั่วโมง ที่ไม่มีข้อมูลใหม่ แล้วแบนเนอร์จะเตือนคุณ"), M, y + 2.0, 4.0, 1.75, { size: 20, color: C.mutedDark, lh: 1.1 });
  const x = M + 4.4, w = CW - 4.4;
  card(s, x, y + 0.1, w, 1.25, "3A2A0E", { line: C.amber, lineW: 2.5 });
  emoji(s, "🕑", x + 0.3, y + 0.42, 36);
  text(s, L("Alerts last updated 14:05. They may be out of date.", "อัปเดตประกาศล่าสุด 14:05 ข้อมูลอาจไม่เป็นปัจจุบัน"),
    x + 1.15, y + 0.1, w - 1.4, 1.25, { size: 20, color: C.cream, valign: "middle", bold: true });
  text(s, L(["HTTPS only. Nothing is fetched over plain http.", "A failed download keeps the last good copy.", "A broken cache is skipped, not crashed on."],
            ["ใช้ HTTPS เท่านั้น ไม่ดึงข้อมูลผ่าน http ธรรมดา", "ดาวน์โหลดล้มเหลว ก็ยังเก็บสำเนาดีล่าสุดไว้", "แคชเสียจะถูกข้าม ไม่ทำให้แอปพัง"]),
    x, y + 1.75, w, 2.0, { size: 20, color: C.mutedDark, gap: 10 });
}

// ================= 9 · mapstack =================
{
  const s = frame(9, {
    dark: true, eyebrow: L("Map stack · planned", "ชุดแผนที่ · อยู่ในแผน"), title: L("Open maps that work with no signal.", "แผนที่เปิด ใช้ได้แม้ไม่มีสัญญาณ"),
    notes: L(
      "Today the app loads map images live from OpenStreetMap's own servers, which is fine for a prototype but not allowed for a real app at scale. The switch keeps the same map library and data; only the base layer changes. Open risks: Thai labels and drawing speed on older phones, to be checked with a throwaway test. Routing is optional and needs one small server. The Waze programme terms are still to be checked.\n" +
      "Figures: Cloudflare R2 '10 GB free, downloads free' kept exactly as the source states it (vendor pricing). No comparison added for 10 GB because none could be made exactly true.",
      "ตอนนี้แอปโหลดภาพแผนที่สดจากเซิร์ฟเวอร์ของ OpenStreetMap เอง ซึ่งใช้ได้สำหรับต้นแบบ แต่ไม่อนุญาตสำหรับแอปจริงที่มีผู้ใช้จำนวนมาก การเปลี่ยนครั้งนี้ใช้ไลบรารีแผนที่และข้อมูลเดิม เปลี่ยนแค่ชั้นแผนที่ฐาน ความเสี่ยงที่ยังเปิดอยู่: ป้ายชื่อภาษาไทยและความเร็วในการวาดบนมือถือรุ่นเก่า ต้องทดสอบด้วยต้นแบบทดลองก่อน ระบบหาเส้นทางเป็นทางเลือก และต้องมีเซิร์ฟเวอร์เล็ก ๆ หนึ่งเครื่อง เงื่อนไขโครงการของ Waze ยังต้องตรวจสอบ\n" +
      "ตัวเลข: Cloudflare R2 'พื้นที่ 10 GB ฟรี ดาวน์โหลดฟรี' คงไว้ตรงตามต้นฉบับ (ราคาจากผู้ให้บริการ) ไม่ได้เพิ่มการเปรียบเทียบให้ 10 GB เพราะหาการเปรียบเทียบที่ถูกต้องตรงตัวไม่ได้"),
  });
  const parts = L([["DATA", "OpenStreetMap", "Free, with attribution."], ["PACKAGE", "Protomaps", "One file per province, on the phone."],
    ["HOST", "Cloudflare R2", "10 GB stored free. Downloads free."], ["ROUTING", "Valhalla", "Routes around flooded streets."]],
  [["ข้อมูล", "OpenStreetMap", "ฟรี โดยระบุแหล่งที่มา"], ["แพ็กเกจ", "Protomaps", "หนึ่งไฟล์ต่อจังหวัด เก็บในเครื่อง"],
    ["โฮสต์", "Cloudflare R2", "พื้นที่ 10 GB ฟรี ดาวน์โหลดฟรี"], ["เส้นทาง", "Valhalla", "หาเส้นทางเลี่ยงถนนที่น้ำท่วม"]]);
  const gap = 0.25, w = (CW - 3 * gap) / 4, y = Y.top + 0.05, h = 2.85;
  parts.forEach(([lab, name, d], i) => {
    const x = M + i * (w + gap);
    card(s, x, y, w, h, C.navy2, { line: C.navyLine });
    text(s, lab, x + 0.25, y + 0.25, w - 0.4, 0.45, { font: F.mono, size: 20, color: C.teal });
    text(s, name, x + 0.25, y + 0.7, w - 0.35, 0.45, { font: F.head, size: 20, bold: true, color: C.cream });
    text(s, d, x + 0.25, y + 1.25, w - 0.4, 1.5, { size: 20, color: C.mutedDark, lh: TH ? 1.0 : 1.1 });
  });
  text(s, L([
    { t: "Why not Google Maps? No offline use, and it charges per view.", o: { color: C.cream } },
    { t: "It also can't route around our own flood areas.", o: { color: C.mutedDark } },
    { t: "Instead, share our flood points with Waze's partner programme.", o: { color: C.mutedDark } },
  ], [
    { t: "ทำไมไม่ใช้ Google Maps? ใช้ออฟไลน์ไม่ได้ และคิดเงินต่อการเปิดดู", o: { color: C.cream } },
    { t: "และหาเส้นทางเลี่ยงพื้นที่น้ำท่วมของเราไม่ได้", o: { color: C.mutedDark } },
    { t: "ทางเลือก: ส่งจุดน้ำท่วมให้ Waze ผ่านโครงการพาร์ทเนอร์", o: { color: C.mutedDark } },
  ]), M, 5.0, CW, 1.55, { size: 20, gap: 2, lh: TH ? 1.0 : 1.1 });
}

// ================= 10 · iot =================
{
  const s = frame(10, {
    dark: true, eyebrow: L("Next: IoT · planned", "ถัดไป: IoT · อยู่ในแผน"), title: L("Real water sensors, same pipeline.", "เซนเซอร์น้ำจริง ท่อข้อมูลเดิม"),
    notes: L(
      "This is planned, not built. Dashed boxes mean planned, same as the architecture slide. The app side is the small part: screens already read from SensorService, so we swap its mock source for real readings and move the fixed safe limit to per-station settings. Every hardware and network name here is an option, not a decision, and we have no cost figures yet. The pilot needs: hardware choice, sites, who installs and maintains, and a budget.\n" +
      "Figures: none (no costs exist yet, so none are shown). Steps 01–04 are the source's own.",
      "ส่วนนี้อยู่ในแผน ยังไม่ได้สร้าง กล่องเส้นประหมายถึงอยู่ในแผน เหมือนสไลด์สถาปัตยกรรม ฝั่งแอปเป็นส่วนเล็ก: หน้าจออ่านค่าจาก SensorService อยู่แล้ว เราแค่เปลี่ยนแหล่งข้อมูลจำลองเป็นค่าจริง และย้ายค่าขีดจำกัดความปลอดภัยแบบตายตัวไปเป็นการตั้งค่าต่อสถานี ชื่อฮาร์ดแวร์และเครือข่ายทั้งหมดในสไลด์เป็นตัวเลือก ยังไม่ใช่การตัดสินใจ และยังไม่มีตัวเลขค่าใช้จ่าย โครงการนำร่องต้องการ: เลือกฮาร์ดแวร์ เลือกจุดติดตั้ง ใครติดตั้งและดูแล และงบประมาณ\n" +
      "ตัวเลข: ไม่มี (ยังไม่มีค่าใช้จ่าย จึงไม่แสดง) ขั้นตอน 01–04 มาจากต้นฉบับ"),
  });
  const steps = L([["01 STATION", "Ultrasonic or pressure sensor, solar and battery."], ["02 LINK", "LoRaWAN, NB-IoT or 4G, picked per site."],
    ["03 BACKEND", "MQTT or HTTPS, one key per device."], ["04 APP", "Same snapshot, same water meter and Sensors tab."]],
  [["01 สถานี", "เซนเซอร์อัลตราโซนิกหรือแรงดัน พลังแสงอาทิตย์และแบตเตอรี่"], ["02 การเชื่อมต่อ", "LoRaWAN, NB-IoT หรือ 4G เลือกตามพื้นที่"],
    ["03 แบ็กเอนด์", "MQTT หรือ HTTPS หนึ่งคีย์ต่ออุปกรณ์"], ["04 แอป", "สแนปช็อตเดิม มาตรวัดน้ำเดิม และแท็บเซนเซอร์เดิม"]]);
  const aw = 0.36, ag = 0.12, w = (CW - 3 * (aw + 2 * ag)) / 4, y = Y.top + 0.05, h = 2.9;
  steps.forEach(([lab, d], i) => {
    const x = M + i * (w + aw + 2 * ag), last = i === 3;
    card(s, x, y, w, h, last ? C.amber : C.navy2, last ? {} : { line: C.teal, dash: "dash", lineW: 2 });
    text(s, lab, x + 0.2, y + 0.25, w - 0.3, 0.45, { font: F.mono, size: 20, bold: true, color: last ? C.navy : C.teal });
    text(s, d, x + 0.2, y + 0.8, w - 0.3, 1.95, { size: 20, color: last ? C.navy : C.cream, lh: TH ? 1.0 : 1.1 });
    if (!last) arrow(s, x + w + ag, y + h / 2 - 0.16, aw, C.amber);
  });
  emoji(s, "🔇", M, 5.18, 28);
  text(s, L([
    { t: "A silent station shows as offline, never as a false Safe.", o: { color: C.cream } },
    { t: "Labelled honestly: community data, not an official gauge.", o: { color: C.mutedDark } },
    { t: "Range checks on every reading. No hardware is chosen yet.", o: { color: C.mutedDark } },
  ], [
    { t: "สถานีที่เงียบไปจะแสดงว่าออฟไลน์ ไม่ใช่ “ปลอดภัย” ปลอม", o: { color: C.cream } },
    { t: "บอกตรง ๆ: ข้อมูลชุมชน ไม่ใช่มาตรวัดทางการ", o: { color: C.mutedDark } },
    { t: "ตรวจช่วงค่าทุกครั้ง ยังไม่ได้เลือกฮาร์ดแวร์", o: { color: C.mutedDark } },
  ]), M + 0.65, 5.05, CW - 0.65, 1.5, { size: 20, gap: 2, lh: TH ? 1.0 : 1.1 });
}

// ================= 11 · channels =================
{
  const s = frame(11, {
    dark: false, eyebrow: L("Reaching everyone", "เข้าถึงทุกคน"), title: L("No single channel does it all.", "ไม่มีช่องทางเดียวที่ทำได้ทุกอย่าง"),
    notes: L(
      "Pilot suggestion: push plus SMS for Danger only. SMS example from the source: 10,000 users, 4 alerts a month, 2 segments each is 'about 24,000 to 80,000 baht a month'; sending only for Danger, only in the alert area, only to opt-ins cuts that sharply. Prices are vendor listings, get quotes. Cell broadcast and village towers come through partnerships. Push needs the Firebase project, which is on hold.\n" +
      "Figures: SMS about ฿0.15–1 per segment, Thai alerts usually 2 segments → shown as 'usually ฿0.30–2 each' (exact multiplication, keeping the source's 'usually'). [unverified] the source's low end of 24,000 baht: 80,000 segments × ฿0.15 = ฿12,000, so check that figure before quoting it.",
      "ข้อเสนอสำหรับโครงการนำร่อง: ส่งแบบพุช และส่ง SMS เฉพาะระดับอันตราย ตัวอย่าง SMS จากต้นฉบับ: ผู้ใช้ 10,000 คน ประกาศ 4 ครั้งต่อเดือน ครั้งละ 2 ข้อความย่อย 'ประมาณ 24,000 ถึง 80,000 บาทต่อเดือน' ถ้าส่งเฉพาะระดับอันตราย เฉพาะในพื้นที่ประกาศ และเฉพาะคนที่สมัครรับ ค่าใช้จ่ายจะลดลงมาก ราคาเป็นราคาประกาศของผู้ให้บริการ ควรขอใบเสนอราคา Cell broadcast และหอกระจายข่าวหมู่บ้านต้องผ่านความร่วมมือ การส่งแบบพุชต้องใช้โปรเจกต์ Firebase ซึ่งยังพักไว้\n" +
      "ตัวเลข: SMS ประมาณ ฿0.15–1 ต่อข้อความย่อย ประกาศภาษาไทยปกติใช้ 2 ข้อความย่อย → แสดงเป็น 'ปกติ ฿0.30–2 ต่อข้อความ' (คูณตรงตัว และคงคำว่า 'ปกติ' ตามต้นฉบับ) [unverified] ตัวเลขขั้นต่ำ 24,000 บาทในต้นฉบับ: 80,000 ข้อความย่อย × ฿0.15 = ฿12,000 ควรตรวจตัวเลขนี้ก่อนอ้างอิง 'ปภ.' คือชื่อย่อภาษาไทยของ DDPM"),
  });
  const rows = L([
    [C.teal, "Push notification", "Seconds · app users · free"],
    [C.safe, "SMS", "No data needed · usually ฿0.30–2 each"],
    [C.amber, "LINE Official Account", "Almost everyone in Thailand · paid plans"],
    [C.warning, "Cell broadcast", "T-Alert · every phone · DDPM and networks"],
    [C.danger, "Towers and sirens", "No phone · local admin or IoT stations"],
  ], [
    [C.teal, "แจ้งเตือนแบบพุช", "ไม่กี่วินาที · ผู้ใช้แอป · ฟรี"],
    [C.safe, "SMS", "ไม่ต้องใช้เน็ต · ปกติ ฿0.30–2 ต่อข้อความ"],
    [C.amber, "LINE Official Account", "คนไทยเกือบทุกคนใช้ · แพ็กเกจเสียเงิน"],
    [C.warning, "Cell broadcast", "T-Alert · ทุกเครื่อง · ปภ. และค่ายมือถือ"],
    [C.danger, "หอกระจายข่าวและไซเรน", "ไม่ต้องมีมือถือ · ท้องถิ่นหรือสถานี IoT"],
  ]);
  const rh = 0.66, gap = 0.12;
  rows.forEach(([col, n, d], i) => {
    const y = Y.top + 0.05 + i * (rh + gap);
    card(s, M, y, CW, rh, C.navy);
    s.addShape(pres.shapes.OVAL, { x: M + 0.28, y: y + rh / 2 - 0.11, w: 0.22, h: 0.22, fill: { color: col }, line: { type: "none" } });
    text(s, n, M + 0.7, y, 4.1, rh, { font: F.head, size: 20, bold: true, color: C.cream, valign: "middle" });
    text(s, d, M + 4.85, y, CW - 5.0, rh, { size: 20, color: C.mutedDark, valign: "middle" });
  });
  line(s, L([["Escalate by level: ", { bold: true, color: C.ink }], ["Danger on every layer, Watch on push only.", { color: C.muted }]],
            [["ส่งตามระดับ: ", { bold: true, color: C.ink }], ["อันตรายส่งทุกช่องทาง เฝ้าระวังส่งแค่พุช", { color: C.muted }]]),
    M, 6.0, CW, 0.5);
}

// ================= 12 · quality =================
{
  const s = frame(12, {
    dark: false, eyebrow: L("Proof, not promises", "พิสูจน์ได้ ไม่ใช่แค่สัญญา"), title: L("Built to be checked by machines.", "สร้างมาให้เครื่องตรวจสอบได้"),
    notes: L(
      "These numbers come straight from the last test run. Accessibility is tested, not hoped for: larger text, big tap targets, labelled controls. Be honest that the golden screenshots folder had stale diffs earlier and that one thing still unverified is the PDF form layout.\n" +
      "Figures: 41 tests passing, 0 analyzer issues, 13 golden screenshot tests, 1.5x text scale with no overflow, 48 dp minimum tap target. '1.5x' shown as '150%' (exact). The thumb line for 48 dp is the brief's own example and makes no measured claim; '0 analyzer issues' became 'zero code-checker complaints' so non-developers follow it.",
      "ตัวเลขเหล่านี้มาจากการรันเทสต์ครั้งล่าสุดโดยตรง การเข้าถึงได้ (accessibility) ผ่านการทดสอบจริง ไม่ใช่แค่หวัง: ตัวอักษรใหญ่ขึ้น จุดแตะใหญ่ ปุ่มมีป้ายกำกับ บอกตรง ๆ ว่าโฟลเดอร์ภาพ golden เคยมีภาพเปรียบเทียบที่ค้างเก่า และสิ่งที่ยังไม่ได้ตรวจคือเลย์เอาต์ของฟอร์ม PDF\n" +
      "ตัวเลข: ผ่านเทสต์ 41 รายการ เครื่องตรวจโค้ดพบปัญหา 0 ข้อ เทสต์ภาพหน้าจอ golden 13 รายการ ขยายตัวอักษร 1.5 เท่าโดยไม่ล้น จุดแตะขั้นต่ำ 48 dp '1.5x' แสดงเป็น '150%' (ตรงตัว) ประโยคเรื่องนิ้วโป้งสำหรับ 48 dp มาจากตัวอย่างในโจทย์ ไม่ได้อ้างการวัดจริง"),
  });
  const y = Y.top + 0.05, hw = 3.9, h = 3.95;
  card(s, M, y, hw, h, C.navy);
  text(s, "41", M + 0.4, y + 0.3, hw - 0.8, 1.8, { font: F.head, size: 96, bold: true, color: C.amber, valign: "middle" });
  text(s, L(["automated tests,", "all passing."], ["การทดสอบอัตโนมัติ", "ผ่านทั้งหมด"]), M + 0.4, y + 2.2, hw - 0.8, 1.4, { size: 20, color: C.cream, lh: 1.1 });
  const stats = L([["0", "Zero code-checker complaints."], ["13", "Screens checked against snapshots."],
    ["150%", "Text that big still fits."], ["48 dp", "Big enough for a thumb in a hurry."]],
  [["0", "เครื่องตรวจโค้ดไม่พบปัญหาเลย"], ["13", "หน้าจอที่เทียบกับภาพต้นแบบ"],
    ["150%", "ขยายตัวอักษรขนาดนี้ ยังไม่ล้น"], ["48 dp", "ใหญ่พอสำหรับนิ้วโป้งที่กำลังรีบ"]]);
  const gx = M + hw + 0.35, gw = (CW - hw - 0.35 - 0.3) / 2, gh = (h - 0.3) / 2;
  stats.forEach(([n, d], i) => {
    const x = gx + (i % 2) * (gw + 0.3), yy = y + Math.floor(i / 2) * (gh + 0.3);
    card(s, x, yy, gw, gh, C.white, { line: C.line });
    text(s, n, x + 0.3, yy + 0.15, gw - 0.5, 0.7, { font: F.head, size: 36, bold: true, color: i % 2 ? C.rust : C.ink, valign: "middle" });
    text(s, d, x + 0.3, yy + 0.88, gw - 0.5, 0.85, { size: 20, color: C.muted, lh: TH ? 1.0 : 1.1 });
  });
  text(s, L("Also tested: contrast, screen-reader labels, SOS hold, alert rules.",
            "ทดสอบด้วย: คอนทราสต์ ป้ายโปรแกรมอ่านหน้าจอ การกดค้าง SOS กฎประกาศ"), M, 6.1, CW, 0.5, { size: 20, color: C.muted });
}

// ================= 13 · safety =================
{
  const s = frame(13, {
    dark: true, eyebrow: L("Trust and limits", "ความน่าเชื่อถือและข้อจำกัด"), title: L("A helper, never a replacement.", "เป็นผู้ช่วย ไม่ใช่ตัวแทน"),
    notes: L(
      "The safety stance is built into the product with an About screen, not just a footnote. The disclaimer wording is a draft: the owner rewrites it and Thai counsel should review it before release. For data, we only use TMD now because it states public domain; HII, PCD, DMR, RID and GISTDA need permission letters, which we draft and the owner sends.\n" +
      "Figures: numbers 1669 and 1784 confirmed (as in the source). No analogy used.",
      "จุดยืนด้านความปลอดภัยฝังอยู่ในผลิตภัณฑ์ผ่านหน้า 'เกี่ยวกับ' ไม่ใช่แค่หมายเหตุท้ายจอ ข้อความปฏิเสธความรับผิดชอบยังเป็นร่าง เจ้าของโครงการจะเขียนใหม่ และควรให้ที่ปรึกษากฎหมายไทยตรวจก่อนเปิดตัว ด้านข้อมูล ตอนนี้ใช้เฉพาะ TMD เพราะระบุว่าเป็นสาธารณสมบัติ ส่วน HII, PCD, DMR, RID และ GISTDA ต้องมีหนังสืออนุญาต ซึ่งเราร่างให้และเจ้าของโครงการเป็นผู้ส่ง\n" +
      "ตัวเลข: เบอร์ 1669 และ 1784 ยืนยันแล้ว (ตามต้นฉบับ) ไม่ได้ใช้การเปรียบเทียบ"),
  });
  const y = Y.top + 0.05, w = (CW - 0.3) / 2, h = 4.0;
  const cols = [
    [L("What Mahoka is not", "สิ่งที่ Mahoka ไม่ใช่"), C.amber, L(["Not a government channel.", "Alerts may be late or wrong.", "No alert does not mean no danger.", "Community sensors aren't official gauges."],
      ["ไม่ใช่ช่องทางของรัฐ", "ประกาศอาจช้าหรือผิดพลาด", "ไม่มีประกาศ ไม่ได้แปลว่าไม่มีอันตราย", "เซนเซอร์ชุมชนไม่ใช่มาตรวัดทางการ"])],
    [L("Where data comes from", "ข้อมูลมาจากไหน"), C.teal, L(["TMD CAP feed: public domain, used first.", "T-Alert reaches phones; we point users to it.", "Others need written permission.", "Numbers 1669 and 1784 are confirmed."],
      ["ฟีด TMD CAP: สาธารณสมบัติ ใช้เป็นแหล่งแรก", "T-Alert ส่งถึงมือถือเอง เราแนะนำผู้ใช้ไปที่นั่น", "หน่วยงานอื่นต้องขออนุญาตเป็นลายลักษณ์อักษร", "เบอร์ 1669 และ 1784 ยืนยันแล้ว"])],
  ];
  cols.forEach(([h3, col, lines], i) => {
    const x = M + i * (w + 0.3);
    card(s, x, y, w, h, C.navy2, { line: C.navyLine });
    text(s, h3, x + 0.3, y + 0.25, w - 0.6, 0.55, { font: F.head, size: 24, bold: true, color: col, valign: "middle" });
    text(s, lines, x + 0.3, y + 0.85, w - 0.5, h - 0.95, { size: 20, color: C.cream, gap: 4, lh: TH ? 1.0 : 1.1 });
  });
  emoji(s, "⚖️", M, 6.1, 24);
  text(s, L("Still open: who may legally issue warnings in Thailand.", "ยังไม่มีข้อสรุป: ใครมีสิทธิ์ออกคำเตือนในไทยตามกฎหมาย"),
    M + 0.65, 6.05, CW - 0.65, 0.5, { size: 20, color: C.mutedDark, valign: "middle" });
}

// ================= 14 · partners =================
{
  const s = frame(14, {
    dark: false, eyebrow: L("The bigger picture · future", "ภาพใหญ่ · อนาคต"), title: L("From helper app to warning partner.", "จากแอปผู้ช่วย สู่พาร์ทเนอร์เตือนภัย"),
    notes: L(
      "Be clear: these are future plans, no partnership or agreement exists yet. What we offer partners is app reach and community sensor data that can sit beside official gauges. The owner leads outreach; we can draft proposals and data-sharing terms. PDPA matters because the app handles location and photo reports.\n" +
      "Figures: none. Partner groups and agency names are the source's own; none added.",
      "พูดให้ชัด: ทั้งหมดนี้เป็นแผนในอนาคต ยังไม่มีความร่วมมือหรือข้อตกลงใดเกิดขึ้น สิ่งที่เราเสนอให้พาร์ทเนอร์คือการเข้าถึงผู้ใช้ผ่านแอป และข้อมูลเซนเซอร์ชุมชนที่ใช้คู่กับมาตรวัดทางการได้ เจ้าของโครงการเป็นผู้นำการติดต่อ เราช่วยร่างข้อเสนอและเงื่อนไขการแบ่งปันข้อมูลได้ PDPA สำคัญเพราะแอปจัดการตำแหน่งที่ตั้งและรายงานที่มีรูปภาพ\n" +
      "ตัวเลข: ไม่มี กลุ่มพาร์ทเนอร์และชื่อหน่วยงานมาจากต้นฉบับ ไม่ได้เพิ่มใหม่"),
  });
  const groups = L([["Government", "TMD, DDPM, HII, RID, local administrations", "Official data, shelter lists, sensor sites"],
    ["Telecom", "Mobile network operators", "NB-IoT and 4G links for stations"],
    ["Big companies", "Insurers, utilities, industrial estates, CSR", "Fund stations, get early warning for sites"]],
  [["ภาครัฐ", "TMD, DDPM, HII, RID, องค์กรปกครองส่วนท้องถิ่น", "ข้อมูลทางการ รายชื่อศูนย์พักพิง จุดติดเซนเซอร์"],
    ["โทรคมนาคม", "ผู้ให้บริการเครือข่ายมือถือ", "การเชื่อมต่อ NB-IoT และ 4G สำหรับสถานี"],
    ["บริษัทขนาดใหญ่", "ประกันภัย สาธารณูปโภค นิคมอุตสาหกรรม CSR", "สนับสนุนสถานี ได้รับเตือนล่วงหน้าสำหรับพื้นที่"]]);
  const gap = 0.3, w = (CW - 2 * gap) / 3, y = Y.top + 0.05, h = 3.85;
  groups.forEach(([n, who, what], i) => {
    const x = M + i * (w + gap);
    card(s, x, y, w, h, C.navy);
    text(s, n, x + 0.3, y + 0.25, w - 0.5, 0.55, { font: F.head, size: 24, bold: true, color: C.cream, valign: "middle" });
    text(s, [{ t: who, o: { color: C.mutedDark } }, { t: what, o: { color: C.amber } }], x + 0.3, y + 0.95, w - 0.5, h - 1.05, { size: 20, gap: 10, lh: TH ? 1.0 : 1.1 });
  });
  text(s, L([{ t: "No partnership exists yet. These are future plans.", o: { bold: true, color: C.ink } },
             { t: "Before any deal: data agreements, PDPA, security review, uptime promise.", o: { color: C.muted } }],
            [{ t: "ยังไม่มีความร่วมมือใดเกิดขึ้น ทั้งหมดเป็นแผนในอนาคต", o: { bold: true, color: C.ink } },
             { t: "ก่อนตกลง: ข้อตกลงข้อมูล PDPA ตรวจความปลอดภัย และสัญญาเวลาให้บริการ", o: { color: C.muted } }]),
    M, 5.95, CW, 0.95, { size: 20, gap: 2, lh: 1.0 });
}

// ================= 15 · roadmap =================
{
  const s = frame(15, {
    dark: true, eyebrow: L("What happens next", "ขั้นต่อไป"), title: L("Code ready. Five decisions left.", "โค้ดพร้อมแล้ว เหลือห้าเรื่องให้ตัดสินใจ"),
    notes: L(
      "Close with the ask. Nothing is deployed and no deploy is planned until these decisions are made. Also pending: Firebase for push notifications (owner said not yet), agency permission letters, and Thai legal review of the disclaimer. Everything is captured in the inputs form in the docs folder, also as a fillable PDF.\n" +
      "Figures: the source listed 6 decisions; decision 3 (app name) is now done as Mahoka, so 5 remain. The source's decision 3 also covered the package id, which is not confirmed as decided [unverified]. [OWNER] marks who decides each item and is left for you to fill in.",
      "ปิดด้วยสิ่งที่ต้องการ ยังไม่มีอะไรเปิดใช้งานจริง และจะไม่วางแผนเปิดใช้จนกว่าจะตัดสินใจเรื่องเหล่านี้ เรื่องที่ยังค้างอยู่ด้วย: Firebase สำหรับการแจ้งเตือนแบบพุช (เจ้าของโครงการบอกว่ายังไม่ใช่ตอนนี้) หนังสืออนุญาตจากหน่วยงาน และการตรวจข้อความปฏิเสธความรับผิดชอบโดยที่ปรึกษากฎหมายไทย ทุกอย่างอยู่ในแบบฟอร์มข้อมูลในโฟลเดอร์ docs และมีเป็น PDF ที่กรอกได้ด้วย\n" +
      "ตัวเลข: ต้นฉบับมี 6 เรื่องให้ตัดสินใจ เรื่องที่ 3 (ชื่อแอป) เสร็จแล้วเป็น Mahoka จึงเหลือ 5 เรื่อง เรื่องที่ 3 ในต้นฉบับครอบคลุม package id ด้วย ซึ่งยังไม่ยืนยันว่าตัดสินใจแล้ว [unverified] [OWNER] คือช่องให้ระบุผู้ตัดสินใจแต่ละเรื่อง เว้นไว้ให้กรอก"),
  });
  // status strip: done + ready to build
  const y = Y.top + 0.05, sh = 1.5, sws = [5.4, CW - 5.7];
  [[L("Done", "เสร็จแล้ว"), C.safe, L("Tier model, rules, offline cache, SOS, About screen.", "โมเดลระดับ กฎประกาศ แคชออฟไลน์ SOS หน้าเกี่ยวกับ")],
   [L("Ready to build", "พร้อมสร้าง"), C.teal, L("Poller, offline maps, send queue, flood map, IoT, translations.", "Poller แผนที่ออฟไลน์ คิวส่ง แผนที่น้ำท่วม IoT การแปลภาษา")]].forEach(([hd, col, body], i) => {
    const sw = sws[i], x = M + (i ? sws[0] + 0.3 : 0);
    card(s, x, y, sw, sh, C.navy2, { line: col, lineW: 2 });
    text(s, hd, x + 0.3, y + 0.12, sw - 0.6, 0.55, { font: F.head, size: 24, bold: true, color: col, valign: "middle" });
    text(s, body, x + 0.3, y + 0.66, sw - 0.5, 0.8, { size: 20, color: C.cream, lh: 1.0 });
  });
  // focal: the ask
  const ya = y + sh + 0.18, h = 6.68 - ya;
  card(s, M, ya, CW, h, C.amber);
  text(s, L("Your call", "ให้คุณตัดสินใจ"), M + 0.35, ya + 0.17, 2.6, 0.56, { font: F.head, size: 24, bold: true, color: C.navy, valign: "middle" });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: M + 3.0, y: ya + 0.2, w: 6.4, h: 0.5, rectRadius: 0.1, fill: { color: C.navy }, line: { type: "none" } });
  text(s, L("✓  Name chosen: Mahoka (มโหฆะ)", "✓  เลือกชื่อแล้ว: Mahoka (มโหฆะ)"), M + 3.2, ya + 0.2, 6.1, 0.5, { size: 20, bold: true, color: C.amber, valign: "middle" });
  const asks = L(["Hosting provider and budget", "Pilot province", "Who writes and reviews Thai safety text",
    "Go-ahead and budget for IoT pilot", "Who leads partner talks"],
  ["ผู้ให้บริการโฮสติ้งและงบประมาณ", "จังหวัดนำร่อง", "ใครเขียนและตรวจข้อความความปลอดภัยภาษาไทย",
    "อนุมัติและงบนำร่องเซนเซอร์ IoT", "ใครเป็นผู้นำการเจรจาพาร์ทเนอร์"]);
  const cw = (CW - 0.7 - 0.4) / 2, items = asks.map((a, i) => `${i + 1}. ${a} [OWNER]`);
  text(s, items.slice(0, 3), M + 0.35, ya + 0.82, cw, h - 0.9, { size: 20, color: C.navy, gap: 2, lh: 1.0 });
  text(s, items.slice(3), M + 0.35 + cw + 0.4, ya + 0.82, cw, h - 0.9, { size: 20, color: C.navy, gap: 2, lh: 1.0 });
}

console.log(FIT.length ? "FIT WARNINGS:\n  " + FIT.join("\n  ") : "FIT: all text boxes fit (estimate)");
if (process.argv.includes("--check")) process.exit(0);
pres.writeFile({ fileName: OUT }).then((f) => console.log("Wrote " + f));

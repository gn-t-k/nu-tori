// 試作: 案A（大きく・濃く）と案B（枠なし＋拡大の吹き出し）の5枚を合成する。使い捨て
import { createRequire } from "node:module";
import { readFile, mkdir } from "node:fs/promises";
const require = createRequire("/Users/gntk/repository/nu-tori/.claude/worktrees/agent-a8051e6d062e57df7/site/package.json");
const { chromium } = require("playwright");

const S = "/private/tmp/claude-501/-Users-gntk-repository-nu-tori--claude-worktrees-bridge-cse-019jSwzfeb59Z9TqCkSygHXD/7118c303-2fb7-5cca-992c-7312a3d5c4e2/scratchpad";
const RAW = `${S}/notes/raw-858`;
const OUT = `${S}/proto/out`;
const BEZEL = "/Users/gntk/repository/nu-tori/site/screenshots/bezel/iphone.png";
const W = 1320, H = 2868;

const raw = {};
for (const n of ["step-weigh", "step-photo", "step-guide", "photo-estimated", "text-meal", "dish-detail", "weekly-review", "eat-while-estimating"]) {
  raw[n] = `data:image/png;base64,${(await readFile(`${RAW}/${n}.png`)).toString("base64")}`;
}
const bezel = `data:image/png;base64,${(await readFile(BEZEL)).toString("base64")}`;

// 生の画面の座標（1320×2868）で切り出す範囲
const crops = {
  weigh: ["step-weigh", 970, 2160, 300, 150],
  photo: ["step-photo", 321, 1406, 947, 904],
  guide: ["step-guide", 52, 1573, 1217, 488],
  estimatedLabel: ["photo-estimated", 321, 2066, 947, 244],
  estimating: ["eat-while-estimating", 321, 2118, 947, 192],
  kcal: ["dish-detail", 63, 1780, 1194, 336],
  target: ["weekly-review", 52, 1587, 1217, 623],
};

const font = `"Hiragino Sans", "Hiragino Kaku Gothic ProN", sans-serif`;
const base = `*{box-sizing:border-box;margin:0}html,body{width:${W}px;height:${H}px;overflow:hidden}body{position:relative;font-family:${font}}
h1{position:absolute;left:90px;right:90px;top:200px;font-weight:800;line-height:1.3;letter-spacing:.01em;white-space:pre-line;text-align:center}
em{font-style:normal}`;

const cut = (key, width, extra = "") => {
  const [n, x, y, w, h] = crops[key];
  const s = width / w;
  return `<div style="position:absolute;width:${w * s}px;height:${h * s}px;overflow:hidden;border-radius:${44 * s}px;box-shadow:0 30px 80px rgba(30,20,90,.28);${extra}">
<img src="${raw[n]}" style="position:absolute;left:${-x * s}px;top:${-y * s}px;width:${W * s}px;height:${H * s}px"></div>`;
};

// 枠の穴（load-bezel.ts で測った値を試作用に手で写す代わりに、ブラウザで測る）
const bezelHole = async (page) => page.evaluate(async (src) => {
  const im = new Image(); im.src = src; await im.decode();
  const c = document.createElement("canvas"); c.width = im.naturalWidth; c.height = im.naturalHeight;
  const g = c.getContext("2d"); g.drawImage(im, 0, 0);
  const d = g.getImageData(0, 0, c.width, c.height).data;
  const clear = (x, y) => d[(y * c.width + x) * 4 + 3] === 0;
  const cx = c.width >> 1, cy = c.height >> 1;
  let l = cx; while (clear(l - 1, cy)) l--; let r = cx; while (clear(r + 1, cy)) r++;
  const px = Math.floor(l + (r - l) / 4);
  let t = cy; while (clear(px, t - 1)) t--; let b = cy; while (clear(px, b + 1)) b++;
  let k = 0; while (!clear(l + k, t + k)) k++;
  return { bw: c.width, bh: c.height, l, t, w: r - l + 1, h: b - t + 1, rad: 191 };
}, bezel);

const framed = (hole, screen, height) => {
  const s = height / hole.bh;
  const width = hole.bw * s;
  return `<div style="position:absolute;left:${(W - width) / 2}px;bottom:110px;width:${width}px;height:${height}px">
<img src="${raw[screen]}" style="position:absolute;left:${(hole.l - 1) * s}px;top:${(hole.t - 1) * s}px;width:${(hole.w + 2) * s}px;height:${(hole.h + 2) * s}px;border-radius:${(hole.rad + 1) * s}px">
<img src="${bezel}" style="position:absolute;inset:0;width:100%;height:100%"></div>`;
};

const headlines = {
  "01": "体重を量って、\n食べる前に<em>撮るだけ</em>",
  "02": "撮って送るだけ。\n撮り忘れたら、書くだけ",
  "03": "撮ったら、あとは\n<em>まかせて閉じられる</em>",
  "04": "栄養は、材料ごとに\n日本食品標準成分表から",
  "05": "食べる量の目安は、\n<em>毎週の体重</em>で決め直す",
};

// 案A: 地は primary、字は白、端末1台を高さの約75%
const variantA = (hole) => {
  const screens = { "01": "step-photo", "02": "photo-estimated", "03": "eat-while-estimating", "04": "dish-detail", "05": "weekly-review" };
  return Object.fromEntries(Object.entries(screens).map(([k, sc]) => [k, `<style>${base}body{background:#6155F5;color:#fff}h1{font-size:112px;top:170px}em{color:#FFE27A}</style>
<h1>${headlines[k]}</h1>${framed(hole, sc, 2180)}`]));
};

// 案B: 地は primary の淡い色、枠なしで画面を大きく置いて下で切り、要のカードを拡大して重ねる
const variantB = () => {
  const bg = `<style>${base}body{background:color-mix(in srgb,#6155F5 22%,#fff);color:#1C1A3A}h1{font-size:108px}em{color:#6155F5}</style>`;
  const screenScale = 1000 / W;
  const screenTop = 760;
  const screen = (n) => `<div style="position:absolute;left:${(W - 1000) / 2}px;top:${screenTop}px;width:1000px;height:${H * screenScale}px;border-radius:110px;overflow:hidden;box-shadow:0 40px 100px rgba(30,20,90,.25);border:14px solid #fff">
<img src="${raw[n]}" style="width:100%;height:100%;display:block"></div>`;
  // 生の画面の y を、置いた画面の上の y に写す
  const at = (key) => screenTop + crops[key][2] * screenScale;
  const step = (num, label, top) => `<div style="position:absolute;left:110px;top:${top}px;display:flex;align-items:center;gap:28px;font-size:64px;font-weight:800;color:#1C1A3A"><span style="display:inline-grid;place-items:center;width:96px;height:96px;border-radius:50%;background:#6155F5;color:#fff;font-size:56px">${num}</span>${label}</div>`;
  return {
    "01": `${bg}<h1>${headlines["01"]}</h1>
${step(1, "朝、体重を量る", 760)}${cut("weigh", 520, "left:690px;top:720px")}
${step(2, "食べる前に撮る", 1000)}${cut("photo", 900, "left:310px;top:1130px")}
${step(3, "目安が合っていく", 2050)}${cut("guide", 1160, "left:80px;top:2190px")}`,
    "02": `${bg}<h1>${headlines["02"]}</h1>${screen("photo-estimated")}${cut("estimatedLabel", 1180, `left:70px;top:${at("estimatedLabel") - 60}px`)}`,
    "03": `${bg}<h1>${headlines["03"]}</h1>${screen("eat-while-estimating")}${cut("estimating", 1180, `left:70px;top:${at("estimating") - 60}px`)}`,
    "04": `${bg}<h1>${headlines["04"]}</h1>${screen("dish-detail")}${cut("kcal", 1200, `left:60px;top:${at("kcal") - 40}px`)}`,
    "05": `${bg}<h1>${headlines["05"]}</h1>${screen("weekly-review")}${cut("target", 1200, `left:60px;top:${at("target") - 80}px`)}`,
  };
};

await mkdir(OUT, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H } });
await page.setContent("<html></html>");
const hole = await bezelHole(page);
for (const [v, set] of [["a", variantA(hole)], ["b", variantB()]]) {
  for (const [k, html] of Object.entries(set)) {
    await page.setContent(html, { waitUntil: "load" });
    await page.screenshot({ path: `${OUT}/${v}-${k}.png` });
  }
}
await browser.close();
console.log("done", hole);

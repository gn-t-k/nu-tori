// 試作（捨てる）: LP の版 a のファーストビューで「何のアプリか」をどこに書くかの見比べ。
// 本物の LP を書き出した site/dist から、ヘッダーとファーストビューだけを案ごとに差し替えた1枚の HTML を作る。
// 回し方: site/ で `pnpm exec vite build` のあと、リポジトリ直下で `node prototype/976-lp-first-view/build.mjs`
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, "../../site/dist");
const read = (p) => readFileSync(join(dist, p), "utf8");
const dataUri = (p, type) =>
  `data:${type};base64,${readFileSync(join(dist, p)).toString("base64")}`;

let lp = read("_lp/a/index.html");
// 画像は data URI にして1枚に収める（Artifact に載せるため）
for (const p of [
  "/landing-a/steps/step-weigh.webp",
  "/landing-a/steps/step-photo.webp",
  "/landing-a/steps/step-guide.webp",
  "/landing-a/curry.webp",
  "/landing-a/onigiri.webp",
  "/landing-a/oyakodon.webp",
]) {
  lp = lp.replaceAll(p, dataUri(p.slice(1), "image/webp"));
}
lp = lp.replaceAll("/app-store-badge.svg", dataUri("app-store-badge.svg", "image/svg+xml"));
lp = lp
  .replace(/<script defer="" src="https:\/\/static\.cloudflareinsights[^>]*><\/script>/, "")
  .replace('<link rel="stylesheet" href="/site.css"/>', `<style>${read("site.css")}</style>`)
  .replace('<script src="/landing-a.js" defer=""></script>', `<script>${read("landing-a.js")}</script>`)
  .replace(/<link rel="canonical"[^>]*>/, "");

const header = lp.match(/<header class="site-header">.*?<\/header>/)[0];
const h1 = lp.match(/<h1>.*?<\/h1>/)[0];
const lead = lp.match(/<p class="lp-lead">.*?<\/p>/)[0];

// 試作だけの見た目。トークンは site.css のものを使う
const protoCss = `
.proto-kicker{word-break:keep-all;overflow-wrap:anywhere;text-wrap:balance;margin:0 0 12px;font-size:17px;font-weight:600;color:var(--primary)}
.site-header .proto-tagline{margin-left:8px;font-size:15px;color:var(--lp-secondary)}
`;

const variants = [
  {
    key: "now",
    name: "今",
    note: "見出しは得られること、補足はすること。何のアプリかは書いていない",
    header,
    h1,
    lead,
  },
  {
    key: "A",
    name: "見出しの上に一行",
    note: "見出しと補足はそのまま。見出しの上に、App Store の名前と同じ語で何のアプリかを置く",
    header,
    h1: `<p class="proto-kicker">写真で食事記録と<wbr/>カロリー計算の<wbr/>iPhone アプリ</p>${h1}`,
    lead,
  },
  {
    key: "B",
    name: "補足を差し替え",
    note: "見出しはそのまま。補足を「何のアプリか」に替え、「すること」は下の手順の3枚に任せる",
    header,
    h1,
    lead: `<p class="lp-lead">食事の写真でカロリーを記録し、<wbr/>体重の動きから、あなたに合った1日のカロリーを毎週計算し直す iPhone のアプリです。</p>`,
  },
  {
    key: "B2",
    name: "補足を2文に（開発者の案）",
    note: "見出しはそのまま。補足の1文目で何のアプリか、2文目で今の「すること」を言う",
    header,
    h1,
    lead: `<p class="lp-lead">あなたに合った1日の摂取カロリーを計算するiPhoneアプリです。あなたがすることは、体重を量ることと食べる前に写真を1枚撮ることだけです。</p>`,
  },
  {
    key: "B3",
    name: "B2 に「毎週計算し直す」",
    note: "B2 の1文目を「毎週計算し直す」にして一度きりの計算機と分け、2文目の「あなたが」を落とす",
    header,
    h1,
    lead: `<p class="lp-lead">あなたに合った1日の摂取カロリーを毎週計算し直す iPhone アプリです。することは、体重を量ることと食べる前に写真を1枚撮ることだけです。</p>`,
  },
  {
    key: "C",
    name: "見出しに入れる",
    note: "見出しの終わりを「食事記録アプリ」にして、見出しだけで分類まで言う。補足はそのまま",
    header,
    h1: `<h1>続けるほど、<wbr/>あなたにちょうどいい<wbr/>量が分かる、<wbr/>食事記録アプリ</h1>`,
    lead,
  },
  {
    key: "D",
    name: "ヘッダーに説明",
    note: "ファーストビューはそのまま。ヘッダーの名前の横に、App Store の名前の後半を置く",
    header: header.replace(
      "nu-tori</a>",
      `nu-tori</a><span class="proto-tagline">写真で食事記録とカロリー計算</span>`,
    ),
    h1,
    lead,
  },
];

const pages = variants.map((v) =>
  lp
    .replace(header, v.header)
    .replace(h1, v.h1)
    .replace(lead, v.lead)
    .replace("</head>", `<style>${protoCss}</style></head>`),
);

// Artifact が <html>・<head>・<body> で包むので、中身だけを書く
const shell = `<title>LP ファーストビュー試作</title>
<style>
:root{--bg:#e5e5ea;--fg:#000;--bar:#1c1c1e;--bar-fg:#fff;--muted:#3c3c43}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#2c2c2e;--fg:#fff;--bar:#f2f2f7;--bar-fg:#000;--muted:#ebebf5}}
:root[data-theme="dark"]{--bg:#2c2c2e;--fg:#fff;--bar:#f2f2f7;--bar-fg:#000;--muted:#ebebf5}
html,body{margin:0;height:100%}
body{background:var(--bg);color:var(--fg);font-family:-apple-system,BlinkMacSystemFont,"Hiragino Sans",sans-serif;display:flex;flex-direction:column}
.note{padding:10px 16px 6px;font-size:14px;color:var(--muted);text-align:center}
.note b{color:var(--fg)}
.stage{flex:1;display:flex;justify-content:center;padding:0 0 calc(76px + env(safe-area-inset-bottom, 0px));min-height:0}
iframe{border:0;background:#fff;height:100%;width:100%;transition:width .2s}
body.phone iframe{width:390px;max-width:100%;box-shadow:0 0 0 1px rgba(0,0,0,.15)}
.bar{position:fixed;left:50%;bottom:16px;transform:translateX(-50%);display:flex;align-items:center;gap:4px;background:var(--bar);color:var(--bar-fg);border-radius:999px;padding:6px;box-shadow:0 6px 20px rgba(0,0,0,.3);font-size:15px;white-space:nowrap}
.bar button{background:none;border:0;color:inherit;font:inherit;padding:8px 12px;border-radius:999px;cursor:pointer}
.bar button:hover{background:rgba(127,127,127,.25)}
.bar .label{min-width:11em;text-align:center;font-weight:600}
.bar .width{border-left:1px solid rgba(127,127,127,.4);border-radius:0 999px 999px 0;padding-left:14px}
</style>
<p class="note">試作（捨てる）: <b id="name"></b> — <span id="desc"></span></p>
<div class="stage"><iframe id="f" title="LP"></iframe></div>
<div class="bar">
  <button id="prev" aria-label="前の案">←</button>
  <span class="label" id="label"></span>
  <button id="next" aria-label="次の案">→</button>
  <button class="width" id="width"></button>
</div>
<script>
const variants = ${JSON.stringify(variants.map(({ key, name, note }) => ({ key, name, note })))};
const pages = ${JSON.stringify(pages).replaceAll("</", "<\\/")};
const f = document.getElementById("f");
let i = Math.max(0, variants.findIndex((v) => v.key === new URLSearchParams(location.search).get("variant")));
const show = () => {
  const v = variants[i];
  f.srcdoc = pages[i];
  document.getElementById("label").textContent = v.key === "now" ? "今" : v.key + "（" + v.name + "）";
  document.getElementById("name").textContent = v.key === "now" ? "今の形" : "案 " + v.key + "：" + v.name;
  document.getElementById("desc").textContent = v.note;
  try { const u = new URL(location.href); u.searchParams.set("variant", v.key); history.replaceState(null, "", u); } catch {}
};
const step = (d) => { i = (i + d + variants.length) % variants.length; show(); };
document.getElementById("prev").onclick = () => step(-1);
document.getElementById("next").onclick = () => step(1);
const widthBtn = document.getElementById("width");
const syncWidth = () => { widthBtn.textContent = document.body.classList.contains("phone") ? "幅: 携帯 390" : "幅: 画面いっぱい"; };
widthBtn.onclick = () => { document.body.classList.toggle("phone"); syncWidth(); };
addEventListener("keydown", (e) => {
  if (e.target.closest && e.target.closest("input,textarea,[contenteditable]")) return;
  if (e.key === "ArrowLeft") step(-1);
  if (e.key === "ArrowRight") step(1);
});
document.body.classList.add("phone");
syncWidth();
show();
</script>`;

writeFileSync(join(here, "index.html"), shell);
console.log("wrote", join(here, "index.html"), (shell.length / 1024).toFixed(0) + " KB");

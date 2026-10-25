// PROTOTYPE（#745）。data.json（simulate.ts が本番のドメインの関数で出した値）から、3案を見比べる index.html を書き出す。
// 図はすべて静的な SVG と CSS。案の切り替えの下の帯だけが JavaScript で、本番には持ち込まない。
// 回し方: node site/prototype/daily-guide-745/build.mjs
import { readFileSync, writeFileSync } from "node:fs";

const data = JSON.parse(readFileSync(new URL("./data.json", import.meta.url), "utf8"));
const { initial, reviews, days, priorDays, plateau } = data;

const kcal = (v) => Math.round(v).toLocaleString("en-US");
const kg1 = (v) => v.toFixed(1);
const kg2 = (v) => Math.abs(v).toFixed(2);
const signedKg = (v) => `${v < 0 ? "−" : "+"}${kg2(v)}`;
const md = (day) => {
  const [, m, d] = day.split("-").map(Number);
  return `${m}月${d}日`;
};
const mdShort = (day) => {
  const [, m, d] = day.split("-").map(Number);
  return `${m}/${d}`;
};
// 動かした割合 k。丸めた推定から逆に出し、0.05 単位に寄せる（本番の値は 0.25・0.5・0.75 のどれか）
const gainOf = (r) =>
  Math.round(
    ((r.expenditureKcal - r.previousExpenditureKcal) / ((7700 * r.deviationKg) / 7)) * 20,
  ) / 20;
const addDaysIso = (day, n) => {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};
const scale = (d0, d1, r0, r1) => (v) => r0 + ((v - d0) / (d1 - d0)) * (r1 - r0);
const path = (points) =>
  points.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x.toFixed(1)} ${y.toFixed(1)}`).join(" ");

// ---------- 図1: 毎朝の体重と体重の傾向 ----------
const trendFigure = ({ id, withPrior = true, caption = true }) => {
  const series = [...(withPrior ? priorDays.slice(-14) : []), ...days];
  const W = 360,
    H = 230,
    L = 34,
    R = 74,
    T = 14,
    B = 30;
  const x = scale(0, series.length - 1, L, W - R);
  const y = scale(76.6, 79.2, H - B, T);
  const ticks = [77, 78, 79];
  const startIndex = withPrior ? 14 : 0;
  const last = series.at(-1);
  return `
<figure class="figure" id="${id}">
  <div class="figure-scroll">
  <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="毎朝の体重は1日で0.5 kg ほど上下するが、体重の傾向はなめらかに動く">
    ${ticks.map((t) => `<line class="grid" x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}"/><text class="tick" x="${L - 6}" y="${y(t) + 4}" text-anchor="end">${t}</text>`).join("")}
    ${withPrior ? `<line class="marker" x1="${x(startIndex)}" x2="${x(startIndex)}" y1="${T}" y2="${H - B}"/><text class="tick" x="${x(startIndex) + 4}" y="${T + 10}">使い始めた日</text>` : ""}
    ${series.map((d, i) => `<circle class="dot" cx="${x(i).toFixed(1)}" cy="${y(d.weightKg).toFixed(1)}" r="2.6"/>`).join("")}
    <path class="trend" d="${path(series.map((d, i) => [x(i), y(d.trendKg)]))}"/>
    <text class="series-label" x="${W - R + 6}" y="${y(last.trendKg) + 4}">体重の傾向</text>
    <text class="series-label muted" x="${W - R + 6}" y="${y(last.weightKg) + 16}">毎朝の体重</text>
    <text class="tick" x="${x(0)}" y="${H - 10}" text-anchor="start">${mdShort(series[0].calendarDay)}</text>
    <text class="tick" x="${x(series.length - 1)}" y="${H - 10}" text-anchor="end">${mdShort(last.calendarDay)}</text>
    <text class="tick" x="${L - 6}" y="${T - 2}" text-anchor="end">kg</text>
  </svg>
  </div>
  ${caption ? `<figcaption>点は毎朝の体重、線は体重の傾向です。1日で 0.5 kg ほど上下しても、傾向はなめらかに動きます。nu-tori は、傾向のほうの動きを見ます。</figcaption>` : ""}
</figure>`;
};

// ---------- 図2: 1週の見直し（予想した動きと実際の傾向のずれ） ----------
const reviewFigure = ({ id, review = reviews[1], caption = true }) => {
  const weekEndIndex = days.findIndex(
    (d) => d.calendarDay === addDaysIso(review.reviewedMonday, -1),
  );
  const weekStartIndex = weekEndIndex - 7; // その前の日曜
  const segment = days.slice(weekStartIndex, weekEndIndex + 1);
  const startKg = segment[0].trendKg;
  const predictedEnd = startKg + review.predictedWeightChangeKg;
  const actualEnd = segment.at(-1).trendKg;
  const W = 360,
    H = 240,
    L = 34,
    R = 96,
    T = 16,
    B = 30;
  const x = scale(0, 7, L, W - R);
  const lo = Math.min(predictedEnd, actualEnd) - 0.15;
  const hi = startKg + 0.2;
  const y = scale(lo, hi, H - B, T);
  const ticks = [];
  for (let t = Math.ceil(lo * 10) / 10; t <= hi; t = Math.round((t + 0.1) * 10) / 10) ticks.push(t);
  const gapX = x(7) + 10;
  return `
<figure class="figure" id="${id}">
  <div class="figure-scroll">
  <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="予想した体重の動きと、実際の体重の傾向のずれ">
    ${ticks.map((t) => `<line class="grid" x1="${L}" x2="${x(7)}" y1="${y(t)}" y2="${y(t)}"/><text class="tick" x="${L - 6}" y="${y(t) + 4}" text-anchor="end">${t.toFixed(1)}</text>`).join("")}
    <path class="predicted" d="${path([
      [x(0), y(startKg)],
      [x(7), y(predictedEnd)],
    ])}"/>
    <path class="trend" d="${path(segment.map((d, i) => [x(i), y(d.trendKg)]))}"/>
    <circle class="end" cx="${x(7)}" cy="${y(predictedEnd)}" r="3.5"/>
    <circle class="end trend-end" cx="${x(7)}" cy="${y(actualEnd)}" r="3.5"/>
    <text class="series-label" x="${x(0) + 4}" y="${y(Math.max(...segment.map((d) => d.trendKg))) - 10}">実際の傾向 ${signedKg(review.actualWeightChangeKg)} kg</text>
    <text class="series-label muted" x="${x(3)}" y="${y(startKg + (review.predictedWeightChangeKg * 3) / 7) + 20}" text-anchor="middle">予想 ${signedKg(review.predictedWeightChangeKg)} kg</text>
    <path class="gap" d="M${gapX} ${y(actualEnd)} h6 V${y(predictedEnd)} h-6"/>
    <text class="gap-label" x="${gapX + 12}" y="${(y(actualEnd) + y(predictedEnd)) / 2 - 2}">ずれ</text>
    <text class="gap-label" x="${gapX + 12}" y="${(y(actualEnd) + y(predictedEnd)) / 2 + 14}">${kg2(review.deviationKg)} kg</text>
    <text class="tick" x="${x(0)}" y="${H - 10}" text-anchor="start">${mdShort(segment[0].calendarDay)}（日）</text>
    <text class="tick" x="${x(7)}" y="${H - 10}" text-anchor="end">${mdShort(segment.at(-1).calendarDay)}（日）</text>
    <text class="tick" x="${L - 6}" y="${T - 4}" text-anchor="end">kg</text>
  </svg>
  </div>
  ${caption ? `<figcaption>${md(segment[1].calendarDay)}〜${md(segment.at(-1).calendarDay)}の週。食べた量の平均 ${kcal(review.averageEnergyIntakeKcal)} kcal と、推定消費カロリー ${kcal(review.previousExpenditureKcal)} kcal の差から予想した動き（点線）より、実際の傾向（実線）は減りませんでした。</figcaption>` : ""}
</figure>`;
};

// ずれから推定消費カロリーを動かす式を、1週ぶん数字で見せる
const reviewEquation = (review = reviews[1]) => {
  const perDay = (7700 * Math.abs(review.deviationKg)) / 7;
  const k = gainOf(review);
  return `
<div class="equation">
  <div class="eq-row"><span class="eq-label">ずれ</span><span class="eq-value">${kg2(review.deviationKg)} kg × 7,700 kcal ÷ 7 日 ＝ 1日 ${kcal(perDay)} kcal</span></div>
  <div class="eq-row"><span class="eq-label">動かす割合</span><span class="eq-value">× ${k}（${review.recordedMealDayCount}日記録・同じ向きのずれが${k === 0.25 ? "初めて" : `${Math.round(k / 0.25)}週続いた`}）</span></div>
  <div class="eq-row eq-result"><span class="eq-label">推定消費カロリー</span><span class="eq-value">${kcal(review.previousExpenditureKcal)} → <strong>${kcal(review.expenditureKcal)} kcal</strong></span></div>
</div>`;
};

// ---------- 図3: 4週間の推定消費カロリーと1日の目安 ----------
const weeksFigure = ({ id, caption = true }) => {
  const W = 360,
    H = 250,
    L = 40,
    R = 84,
    T = 16,
    B = 30;
  const x = scale(0, 5, L, W - R); // 週 0〜5（4回の見直しのあと1週）
  const y = scale(1500, 2450, H - B, T);
  const est = [initial.kcal, ...reviews.map((r) => r.expenditureKcal)];
  const guide = [initial.guideKcal, ...reviews.map((r) => r.guideKcal)];
  const step = (vals) =>
    path(
      vals.flatMap((v, i) => [
        [x(i), y(v)],
        [x(i + 1), y(v)],
      ]),
    );
  const trueLine = path(
    days
      .filter((_, i) => i % 7 === 0 || i === days.length - 1)
      .map((d, i, arr) => [x(i === arr.length - 1 ? 4 : i), y(d.trueExpenditureKcal)]),
  );
  const ticks = [1600, 1800, 2000, 2200, 2400];
  return `
<figure class="figure" id="${id}">
  <div class="figure-scroll">
  <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="推定消費カロリーが毎週の見直しで本当の消費に近づき、1日の目安もそれに沿って下がる">
    ${ticks.map((t) => `<line class="grid" x1="${L}" x2="${x(5)}" y1="${y(t)}" y2="${y(t)}"/><text class="tick" x="${L - 6}" y="${y(t) + 4}" text-anchor="end">${kcal(t)}</text>`).join("")}
    <path class="truth" d="${trueLine}"/>
    <path class="trend" d="${step(est)}"/>
    <path class="guide" d="${step(guide)}"/>
    ${est.map((v, i) => `<text class="value" x="${(x(i) + x(i + 1)) / 2}" y="${y(v) - 6}" text-anchor="middle">${kcal(v)}</text>`).join("")}
    ${guide.map((v, i) => `<text class="value muted" x="${(x(i) + x(i + 1)) / 2}" y="${y(v) + 15}" text-anchor="middle">${kcal(v)}</text>`).join("")}
    <text class="series-label" x="${x(5) + 6}" y="${y(est.at(-1)) - 2}">推定消費</text>
    <text class="series-label" x="${x(5) + 6}" y="${y(est.at(-1)) + 12}">カロリー</text>
    <text class="series-label muted" x="${x(5) + 6}" y="${y(guide.at(-1)) + 4}">1日の目安</text>
    <text class="series-label faint" x="${x(4) + 4}" y="${y(days.at(-1).trueExpenditureKcal) - 22}">本当の消費</text>
    ${[0, 1, 2, 3, 4].map((i) => `<text class="tick" x="${(x(i) + x(i + 1)) / 2}" y="${H - 10}" text-anchor="middle">${i === 0 ? "1週目" : i + 1 + "週目"}</text>`).join("")}
    <text class="tick" x="${L - 6}" y="${T - 4}" text-anchor="end">kcal</text>
  </svg>
  </div>
  ${caption ? `<figcaption>架空の1人の例です。「本当の消費」（点線）は、この人の体だけが知っている値として置いた仮定で、nu-tori には見えません。推定消費カロリーは、毎週のずれから本当の消費に近づいていきます。</figcaption>` : ""}
</figure>`;
};

// ---------- 図4: 見直さずに同じ量を食べ続けたら ----------
const plateauFigure = ({ id, caption = true }) => {
  const W = 360,
    H = 220,
    L = 34,
    R = 20,
    T = 16,
    B = 30;
  const w0 = plateau[0].week,
    w1 = plateau.at(-1).week;
  const x = scale(w0, w1, L, W - R);
  const y = scale(58, 80, H - B, T);
  const ticks = [60, 65, 70, 75];
  const at = (w) => plateau.reduce((a, b) => (Math.abs(b.week - w) < Math.abs(a.week - w) ? b : a));
  const p1 = at(w0 + 52),
    p2 = at(w1);
  return `
<figure class="figure" id="${id}">
  <div class="figure-scroll">
  <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="同じ量を食べ続けると、体重の減り方がだんだん緩くなり、止まっていく">
    ${ticks.map((t) => `<line class="grid" x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}"/><text class="tick" x="${L - 6}" y="${y(t) + 4}" text-anchor="end">${t}</text>`).join("")}
    <path class="trend" d="${path(plateau.map((p) => [x(p.week), y(p.trueWeightKg)]))}"/>
    <circle class="end trend-end" cx="${x(p1.week)}" cy="${y(p1.trueWeightKg)}" r="3.5"/>
    <text class="value" x="${x(p1.week) + 6}" y="${y(p1.trueWeightKg) - 12}" text-anchor="start">1年で ${kg1(plateau[0].trueWeightKg - p1.trueWeightKg)} kg 減</text>
    <circle class="end trend-end" cx="${x(p2.week)}" cy="${y(p2.trueWeightKg)}" r="3.5"/>
    <text class="value" x="${x(p2.week)}" y="${y(p2.trueWeightKg) - 14}" text-anchor="end">次の1年は ${kg1(p1.trueWeightKg - p2.trueWeightKg)} kg 減</text>
    <text class="tick" x="${x(w0)}" y="${H - 10}" text-anchor="start">今</text>
    <text class="tick" x="${x(w0 + 52)}" y="${H - 10}" text-anchor="middle">1年後</text>
    <text class="tick" x="${x(w1)}" y="${H - 10}" text-anchor="end">2年後</text>
    <text class="tick" x="${L - 6}" y="${T - 4}" text-anchor="end">kg</text>
  </svg>
  </div>
  ${caption ? `<figcaption>${kcal(reviews.at(-1).guideKcal)} kcal を見直さずに食べ続けたときの体重の動き（同じ仮定で計算）。体重が減ると消費も減り（この例では 1 kg あたり 1日 27 kcal）、食べた量との差が縮んで、減り方がだんだん緩くなります。nu-tori は毎週の見直しで、この変化に合わせて1日の目安を直します。</figcaption>` : ""}
</figure>`;
};

// 流れの図の箱
const box = (x, y, w, lines, cls = "") =>
  `<rect class="node ${cls}" x="${x}" y="${y}" width="${w}" height="${lines.length > 1 ? 48 : 36}" rx="10"/>` +
  lines
    .map(
      (l, i) =>
        `<text class="node-text ${cls}" x="${x + w / 2}" y="${y + (lines.length > 1 ? 20 + i * 17 : 23)}" text-anchor="middle">${l}</text>`,
    )
    .join("");

// ---------- 図5（案C）: 毎週の見直しの流れ ----------
const loopFigure = ({ id }) => {
  const arrow = (d) => `<path class="arrow" d="${d}" marker-end="url(#${id}-head)"/>`;
  return `
<figure class="figure figure-loop" id="${id}">
  <div class="figure-scroll">
  <svg viewBox="0 0 360 470" role="img" aria-label="毎週の見直しの流れ">
    <defs><marker id="${id}-head" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path class="arrow-head" d="M0 0 L10 5 L0 10 z"/></marker></defs>
    <text class="col-label" x="100" y="14" text-anchor="middle">食事の記録から</text>
    <text class="col-label" x="265" y="14" text-anchor="middle">体重の記録から</text>
    ${box(36, 24, 128, ["食べた量"])}
    ${box(196, 24, 138, ["毎朝の体重"])}
    ${box(36, 92, 128, ["推定消費カロリー", "との差"])}
    ${box(196, 92, 138, ["体重の傾向", "（揺れをならす）"])}
    ${box(36, 172, 128, ["予想した", "体重の動き"])}
    ${box(196, 172, 138, ["実際の", "体重の動き"])}
    ${arrow("M100 60 V90")}
    ${arrow("M265 60 V90")}
    ${arrow("M100 140 V170")}
    ${arrow("M265 140 V170")}
    ${box(110, 258, 150, ["ずれ"], "accent")}
    ${arrow("M100 220 L160 256")}
    ${arrow("M265 220 L210 256")}
    ${box(96, 326, 178, ["推定消費カロリーを", "ずれの分だけ動かす"])}
    ${box(96, 406, 178, ["1日の目安を", "出し直す"])}
    ${arrow("M185 294 V324")}
    ${arrow("M185 374 V404")}
    <path class="arrow loop" d="M96 430 H16 V42 H34" marker-end="url(#${id}-head)"/>
    <text class="col-label loop-label" x="56" y="452" text-anchor="middle">次の週へ</text>
  </svg>
  </div>
  <figcaption>毎週月曜に、前の週（月〜日）の記録でこの流れを1回まわします。</figcaption>
</figure>`;
};

const persona = `30歳・身長 172 cm・ほぼ座り仕事の男性。使い始める前の4週間は体重計だけ使い、体重の傾向は ${kg1(initial.startingWeightTrendKg)} kg で横ばい。食事は記録していなかったので、最初の推定消費カロリーは式で出します。目標は12週で ${kg1(74.4)} kg`;

// ---------- ミントのピラミッドで組み直した2案 ----------
// どちらも、導入を状況（S）→ 複雑化（C）→ 問い（Q）で書き、その直後に答え（A）を置く。
// 答えを支える要点（キーライン）を、漏れなく重ならず並べ、見出しは話題の名前でなく、言いたいことの文にする

// 試作だけの、文書の骨組みの表示
const structurePanel = ({ s, c, q, a, axis, keyLine }) => `
<details class="proto-structure" open>
  <summary>PROTOTYPE: この案の骨組み</summary>
  <dl>
    <div><dt>状況</dt><dd>${s}</dd></div>
    <div><dt>複雑化</dt><dd>${c}</dd></div>
    <div><dt>問い</dt><dd>${q}</dd></div>
    <div><dt>答え</dt><dd><strong>${a}</strong></dd></div>
  </dl>
  <p class="proto-axis">答えに読み手が返す問い「${axis}」に、要点で答える</p>
  <ol>${keyLine.map((k) => `<li>${k}</li>`).join("")}</ol>
</details>`;

const keyLineNav = (items) =>
  `<ol class="key-line">${items.map(([id, text]) => `<li><a href="#${id}">${text}</a></li>`).join("")}</ol>`;

const rules = {
  backCalculated: `<p>今日を除く直前の 28 日の、食べた量と体重から出します。食べた量は、nu-tori を使い始めた日からは nu-tori の食事の記録を、使い始める前の日はヘルスケアの摂取エネルギーを使います。</p>
<ul><li>食べた量のある日が 14 日以上あること。食べた量がほかの日の中ほどの値の半分に満たない日（1食だけ記録した日など）は、記録の途中とみなして数えません</li><li>体重を記録した日が 4 日以上あり、最初の日から最後の日まで 14 日以上あること</li></ul>
<p>食べた量の1日の平均から、体重の傾きの分を引いて出します。体重 1 kg の増減を 7,700 kcal とみなし、たとえば体重が1日に 0.1 kg ずつ減っていれば、食べた量の平均に 770 kcal を足した値になります。</p>`,
  formula: `<p>身長・生年月日（年齢）・性別と、開始の日の体重の傾向から、安静にしているときの消費を Mifflin-St Jeor の式で出し、活動量の係数を掛けます。ヘルスケアから読めない値は、アプリで入れていただきます。</p>
<ul><li>歩数が読めるとき: 直前 28 日の、歩いた日の平均の歩数で決めます。5,000 歩未満は 1.4、10,000 歩未満は 1.55、それ以上は 1.7</li><li>歩数が読めないとき: 3つから選んでいただきます。ほぼ座り仕事は 1.4、立ち仕事が多いは 1.55、よく動くは 1.7</li></ul>
<p>身体データと、使い始める前の摂取エネルギーは、この計算にだけ使い、保存しません。</p>`,
  pace: `<p>1日に減らす（足す）分は、期限の日までに目標体重へ届くのに要る体重の変化の速さに、7,700 kcal/kg を掛けて出します。たとえば、体重の傾向が1日に 0.05 kg ずつ減る速さなら、1日に 385 kcal を減らします。増量では、1日に足す分を足します。維持では、体重の傾向が目標体重の ±0.7 kg の中にあれば、減らしも足しもしません。外れたら、体重の傾向の 1週間に 0.15% の速さで目標体重へ戻す分だけ減らし（足し）ます。</p>`,
  limits: `<p>値は 50 kcal 単位に丸め、次の上限と下限を当てます。</p>
<ul><li>必要な速さの上限: 1週間に、開始の日の体重の傾向の 0.75%（減量）・0.5%（増量）より速くしません。期限までの日が少なくても、無理な速さにしません</li><li>1日の目安の下限: 1,200 kcal より低くしません</li><li>1週の変化の幅: 毎週の見直しで、前の週の1日の目安から ±150 kcal より大きく変えません</li></ul>`,
  review: `<ol><li>前の週（月曜から日曜）の食べた量の平均と、そのときの推定消費カロリーから、体重の傾向がどれだけ変わるはずだったかを出します</li><li>実際の体重の傾向の変化と比べ、ずれの分だけ推定消費カロリーを動かします。一度に全部は動かさず、食事を記録した日が多い週ほど、同じ向きのずれが続いた週ほど大きく動かします</li><li>新しい推定消費カロリーで、1日の目安を出し直します</li></ol>`,
  skip: `<p>次のどれかに当たる週は、見直しを見送り、推定消費カロリーも1日の目安も前の週のままにします。</p>
<ul><li>使い始めて 7 日に満たない（最初の値を食べた量と体重から逆算したときは当てません）</li><li>その週に体重の記録が無い</li><li>その週に食事を記録した日が 4 日に満たない（1食だけ記録した日などは数えません）</li></ul>`,
  trend: `<p>体重の傾向は、体重の記録から日々の増減をならした体重の推移です。運動の記録やワークアウト、消費したエネルギーの記録は使いません。運動した分も、体重の傾向の動きに表れるからです。</p>`,
};

const howToRecord = `<p>毎朝の体重と、食事の記録が揃うほど、推定は本当の消費に近づき、1日の目安も合っていきます。</p>
<ul><li>体重は、毎朝、同じころに量ってください。日々の揺れが小さくなります</li><li>食事は、食べたものを撮るか書くかして、1日の分をなるべく全部記録してください。1食だけの日は、見直しに数えません</li></ul>`;

const medical = `<h2>医療の助言ではありません</h2>
<p>持病のある方は、医師に相談してください。</p>`;

const exampleIntro = `<p class="persona">例: ${persona}。式の値は ${kcal(initial.kcal)} kcal、1日の目安は ${kcal(initial.guideKcal)} kcal でした。この人の本当の消費は 2,150 kcal だったとします（nu-tori には見えない値）。</p>`;

// ---------- 案D: 手順のピラミッド（どうやって？に、手順の順で答える） ----------
const variantD = `
${structurePanel({
  s: "1日の目安は、消費カロリーから目標の速さで減らす分を引いた値",
  c: "消費カロリーは測れない。人によって数百 kcal 違い、体重が減れば消費も減る",
  q: "nu-tori は、どうやって自分に合った目安を出し続けるのか",
  a: "毎週の記録で、予想と実際の体重の動きのずれから、推定消費カロリーを直す。記録を続けるほど、目安は体に合っていく",
  axis: "どうやって？",
  keyLine: [
    "最初の推定を、記録か身体データから出す",
    "毎週、ずれから推定を直す",
    "直した推定から、1日の目安を出す",
  ],
})}
<h1>推定消費カロリーと1日の目安の出し方</h1>
<p>目標を立てると、nu-tori は1日に食べる量の目安（1日の目安）を出します。1日の目安は、1日に消費するカロリーから、目標の速さで減らす分を引いた値です。</p>
<p>ところが、1日に消費するカロリーは測れません。同じ身長・体重・年齢でも、人によって数百 kcal 違います。体重が減れば、消費も減ります。</p>
<div class="answer"><p><strong>そこで nu-tori は、毎週の体重と食事の記録から、消費カロリーを推定し直します。</strong>食べた量から予想した体重の動きと、実際の体重の傾向がずれたら、ずれの分だけ推定を直します。記録を続けるほど、1日の目安はあなたの体に合っていきます。</p></div>
${loopFigure({ id: "d-loop" })}
<p>出し方は、次の3つの段です。</p>
${keyLineNav([
  ["d-1", "最初の推定消費カロリーは、記録か身体データから出します"],
  ["d-2", "毎週、予想と実際の体重の動きのずれから、推定を直します"],
  ["d-3", "1日の目安は、直した推定から、目標の速さで減らす分を引いて出します"],
])}

<h2 id="d-1">1. 最初の推定消費カロリーは、記録か身体データから出します</h2>
<p>初めて目標を立てるとき、記録が足りれば記録から逆算し、足りなければ身長・年齢・性別から式で出します。式の値は、同じ体格の人の平均なので、あなたの本当の消費とずれていることがあります。ずれは、次の毎週の見直しで直します。</p>
<h3>記録が足りるときは、食べた量と体重の傾向から逆算します</h3>
${rules.backCalculated}
<h3>記録が足りないときは、身体データから式で出します</h3>
${rules.formula}

<h2 id="d-2">2. 毎週、予想と実際の体重の動きのずれから、推定を直します</h2>
<p>毎週月曜に、前の週（月曜から日曜）の記録で見直します。予想した動きと実際の動きを比べ、ずれの一部ずつ推定を動かします。くり返すと、推定は本当の消費に近づきます。</p>
<h3>体重は、日々の揺れをならした傾向で見ます</h3>
${trendFigure({ id: "d-trend" })}
${rules.trend}
<h3>食べた量から予想した動きと、実際の傾向を比べます</h3>
${reviewFigure({ id: "d-review" })}
<h3>ずれの一部ずつ、推定を動かします</h3>
${reviewEquation()}
<p>一度に全部は動かしません。食事を記録した日が多い週ほど、同じ向きのずれが続いた週ほど、大きく動かします。</p>
<h3>くり返すと、推定は本当の消費に近づきます</h3>
${exampleIntro}
${weeksFigure({ id: "d-weeks" })}
<h3>記録が少ない週は、見直しを見送ります</h3>
${rules.skip}

<h2 id="d-3">3. 1日の目安は、直した推定から、目標の速さで減らす分を引いて出します</h2>
<p>推定を直すたびに、1日の目安も出し直します。体重が減ると消費も減るので、目安もそれに合わせて下がっていきます。</p>
<h3>減らす分は、期限までに目標体重へ届く速さから出します</h3>
${rules.pace}
<h3>無理な速さや急な変化にならないよう、上限と下限を当てます</h3>
${rules.limits}
<h3>見直さずに同じ量を食べ続けると、減り方が緩くなっていきます</h3>
${plateauFigure({ id: "d-plateau" })}

<h2>推定を確かにするために、毎朝の体重と1日分の食事を記録してください</h2>
${howToRecord}
${medical}
`;

// ---------- 案E: 理由のピラミッド（目安が外れていたら？に、理由で答える） ----------
const variantE = `
${structurePanel({
  s: "1日の目安は、推定消費カロリーから目標の速さで減らす分を引いた値",
  c: "最初の推定は、同じ体格の人の平均。本当の消費と数百 kcal ずれていることがある",
  q: "最初の目安が外れていたら、どうなるのか",
  a: "外れていても、目安は記録で毎週直るので、使い続けるほど合っていく",
  axis: "なぜそう言える？",
  keyLine: [
    "ずれの分だけ直すので、本当の消費に近づく（正しさ）",
    "体重が減っても直し続けるので、目安がずれていかない（変化への追従）",
    "一度に大きく変えないので、揺れに振り回されない（安定）",
  ],
})}
<h1>推定消費カロリーと1日の目安の出し方</h1>
<p>目標を立てると、nu-tori は1日に食べる量の目安（1日の目安）を出します。1日の目安は、推定消費カロリーから、目標の速さで減らす分を引いた値です。</p>
<p>推定消費カロリーの最初の値は、記録が足りなければ、身長・年齢・性別から出した、同じ体格の人の平均です。あなたの本当の消費とは、数百 kcal ずれていることがあります。</p>
<p>では、最初の目安が外れていたら、どうなるのでしょうか。</p>
<div class="answer"><p><strong>外れていても、1日の目安はあなたの記録で毎週直るので、使い続けるほど合っていきます。</strong>理由は3つです。</p>
${keyLineNav([
  ["e-1", "ずれの分だけ推定を直すので、本当の消費に近づきます"],
  ["e-2", "体重が減って消費が減っても、毎週直すので、目安がずれていきません"],
  ["e-3", "一度に大きく変えないので、日々の揺れに振り回されません"],
])}</div>

<h2 id="e-1">1. ずれの分だけ推定を直すので、本当の消費に近づきます</h2>
<p>毎週月曜に、前の週の食べた量と推定消費カロリーから、体重の傾向がどれだけ変わるはずだったかを出し、実際の傾向と比べます。予想より減らなければ、推定が高すぎたので下げます。予想より減っていれば、上げます。</p>
${reviewFigure({ id: "e-review" })}
${reviewEquation()}
<p>これを毎週くり返すと、最初の値が外れていても、推定は本当の消費に近づきます。</p>
${exampleIntro}
${weeksFigure({ id: "e-weeks" })}

<h2 id="e-2">2. 体重が減って消費が減っても、毎週直すので、目安がずれていきません</h2>
<p>体重が減ると、体を動かすのに要るカロリーも減ります。一度合った目安でも、同じ量を食べ続けると、減り方はだんだん緩くなり、やがて止まります。</p>
${plateauFigure({ id: "e-plateau" })}
<p>毎週の見直しは、減った消費に合わせて推定を直し、1日の目安を出し直します。上の例では、4週間で1日の目安が ${kcal(initial.guideKcal)} kcal から ${kcal(reviews.at(-1).guideKcal)} kcal になりました。</p>

<h2 id="e-3">3. 一度に大きく変えないので、日々の揺れに振り回されません</h2>
<p>体重は水分などで1日に 0.5 kg ほど上下します。nu-tori は、揺れで推定や目安が跳ねないよう、次の4つで抑えます。</p>
<h3>体重は、日々の揺れをならした傾向で見ます</h3>
${trendFigure({ id: "e-trend" })}
${rules.trend}
<h3>ずれの一部ずつ動かし、確かな週ほど大きく動かします</h3>
<p>一度に全部は動かしません。食事を記録した日が多い週ほど、同じ向きのずれが続いた週ほど、大きく動かします。</p>
<h3>1日の目安は、1週に ±150 kcal までしか変えません</h3>
<p>上の例の1週目と2週目は、推定が大きく下がりましたが、1日の目安は 150 kcal ずつ下げるところで止めました。</p>
<h3>記録が少ない週は、見直しを見送ります</h3>
${rules.skip}

<h2>推定を確かにするために、毎朝の体重と1日分の食事を記録してください</h2>
${howToRecord}

<h2>計算の決まり</h2>
<p>上で説明した計算の、細かい決まりです。</p>
<details><summary>最初の推定消費カロリー</summary><h3>記録が足りるとき: 食べた量と体重の傾向から逆算します</h3>${rules.backCalculated}<h3>記録が足りないとき: 身体データから式で出します</h3>${rules.formula}</details>
<details><summary>1日の目安</summary>${rules.pace}${rules.limits}</details>
<details><summary>毎週の見直し</summary>${rules.review}</details>
${medical}
`;

const variants = [
  { key: "d", name: "手順のピラミッド", body: variantD },
  { key: "e", name: "理由のピラミッド", body: variantE },
];

const html = `<title>消費カロリーの説明の試作</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>
/* PROTOTYPE（#745）。site/public/site.css の写しに、図のための規則を足した。本番に移すときは site.css に置く */
:root {
  --background: #f2f2f7;
  --surface: #ffffff;
  --on-surface: #000000;
  --on-surface-secondary: rgba(60, 60, 67, 0.6);
  --on-surface-tertiary: rgba(60, 60, 67, 0.3);
  --separator: rgba(60, 60, 67, 0.29);
  --fill: #efeff0;
  --primary: #6155f5;
  --primary-soft: color-mix(in srgb, #6155f5 22%, #ffffff);
  --switcher-bg: #1c1c1e;
  --switcher-fg: #ffffff;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --background: #000000; --surface: #1c1c1e; --on-surface: #ffffff;
    --on-surface-secondary: rgba(235, 235, 245, 0.6); --on-surface-tertiary: rgba(235, 235, 245, 0.3);
    --separator: rgba(84, 84, 88, 0.6); --fill: #323236; --primary: #6d7cff;
    --primary-soft: color-mix(in srgb, #6d7cff 30%, #1c1c1e);
    --switcher-bg: #ffffff; --switcher-fg: #000000; color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --background: #000000; --surface: #1c1c1e; --on-surface: #ffffff;
  --on-surface-secondary: rgba(235, 235, 245, 0.6); --on-surface-tertiary: rgba(235, 235, 245, 0.3);
  --separator: rgba(84, 84, 88, 0.6); --fill: #323236; --primary: #6d7cff;
  --primary-soft: color-mix(in srgb, #6d7cff 30%, #1c1c1e);
  --switcher-bg: #ffffff; --switcher-fg: #000000; color-scheme: dark;
}
body { margin: 0; background: var(--background); color: var(--on-surface); font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", sans-serif; font-size: 17px; line-height: 1.6; }
.site-header, main, .site-footer { max-width: 680px; margin: 0 auto; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
.site-header { padding-top: 16px; }
.site-name { color: var(--on-surface); font-size: 17px; font-weight: 600; text-decoration: none; }
main { padding-top: 24px; padding-bottom: 48px; }
.site-footer { border-top: 1px solid var(--separator); padding-top: 24px; padding-bottom: 120px; color: var(--on-surface-secondary); font-size: 13px; line-height: 18px; }
.site-footer p { margin: 0 0 4px; }
h1 { font-size: 28px; line-height: 1.3; margin: 0 0 8px; text-wrap: balance; }
h2 { font-size: 22px; line-height: 1.4; margin: 40px 0 12px; text-wrap: balance; }
h3 { font-size: 17px; margin: 24px 0 8px; }
p, ul, ol { margin: 0 0 12px; }
ul, ol { padding-left: 1.4em; }
a { color: var(--primary); }

/* ---- 図 ---- */
.figure { margin: 16px 0 20px; background: var(--surface); border-radius: 12px; padding: 12px 12px 14px; }
.figure-scroll { overflow-x: auto; }
.figure svg { display: block; width: 100%; max-width: 560px; height: auto; margin: 0 auto; font-family: inherit; }
.figure figcaption { margin-top: 8px; color: var(--on-surface-secondary); font-size: 13px; line-height: 18px; }
.grid { stroke: var(--separator); stroke-width: 0.5; fill: none; }
.marker { stroke: var(--on-surface-tertiary); stroke-width: 1; stroke-dasharray: 2 3; fill: none; }
.tick { fill: var(--on-surface-secondary); font-size: 10px; font-variant-numeric: tabular-nums; }
.dot { fill: var(--on-surface-tertiary); stroke: none; }
.trend { stroke: var(--primary); stroke-width: 2.5; fill: none; stroke-linejoin: round; stroke-linecap: round; }
.predicted { stroke: var(--on-surface-secondary); stroke-width: 2; stroke-dasharray: 5 4; fill: none; }
.guide { stroke: var(--on-surface-secondary); stroke-width: 2; fill: none; }
.truth { stroke: var(--on-surface-tertiary); stroke-width: 2; stroke-dasharray: 2 4; fill: none; stroke-linecap: round; }
.end { fill: var(--on-surface-secondary); stroke: var(--surface); stroke-width: 1.5; }
.trend-end { fill: var(--primary); }
.gap { stroke: var(--on-surface); stroke-width: 1.2; fill: none; }
.gap-label { fill: var(--on-surface); font-size: 12px; font-weight: 600; font-variant-numeric: tabular-nums; }
.series-label { fill: var(--primary); font-size: 11px; font-weight: 600; font-variant-numeric: tabular-nums; }
.series-label.muted, .value.muted { fill: var(--on-surface-secondary); }
.series-label.faint { fill: var(--on-surface-secondary); font-weight: 400; }
.value { fill: var(--primary); font-size: 10px; font-weight: 600; font-variant-numeric: tabular-nums; }
.node { fill: var(--fill); stroke: none; }
.node.accent { fill: var(--primary-soft); }
.node-text { fill: var(--on-surface); font-size: 13px; }
.node-text.accent { font-weight: 600; }
.col-label { fill: var(--on-surface-secondary); font-size: 11px; }
.loop-label { fill: var(--primary); }
.arrow { stroke: var(--on-surface-secondary); stroke-width: 1.4; fill: none; }
.arrow.loop { stroke: var(--primary); stroke-dasharray: 4 3; }
.arrow-head { fill: var(--on-surface-secondary); }

.equation { background: var(--surface); border-radius: 12px; padding: 12px 16px; margin: 0 0 20px; font-size: 15px; line-height: 20px; display: grid; gap: 8px; font-variant-numeric: tabular-nums; }
.eq-row { display: grid; grid-template-columns: 7.5em 1fr; gap: 8px; }
.eq-row > * { min-width: 0; }
.eq-label { color: var(--on-surface-secondary); font-size: 13px; }
.eq-result { border-top: 1px solid var(--separator); padding-top: 8px; }
@media (max-width: 420px) { .eq-row { grid-template-columns: 1fr; gap: 0; } }

.persona { color: var(--on-surface-secondary); font-size: 15px; line-height: 20px; }
.figure-title { margin-top: 32px; }
.week { background: var(--surface); border-radius: 12px; padding: 14px 16px; margin: 12px 0; font-size: 15px; line-height: 21px; }
.week h3 { margin: 0 0 8px; font-size: 17px; }
.week p { margin: 0 0 8px; }
.week p:last-child { margin-bottom: 0; }
.week-dates { color: var(--on-surface-secondary); font-weight: 400; font-size: 13px; margin-left: 6px; }
.week-facts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; margin: 0 0 10px; }
.week-facts div { min-width: 0; }
.week-facts dt { color: var(--on-surface-secondary); font-size: 12px; line-height: 16px; }
.week-facts dd { margin: 0; font-weight: 600; font-variant-numeric: tabular-nums; }
.bars { display: grid; gap: 4px; margin: 0 0 10px; }
.bar-row { display: grid; grid-template-columns: 2.5em 1fr; align-items: center; gap: 8px; font-size: 12px; color: var(--on-surface-secondary); }
.bar-track { display: block; position: relative; height: 10px; background: var(--fill); border-radius: 4px; overflow: hidden; }
.bar-track::after { content: ""; position: absolute; left: 50%; top: 0; bottom: 0; width: 1px; background: var(--on-surface-secondary); }
.bar { position: absolute; top: 0; height: 100%; }
.bar.neg { right: 50%; border-radius: 4px 0 0 4px; }
.bar.pos { left: 50%; border-radius: 0 4px 4px 0; }
.bar-axis-labels { display: flex; justify-content: space-between; font-size: 11px; line-height: 14px; }
.predicted-bar { background: var(--on-surface-tertiary); }
.actual-bar { background: var(--primary); }
.week-result { border-top: 1px solid var(--separator); padding-top: 8px; font-variant-numeric: tabular-nums; }
.note { display: block; color: var(--on-surface-secondary); font-size: 13px; line-height: 18px; margin-top: 2px; }
details { background: var(--surface); border-radius: 10px; padding: 0 16px; margin: 0 0 8px; }
summary { min-height: 44px; display: flex; align-items: center; cursor: pointer; font-weight: 600; }
details[open] { padding-bottom: 8px; }
.rule-head { margin-top: 28px; }
.answer { background: var(--surface); border-radius: 12px; padding: 14px 16px; margin: 16px 0 20px; }
.answer p { margin: 0 0 8px; }
.answer p:last-child, .answer ol:last-child { margin-bottom: 0; }
.key-line { padding-left: 1.4em; display: grid; gap: 6px; }
.key-line a { text-decoration: none; }
.proto-structure { border: 1px dashed var(--on-surface-tertiary); background: transparent; border-radius: 10px; padding: 0 12px 8px; margin: 0 0 24px; font-size: 13px; line-height: 18px; color: var(--on-surface-secondary); }
.proto-structure summary { font-weight: 600; min-height: 36px; }
.proto-structure dl { display: grid; gap: 6px; margin: 0 0 8px; }
.proto-structure dl div { display: grid; grid-template-columns: 4.5em 1fr; gap: 8px; }
.proto-structure dt { font-weight: 600; }
.proto-structure dd { margin: 0; min-width: 0; color: var(--on-surface); }
.proto-structure ol { margin: 0; color: var(--on-surface); }
.proto-axis { margin: 0 0 4px; }

/* ---- 試作の切り替え（本番には持ち込まない） ---- */
.proto-note { max-width: 680px; margin: 0 auto; padding: 12px max(16px, env(safe-area-inset-right, 0px)) 0 max(16px, env(safe-area-inset-left, 0px)); color: var(--on-surface-secondary); font-size: 12px; line-height: 16px; }
.switcher { position: fixed; left: 50%; transform: translateX(-50%); bottom: calc(16px + env(safe-area-inset-bottom, 0px)); z-index: 20; display: flex; align-items: center; gap: 4px; background: var(--switcher-bg); color: var(--switcher-fg); border-radius: 9999px; padding: 4px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.25); font-size: 14px; max-width: calc(100vw - 32px); }
.switcher button { width: 44px; height: 44px; border: 0; border-radius: 9999px; background: transparent; color: inherit; font-size: 18px; cursor: pointer; }
.switcher button:focus-visible { outline: 2px solid var(--primary); }
.switcher-label { padding: 0 8px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; min-width: 0; }
</style>

<p class="proto-note">PROTOTYPE（#745）: 「推定消費カロリーと1日の目安の出し方」の見せ方をミントのピラミッドで組み直した2案で見比べる試作です。下の帯の ← → で案を切り替えます。数字は架空の1人を、本番のサーバーの決まりで計算した値です。</p>
<header class="site-header"><a class="site-name" href="#">nu-tori</a></header>
${variants.map((v) => `<main id="variant-${v.key}" data-name="${v.name}"${v.key === variants[0].key ? "" : " hidden"}>${v.body}</main>`).join("\n")}
<footer class="site-footer">
  <p>医療の助言ではありません。持病のある方は、医師に相談してください。</p>
  <p>nu-tori for iPhone</p>
</footer>
<nav class="switcher" aria-label="試作の案の切り替え">
  <button type="button" id="prev" aria-label="前の案">←</button>
  <span class="switcher-label" id="label"></span>
  <button type="button" id="next" aria-label="次の案">→</button>
</nav>
<script>
// 試作の切り替えだけ。Artifact では URL のクエリが届かないので、#a・#b・#c で案を選ぶ
const keys = ${JSON.stringify(variants.map((v) => v.key))};
let current = keys.includes(location.hash.slice(1)) ? location.hash.slice(1) : keys[0];
const show = (key) => {
  current = key;
  for (const k of keys) document.getElementById("variant-" + k).hidden = k !== key;
  const main = document.getElementById("variant-" + key);
  document.getElementById("label").textContent = key.toUpperCase() + "（" + main.dataset.name + "）";
  try { history.replaceState(null, "", "#" + key); } catch {}
};
const step = (n) => { show(keys[(keys.indexOf(current) + n + keys.length) % keys.length]); window.scrollTo(0, 0); };
document.getElementById("prev").addEventListener("click", () => step(-1));
document.getElementById("next").addEventListener("click", () => step(1));
document.addEventListener("keydown", (e) => {
  if (e.target.closest && e.target.closest("input, textarea, [contenteditable]")) return;
  if (e.key === "ArrowLeft") step(-1);
  if (e.key === "ArrowRight") step(1);
});
show(current);
</script>
`;

writeFileSync(new URL("./index.html", import.meta.url), html);
console.log("wrote index.html", html.length);

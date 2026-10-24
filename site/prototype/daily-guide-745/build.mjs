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

// ---------- 今のページの本文（節ごと） ----------
const sec = {
  intro: `<p>nu-tori は、1日に食べる量の目安（1日の目安）を、推定消費カロリーと目標から出し、毎週の記録で見直します。このページでは、その出し方を説明します。</p>`,
  s1: `<h2>1. 推定消費カロリーは推定です</h2>
<p>推定消費カロリーは、1日に消費するカロリーを、体重の傾向と食べた量から推定した値です。体の中を測った値ではありません。</p>
<p>体重の傾向は、体重の記録から日々の増減をならした体重の推移です。食べた量に比べて体重の傾向が減っていれば、食べた量より多く消費していると推定します。</p>`,
  s1b: `<p>運動の記録やワークアウト、消費したエネルギーの記録は使いません。運動した分も、体重の傾向の動きに表れるからです。</p>`,
  s2: `<h2>2. 最初の推定消費カロリー</h2>
<p>初めて目標を立てるときに、次のどちらかで出します。</p>
<h3>記録が足りるとき: 食べた量と体重の傾向から逆算します</h3>
<p>今日を除く直前の 28 日の、食べた量と体重から出します。食べた量は、nu-tori を使い始めた日からは nu-tori の食事の記録を、使い始める前の日はヘルスケアの摂取エネルギーを使います。</p>
<ul><li>食べた量のある日が 14 日以上あること。食べた量がほかの日の中ほどの値の半分に満たない日（1食だけ記録した日など）は、記録の途中とみなして数えません</li><li>体重を記録した日が 4 日以上あり、最初の日から最後の日まで 14 日以上あること</li></ul>
<p>食べた量の1日の平均から、体重の傾きの分を引いて出します。体重 1 kg の増減を 7,700 kcal とみなし、たとえば体重が1日に 0.1 kg ずつ減っていれば、食べた量の平均に 770 kcal を足した値になります。</p>
<h3>記録が足りないとき: 身体データから式で出します</h3>
<p>身長・生年月日（年齢）・性別と、開始の日の体重の傾向から、安静にしているときの消費を Mifflin-St Jeor の式で出し、活動量の係数を掛けます。ヘルスケアから読めない値は、アプリで入れていただきます。</p>
<ul><li>歩数が読めるとき: 直前 28 日の、歩いた日の平均の歩数で決めます。5,000 歩未満は 1.4、10,000 歩未満は 1.55、それ以上は 1.7</li><li>歩数が読めないとき: 3つから選んでいただきます。ほぼ座り仕事は 1.4、立ち仕事が多いは 1.55、よく動くは 1.7</li></ul>
<p>身体データと、使い始める前の摂取エネルギーは、この計算にだけ使い、保存しません。</p>`,
  s3: `<h2>3. 1日の目安</h2>
<p>1日の目安は、推定消費カロリーから、目標の速さで1日に減らす分を引いたものです。増量では、1日に足す分を足します。</p>
<p>1日に減らす（足す）分は、期限の日までに目標体重へ届くのに要る体重の変化の速さに、7,700 kcal/kg を掛けて出します。たとえば、体重の傾向が1日に 0.05 kg ずつ減る速さなら、1日に 385 kcal を減らします。維持では、体重の傾向が目標体重の ±0.7 kg の中にあれば、減らしも足しもしません。外れたら、体重の傾向の 1週間に 0.15% の速さで目標体重へ戻す分だけ減らし（足し）ます。</p>
<p>値は 50 kcal 単位に丸め、次の上限と下限を当てます。</p>
<ul><li>必要な速さの上限: 1週間に、開始の日の体重の傾向の 0.75%（減量）・0.5%（増量）より速くしません。期限までの日が少なくても、無理な速さにしません</li><li>1日の目安の下限: 1,200 kcal より低くしません</li><li>1週の変化の幅: 毎週の見直しで、前の週の1日の目安から ±150 kcal より大きく変えません</li></ul>`,
  s4head: `<h2>4. 毎週の見直し</h2>
<p>毎週、月曜から当てる推定消費カロリーと1日の目安を、その前の週（月曜から日曜）の記録で見直します。</p>`,
  s4list: `<ol><li>前の週の食べた量の平均と、そのときの推定消費カロリーから、体重の傾向がどれだけ変わるはずだったかを出します</li><li>実際の体重の傾向の変化と比べ、ずれの分だけ推定消費カロリーを動かします。一度に全部は動かさず、食事を記録した日が多い週ほど、同じ向きのずれが続いた週ほど大きく動かします</li><li>新しい推定消費カロリーで、上の 3 と同じように1日の目安を出し直します</li></ol>`,
  s4skip: `<p>次のどれかに当たる週は、見直しを見送り、推定消費カロリーも1日の目安も前の週のままにします。</p>
<ul><li>使い始めて 7 日に満たない（最初の値を食べた量と体重から逆算したときは当てません）</li><li>その週に体重の記録が無い</li><li>その週に食事を記録した日が 4 日に満たない（1食だけ記録した日などは数えません）</li></ul>`,
  s5: `<h2>5. 記録を続けると、推定が確かになります</h2>
<p>推定消費カロリーは、体重の傾向と食べた量のずれから直していきます。毎朝の体重と、食事の記録が揃うほど、推定は実際の消費に近づき、1日の目安も合っていきます。</p>
<p>体重は、毎朝、同じころに量ると、日々の揺れが小さくなります。食事は、食べたものを撮るか書くかして、1日の分をなるべく全部記録してください。</p>`,
  s6: `<h2>6. 医療の助言ではありません</h2>
<p>医療の助言ではありません。持病のある方は、医師に相談してください。</p>`,
};

const persona = `30歳・身長 172 cm・ほぼ座り仕事の男性。使い始める前の4週間は体重計だけ使い、体重の傾向は ${kg1(initial.startingWeightTrendKg)} kg で横ばい。食事は記録していなかったので、最初の推定消費カロリーは式で出します。目標は12週で ${kg1(74.4)} kg`;

// ---------- 案A: 今の本文に図を差し込む ----------
const variantA = `
<h1>推定消費カロリーと1日の目安の出し方</h1>
${sec.intro}
${sec.s1}
${trendFigure({ id: "a-trend" })}
${sec.s1b}
${sec.s2}
${sec.s3}
${sec.s4head}
${sec.s4list}
${reviewFigure({ id: "a-review" })}
${reviewEquation()}
${sec.s4skip}
<h2>5. 例: ある人の4週間</h2>
<p class="persona">${persona}。</p>
<p>式で出した推定消費カロリーは ${kcal(initial.kcal)} kcal、1日の目安は ${kcal(initial.guideKcal)} kcal でした。毎週の見直しで、次のように動きます。</p>
${weeksFigure({ id: "a-weeks" })}
<p>体重が減ると、消費も減ります。見直しをせずに同じ量を食べ続けると、減り方はだんだん緩くなり、やがて止まります。</p>
${plateauFigure({ id: "a-plateau" })}
${sec.s5.replace("<h2>5.", "<h2>6.")}
${sec.s6.replace("<h2>6.", "<h2>7.")}
`;

// ---------- 案B: 架空の1人の4週間を追う ----------
const weekCard = (r, i) => {
  const limited = r.limitHits.includes("weekly_change");
  const k = gainOf(r);
  const dir =
    Math.abs(r.deviationKg) < 0.02
      ? "ほぼ予想どおり"
      : r.deviationKg < 0
        ? "予想より減らなかった"
        : "予想より減った";
  const weekStart = addDaysIso(r.reviewedMonday, -7);
  return `
<section class="week">
  <h3>${i + 1}週目 <span class="week-dates">${md(weekStart)}〜${md(addDaysIso(r.reviewedMonday, -1))}</span></h3>
  <dl class="week-facts">
    <div><dt>食べた量</dt><dd>${kcal(r.averageEnergyIntakeKcal)} kcal</dd></div>
    <div><dt>予想した動き</dt><dd>${signedKg(r.predictedWeightChangeKg)} kg</dd></div>
    <div><dt>実際の動き</dt><dd>${signedKg(r.actualWeightChangeKg)} kg</dd></div>
  </dl>
  <div class="bars" aria-hidden="true">
    ${barPair(r)}
  </div>
  <p>${dir}（ずれ ${kg2(r.deviationKg)} kg）。${i === 0 ? "体重の傾向は水分の揺れで少し上がりました。" : ""}動かす割合は ${k}${k > 0.25 ? `（同じ向きのずれが${Math.round(k / 0.25)}週続いたので大きく）` : i > 0 ? "（ずれの向きが変わったので小さく戻す）" : ""}。</p>
  <p class="week-result">推定消費カロリー ${kcal(r.previousExpenditureKcal)} → <strong>${kcal(r.expenditureKcal)} kcal</strong><br>1日の目安 ${kcal(r.previousGuideKcal)} → <strong>${kcal(r.guideKcal)} kcal</strong>${limited ? '<span class="note">前の週から 150 kcal までしか変えない決まりで止めました</span>' : ""}</p>
</section>`;
};
// 0 を真ん中に、減りは左、増えは右へ伸ばす。±0.5 kg で端
const bar = (v, cls) =>
  `<span class="bar ${cls} ${v < 0 ? "neg" : "pos"} w${Math.round(Math.min(Math.abs(v) / 0.5, 1) * 50)}"></span>`;
const barPair = (r) => {
  return `
<div class="bar-row"><span class="bar-name">予想</span><span class="bar-track">${bar(r.predictedWeightChangeKg, "predicted-bar")}</span></div>
<div class="bar-row"><span class="bar-name">実際</span><span class="bar-track">${bar(r.actualWeightChangeKg, "actual-bar")}</span></div>
<div class="bar-row bar-axis"><span></span><span class="bar-axis-labels"><span>減る</span><span>0</span><span>増える</span></span></div>`;
};

const variantB = `
<h1>推定消費カロリーと1日の目安の出し方</h1>
${sec.intro}
<p>決まりを読む前に、架空の1人が使い始めてからの4週間を追います。数字は、nu-tori が実際に使っている決まりで計算しました。</p>
<h2>ある人の4週間</h2>
<p class="persona">${persona}。</p>
<section class="week week-zero">
  <h3>使い始めた日 <span class="week-dates">${md(days[0].calendarDay)}（月）</span></h3>
  <p>身長・年齢・性別と体重の傾向から、式で推定消費カロリーを <strong>${kcal(initial.kcal)} kcal</strong> と出しました。12週で ${kg1(initial.startingWeightTrendKg - 74.4)} kg 減らすのに1日 ${kcal(initial.kcal - initial.guideKcal)} kcal ほど減らし、1日の目安は <strong>${kcal(initial.guideKcal)} kcal</strong>。式の値は、同じ体格の人の平均です。この人の本当の消費は分かりません。</p>
</section>
<h3 class="figure-title">毎朝の体重は揺れます</h3>
${trendFigure({ id: "b-trend" })}
${reviews.map(weekCard).join("")}
<h3 class="figure-title">4週間で、推定は本当の消費に近づきました</h3>
${weeksFigure({ id: "b-weeks" })}
<h3 class="figure-title">体重が減ると、消費も減ります</h3>
<p>この人が4週目の ${kcal(reviews.at(-1).guideKcal)} kcal を、見直さずに食べ続けたとします。</p>
${plateauFigure({ id: "b-plateau" })}
<p>毎週の体重と食べた量のずれを読み、推定消費カロリーを直し続けるのが、nu-tori の見直しです。</p>
<h2>決まりの詳細</h2>
<details><summary>推定消費カロリーは推定です</summary>${sec.s1.replace(/<h2>.*?<\/h2>/, "")}${sec.s1b}</details>
<details><summary>最初の推定消費カロリー</summary>${sec.s2.replace(/<h2>.*?<\/h2>/, "")}</details>
<details><summary>1日の目安</summary>${sec.s3.replace(/<h2>.*?<\/h2>/, "")}</details>
<details><summary>毎週の見直し</summary>${sec.s4head.replace(/<h2>.*?<\/h2>/, "")}${sec.s4list}${sec.s4skip}</details>
<details><summary>記録を続けると、推定が確かになります</summary>${sec.s5.replace(/<h2>.*?<\/h2>/, "")}</details>
${sec.s6}
`;

// ---------- 案C: 流れの図を先に、各段を図で読む ----------
const variantC = `
<h1>推定消費カロリーと1日の目安の出し方</h1>
${sec.intro}
${loopFigure({ id: "c-loop" })}
<p>推定消費カロリーは、体重の傾向と食べた量から推定した値です。体の中を測った値ではありません。予想した体重の動きと実際の動きがずれたら、推定のほうを直します。図の段を、ひとつずつ見ていきます。</p>
<h2>体重の傾向: 日々の揺れをならします</h2>
${trendFigure({ id: "c-trend" })}
<p>運動の記録やワークアウト、消費したエネルギーの記録は使いません。運動した分も、体重の傾向の動きに表れるからです。</p>
<h2>ずれ: 予想と実際を比べます</h2>
${reviewFigure({ id: "c-review" })}
<h2>動かす: ずれの一部ずつ直します</h2>
${reviewEquation()}
<p>一度に全部は動かしません。食事を記録した日が多い週ほど、同じ向きのずれが続いた週ほど大きく動かします。これを毎週くり返すと、推定は本当の消費に近づきます。</p>
${weeksFigure({ id: "c-weeks" })}
<h2>出し直す: 体重が減ると、消費も減ります</h2>
<p>体重が減ると消費も減るので、同じ量を食べ続けると、減り方はだんだん緩くなります。毎週の見直しは、この変化にも合わせます。</p>
${plateauFigure({ id: "c-plateau" })}
<h2>決まりの詳細</h2>
${sec.s2.replace("<h2>2. ", '<h3 class="rule-head">').replace("</h2>", "</h3>")}
${sec.s3.replace("<h2>3. ", '<h3 class="rule-head">').replace("</h2>", "</h3>")}
<h3 class="rule-head">毎週の見直し</h3>
${sec.s4head.replace(/<h2>.*?<\/h2>/, "")}${sec.s4list}${sec.s4skip}
${sec.s5}
${sec.s6}
`;

const variants = [
  { key: "a", name: "今の本文に図を差し込む", body: variantA },
  { key: "b", name: "1人の4週間を追う", body: variantB },
  { key: "c", name: "流れの図から読む", body: variantC },
];

// 案 B の棒の幅。インラインの style を使わず、5% 刻みのクラスにする（本番の CSP に合わせる）
const widthClasses = Array.from({ length: 101 }, (_, i) => `.w${i}{width:${i}%}`).join("");

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
${widthClasses}
details { background: var(--surface); border-radius: 10px; padding: 0 16px; margin: 0 0 8px; }
summary { min-height: 44px; display: flex; align-items: center; cursor: pointer; font-weight: 600; }
details[open] { padding-bottom: 8px; }
.rule-head { margin-top: 28px; }

/* ---- 試作の切り替え（本番には持ち込まない） ---- */
.proto-note { max-width: 680px; margin: 0 auto; padding: 12px max(16px, env(safe-area-inset-right, 0px)) 0 max(16px, env(safe-area-inset-left, 0px)); color: var(--on-surface-secondary); font-size: 12px; line-height: 16px; }
.switcher { position: fixed; left: 50%; transform: translateX(-50%); bottom: calc(16px + env(safe-area-inset-bottom, 0px)); z-index: 20; display: flex; align-items: center; gap: 4px; background: var(--switcher-bg); color: var(--switcher-fg); border-radius: 9999px; padding: 4px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.25); font-size: 14px; max-width: calc(100vw - 32px); }
.switcher button { width: 44px; height: 44px; border: 0; border-radius: 9999px; background: transparent; color: inherit; font-size: 18px; cursor: pointer; }
.switcher button:focus-visible { outline: 2px solid var(--primary); }
.switcher-label { padding: 0 8px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; min-width: 0; }
</style>

<p class="proto-note">PROTOTYPE（#745）: 「推定消費カロリーと1日の目安の出し方」の見せ方を3案で見比べる試作です。下の帯の ← → で案を切り替えます。数字は架空の1人を、本番のサーバーの決まりで計算した値です。</p>
<header class="site-header"><a class="site-name" href="#">nu-tori</a></header>
${variants.map((v) => `<main id="variant-${v.key}" data-name="${v.name}"${v.key === "a" ? "" : " hidden"}>${v.body}</main>`).join("\n")}
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
let current = keys.includes(location.hash.slice(1)) ? location.hash.slice(1) : "a";
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

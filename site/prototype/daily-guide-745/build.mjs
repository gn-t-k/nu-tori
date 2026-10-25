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
  ${caption ? `<figcaption>例の人の、毎朝の体重（点）と体重の傾向（線）です。毎朝の体重が1日で 0.5 kg ほど上下しても、体重の傾向はなめらかに動きます。</figcaption>` : ""}
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
  ${caption ? `<figcaption>例の人の、${md(segment[1].calendarDay)}〜${Number(segment.at(-1).calendarDay.slice(8))}日の週です。この週にこの人が食べた量の平均は ${kcal(review.averageEnergyIntakeKcal)} kcal、その週の推定消費カロリーは ${kcal(review.previousExpenditureKcal)} kcal でした。nu-tori はこの差から、体重の傾向が ${kg2(review.predictedWeightChangeKg)} kg 減ると予想しました（点線）。実際の体重の傾向は ${kg2(review.actualWeightChangeKg)} kg しか減らず（実線）、予想とのずれは ${kg2(review.deviationKg)} kg でした。</figcaption>` : ""}
</figure>`;
};

// ずれから推定消費カロリーを動かす式を、1週ぶん数字で見せる
const reviewEquation = (review = reviews[1]) => {
  const perDay = (7700 * Math.abs(review.deviationKg)) / 7;
  const k = gainOf(review);
  return `
<div class="equation">
  <div class="eq-row"><span class="eq-label">ずれを1日あたりのカロリーにする</span><span class="eq-value">約 ${kg2(review.deviationKg)} kg × 7,700 kcal/kg ÷ 7 日 ＝ 1日 約 ${kcal(perDay)} kcal</span></div>
  <div class="eq-row"><span class="eq-label">そのうち動かす割合</span><span class="eq-value">× ${k} ＝ 約 ${kcal(perDay * k)} kcal（この週は、食事を${review.recordedMealDayCount === 7 ? "7日とも" : `${review.recordedMealDayCount}日`}記録し、推定が${review.deviationKg < 0 ? "高すぎる" : "低すぎる"}向きのずれが${Math.round(k / 0.25) === 1 ? "初めて出た" : `${Math.round(k / 0.25)}週続いた`}ので）</span></div>
  <div class="eq-row eq-result"><span class="eq-label">新しい推定消費カロリー</span><span class="eq-value">${kcal(review.previousExpenditureKcal)} kcal ${review.deviationKg < 0 ? "−" : "＋"} 約 ${kcal(perDay * k)} kcal ＝ <strong>${kcal(review.expenditureKcal)} kcal</strong></span></div>
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
  ${caption ? `<figcaption>例の人の4週間です。点線の「本当の消費」は、説明のために置いた仮定で、nu-tori には分かりません。nu-tori が毎週ずれから推定を直すにつれて、推定消費カロリーは本当の消費に近づき、1日の目安も下がっていきます。</figcaption>` : ""}
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
  ${caption ? `<figcaption>例の人が、4週目の1日の目安 ${kcal(reviews.at(-1).guideKcal)} kcal を、見直さずに2年食べ続けたときの体重です。体重が 1 kg 減るとこの人の消費が1日 27 kcal 減る、と仮定して計算しました。体重が減るほど、消費と食べた量の差が縮み、体重の減り方が緩くなります。</figcaption>` : ""}
</figure>`;
};

// ---------- ミントのピラミッドで組んだ案（開発者が E を選んだ） ----------
// 導入を状況（S）→ 複雑化（C）→ 問い（Q）で書き、その直後に答え（A）を置く。
// 答えに読み手が返す「なぜそう言える？」に、漏れなく重ならない3つの理由（キーライン）で答え、見出しは言いたいことの文にする。
// 文は、主語（nu-tori か、あなたか、どの値か）と目的語を省かずに書く

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
  backCalculated: `<p>nu-tori は、今日を除く直前の 28 日に、あなたが食べた量と、あなたの体重から、推定消費カロリーを逆算します。食べた量には、nu-tori を使い始めた日からは nu-tori の食事の記録を、使い始める前の日はヘルスケアの摂取エネルギーを使います。</p>
<p>逆算するには、次の2つが要ります。</p>
<ul><li>食べた量のある日が 14 日以上あること。ただし、食べた量がほかの日の中ほどの値の半分に満たない日（1食だけ記録した日など）は、記録の途中とみなして数えません</li><li>体重を記録した日が 4 日以上あり、最初の日から最後の日まで 14 日以上あること</li></ul>
<p>推定消費カロリーは、食べた量の1日の平均から、体重の傾向の傾きの分を引いて出します。nu-tori は、体重 1 kg の増減を 7,700 kcal とみなします。たとえば、体重の傾向が1日に 0.1 kg ずつ減っていれば、推定消費カロリーは、食べた量の平均に 770 kcal を足した値になります。</p>`,
  formula: `<p>nu-tori は、あなたの身長・生年月日（年齢）・性別と、目標を始める日の体重の傾向から、安静にしているときの消費を Mifflin-St Jeor の式で出し、それに活動量の係数を掛けます。ヘルスケアから読めない値は、アプリで入れていただきます。</p>
<ul><li>ヘルスケアから歩数を読めるとき: nu-tori は係数を、直前 28 日のうち歩いた日の、平均の歩数で決めます。5,000 歩未満なら 1.4、10,000 歩未満なら 1.55、それ以上なら 1.7 です</li><li>歩数を読めないとき: あなたに、次の3つから選んでいただきます。ほぼ座り仕事なら 1.4、立ち仕事が多いなら 1.55、よく動くなら 1.7 です</li></ul>
<p>nu-tori は、身体データと、使い始める前の摂取エネルギーを、この計算にだけ使い、保存しません。</p>`,
  guide: `<p>1日の目安は、推定消費カロリーから、目標の速さで体重を減らすために1日に減らすカロリー（1日に減らす分）を引いた値です。増量では、引く代わりに、1日に足す分を足します。</p>
<p>nu-tori は、1日に減らす（足す）分を、期限の日までに目標体重へ届くのに要る体重の変化の速さに、7,700 kcal/kg を掛けて出します。たとえば、体重の傾向を1日に 0.05 kg ずつ減らす速さなら、1日に減らす分は 385 kcal です。維持では、体重の傾向が目標体重の ±0.7 kg の中にあれば、nu-tori は減らしも足しもしません。体重の傾向がその幅から外れたら、体重の傾向を1週間に 0.15% の速さで目標体重へ戻す分だけ、減らし（足し）ます。</p>`,
  limits: `<p>nu-tori は、1日の目安を 50 kcal 単位に丸め、次の上限と下限を当てます。</p>
<ul><li>体重を変える速さの上限: 体重を1週間に、目標を始めた日の体重の傾向の 0.75%（減量）・0.5%（増量）より速く変える目安にはしません。期限までの日が少なくても、無理な速さにはしません</li><li>1日の目安の下限: 1日の目安を 1,200 kcal より低くしません</li><li>1週の変化の幅: 毎週の見直しで、1日の目安を前の週から ±150 kcal より大きく変えません</li></ul>`,
  review: `<p>nu-tori は毎週月曜に、次の順で見直します。</p>
<ol><li>前の週（月曜から日曜）にあなたが食べた量の平均と、その週の推定消費カロリーから、体重の傾向がどれだけ変わるはずだったかを予想します</li><li>その予想を、実際の体重の傾向の変化と比べ、ずれの分だけ推定消費カロリーを動かします。ずれの分を、一度に全部は動かしません。動かす割合は、0.25 に「その週に食事を記録した日の数 ÷ 7」と「同じ向きのずれが続いた週の数 ＋ 1」を掛けた値で、0.75 を上限にします</li><li>新しい推定消費カロリーで、1日の目安を出し直します</li></ol>`,
  skip: `<p>nu-tori は、次のどれかに当たる週の見直しを見送り、推定消費カロリーと1日の目安を前の週のままにします。</p>
<ul><li>あなたが nu-tori を使い始めて 7 日に満たない（最初の推定消費カロリーを、食べた量と体重から逆算したときは、この決まりを当てません）</li><li>その週に、体重の記録が無い</li><li>その週に、食事を記録した日が 4 日に満たない（1食だけ記録した日などは数えません）</li></ul>`,
};

const exampleIntro = `<p class="persona">ここからは、架空の1人を例に追います。この人は 30 歳・身長 172 cm の男性で、ほぼ座り仕事です。nu-tori を使い始める前の4週間は、体重計で体重だけを量っていて、体重の傾向は ${kg1(initial.startingWeightTrendKg)} kg で横ばいでした。食事は記録していなかったので、nu-tori は最初の推定消費カロリーを式で出し、${kcal(initial.kcal)} kcal としました。目標は、12週で ${kg1(74.4)} kg まで減らすことで、最初の1日の目安は ${kcal(initial.guideKcal)} kcal でした。この人が本当に消費しているカロリーは、${kcal(days[0].trueExpenditureKcal)} kcal とします。この値は説明のために置いた仮定で、nu-tori には分かりません。</p>`;

const variantE = `
${structurePanel({
  s: "1日の目安は、推定消費カロリーから、目標の速さで体重を減らすために1日に減らす分を引いた値",
  c: "記録が足りないとき、最初の推定消費カロリーは同じ体格の人の平均で、本当に消費しているカロリーと数百 kcal ずれることがある",
  q: "最初の1日の目安が外れていたら、どうなるのか",
  a: "外れていても、nu-tori が記録から毎週直すので、目安は使い続けるほど体に合っていく",
  axis: "なぜそう言える？",
  keyLine: [
    "ずれの分だけ直すので、推定が本当の消費に近づく（正しさ）",
    "体重が減って消費が減っても、毎週直すので、目安が体に合ったまま（変化への追従）",
    "一度に大きく変えないので、体重の揺れで目安が跳ねない（安定）",
  ],
})}
<h1>推定消費カロリーと1日の目安の出し方</h1>
<p>あなたが目標を立てると、nu-tori は、あなたが1日に食べる量の目安（1日の目安）を出します。1日の目安は、推定消費カロリー（あなたが1日に消費するカロリーを、nu-tori が推定した値）から、1日に減らす分を引いた値です。1日に減らす分は、目標の速さで体重を減らすために、消費するカロリーより少なく食べるカロリーです。</p>
<p>食事と体重の記録が足りないとき、nu-tori は最初の推定消費カロリーを、あなたの身長・年齢・性別から式で出します。この値は、同じ体格の人の平均です。そのため、あなたが本当に消費しているカロリーとは、数百 kcal ずれていることがあります。</p>
<p>では、最初の1日の目安が外れていたら、どうなるのでしょうか。</p>
<div class="answer"><p><strong>最初の1日の目安が外れていても、nu-tori があなたの記録から目安を毎週直すので、使い続けるほど、目安はあなたの体に合っていきます。</strong>そう言える理由は3つです。</p>
${keyLineNav([
  ["e-1", "nu-tori は体重の予想と実際のずれから推定を直すので、推定は本当の消費に近づきます"],
  ["e-2", "体重が減って消費が減っても、nu-tori が毎週直すので、目安は体に合ったままです"],
  ["e-3", "nu-tori は推定と目安を一度に大きく変えないので、体重の揺れで目安が跳ねません"],
])}</div>

<h2 id="e-1">1. nu-tori は体重の予想と実際のずれから推定を直すので、推定は本当の消費に近づきます</h2>
<p>nu-tori は毎週月曜に、前の週にあなたが食べた量の平均と、その週の推定消費カロリーから、体重の傾向がどれだけ変わるはずだったかを予想します。体重の傾向は、毎朝の体重から日々の揺れをならした値です（3 で説明します）。nu-tori は、この予想を、実際の体重の傾向の変化と比べます。</p>
<ul><li>体重の傾向が予想より減らなかったなら、推定消費カロリーが高すぎたので、nu-tori は推定を下げます</li><li>体重の傾向が予想より減ったなら、推定消費カロリーが低すぎたので、nu-tori は推定を上げます</li></ul>
<p>nu-tori は、運動やワークアウトの記録と、消費したエネルギーの記録を使いません。あなたが運動して消費した分も、体重の傾向の動きに表れるからです。</p>
${exampleIntro}
${reviewFigure({ id: "e-review" })}
${reviewEquation()}
<p>nu-tori がこれを毎週くり返すと、最初の推定消費カロリーが外れていても、推定は本当の消費に近づきます。</p>
${weeksFigure({ id: "e-weeks" })}

<h2 id="e-2">2. 体重が減って消費が減っても、nu-tori が毎週直すので、目安は体に合ったままです</h2>
<p>あなたの体重が減ると、あなたが1日に消費するカロリーも減ります。体が軽くなるほど、体を保ち、動かすのに要るカロリーが減るからです。そのため、一度は体に合っていた1日の目安でも、同じ量を食べ続けると、体重の減り方はだんだん緩くなり、やがて止まります。</p>
${plateauFigure({ id: "e-plateau" })}
<p>nu-tori は、体重が減って消費が減った分も、1 と同じ見直しで毎週推定消費カロリーに反映し、1日の目安を出し直します。そのため、あなたが自分で計算し直さなくても、1日の目安は今の体に合ったままです。</p>

<h2 id="e-3">3. nu-tori は推定と目安を一度に大きく変えないので、体重の揺れで目安が跳ねません</h2>
<p>あなたの体重は、体の水分などで1日に 0.5 kg ほど上下します。nu-tori は、この揺れで推定消費カロリーや1日の目安が跳ねないように、次の4つの決まりで変化を抑えます。</p>
<h3>nu-tori は、日々の揺れをならした体重の傾向を見ます</h3>
${trendFigure({ id: "e-trend" })}
<p>体重の傾向は、毎朝の体重の記録から、日々の増減をならした体重の推移です。nu-tori は、1日ごとの体重ではなく、体重の傾向の動きを予想と比べます。</p>
<h3>nu-tori は、推定消費カロリーを、ずれの一部ずつ動かします</h3>
<p>nu-tori は、1週のずれの分を、推定消費カロリーに一度に全部は反映しません。食事を記録した日が多い週ほど、また同じ向きのずれが続いた週ほど、推定を大きく動かします。記録が少ない週や、たまたま体重が揺れた週のずれで、推定が大きく動かないようにするためです。</p>
<h3>nu-tori は、1日の目安を1週に ±150 kcal までしか変えません</h3>
<p>nu-tori は、毎週の見直しで、1日の目安を前の週から 150 kcal より大きく上げ下げしません。例の人の1週目と2週目の見直しでは、推定消費カロリーが大きく下がりましたが、nu-tori は1日の目安を 150 kcal ずつ下げるところで止めました。</p>
<h3>nu-tori は、記録が少ない週の見直しを見送ります</h3>
${rules.skip}

<h2>推定を確かにするために、毎朝の体重と1日分の食事を記録してください</h2>
<p>毎朝の体重と食事の記録が揃うほど、推定消費カロリーは本当の消費に近づき、1日の目安もあなたの体に合っていきます。</p>
<ul><li>体重は、毎朝同じころに量ってください。量る時刻がそろうと、日々の揺れが小さくなります</li><li>食事は、食べたものを撮るか書くかして、1日の分をなるべく全部記録してください。1食だけ記録した日を、nu-tori は見直しで数えません</li></ul>

<h2>計算の決まり</h2>
<p>ここまでで説明した計算の、細かい決まりです。</p>
<details><summary>最初の推定消費カロリー</summary><h3>記録が足りるとき: nu-tori は、食べた量と体重の傾向から逆算します</h3>${rules.backCalculated}<h3>記録が足りないとき: nu-tori は、身体データから式で出します</h3>${rules.formula}</details>
<details><summary>1日の目安</summary>${rules.guide}${rules.limits}</details>
<details><summary>毎週の見直し</summary>${rules.review}</details>

<h2>医療の助言ではありません</h2>
<p>このページの内容は、医療の助言ではありません。持病のある方は、医師に相談してください。</p>
`;

const variants = [{ key: "e", name: "理由のピラミッド", body: variantE }];

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
.eq-row { display: grid; grid-template-columns: 10em 1fr; gap: 8px; }
.eq-row > * { min-width: 0; }
.eq-label { color: var(--on-surface-secondary); font-size: 13px; }
.eq-result { border-top: 1px solid var(--separator); padding-top: 8px; }
@media (max-width: 420px) { .eq-row { grid-template-columns: 1fr; gap: 0; } }


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

<p class="proto-note">PROTOTYPE（#745）: 「推定消費カロリーと1日の目安の出し方」の見せ方をミントのピラミッドで組み直した案（E）の試作です。数字は架空の1人を、本番のサーバーの決まりで計算した値です。</p>
<header class="site-header"><a class="site-name" href="#">nu-tori</a></header>
${variants.map((v) => `<main id="variant-${v.key}" data-name="${v.name}"${v.key === variants[0].key ? "" : " hidden"}>${v.body}</main>`).join("\n")}
<footer class="site-footer">
  <p>医療の助言ではありません。持病のある方は、医師に相談してください。</p>
  <p>nu-tori for iPhone</p>
</footer>
`;

writeFileSync(new URL("./index.html", import.meta.url), html);
console.log("wrote index.html", html.length);

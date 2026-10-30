// PROTOTYPE（prototype/lp-a-f-section の枝だけに置く。main と PR #809 には入れない）
// 問い: F 節の右の見本で、「毎週の体重で目安が決め直される」ことを、触る人が迷わずに分かるにはどうするか。
// 3案を同じページに並べ、?variant=A|B|C と下の切り替えの帯（/prototype-switcher.js）で1つだけ見せる
import { AppChevron } from "./app-chevron";
import { AppPfc } from "./app-pfc";
import { appText } from "./app-text";
import { JsonScript } from "./json-script";
import examples from "./landing-a-examples.json";
import guideExample from "../daily-guide/daily-guide-example.json";

const review = examples.review;
const goalIndex = review.goals.findIndex((goal) => goal.key === "lose-3kg");
const goal = review.goals[goalIndex]!;
const intakeIndex = (kcal: number) => review.intakeOptionsKcal.indexOf(kcal);
const weightIndex = (kg: number) => review.weightChangeOptionsKg.indexOf(kg);
const outcomeOf = (g: (typeof review.goals)[number], kcal: number, kg: number) =>
  g.outcomes[intakeIndex(kcal)]![weightIndex(kg)]!;

const goalLabel = (g: (typeof review.goals)[number]) =>
  g.direction === "maintain" ? "保つ" : `${review.startingWeightTrendKg - g.targetWeightKg} kg 減らす`;

// 知らせのカード。理由の文は試作なので短い形にする
const Notice = ({
  guideKcal,
  previousGuideKcal,
  proteinG,
  fatG,
  carbohydrateG,
  reason,
  data,
}: {
  guideKcal: number;
  previousGuideKcal: number;
  proteinG: number;
  fatG: number;
  carbohydrateG: number;
  reason: string;
  data?: boolean;
}) => (
  <div class="app-card app-notice">
    <p class="app-notice-head">
      <b>1日の目安が変わりました</b>
      <span class="app-secondary">月曜 7:02</span>
    </p>
    <p class="app-notice-value">
      <span class="app-notice-energy" data-proto-energy={data ? "" : undefined}>
        {appText.kcal(guideKcal)}
      </span>
      <span class="app-secondary" data-proto-change={data ? "" : undefined}>
        {appText.signedKcal(guideKcal - previousGuideKcal)}
      </span>
    </p>
    <div class="app-secondary">
      <AppPfc
        protein={appText.grams(proteinG)}
        fat={appText.grams(fatG)}
        carbohydrate={appText.grams(carbohydrateG)}
        replacedByScript={false}
      />
    </div>
    <p class="app-secondary" data-proto-reason={data ? "" : undefined}>
      {reason}
    </p>
    <span class="app-notice-link">
      目標
      <AppChevron />
    </span>
  </div>
);

const expenditureReason = (kcal: number) =>
  `推定消費カロリーが ${appText.number(review.previousExpenditureKcal)} から ${appText.kcal(kcal)} に${kcal < review.previousExpenditureKcal ? "下がった" : "上がった"}ためです。`;

export const FSectionPrototype = () => (
  <>
    <div data-proto-variant="A" data-proto-name="手順の順に並べる">
      <VariantA />
    </div>
    <div data-proto-variant="B" data-proto-name="よくある週を選ぶ" hidden>
      <VariantB />
    </div>
    <div data-proto-variant="C" data-proto-name="4週で合っていく" hidden>
      <VariantC />
    </div>
  </>
);

// A: 左の手順と同じ順（前提 → 先週の記録 → 見積もり直した使ったカロリー → 知らせ）に縦に並べ、段ごとに見出しを付ける。
// 動かす2つは「先週の記録」の枠に入れ、そこから出る中間の値（使ったカロリー）を矢印の先に見せる
const VariantA = () => {
  const states = review.goals.map((g) =>
    g.outcomes.map((row) =>
      row.map((o) => ({
        expenditure: appText.kcal(o.expenditureKcal),
        energy: appText.kcal(o.guideKcal),
        change: appText.signedKcal(o.guideKcal - g.previousGuideKcal),
        reason:
          o.mainReason === "expenditure_change"
            ? expenditureReason(o.expenditureKcal)
            : "目標の期限に合わせて、使ったカロリーとの差を変えたためです。",
      })),
    ),
  );
  const first = outcomeOf(goal, 1900, 0);
  return (
    <div class="lp-example proto-f-a" data-proto-review-a>
      <p class="proto-f-lead">先週の記録を動かすと、月曜の朝に届く知らせが変わります。</p>
      <div class="proto-f-stage">
        <p class="proto-f-stage-head">見本の人の目標</p>
        <div class="lp-segmented" role="group" aria-label="目標">
          {review.goals.map((g, index) => (
            <button
              type="button"
              data-proto-goal={String(index)}
              aria-pressed={index === goalIndex ? "true" : "false"}
            >
              {goalLabel(g)}
            </button>
          ))}
        </div>
        <p class="lp-fine">
          体重 70.0 kg から始め、1日に使うカロリーを 2,100 kcal と見積もっていた人です。
        </p>
      </div>
      <div class="proto-f-stage proto-f-input">
        <p class="proto-f-stage-head">① 先週の記録（ここを動かす）</p>
        <div class="lp-control">
          <label for="proto-intake">
            1日に食べた量（平均）<output data-proto-intake-label>1,900 kcal</output>
          </label>
          <input type="range" id="proto-intake" min="0" max="8" step="1" value={String(intakeIndex(1900))} data-proto-intake />
        </div>
        <div class="lp-control">
          <label for="proto-weight">
            体重の変化<output data-proto-weight-label>±0.0 kg</output>
          </label>
          <input type="range" id="proto-weight" min="0" max="9" step="1" value={String(weightIndex(0))} data-proto-weight />
        </div>
      </div>
      <p class="proto-f-arrow" aria-hidden="true">↓</p>
      <div class="proto-f-stage">
        <p class="proto-f-stage-head">② 見積もり直した、1日に使っているカロリー</p>
        <p class="proto-f-big">
          <span class="app-secondary">2,100 kcal →</span>{" "}
          <b data-proto-expenditure>{appText.kcal(first.expenditureKcal)}</b>
        </p>
      </div>
      <p class="proto-f-arrow" aria-hidden="true">↓</p>
      <div class="proto-f-stage">
        <p class="proto-f-stage-head">③ 月曜の朝の知らせ</p>
        <Notice
          guideKcal={first.guideKcal}
          previousGuideKcal={goal.previousGuideKcal}
          proteinG={first.proteinG}
          fatG={first.fatG}
          carbohydrateG={first.carbohydrateG}
          reason={expenditureReason(first.expenditureKcal)}
          data
        />
      </div>
      <JsonScript
        type="application/json"
        value={{
          states,
          intakeLabels: review.intakeOptionsKcal.map((k) => appText.kcal(k)),
          weightLabels: review.weightChangeOptionsKg.map((k) => appText.signedKg(k)),
        }}
      />
    </div>
  );
};

// B: 動かす値をやめ、「よくある週」を3つから選ぶ。週ごとに、何が起きたかの1文と、見積もり直した値と、知らせを出す。
// 上の2つは食べた量が同じで、体重の動きだけで目安が逆に動くのを見せる
const weeks = [
  {
    key: "flat",
    label: "減らなかった週",
    story: "1日 1,900 kcal 食べて、体重は変わらなかった。",
    intake: 1900,
    weight: 0,
    because: "思ったほど使っていなかったので、見積もりを下げます。",
  },
  {
    key: "fast",
    label: "思ったより減った週",
    story: "同じ 1,900 kcal で、体重が 0.5 kg 減った。",
    intake: 1900,
    weight: -0.5,
    because: "思ったより使っていたので、見積もりを上げます。",
  },
  {
    key: "over",
    label: "食べすぎた週",
    story: "1日 2,100 kcal 食べて、体重が 0.1 kg 増えた。",
    intake: 2100,
    weight: 0.1,
    because: "見積もりはほぼそのままで、期限に間に合うよう目安を下げます。",
  },
] as const;

const VariantB = () => (
  <div class="lp-example" data-proto-weeks>
    <p class="proto-f-lead">3 kg 減らす目標の人の、よくある週を選んでください。</p>
    <div class="lp-segmented" role="group" aria-label="週を選ぶ">
      {weeks.map((week, index) => (
        <button type="button" data-proto-week={week.key} aria-pressed={index === 0 ? "true" : "false"}>
          {week.label}
        </button>
      ))}
    </div>
    {weeks.map((week, index) => {
      const o = outcomeOf(goal, week.intake, week.weight);
      return (
        <div class="proto-f-week" data-proto-week-panel={week.key} hidden={index !== 0}>
          <p class="proto-f-story">{week.story}</p>
          <p class="proto-f-big">
            <span class="app-secondary">1日に使うカロリーの見積もり 2,100 →</span>{" "}
            <b>{appText.kcal(o.expenditureKcal)}</b>
          </p>
          <p class="lp-fine">{week.because}</p>
          <Notice
            guideKcal={o.guideKcal}
            previousGuideKcal={goal.previousGuideKcal}
            proteinG={o.proteinG}
            fatG={o.fatG}
            carbohydrateG={o.carbohydrateG}
            reason={
              o.mainReason === "expenditure_change"
                ? expenditureReason(o.expenditureKcal)
                : "期限に間に合うよう、1日の目安を推定消費カロリーよりさらに下げたためです。"
            }
          />
        </div>
      );
    })}
    <p class="lp-fine">
      見本の人: 体重 70.0 kg、1日に使うカロリーを 2,100 kcal と見積もり、先週の目安は 1,850 kcal でした。
    </p>
  </div>
);

// C: 動かさない。/daily-guide の見本の人（式で出した最初の見積もりが高すぎた人）の4週を並べ、
// 見積もりが本当の値に近づき、目安が落ち着いていくのを棒で見せる。棒の長さは 1,500〜2,500 kcal の幅で描く
const trueKcal =
  Math.round(
    guideExample.days.reduce((sum, day) => sum + day.trueExpenditureKcal, 0) /
      guideExample.days.length /
      10,
  ) * 10;
const rows = [
  { when: "始めた日", expenditure: guideExample.initial.kcal, guide: guideExample.initial.guideKcal, note: "身長・年齢・性別と活動量から" },
  ...guideExample.reviews.map((r, i) => ({
    when: `${i + 1}週目の見直し`,
    expenditure: r.expenditureKcal,
    guide: r.guideKcal,
    note: `その週は 1日 ${appText.number(r.averageEnergyIntakeKcal)} kcal 食べて、体重 ${appText.signedKg(Math.round(r.actualWeightChangeKg * 10) / 10)}`,
  })),
];
const barMin = 1500;
const barMax = 2500;
const barPercent = (kcal: number) => `${((kcal - barMin) / (barMax - barMin)) * 100}%`;

const VariantC = () => (
  <div class="lp-example proto-f-c">
    <p class="proto-f-lead">
      最初の見積もりが高すぎた人の4週です。本当に使っていたのは 1日 約{appText.number(trueKcal)} kcal でした。
    </p>
    <ol class="proto-f-weeks">
      {rows.map((row) => (
        <li>
          <p class="proto-f-week-head">
            <b>{row.when}</b>
            <span>
              目安 <b>{appText.kcal(row.guide)}</b>
            </span>
          </p>
          <div class="proto-f-bar" data-width={barPercent(row.expenditure)} data-true={barPercent(trueKcal)}>
            <span class="proto-f-bar-fill" />
            <span class="proto-f-bar-true" />
          </div>
          <p class="lp-fine">
            使っているカロリーの見積もり {appText.kcal(row.expenditure)}（{row.note}）
          </p>
        </li>
      ))}
    </ol>
    <p class="lp-fine">
      縦の線が本当に使っていたカロリーです。数字は <a href="/daily-guide">1日の目安の出し方</a> の見本の人のものです。
    </p>
  </div>
);

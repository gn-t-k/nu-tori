import type { SitePage } from "../site-page";
import { dailyGuideExample } from "./daily-guide/daily-guide-example";
import { formatExampleValue } from "./daily-guide/format-example-value";
import { PlateauFigure } from "./daily-guide/plateau-figure";
import { ReviewEquation } from "./daily-guide/review-equation";
import { ReviewFigure } from "./daily-guide/review-figure";
import { TrendFigure } from "./daily-guide/trend-figure";
import { WeeksFigure } from "./daily-guide/weeks-figure";

// 目標の設定と目標の画面のリンク（#641）が開く先。最初の読み手は、栄養の知識が無く数秒しか読まない人（docs/ui-design/0001-first-release/00-persona-model.md の Tさん）なので、答えを先に置く
// 決まりの文は、書いたときのサーバーのドメイン層のコードに合わせた（場所は節ごとのコメント）。サーバーで値や決まりを変えたら、同じ PR でここを直す
export const dailyGuidePage: SitePage = {
  outputPath: "/daily-guide",
  title: "1日の目安が、あなたの体に合っていく仕組み | nu-tori",
  description:
    "nu-tori が、推定消費カロリーと1日の目安をどう出し、毎週の記録でどうあなたの体に合わせていくかを説明します。",
  kind: "public",
  // 目標の設定と目標の画面のリンク（#641）と同じ文言にする
  footerLabel: "1日の目安が、あなたの体に合っていく仕組み",
  Content: () => <DailyGuideContent />,
};

const { kcal, kg, monthDay, dayOfMonth } = formatExampleValue;
const {
  person,
  initial,
  exampleReview,
  lastReview,
  firstDay,
  lastDay,
  plateauStart,
  plateauAfterOneYear,
  plateauAfterTwoYears,
} = dailyGuideExample;

const DailyGuideContent = () => (
  <>
    <h1>1日の目安が、あなたの体に合っていく仕組み</h1>
    <p>
      nu-tori
      は、あなたの体が1日に使うカロリーを推定します。この値を「推定消費カロリー」と呼びます。やせたいときは推定消費カロリーより少ない量を、体重を増やしたいときは多い量を、nu-tori
      は1日の目安にします。
    </p>
    <p>
      ただ、最初の推定は、あなたの身長・体重・年齢から出した、おおよその値です。筋肉の量やふだんの動きは人によって違うので、最初の推定は、あなたの体と数百
      kcal ずれることがあります。
    </p>
    <div class="answer">
      <p>
        <strong>
          ずれていても、nu-tori
          が毎週あなたの体重の記録を見て、目安を直します。使い続けるほど、目安はあなたの体に合っていきます。
        </strong>
      </p>
      <ol class="key-line">
        <li>
          <a href="#review">体重が予想どおりに変わったかを見て、nu-tori が推定を直します</a>
        </li>
        <li>
          <a href="#follow">
            体重が変わって体が使うカロリーが変わっても、nu-tori が目安を合わせ直します
          </a>
        </li>
        <li>
          <a href="#steady">体重計の数字が一時的に上下しても、nu-tori は目安を大きく変えません</a>
        </li>
      </ol>
    </div>
    <p>
      あなたがするのは、毎朝同じころに体重を量ることと、食べたものを撮ることだけです。1日の分をなるべく全部記録すると、目安は早くあなたの体に合います。
    </p>

    {/* ADR-0007（docs/adr/0007-expenditure-from-weight-trend.md）、server/src/weekly-review/domain/compute-reviewed-expenditure/compute-reviewed-expenditure.ts */}
    <h2 id="review">1. 体重が予想どおりに変わったかを見て、nu-tori が推定を直します</h2>
    <p>
      nu-tori
      は毎週月曜に、先週あなたが食べた量から、体重がどれだけ変わるはずだったかを予想し、実際の体重と比べます。
    </p>
    <ul>
      <li>実際の体重が予想より重いほうにずれたら、nu-tori は推定を下げます</li>
      <li>実際の体重が予想より軽いほうにずれたら、nu-tori は推定を上げます</li>
    </ul>
    <p>nu-tori は、運動の記録を使いません。運動で使った分も、体重の動きに表れるからです。</p>
    <h3>Aさんの例</h3>
    <p>
      Aさんは、{person.ageYears} 歳・身長 {person.heightCentimeters} cm・体重{" "}
      {kg(initial.startingWeightTrendKg, 1)} kg の男性で、ほぼ座り仕事です。nu-tori
      は、Aさんの最初の推定消費カロリーを式で出し、{kcal(initial.kcal)} kcal
      としました。Aさんの目標は{person.goalWeeks}週で {kg(person.targetWeightKg, 1)} kg
      まで減らすことで、最初の1日の目安は {kcal(initial.guideKcal)} kcal
      でした。ここでは、Aさんの体が本当に使うカロリーを {kcal(firstDay.trueExpenditureKcal)} kcal
      とします。ただ、この本当の値は、Aさん本人にも nu-tori にも分かりません。nu-tori
      に分かるのは、Aさんが食べた量と、体重の動きだけです。
    </p>
    <p>
      2週目（{monthDay(exampleReview.weekFirstDay)}〜{dayOfMonth(exampleReview.weekLastDay)}
      日）に、Aさんが食べた量の平均は {kcal(exampleReview.averageEnergyIntakeKcal)} kcal
      で、その週の推定消費カロリーは {kcal(exampleReview.previousExpenditureKcal)} kcal
      でした。nu-tori はこの差から、Aさんの体重の傾向（毎朝の体重をならした値。3 で説明します）が{" "}
      {kg(exampleReview.predictedWeightChangeKg, 2)} kg 減ると予想しました。実際の体重の傾向は{" "}
      {kg(exampleReview.actualWeightChangeKg, 2)} kg しか減らず、予想とのずれは{" "}
      {kg(exampleReview.deviationKg, 2)} kg でした。
    </p>
    <ReviewFigure caption="Aさんの2週目です。点線が nu-tori の予想、実線が実際の体重の傾向です。" />
    <p>nu-tori は、このずれから、推定消費カロリーを次のように直しました。</p>
    <ReviewEquation />
    <p>
      nu-tori
      がこれを毎週くり返すと、Aさんの推定消費カロリーは、Aさんの体が本当に使うカロリー（点線）に近づきます。
    </p>
    <WeeksFigure caption="Aさんが使い始めてから5週目までです。推定消費カロリーが毎週直り、1日の目安もそれに合わせて下がります。" />

    <h2 id="follow">
      2. 体重が変わって体が使うカロリーが変わっても、nu-tori が目安を合わせ直します
    </h2>
    <p>
      体重が変わると、あなたの体が1日に使うカロリーも変わります。体が軽くなるほど、体を保ち、動かすのに要るカロリーが減り、重くなるほど増えるからです。そのため、同じ量を食べ続けると、体重の変わり方はだんだん緩くなります。
    </p>
    <p>
      nu-tori は、この分も 1
      と同じ毎週の見直しで推定消費カロリーに反映し、1日の目安を出し直します。あなたが計算し直す必要はありません。
    </p>
    <h3>Aさんの例</h3>
    <p>
      Aさんの体が本当に使うカロリーは、4週間で体重が減るにつれて、
      {kcal(firstDay.trueExpenditureKcal)} kcal から {kcal(lastDay.trueExpenditureKcal)} kcal
      に減りました。もしAさんが、4週目の1日の目安 {kcal(lastReview.guideKcal)} kcal
      を見直さずに食べ続けると、体重は1年目に{" "}
      {kg(plateauStart.trueWeightKg - plateauAfterOneYear.trueWeightKg, 1)} kg 減りますが、2年目には{" "}
      {kg(plateauAfterOneYear.trueWeightKg - plateauAfterTwoYears.trueWeightKg, 1)} kg
      しか減りません。
    </p>
    <PlateauFigure
      caption={`Aさんが ${kcal(lastReview.guideKcal)} kcal を2年食べ続けたときの体重です。体重が 1 kg 減ると、Aさんの体が1日に使うカロリーが ${person.trueExpenditureKcalPerKg} kcal 減ると仮定しました。`}
    />

    {/* server/src/weight-trend/domain/compute-weight-trend.ts、server/src/weekly-review/domain/compute-reviewed-expenditure/compute-reviewed-expenditure.ts、server/src/daily-guide/domain/maximum-weekly-change-kcal.ts、server/src/weekly-review/domain/judge-review-week/judge-review-week.ts */}
    <h2 id="steady">3. 体重計の数字が一時的に上下しても、nu-tori は目安を大きく変えません</h2>
    <p>
      外食した翌朝は、体重計の数字が 0.5〜1 kg
      増えていることがあります。増えたのは脂肪ではなく、食べた物や体の水分です。nu-tori
      は、こうした一時的な増減で目安を大きく変えないように、次の4つの決まりを守ります。
    </p>
    <h3>nu-tori は、毎朝の体重をならした「体重の傾向」を見ます</h3>
    <p>
      nu-tori
      は、1日ごとの体重ではなく、毎朝の体重をならした体重の傾向の動きを、予想と比べます。たとえば、Aさんの毎朝の体重は日によって
      0.5 kg ほど上下しましたが、Aさんの体重の傾向はなめらかに動きました。
    </p>
    <TrendFigure caption="Aさんの、毎朝の体重（点）と体重の傾向（線）です。" />
    <h3>nu-tori は、推定消費カロリーを、ずれの一部ずつ直します</h3>
    <p>
      nu-tori
      は、1週のずれの分を、一度に全部は推定消費カロリーに反映しません。食事を記録した日が多い週ほど、また同じ向きのずれが続いた週ほど、大きく直します。たとえば、Aさんの2週目のずれは、1日あたりにすると約{" "}
      {kcal(exampleReview.deviationKcalPerDay)} kcal でした。nu-tori は、そのうち半分の約{" "}
      {kcal(exampleReview.adjustedKcal)} kcal だけ、推定消費カロリーを下げました。
    </p>
    <h3>nu-tori は、1日の目安を1週に 150 kcal までしか変えません</h3>
    <p>
      nu-tori は、毎週の見直しで、1日の目安を前の週から 150 kcal
      より大きく上げ下げしません。たとえば、Aさんの1週目と2週目の見直しでは、決まりどおりに出すと1日の目安が
      150 kcal より大きく下がるところでした。nu-tori は、どちらの週も 150 kcal
      下げるところで止めました。
    </p>
    <h3>nu-tori は、記録が少ない週の見直しを見送ります</h3>
    <p>
      nu-tori は、体重の記録が無い週と、食事を記録した日が 4
      日に満たない週の見直しを見送り、推定消費カロリーと1日の目安を前の週のままにします。
    </p>

    <h2>計算の決まり</h2>
    <p>ここからは、ここまでに説明した計算の、細かい決まりです。</p>

    {/* server/src/expenditure-estimate/domain/compute-initial-expenditure-estimate/（compute-initial-expenditure-estimate.ts・compute-back-calculated-expenditure.ts・compute-activity-factor.ts）、server/src/expenditure-estimate/domain/exclude-partially-recorded-days/、server/src/domain/kilocalories-per-kilogram.ts */}
    <h3>記録が足りるとき、nu-tori は最初の推定消費カロリーを、食べた量と体重から逆算します</h3>
    <p>
      nu-tori は、今日を除く直前の 28
      日に、あなたが食べた量の1日の平均から、体重の傾向が変わった分を差し引いて、推定消費カロリーを出します。nu-tori
      は、体重 1 kg の増減を 7,700 kcal とみなします。たとえば、体重の傾向が1日に 0.1 kg
      ずつ減っていたなら、推定消費カロリーは、食べた量の平均に 770 kcal を足した値です。
    </p>
    <p>
      食べた量には、nu-tori を使い始めた日からは nu-tori
      の食事の記録を使い、使い始める前の日はヘルスケアの摂取エネルギーを使います。nu-tori
      が逆算するには、次の2つが要ります。
    </p>
    <ul>
      <li>
        食べた量のある日が 14
        日以上あること。ただし、食べた量がほかの日の中ほどの値の半分に満たない日（1食だけ記録した日など）は、記録の途中とみなして数えません
      </li>
      <li>体重を記録した日が 4 日以上あり、最初の日から最後の日まで 14 日以上あること</li>
    </ul>
    <h3>
      記録が足りないとき、nu-tori は最初の推定消費カロリーを、身長・体重・年齢・性別から式で出します
    </h3>
    <p>
      nu-tori は、まず、あなたの体が安静にしているときに使うカロリーを、Mifflin-St Jeor
      の式で出します。式に使う体重は、目標を始める日の体重の傾向です。nu-tori
      は、その値に、ふだんの動きの多さに合わせた係数を掛けます。
    </p>
    <ul>
      <li>
        ヘルスケアから歩数を読めるとき: nu-tori は係数を、直前 28
        日のうち歩いた日の、平均の歩数で決めます。5,000 歩未満なら 1.4、10,000 歩未満なら
        1.55、それ以上なら 1.7 です
      </li>
      <li>
        歩数を読めないとき: nu-tori は、あなたに次の3つから選んでいただきます。ほぼ座り仕事なら
        1.4、立ち仕事が多いなら 1.55、よく動くなら 1.7 です
      </li>
    </ul>
    <p>
      たとえば、Aさんの体が安静にしているときに使うカロリーは、式で {kcal(initial.restingKcal)} kcal
      でした。nu-tori はAさんの歩数を読めず、Aさんは「ほぼ座り仕事」を選んだので、nu-tori は{" "}
      {person.activityFactor} を掛けて、最初の推定消費カロリーを {kcal(initial.kcal)} kcal
      としました。
    </p>
    <p>
      身長・年齢・性別のうち、ヘルスケアから読めない値は、あなたにアプリで入れていただきます。nu-tori
      は、身体データと、使い始める前の摂取エネルギーを、この計算にだけ使い、保存しません。
    </p>

    {/* server/src/daily-guide/domain/compute-daily-guide-energy/compute-daily-guide-energy.ts、server/src/daily-guide/domain/compute-required-pace.ts、server/src/goal/domain/weekly-pace-rates.ts、server/src/goal/domain/maintenance-band-kg.ts、server/src/daily-guide/domain/minimum-daily-guide-energy-kcal.ts、server/src/daily-guide/domain/maximum-weekly-change-kcal.ts、server/src/daily-guide/domain/round-to-fifty-kcal.ts */}
    <h3>nu-tori は、期限までに目標体重へ届く速さから、1日の目安を出します</h3>
    <p>
      nu-tori は、期限の日までに目標体重へ届くには、体重の傾向を1日に何 kg
      ずつ変えればよいかを出し、それに 7,700 kcal/kg
      を掛けます。体重を減らす目標では、推定消費カロリーからこの分を引き、体重を増やす目標では足します。nu-tori
      は、出した値を 50 kcal 単位に丸めます。
    </p>
    <p>
      たとえば、Aさんは {person.daysFromStartToDeadline} 日で {kg(initial.startingWeightTrendKg, 1)}{" "}
      kg から {kg(person.targetWeightKg, 1)} kg まで減らすので、体重の傾向を1日に約{" "}
      {initial.requiredPaceKgPerDay.toFixed(3)} kg ずつ減らす必要がありました。これは1日 約{" "}
      {kcal(initial.requiredPaceKcalPerDay)} kcal にあたります。nu-tori は、{kcal(initial.kcal)}{" "}
      kcal からこれを引いた約 {kcal(initial.unroundedGuideKcal)} kcal を丸めて、最初の1日の目安を{" "}
      {kcal(initial.guideKcal)} kcal としました。
    </p>
    <p>
      体重を保つ目標では、体重の傾向が目標体重の ±0.7 kg の中にあれば、nu-tori
      は1日の目安を推定消費カロリーと同じにします。体重の傾向がその幅から外れたら、nu-tori
      は、体重の傾向を1週間に 0.15% の速さで目標体重へ戻す分だけ、1日の目安を少なく（多く）します。
    </p>
    <h3>nu-tori は、無理な減らし方にならないように、1日の目安に上限と下限を当てます</h3>
    <ul>
      <li>
        体重を変える速さの上限: nu-tori は、体重を1週間に、目標を始めた日の体重の傾向の
        0.75%（減量）・0.5%（増量）より速く変える目安にしません。期限までの日が少なくても、無理な速さにはしません
      </li>
      <li>1日の目安の下限: nu-tori は、1日の目安を 1,200 kcal より低くしません</li>
      <li>
        1週の変化の幅: nu-tori は、毎週の見直しで、1日の目安を前の週から 150 kcal
        より大きく上げ下げしません
      </li>
    </ul>

    {/* server/src/weekly-review/domain/judge-review-week/judge-review-week.ts、server/src/weekly-review/domain/compute-reviewed-expenditure/compute-reviewed-expenditure.ts、server/src/daily-guide/domain/compute-reviewed-daily-guide/compute-reviewed-daily-guide.ts */}
    <h3>nu-tori は、毎週月曜に、推定消費カロリーと1日の目安を見直します</h3>
    <ol>
      <li>
        nu-tori
        は、前の週（月曜から日曜）にあなたが食べた量の平均と、その週の推定消費カロリーから、体重の傾向がどれだけ変わるはずだったかを予想します
      </li>
      <li>
        nu-tori
        は、その予想を実際の体重の傾向の変化と比べ、ずれの一部だけ推定消費カロリーを動かします。動かす割合は、0.25
        に「その週に食事を記録した日の数 ÷ 7」と「同じ向きのずれが続いた週の数 ＋
        1」を掛けた値で、0.75 を上限にします
      </li>
      <li>nu-tori は、新しい推定消費カロリーで、1日の目安を出し直します</li>
    </ol>
    <p>
      たとえば、Aさんの2週目は、Aさんが食事を7日とも記録し、推定が高すぎる向きのずれが2週続いたので、動かす割合は
      0.25 × 7 ÷ 7 × 2 ＝ {exampleReview.gain} でした。
    </p>
    <h3>nu-tori は、記録が少ない週の見直しを見送ります</h3>
    <p>
      nu-tori
      は、次のどれかに当たる週の見直しを見送り、推定消費カロリーと1日の目安を前の週のままにします。
    </p>
    <ul>
      <li>
        あなたが nu-tori を使い始めて 7
        日に満たない（最初の推定消費カロリーを逆算したときは、この決まりを当てません）
      </li>
      <li>その週に、体重の記録が無い</li>
      <li>その週に、食事を記録した日が 4 日に満たない（1食だけ記録した日などは数えません）</li>
    </ul>

    <h2>医療の助言ではありません</h2>
    <p>このページの内容は、医療の助言ではありません。持病のある方は、医師に相談してください。</p>
  </>
);

import type { SitePage } from "../site-page";

// 目標の設定と目標の画面のリンク（#641）が開く先。数字と決まりは、書いたときのサーバーのドメイン層のコードに合わせた（場所は節ごとのコメント）。
// サーバーで値や決まりを変えたら、同じ PR でここを直す
export const dailyGuidePage: SitePage = {
  outputPath: "/daily-guide",
  title: "推定消費カロリーと1日の目安の出し方 | nu-tori",
  description: "nu-tori が、推定消費カロリーと1日の目安をどう出し、毎週どう見直すかを説明します。",
  kind: "public",
  // 目標の設定と目標の画面のリンク（#641）と同じ文言にする
  footerLabel: "推定消費カロリーと1日の目安の出し方",
  Content: () => (
    <>
      <h1>推定消費カロリーと1日の目安の出し方</h1>
      <p>
        nu-tori
        は、1日に食べる量の目安（1日の目安）を、推定消費カロリーと目標から出し、毎週の記録で見直します。このページでは、その出し方を説明します。
      </p>

      {/* ADR-0007（docs/adr/0007-expenditure-from-weight-trend.md） */}
      <h2>1. 推定消費カロリーは推定です</h2>
      <p>
        推定消費カロリーは、1日に消費するカロリーを、体重の傾向と食べた量から推定した値です。体の中を測った値ではありません。
      </p>
      <p>
        体重の傾向は、体重の記録から日々の増減をならした体重の推移です。食べた量に比べて体重の傾向が減っていれば、食べた量より多く消費していると推定します。
      </p>
      <p>
        運動の記録やワークアウト、消費したエネルギーの記録は使いません。運動した分も、体重の傾向の動きに表れるからです。
      </p>

      {/* server/src/expenditure-estimate/domain/compute-initial-expenditure-estimate/（compute-initial-expenditure-estimate.ts・compute-back-calculated-expenditure.ts・compute-activity-factor.ts）、server/src/expenditure-estimate/domain/exclude-partially-recorded-days/、server/src/domain/kilocalories-per-kilogram.ts */}
      <h2>2. 最初の推定消費カロリー</h2>
      <p>初めて目標を立てるときに、次のどちらかで出します。</p>

      <h3>記録が足りるとき: 食べた量と体重の傾向から逆算します</h3>
      <p>
        今日を除く直前の 28 日の、食べた量と体重から出します。食べた量は、nu-tori
        を使い始めた日からは nu-tori
        の食事の記録を、使い始める前の日はヘルスケアの摂取エネルギーを使います。
      </p>
      <ul>
        <li>
          食べた量のある日が 14
          日以上あること。食べた量がほかの日の中ほどの値の半分に満たない日（1食だけ記録した日など）は、記録の途中とみなして数えません
        </li>
        <li>体重を記録した日が 4 日以上あり、最初の日から最後の日まで 14 日以上あること</li>
      </ul>
      <p>
        食べた量の1日の平均から、体重の傾きの分を引いて出します。体重 1 kg の増減を 7,700 kcal
        とみなし、たとえば体重が1日に 0.1 kg ずつ減っていれば、食べた量の平均に 770 kcal
        を足した値になります。
      </p>

      <h3>記録が足りないとき: 身体データから式で出します</h3>
      <p>
        身長・生年月日（年齢）・性別と、開始の日の体重の傾向から、安静にしているときの消費を
        Mifflin-St Jeor
        の式で出し、活動量の係数を掛けます。ヘルスケアから読めない値は、アプリで入れていただきます。
      </p>
      <ul>
        <li>
          歩数が読めるとき: 直前 28 日の、歩いた日の平均の歩数で決めます。5,000 歩未満は 1.4、10,000
          歩未満は 1.55、それ以上は 1.7
        </li>
        <li>
          歩数が読めないとき: 3つから選んでいただきます。ほぼ座り仕事は 1.4、立ち仕事が多いは
          1.55、よく動くは 1.7
        </li>
      </ul>
      <p>身体データと、使い始める前の摂取エネルギーは、この計算にだけ使い、保存しません。</p>

      {/* server/src/daily-guide/domain/compute-daily-guide-energy/compute-daily-guide-energy.ts、server/src/daily-guide/domain/compute-required-pace.ts、server/src/goal/domain/weekly-pace-rates.ts、server/src/goal/domain/maintenance-band-kg.ts、server/src/daily-guide/domain/minimum-daily-guide-energy-kcal.ts、server/src/daily-guide/domain/maximum-weekly-change-kcal.ts、server/src/daily-guide/domain/round-to-fifty-kcal.ts */}
      <h2>3. 1日の目安</h2>
      <p>
        1日の目安は、推定消費カロリーから、目標の速さで1日に減らす分を引いたものです。増量では、1日に足す分を足します。
      </p>
      <p>
        1日に減らす（足す）分は、期限の日までに目標体重へ届くのに要る体重の変化の速さに、7,700
        kcal/kg を掛けて出します。たとえば、体重の傾向が1日に 0.05 kg ずつ減る速さなら、1日に 385
        kcal を減らします。維持では、体重の傾向が目標体重の ±0.7 kg
        の中にあれば、減らしも足しもしません。外れたら、体重の傾向の 1週間に 0.15%
        の速さで目標体重へ戻す分だけ減らし（足し）ます。
      </p>
      <p>値は 50 kcal 単位に丸め、次の上限と下限を当てます。</p>
      <ul>
        <li>
          必要な速さの上限: 1週間に、開始の日の体重の傾向の
          0.75%（減量）・0.5%（増量）より速くしません。期限までの日が少なくても、無理な速さにしません
        </li>
        <li>1日の目安の下限: 1,200 kcal より低くしません</li>
        <li>1週の変化の幅: 毎週の見直しで、前の週の1日の目安から ±150 kcal より大きく変えません</li>
      </ul>

      {/* server/src/weekly-review/domain/judge-review-week/judge-review-week.ts、server/src/weekly-review/domain/compute-reviewed-expenditure/compute-reviewed-expenditure.ts、server/src/daily-guide/domain/compute-reviewed-daily-guide/compute-reviewed-daily-guide.ts */}
      <h2>4. 毎週の見直し</h2>
      <p>
        毎週、月曜から当てる推定消費カロリーと1日の目安を、その前の週（月曜から日曜）の記録で見直します。
      </p>
      <ol>
        <li>
          前の週の食べた量の平均と、そのときの推定消費カロリーから、体重の傾向がどれだけ変わるはずだったかを出します
        </li>
        <li>
          実際の体重の傾向の変化と比べ、ずれの分だけ推定消費カロリーを動かします。一度に全部は動かさず、食事を記録した日が多い週ほど、同じ向きのずれが続いた週ほど大きく動かします
        </li>
        <li>新しい推定消費カロリーで、上の 3 と同じように1日の目安を出し直します</li>
      </ol>
      <p>
        次のどれかに当たる週は、見直しを見送り、推定消費カロリーも1日の目安も前の週のままにします。
      </p>
      <ul>
        <li>使い始めて 7 日に満たない（最初の値を食べた量と体重から逆算したときは当てません）</li>
        <li>その週に体重の記録が無い</li>
        <li>その週に食事を記録した日が 4 日に満たない（1食だけ記録した日などは数えません）</li>
      </ul>

      <h2>5. 記録を続けると、推定が確かになります</h2>
      <p>
        推定消費カロリーは、体重の傾向と食べた量のずれから直していきます。毎朝の体重と、食事の記録が揃うほど、推定は実際の消費に近づき、1日の目安も合っていきます。
      </p>
      <p>
        体重は、毎朝、同じころに量ると、日々の揺れが小さくなります。食事は、食べたものを撮るか書くかして、1日の分をなるべく全部記録してください。
      </p>

      <h2>6. 医療の助言ではありません</h2>
      <p>医療の助言ではありません。持病のある方は、医師に相談してください。</p>
    </>
  ),
};

import type { LearnArticle } from "../learn-article";
import { LearnFigure } from "../learn-figure";

// ジョギングの METs（2024 Adult Compendium のコード 12020）。出典の claim がトップレベルで読むので、calorieBalance より上に置く
const joggingMets = 7.5;

// 図は ChatGPT で描いた挿絵（文字なし）。site/public/learn/calorie-balance に 1200×800 の WebP で置いた
const Figure = ({ name, alt }: { name: string; alt: string }) => (
  <LearnFigure src={`/learn/calorie-balance/${name}.webp`} alt={alt} width={1200} height={800} />
);

// 「nu-tori では」の決まりの文は、書いたときのサーバーのドメイン層のコードに合わせた（server/src/domain/kilocalories-per-kilogram.ts、server/src/weekly-review/domain/compute-reviewed-expenditure/compute-reviewed-expenditure.ts、server/src/weekly-review/domain/judge-review-week/judge-review-week.ts）。サーバーで値や決まりを変えたら、同じ PR でここを直す
export const calorieBalance: LearnArticle = {
  slug: "calorie-balance",
  question: "摂取カロリーと消費カロリーで、体重はどう決まる？",
  description:
    "体重は、食べたカロリーと体が使ったカロリーの差で決まり、約 7,700 kcal の差で約 1 kg 変わります。運動より食事で差を作るほうが手軽なことと、食べ物のカロリーが見た目では分かりにくいことを、研究をもとに説明します。",
  Lead: () => (
    <>
      <p>
        食事の量を減らしたり、運動の量を増やしたりすると、体重は減ります。では、どのくらい食事や運動の量を変化させればどのくらい体重が変化するのか、ご存じでしょうか。
      </p>
      <p>
        体重の変化は、摂取したカロリーの量と体が消費したカロリーの量の差で決まります。食事の量を 500
        kcal 分減らしても、運動の量を 500 kcal
        分増やしても、カロリーの差としては同じです。カロリーの差を毎日少しずつ積み重ねて、約 7,700
        kcal で 1 kg 体重が減るとされています。
      </p>
      <p>
        nu-tori
        では、食事量の変化を中心にカロリーの差を管理し、毎日の変化ではなく1週間の変化を見て、ダイエットの進捗を判断します。
      </p>
    </>
  ),
  claims: [
    {
      heading: "体重を減らすなら食事で差を作るのがいちばん手軽",
      Research: () => (
        <>
          <p>
            体重の変化は、食べたカロリー（摂取カロリー）と体が使ったカロリー（消費カロリー）の差で決まります。体が使うカロリーが食べたカロリーより多いと、体は脂肪や筋肉を燃やして足りない分を補います。これが体重が減る仕組みです。
          </p>
          <Figure
            name="energy-balance"
            alt="天秤の左の皿に食べ物、右の皿に走る人と炎が乗り、右に少し傾いている"
          />
          <p>体重 1 kg の増減は約 7,700 kcal の差にあたるとみなされています。</p>
          <p>
            運動の量を増やして体重を減らす方法を考えてみましょう。ジョギングは、安静にしているときの約{" "}
            {joggingMets} 倍のカロリーを使う運動ですが、体重 {bodyWeightKg} kg
            の人が30分走って増えるのは約 {joggingKcal} kcal。おにぎりにすると約{" "}
            {onigiriGramsForJogging} g、だいたい1個分です。運動だけで 1 kg
            分の差を作るなら、30分のジョギングを約 {joggingSessionsPerKilogram} 回、合わせて約{" "}
            {joggingSessionsPerKilogram * joggingHours} 時間走ることになります。
          </p>
          <Figure name="jogging-and-onigiri" alt="走る人と30分を示す時計が、おにぎり1個と等しい" />
          <p>
            食事なら、1日に {dailyDeficitKcal} kcal 少なく食べると、2週間ほどで約 7,000
            kcal、体重にして 1 kg 弱の差になります。1日 {dailyDeficitKcal} kcal
            は、おにぎりにすると約 {onigiriGramsForDailyDeficit}{" "}
            g、2個半ほどです。体重を減らすことだけを見るなら、食事で差を作るほうがずっと手軽です。
          </p>
        </>
      ),
      NuTori: () => (
        <>
          <p>
            nu-tori
            は食事で差を作るダイエットを手伝います。撮った食事や書いた食事のカロリーを、その日に記録した分だけ足して1日に食べた量とし、1日の目安と並べて見せます。
          </p>
          <p>
            1日の目安は、nu-tori
            が推定した、あなたの体が1日に使うカロリー（推定消費カロリー）より少なくします。どれだけ少なくするかは体重
            1 kg を 7,700 kcal とみなして決めます。たとえば、体重の傾向を1日に 0.1 kg
            ずつ減らすなら、推定消費カロリーより1日 770 kcal 少なく食べる計算です。
          </p>
        </>
      ),
    },
    {
      heading: "食べ物のカロリーは見た目では分かりにくい",
      Research: () => (
        <>
          <p>
            同じ重さでも、食べ物のカロリーは大きく違います。100 g あたりで比べると、おにぎりは{" "}
            {onigiriKcalPer100g} kcal、食パンは {breadKcalPer100g} kcal、クロワッサンは{" "}
            {croissantKcalPer100g} kcal です。ふんわり軽く見えるクロワッサンは、食パンの約{" "}
            {(croissantKcalPer100g / breadKcalPer100g).toFixed(1)} 倍、おにぎりの約{" "}
            {(croissantKcalPer100g / onigiriKcalPer100g).toFixed(1)} 倍です。
          </p>
          <Figure
            name="same-weight-different-kcal"
            alt="同じはかりに乗ったおにぎり、食パン、クロワッサン。上の炎は右ほど大きい"
          />
        </>
      ),
      NuTori: () => (
        <>
          <p>
            nu-tori
            は撮った食事の写真から料理と材料とその量を見積もり、材料ごとにカロリーを計算します。文部科学省の日本食品標準成分表にある材料は成分表の値を使い、栄養成分表示を撮ればその値を使います。見積もった量は、あとから直せます。
          </p>
        </>
      ),
    },
    {
      heading: "1日ぴったりでなくてよい",
      Research: () => (
        <>
          <p>
            体重の変化は、何日も何週間も、カロリーの差が積み重なって決まります。1日に多く食べても、体のたくわえから見ればわずかです。次の数日で控えれば、積み重ねはほとんど変わりません。1日の目安は、1週間の平均で近ければ十分です。
          </p>
          <Figure name="weekly-average" alt="高さの違う7本の棒と、その平均の高さを通る紫の点線" />
        </>
      ),
      NuTori: () => (
        <>
          <p>
            毎週月曜には、前の週（月曜から日曜）に食べた量の平均と体重の変わり方を見て、推定消費カロリーと1日の目安を見直します。平均には食事を記録した日だけを使い、1食だけ記録した日のような記録の途中の日は外します。体重
            1 kg を 7,700 kcal
            とみなす目安のずれも、この見直しで直します。運動を続けて使う量が増えれば、体重の変わり方に表れるので、この見直しで推定消費カロリーにも反映されます。1週間で見るので、ある日に目安を超えても、その週のほかの日で近づければ大丈夫です。
          </p>
        </>
      ),
    },
  ],
  sources: [
    {
      claim: "体重が、食べたカロリーと体が使ったカロリーの差で増減すること",
      citation:
        "Hall KD, Heymsfield SB, Kemnitz JW, et al. Energy balance and its components: implications for body weight regulation. Am J Clin Nutr. 2012;95(4):989-994.",
      url: "https://doi.org/10.3945/ajcn.112.036350",
      linkLabel: "doi:10.3945/ajcn.112.036350",
    },
    {
      claim: "体重 1 kg の増減を約 7,700 kcal とみなすこと",
      citation:
        "Wishnofsky M. Caloric equivalents of gained or lost weight. Am J Clin Nutr. 1958;6(5):542-546（1 ポンドを 3,500 kcal とする）。",
      url: "https://doi.org/10.1093/ajcn/6.5.542",
      linkLabel: "doi:10.1093/ajcn/6.5.542",
    },
    {
      claim: "この値は、長く続けると体の使うカロリーが変わってずれること",
      citation:
        "Hall KD. What is the required energy deficit per unit weight loss? Int J Obes. 2008;32(3):573-576.",
      url: "https://doi.org/10.1038/sj.ijo.0803720",
      linkLabel: "doi:10.1038/sj.ijo.0803720",
    },
    {
      claim: "体重の変化が、カロリーの差の積み重ねで決まること",
      citation:
        "Hall KD, Sacks G, Chandramohan D, et al. Quantification of the effect of energy imbalance on bodyweight. Lancet. 2011;378(9793):826-837.",
      url: "https://doi.org/10.1016/S0140-6736(11)60812-X",
      linkLabel: "doi:10.1016/S0140-6736(11)60812-X",
    },
    {
      claim: "食べ物のカロリー（100 g あたり）",
      citation:
        "文部科学省「日本食品標準成分表（八訂）増補2023年」（食品番号 01111 おにぎり、01026 角形食パン 食パン、01209 クロワッサン レギュラータイプ）。",
      url: "https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html",
      linkLabel: "文部科学省のページ",
    },
    {
      claim: `ジョギングが安静にしているときの約 ${joggingMets} 倍のカロリーを使うこと`,
      citation:
        "Herrmann SD, Willis EA, Ainsworth BE, et al. 2024 Adult Compendium of Physical Activities: a third update of the energy costs of human activities. J Sport Health Sci. 2024;13(1):6-12（コード 12020、7.5 METs）。運動で使うカロリーは、1 MET を体重 1 kg・1時間あたり 1 kcal とみなして nu-tori が計算しました。",
      url: "https://pacompendium.com/running/",
      linkLabel: "Compendium のランニングの表",
    },
  ],
  decidedByNuTori: [],
};

// 量の感覚の例の値。食品は日本食品標準成分表（八訂）増補2023年の可食部 100 g あたり
const croissantKcalPer100g = 406; // 01209 クロワッサン レギュラータイプ
const breadKcalPer100g = 248; // 01026 角形食パン 食パン
const onigiriKcalPer100g = 170; // 01111 おにぎり
const joggingHours = 0.5;
const bodyWeightKg = 60;
const kilocaloriesPerKilogram = 7700;

// 下の値がトップレベルで読むので先に置く
const roundToNearestFive = (value: number) => Math.round(value / 5) * 5;

// 1 MET を、体重 1 kg・1時間あたり 1 kcal とみなす。安静にしていても使う 1 MET の分を除いた、ジョギングで増える分
const joggingKcal = roundToNearestFive((joggingMets - 1) * bodyWeightKg * joggingHours);
const dailyDeficitKcal = 500;
// 本文の「2個半ほど」は、ジョギングの例の約 115 g を「だいたい1個分」とした数え方に合わせた
const onigiriGramsForDailyDeficit = roundToNearestFive(
  (dailyDeficitKcal / onigiriKcalPer100g) * 100,
);
const onigiriGramsForJogging = roundToNearestFive((joggingKcal / onigiriKcalPer100g) * 100);
const joggingSessionsPerKilogram = roundToNearestFive(kilocaloriesPerKilogram / joggingKcal);

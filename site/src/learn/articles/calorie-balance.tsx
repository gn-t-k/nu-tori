import type { LearnArticle } from "../learn-article";

// ジョギングの METs（2024 Adult Compendium のコード 12020）。出典の claim がトップレベルで読むので、calorieBalance より上に置く
const joggingMets = 7.5;

// 決まりの文は、書いたときのサーバーのドメイン層のコードに合わせた（server/src/domain/kilocalories-per-kilogram.ts、server/src/weekly-review/domain/compute-reviewed-expenditure/compute-reviewed-expenditure.ts、server/src/weekly-review/domain/judge-review-week/judge-review-week.ts）。サーバーで値や決まりを変えたら、同じ PR でここを直す
export const calorieBalance: LearnArticle = {
  slug: "calorie-balance",
  question: "摂取カロリーと消費カロリーで、体重はどう決まる？",
  description:
    "体重は、食べたカロリーと体が使ったカロリーの差で決まります。差は食べる量でも運動でも変わり、約 7,700 kcal で体重約 1 kg にあたること、1週間で合わせれば十分なことを、研究をもとに説明します。",
  Lead: () => (
    <>
      <p>
        ダイエットを始めると、食事を減らしたり、運動を始めたりします。でも、どれだけ続ければ体重がどれくらい変わるのかは、なかなか見えません。体重は何で決まるのでしょうか。
      </p>
      <p>
        答えは、食べたカロリーと体が使ったカロリーの差です。差は食べる量を減らしても、運動で使う量を増やしても広がります。差が約
        7,700 kcal たまるごとに、体重は約 1 kg
        変わります。そして、差は毎日ぴったりでなくても、1週間で合わせれば十分です。
      </p>
    </>
  ),
  Research: () => (
    <>
      <h3>体重はカロリーの差で決まる</h3>
      <p>
        食べたカロリー（摂取カロリー）が体が使ったカロリー（消費カロリー）より多いと、体重は増えます。少ないと、体重は減ります。多く食べた分は脂肪などとして体にたくわえられ、足りない分はそのたくわえから補われます。
      </p>
      <p>
        差を広げる方法は2つです。食べる量を減らすか、運動などで使う量を増やすかです。どちらで広げても、体重の変わり方は差の大きさで決まります。
      </p>
      <h3>差が約 7,700 kcal たまると体重は約 1 kg 変わる</h3>
      <p>
        体重 1 kg の増減は約 7,700 kcal の差にあたるとみなされています。たとえば、1日に 500 kcal
        の差を続けると、2週間で約 7,000 kcal。体重にして 1 kg 弱です。
      </p>
      <p>
        ただし、これは始めのうちの目安です。体重が減ると、体が使うカロリーも減ります。そのため、同じ量を食べ続けると、体重の減り方はだんだん遅くなります。
      </p>
      <h3>同じ重さでもカロリーは大きく違う</h3>
      <p>
        100 g あたりで比べると、おにぎりは {onigiriKcalPer100g} kcal、食パンは {breadKcalPer100g}{" "}
        kcal、クロワッサンは {croissantKcalPer100g} kcal
        です。ふんわり軽く見えるクロワッサンは、食パンの約{" "}
        {(croissantKcalPer100g / breadKcalPer100g).toFixed(1)} 倍、おにぎりの約{" "}
        {(croissantKcalPer100g / onigiriKcalPer100g).toFixed(1)} 倍です。
      </p>
      <h3>30分のジョギングで使うのはおにぎり1個分ほど</h3>
      <p>
        ジョギングは、安静にしているときの約 {joggingMets} 倍のカロリーを使います。体重 {lighterKg}{" "}
        kg の人が30分走ると、安静にしていても使う分のほかに約 {joggingKcal(lighterKg)}{" "}
        kcal。おにぎりにすると約 {onigiriGramsFor(joggingKcal(lighterKg))}{" "}
        g、だいたい1個分です。体重 {heavierKg} kg の人でも約 {joggingKcal(heavierKg)} kcal です。
      </p>
      <h3>1日ぴったりでなくてよい</h3>
      <p>
        体重の変化は、何日も何週間も、カロリーの差が積み重なって決まります。1日に多く食べても、体のたくわえから見ればわずかです。次の数日で控えれば、積み重ねはほとんど変わりません。1日の目安は、1週間の平均で近ければ十分です。
      </p>
    </>
  ),
  NuTori: () => (
    <>
      <p>
        nu-tori
        はこの考え方のとおりに作っています。撮った食事や書いた食事のカロリーを1日ごとに足し、1日の目安と並べて見せます。
      </p>
      <p>
        1日の目安は、あなたの体が1日に使うカロリー（推定消費カロリー）より少なくします。推定消費カロリーは、nu-tori
        が推定します。
      </p>
      <p>
        毎週月曜には、前の週に食べた量の平均と体重の変わり方を見て、推定消費カロリーと1日の目安を見直します。運動を続けて使う量が増えれば、体重の変わり方に表れるので、この見直しで推定消費カロリーにも反映されます。1週間で見るので、ある日に目安を超えても、その週のほかの日で近づければ大丈夫です。
      </p>
    </>
  ),
  Rules: () => (
    <ul>
      <li>
        nu-tori は体重 1 kg の増減を 7,700 kcal とみなします。たとえば、体重の傾向を1日に 0.1 kg
        ずつ減らすには、推定消費カロリーより1日 770 kcal 少なく食べる計算です
      </li>
      <li>1日に食べた量は、その日に記録した食事のカロリーの合計です</li>
      <li>
        毎週月曜の見直しでは、前の週（月曜から日曜）のうち食事を記録した日の、食べた量の平均を使います。1食だけ記録した日のような、記録の途中の日は外します。体重
        1 kg の増減を 7,700 kcal とみなす目安のずれは、この見直しで直します
      </li>
    </ul>
  ),
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
const [lighterKg, heavierKg] = [60, 80] as const;

// 1 MET を、体重 1 kg・1時間あたり 1 kcal とみなす。安静にしていても使う 1 MET の分を除いた、ジョギングで増える分
const joggingKcal = (bodyWeightKg: number) =>
  roundToNearestFive((joggingMets - 1) * bodyWeightKg * joggingHours);

const onigiriGramsFor = (kcal: number) => roundToNearestFive((kcal / onigiriKcalPer100g) * 100);

const roundToNearestFive = (value: number) => Math.round(value / 5) * 5;

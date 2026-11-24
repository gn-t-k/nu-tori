import type { LearnArticle } from "../learn-article";

// ジョギングの METs（2024 Adult Compendium のコード 12020）。出典の claim がトップレベルで読むので、calorieBalance より上に置く
const joggingMets = 7.5;

// 決まりの文は、書いたときのサーバーのドメイン層のコードに合わせた（server/src/domain/kilocalories-per-kilogram.ts、server/src/weekly-review/domain/compute-reviewed-expenditure/compute-reviewed-expenditure.ts、server/src/weekly-review/domain/judge-review-week/judge-review-week.ts）。サーバーで値や決まりを変えたら、同じ PR でここを直す
export const calorieBalance: LearnArticle = {
  slug: "calorie-balance",
  question: "摂取カロリーと消費カロリーで、体重はどう決まる？",
  description:
    "体重は、食べたカロリーと体が使ったカロリーの差で増減します。体重 1 kg が約 7,700 kcal にあたることと、量の感覚をつかむ例を、研究をもとに説明します。",
  Research: () => (
    <>
      <p>
        体重は、食べたカロリー（摂取カロリー）と、体が使ったカロリー（消費カロリー）の差で増えたり減ったりします。使うより多く食べた分は、体に脂肪などとしてたくわえられ、使うより少ない分は、たくわえから補われます。
      </p>
      <h3>何を食べるかより、どれだけ食べるか</h3>
      <p>
        脂質・たんぱく質・炭水化物の割合が違う4つの食事を、800
        人あまりで2年間比べた研究では、どの食事もカロリーを減らしていれば、体重の減り方はほとんど変わりませんでした。脂質を減らす食事と炭水化物を減らす食事を、600
        人あまりで1年間比べた研究でも、体重の減り方に差は見られませんでした。体重を変えたいときにまず効くのは、食べる物の種類より、食べる量です。
      </p>
      <h3>体重 1 kg は、約 7,700 kcal</h3>
      <p>
        体重 1 ポンド（約 0.45 kg）の増減を 3,500 kcal とみなす目安が、昔から使われてきました。1 kg
        にすると約 7,700 kcal です。1日に 500 kcal ずつ少なく食べると、2週間ほどで 7,000
        kcal、体重にして 1 kg 弱にあたります。
      </p>
      <p>
        ただし、これは始めのうちの目安です。体重が減ると、体が使うカロリーも減っていくので、同じ量を食べ続けても、体重の減り方はだんだん遅くなります。
      </p>
      <h3>量の感覚をつかむ</h3>
      <p>
        同じ重さでも、食べ物のカロリーは大きく違います。100 g あたりで比べると、おにぎりは{" "}
        {onigiriKcalPer100g} kcal、食パンは {breadKcalPer100g} kcal、クロワッサンは{" "}
        {croissantKcalPer100g} kcal です。ふんわり軽く見えるクロワッサンは、同じ重さの食パンの約{" "}
        {(croissantKcalPer100g / breadKcalPer100g).toFixed(1)} 倍、おにぎりの約{" "}
        {(croissantKcalPer100g / onigiriKcalPer100g).toFixed(1)} 倍のカロリーがあります。
      </p>
      <p>
        運動で使うカロリーは、体重で変わります。ジョギングは、安静にしているときの約 {joggingMets}{" "}
        倍のカロリーを使う運動です。体重 {lighterKg} kg
        の人が30分ジョギングすると、安静にしていても使う分のほかに、約 {joggingKcal(lighterKg)} kcal
        を使います。おにぎりにすると約 {onigiriGramsFor(joggingKcal(lighterKg))}{" "}
        g、だいたい1個分です。体重 {heavierKg} kg の人なら、同じ30分で約 {joggingKcal(heavierKg)}{" "}
        kcal です。
      </p>
      <h3>1日ぴったりでなくてよい</h3>
      <p>
        体重の変化は、何日、何週間ものカロリーの差が積み重なって決まります。1日に多く食べても、体のたくわえから見ればわずかで、次の日からの数日で控えれば、積み重ねはほとんど変わりません。1日の目安は、毎日ぴったり合わせなくても、1週間の平均で近ければ十分です。
      </p>
    </>
  ),
  NuTori: () => (
    <>
      <p>
        nu-tori
        は、何を食べたかの良し悪しを言わず、どれだけ食べたかを数えます。撮った食事や書いた食事のカロリーを1日ごとに足し、1日の目安と並べて見せます。
      </p>
      <p>
        1日の目安は、nu-tori
        が推定した、あなたの体が1日に使うカロリー（推定消費カロリー）をもとに出します。体重を減らす目標なら、推定消費カロリーより少なく、増やす目標なら多くします。
      </p>
      <p>
        nu-tori
        は毎週月曜に、前の週に食べた量の平均と体重の変わり方を見て、推定消費カロリーと1日の目安を見直します。1日1日でなく1週間で見るので、ある日に目安を超えても、その週のほかの日で近づければ大丈夫です。
      </p>
    </>
  ),
  Rules: () => (
    <ul>
      <li>
        nu-tori は、体重 1 kg の増減を 7,700 kcal とみなします。たとえば、体重の傾向を1日に 0.1 kg
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
      claim: "割合の違う食事でも、カロリーを減らせば体重の減り方がほとんど変わらないこと",
      citation:
        "Sacks FM, Bray GA, Carey VJ, et al. Comparison of weight-loss diets with different compositions of fat, protein, and carbohydrates. N Engl J Med. 2009;360(9):859-873（811 人、2年）。",
      url: "https://doi.org/10.1056/NEJMoa0804748",
      linkLabel: "doi:10.1056/NEJMoa0804748",
    },
    {
      claim: "脂質を減らす食事と炭水化物を減らす食事で、体重の減り方に差が見られなかったこと",
      citation:
        "Gardner CD, Trepanowski JF, Del Gobbo LC, et al. Effect of low-fat vs low-carbohydrate diet on 12-month weight loss in overweight adults and the association with genotype pattern or insulin secretion: the DIETFITS randomized clinical trial. JAMA. 2018;319(7):667-679（609 人、1年）。",
      url: "https://doi.org/10.1001/jama.2018.0245",
      linkLabel: "doi:10.1001/jama.2018.0245",
    },
    {
      claim: "体重 1 kg の増減を 7,700 kcal とみなすこと",
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
  decidedByNuTori: ["食べた量を、毎週の見直しで1週間の平均で見ること"],
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

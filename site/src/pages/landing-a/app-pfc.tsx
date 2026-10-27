// アプリの P・F・C の行。名前の前に色の四角を置き、色だけで示さない（DESIGN.md の nutrient-key）。
// replacedByScript を渡すと、値の span に目印を付け、public/landing-a.js がそこの文を入れ替える
export const AppPfc = ({
  protein,
  fat,
  carbohydrate,
  replacedByScript,
}: {
  protein: string;
  fat: string;
  carbohydrate: string;
  replacedByScript: boolean;
}) => (
  <p class="app-pfc">
    <span>
      <span class="app-key app-key-protein" />P{" "}
      <span data-review-protein={replacedByScript ? "" : undefined}>{protein}</span>
    </span>
    <span>
      <span class="app-key app-key-fat" />F{" "}
      <span data-review-fat={replacedByScript ? "" : undefined}>{fat}</span>
    </span>
    <span>
      <span class="app-key app-key-carbohydrate" />C{" "}
      <span data-review-carbohydrate={replacedByScript ? "" : undefined}>{carbohydrate}</span>
    </span>
  </p>
);

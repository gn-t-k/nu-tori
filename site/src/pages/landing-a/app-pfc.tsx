// アプリの P・F・C の行。名前の前に色の四角を置き、色だけで示さない（DESIGN.md の nutrient-key）
export const AppPfc = ({
  protein,
  fat,
  carbohydrate,
}: {
  protein: string;
  fat: string;
  carbohydrate: string;
}) => (
  <p class="app-pfc">
    <span>
      <span class="app-key app-key-protein" />P {protein}
    </span>
    <span>
      <span class="app-key app-key-fat" />F {fat}
    </span>
    <span>
      <span class="app-key app-key-carbohydrate" />C {carbohydrate}
    </span>
  </p>
);

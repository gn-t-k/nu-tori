// テストの実行環境だけが渡す（vitest.config.ts）。本番には無く、振り分けの Worker は Math.random を使う
interface Env {
  // 版を選ぶ乱数（0 以上 1 未満）を決めた値にする。Worker の中の Math.random は vi.spyOn で差し替えられないため
  LP_VARIANT_DRAW?: number;
}

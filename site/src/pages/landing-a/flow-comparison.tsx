// よくある流れと nu-tori の流れを、同じ形で縦に並べて「食べる」の位置の違いを見せる。
// 横に並べると携帯の幅で矢印が折り返して読みにくかった（#594 の申し送り）ので、手順を縦に積み、2つの流れを左右に置く
export const FlowComparison = () => (
  <div class="lp-flows">
    <Flow name="よくある流れ" steps={["撮る", "待つ", "候補を選ぶ", "確定する", "食べる"]} />
    <Flow name="nu-tori" steps={["撮る", "食べる", "あとで見る・直す"]} />
  </div>
);

const Flow = ({ name, steps }: { name: string; steps: readonly string[] }) => (
  <div class="lp-flow">
    <p class="lp-flow-name">{name}</p>
    <ol>
      {steps.map((step) => (
        <li class={step === "食べる" ? "lp-flow-eat" : undefined}>{step}</li>
      ))}
    </ol>
  </div>
);

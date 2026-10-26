// 図の SVG の座標。値の幅を図の幅に写す
export const chartGeometry = {
  scale:
    (domainStart: number, domainEnd: number, rangeStart: number, rangeEnd: number) =>
    (value: number) =>
      rangeStart + ((value - domainStart) / (domainEnd - domainStart)) * (rangeEnd - rangeStart),
  // 軸の幅は今の例の数字に合わせて決めているので、例を書き出し直して外れたら、図がはみ出す前に止める
  assertWithin: (figure: string, values: readonly number[], low: number, high: number) => {
    if (values.some((value) => value < low || value > high)) {
      throw new Error(`${figure}の値が、軸の幅（${low}〜${high}）から外れた`);
    }
  },
  path: (points: readonly (readonly [number, number])[]) =>
    points.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x.toFixed(1)} ${y.toFixed(1)}`).join(" "),
};

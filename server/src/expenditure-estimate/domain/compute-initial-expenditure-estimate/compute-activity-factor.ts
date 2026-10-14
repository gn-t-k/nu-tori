import { match } from "ts-pattern";
import type { BodyData } from "../body-data";

// 歩数は初期値の窓の中の日だけを受け取る。歩いた日が1日も無ければ undefined。
// 0 歩の日は、端末を持たなかった日とみなして平均から除く
export const computeActivityFactor = (activity: BodyData["activity"]): number | undefined =>
  match(activity)
    .with({ type: "level" }, ({ level }) =>
      match(level)
        .with("sedentary", () => factors.low)
        .with("standing", () => factors.middle)
        .with("active", () => factors.high)
        .exhaustive(),
    )
    .with({ type: "steps" }, ({ dailySteps }) => {
      const walkedDays = dailySteps.filter(({ steps }) => 0 < steps);
      if (walkedDays.length === 0) {
        return undefined;
      }
      const averageSteps =
        walkedDays.reduce((sum, { steps }) => sum + steps, 0) / walkedDays.length;
      if (averageSteps < 5000) {
        return factors.low;
      }
      return averageSteps < 10_000 ? factors.middle : factors.high;
    })
    .exhaustive();

const factors = { low: 1.4, middle: 1.55, high: 1.7 };

import type Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { z } from "zod";
import type {
  DayOfWeek,
  EstimationProvider,
  EstimationProviderReply,
  IdentifiedWrittenMeals,
  WrittenMealsRequest,
} from "../../domain/estimation-provider";
import {
  foodCompositionQuerySection,
  identifiedDishSchema,
  toIdentifiedDishes,
} from "./identify-dishes";
import { requestStructuredOutput } from "./request-structured-output";

// 文章の食事の ①: 送った文章から、時刻の違う食事ごとに、食べた日時と料理と材料と量を読み取る（#419 の「文章の食事」）。
// 送った日時と曜日を渡し、食べた日時を LLM に決めさせる。目安の時刻は指示に書かない。範囲はドメイン層が確かめる
export const identifyWrittenMeals = async (
  client: Anthropic,
  userId: string,
  request: WrittenMealsRequest,
  signal: AbortSignal,
): R.ResultAsync<
  EstimationProviderReply<IdentifiedWrittenMeals>,
  R.InferFailure<EstimationProvider["identifyWrittenMeals"]>
> => {
  // 写真の ① と同じ長さにし、試み全体の上限（3 分）に、② の上限と合わせて収まるようにする
  const timeLimitMs = 90_000;
  const requested = await requestStructuredOutput(
    client,
    {
      system,
      content: [{ type: "text", text: toInstruction(request) }],
      schema: identifiedWrittenMealsSchema,
      userId,
      timeLimitMs,
    },
    signal,
  );
  return R.pipe(
    requested,
    R.map(({ output, usage }) => ({
      output: {
        meals: output.meals.map(({ eatenAt, dishes }) => ({
          eatenAt,
          dishes: toIdentifiedDishes({ dishes }).dishes,
        })),
      },
      usage,
    })),
  );
};

const toInstruction = ({ body, sentAt }: WrittenMealsRequest): string =>
  [
    `送った日時: ${sentAt.localDateTime.replace("T", " ")}（${dayOfWeekNames[sentAt.dayOfWeek]}）`,
    "送った文章:",
    body,
  ].join("\n");

const dayOfWeekNames: Readonly<Record<DayOfWeek, string>> = {
  sunday: "日曜日",
  monday: "月曜日",
  tuesday: "火曜日",
  wednesday: "水曜日",
  thursday: "木曜日",
  friday: "金曜日",
  saturday: "土曜日",
};

const identifiedWrittenMealsSchema = z.object({
  meals: z.array(z.object({ eatenAt: z.string(), dishes: z.array(identifiedDishSchema) })),
});

const system = `あなたは、使う人が食べたものを書いた文章から、栄養を計算するための食事と料理と材料の一覧を作る。文章と一緒に、文章を送った日時と曜日が渡る。

## 食事と日時
- 食べた時刻の違う食事を、別の食事として答える（「朝はパン、昼はうどん」なら2つ）。同じときに食べたものは1つの食事にまとめる。
- 食事ごとに、食べた日時を、送った日時と同じ書き方（YYYY-MM-DDTHH:mm）で答える。「昨日」「今朝」などは送った日時を基準に考える。
- 文章から食べた日時が分からないときは、送った日時にする。

## 料理と材料
- 料理ごとに、名前・量・単位を答える。単位はその料理を数える自然なもの（杯、皿、個、本、枚など）にする。
- 料理ごとに、材料を1つ以上答える。書かれた材料に加え、その料理に一般的に使う材料や油や調味料も、無理なく推定できる範囲で含める。
- 材料ごとに、名前・量・単位・1単位あたりの可食部の g を答える。単位が g なら 1、ml なら水に近いものは 1 とし、個・枚・本などは 1 つの可食部のおよその g にする。皮・骨・殻のように食べない部分は含めない。
- 量は、書かれていればその量、書かれていなければ一般的な1人前を見積もる。

${foodCompositionQuerySection}

## 栄養成分表示（nutritionLabel）
- 文章からは読まないので、いつも null にする。

## 食べたものが無いとき
- 食べたものが書かれていない、または見分けられないときは、meals を空にする。理由は答えない。`;

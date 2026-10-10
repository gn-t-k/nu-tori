import { z } from "zod";

// promptfoo の javascript の assertion。返事の本文の長さと、指し示す食事（提供元が metadata.mealIds に返す）を確かめる。
// 字数は判定役の Claude より数えるほうが確かなので、コードで見る
export type ReplyShapeConfig = {
  // 本文の字数の上限。指示の目安（300 字）に、箇条書きの記号などの揺れを見込んだ値
  maxLength: number;
  // 文脈で ID を付けた食事（listReferableMealIds）。本番はほかを指すと読めない応答にしてやり直す
  referableMealIds: readonly string[];
  // 返事で指し示してほしい食事（記録を直してほしい場面だけ）
  expectedMealIds: readonly string[];
};

export const judgeReplyShape = (
  output: string,
  context: { config: ReplyShapeConfig; metadata: unknown },
): { pass: boolean; score: 0 | 1; reason: string } => {
  const { maxLength, referableMealIds, expectedMealIds } = context.config;
  const metadata = metadataSchema.safeParse(context.metadata);
  if (!metadata.success) {
    throw new Error("返事の提供元が metadata.mealIds を返していない");
  }
  const { mealIds } = metadata.data;
  // 送った文章の受け付ける長さと同じく、コードポイントで数える
  const length = Array.from(output).length;
  const unreferable = mealIds.filter((mealId) => !referableMealIds.includes(mealId));
  const missing = expectedMealIds.filter((mealId) => !mealIds.includes(mealId));
  const failures = [
    ...(length > maxLength ? [`${length} 字（上限 ${maxLength} 字）`] : []),
    ...(unreferable.length > 0
      ? [`文脈で ID を付けていない食事を指し示した: ${unreferable.join("、")}`]
      : []),
    ...(missing.length > 0
      ? [`指し示してほしい食事を指し示していない: ${missing.join("、")}`]
      : []),
  ];
  return failures.length === 0
    ? { pass: true, score: 1, reason: `${length} 字、指し示す食事 ${mealIds.length} 件` }
    : { pass: false, score: 0, reason: failures.join("。") };
};

// 返事の提供元（sonnet-reply-provider.ts）が返す metadata。無ければ提供元の設定の誤りなので投げる
const metadataSchema = z.object({ mealIds: z.array(z.string()) });

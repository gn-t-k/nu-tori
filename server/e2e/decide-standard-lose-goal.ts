import { z } from "zod";
import type { DeviceSession } from "./device-client";
import { generateRecordId } from "../src/domain/record-id";
import { goalDecisionSchema } from "../src/http/goal-setup-routes/goal-decision-schema";
import { goalProposalsSchema } from "../src/http/goal-setup-routes/goal-proposals-schema";
import { sampleBodyData } from "./sample-body-data";

// 減量の標準の案を、目標案で見せていた値のとおりに決める。端末が目標案から目標を決めるのと同じ順で送る。
// 使い始めたばかりで食べた量の記録が無い人として、身体データを添えて式で出す。
// 目標の設定の要求は decidedAt に送ったことにする（開発用の環境だけで効く時刻の差し替え）ので、開始の日は decidedAt の日になる。
// 受け取った目標案と、決めた要求（再送を確かめるため）と、その応答の本文と読んだ形を返す
export const decideStandardLoseGoal = async (
  session: DeviceSession,
  { decidedAt, deadlineOn }: { decidedAt: Date; deadlineOn: string },
): Promise<{
  proposals: z.infer<typeof goalProposalsSchema>;
  decisionRequest: Record<string, unknown>;
  // 応答の本文そのまま。再送の応答が本文ごと同じかを比べるのに使う（読んだ形は知らない欄を落とすので、比べには使わない）
  decision: unknown;
  decided: Extract<z.infer<typeof goalDecisionSchema>, { status: "decided" }>;
}> => {
  const proposals = goalProposalsSchema.parse(
    await session.postGoalSetup(
      "proposals",
      { plan: { direction: "lose", deadlineOn }, bodyData: sampleBodyData },
      decidedAt,
    ),
  );
  if (proposals.direction !== "lose") {
    throw new Error(`減量の目標案を求めたのに、${proposals.direction} の目標案が返った`);
  }
  const standard = proposals.proposals.find(({ pace }) => pace === "standard");
  if (standard?.status !== "offered") {
    throw new Error(`目標案に、出せる標準の案が無い（${standard?.status ?? "枠が無い"}）`);
  }
  const decisionRequest = {
    requestId: generateRecordId(),
    startedOn: proposals.startedOn,
    choice: {
      type: "proposal",
      direction: "lose",
      deadlineOn: proposals.deadlineOn,
      pace: "standard",
    },
    shown: { targetWeightKg: standard.targetWeightKg, dailyGuide: standard.dailyGuide },
    rejectedCustomTargetWeightCount: 0,
    bodyData: sampleBodyData,
  };
  const decision = await session.postGoalSetup("decisions", decisionRequest, decidedAt);
  const decided = goalDecisionSchema.parse(decision);
  if (decided.status !== "decided") {
    throw new Error(`目標が決まらず、${decided.status} が返った`);
  }
  return { proposals, decisionRequest, decision, decided };
};

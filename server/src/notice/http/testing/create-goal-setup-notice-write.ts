import { generateRecordId } from "../../../domain/record-id";

// 目標を立てる知らせを作る書き込み。対象の日付を持たない
export const createGoalSetupNoticeWrite = (
  overrides: { id?: string; notice?: Record<string, unknown> } = {},
): { id: string; type: "create_notice"; notice: Record<string, unknown> } => ({
  id: overrides.id ?? generateRecordId(),
  type: "create_notice",
  notice: {
    id: generateRecordId(),
    noticeType: "goal_setup",
    issuedAt: 1_767_225_600_000,
    timeZone: "Asia/Tokyo",
    ...overrides.notice,
  },
});

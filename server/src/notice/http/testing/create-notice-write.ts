export const createNoticeWrite = (
  overrides: { id?: string; notice?: Record<string, unknown> } = {},
): { id: string; type: "create_notice"; notice: Record<string, unknown> } => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "create_notice",
  notice: {
    id: crypto.randomUUID(),
    noticeType: "missed_weight_record",
    issuedAt: 1_767_225_600_000,
    timeZone: "Asia/Tokyo",
    targetOn: "2026-01-01",
    ...overrides.notice,
  },
});

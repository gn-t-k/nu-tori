export const respondNoticeWrite = (
  noticeId: string,
  overrides: { id?: string; response?: Record<string, unknown> } = {},
): { id: string; type: "respond_notice"; noticeId: string; response: Record<string, unknown> } => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "respond_notice",
  noticeId,
  response: {
    respondedAt: 1_767_229_200_000,
    timeZone: "Asia/Tokyo",
    ...overrides.response,
  },
});

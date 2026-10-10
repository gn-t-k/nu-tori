import { generateRecordId } from "../../../domain/record-id";

export const createSentTextWrite = (
  overrides: { id?: string; sentText?: Record<string, unknown> } = {},
): { id: string; type: "create_sent_text"; sentText: Record<string, unknown> } => ({
  id: overrides.id ?? generateRecordId(),
  type: "create_sent_text",
  sentText: {
    id: generateRecordId(),
    body: "昼に親子丼を食べた",
    sentAt: Date.now(),
    timeZone: "Asia/Tokyo",
    ...overrides.sentText,
  },
});

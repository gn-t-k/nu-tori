import { generateRecordId } from "../../../domain/record-id";

export const createSyncClientState = (
  overrides: Record<string, unknown> = {},
): Record<string, unknown> => ({
  deviceId,
  timeZone: "Asia/Tokyo",
  appVersion: "1.0.0",
  osVersion: "26.0",
  pendingWriteCount: 1,
  oldestPendingWriteAgeSeconds: 30,
  pendingPhotoCount: 0,
  ...overrides,
});

// 呼ぶたびに同じ端末として送るよう、ID はモジュールで1つだけ振る
const deviceId = generateRecordId();

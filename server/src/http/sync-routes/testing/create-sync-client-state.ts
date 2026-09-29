export const createSyncClientState = (
  overrides: Record<string, unknown> = {},
): Record<string, unknown> => ({
  deviceId: "device-1",
  timeZone: "Asia/Tokyo",
  appVersion: "1.0.0",
  osVersion: "26.0",
  pendingWriteCount: 1,
  oldestPendingWriteAgeSeconds: 30,
  pendingPhotoCount: 0,
  ...overrides,
});

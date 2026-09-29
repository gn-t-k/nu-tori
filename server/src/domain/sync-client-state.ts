export type SyncClientState = {
  deviceId: string;
  timeZone: string;
  appVersion: string;
  osVersion: string;
  pendingWriteCount: number;
  // 送り待ちが無いときは undefined
  oldestPendingWriteAgeSeconds: number | undefined;
  pendingPhotoCount: number;
};

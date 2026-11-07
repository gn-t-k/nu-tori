import { z } from "zod";
import { e2eRequestHeaders } from "../src/http/e2e-access";

// 端末と同じ形で Worker の API を呼ぶ。主な流れ（run-main-flow.ts）と、手元で確かめる道具（cli/drive-device.ts）が使う。
// 1つのクライアントを1台の端末として送り（deviceId が同じ）、セッションはサインインで作るか、残したトークンから戻す
export type DeviceClient = {
  // 端末の状態として送るタイムゾーン
  timeZone: string;
  // 確かめの口でサインインし、新しいアカウントを作る。signedInAt を渡すと、その時刻にサインインしたことにする（使い始めた日がその日になる）
  signIn: (signedInAt?: Date) => Promise<DeviceSession>;
  resume: (saved: SavedSession) => DeviceSession;
};

export type DeviceConnection = {
  baseUrl: string;
  // 確かめの口（/v1/e2e/*）と、開発用だけの時刻の差し替えに付ける秘密の値
  signInSecret: string;
  send: (url: string, init: RequestInit) => Promise<Response>;
  deviceId: string;
};

export type DeviceSession = SavedSession & {
  // API を1回呼ぶ。e2e を渡すと確かめの秘密の値を付け、requestedAt があればその時刻に送ったことにする（目標の設定の要求が読む）
  call: (
    method: string,
    path: string,
    init?: {
      headers?: Record<string, string>;
      body?: BodyInit;
      signal?: AbortSignal;
      e2e?: { requestedAt?: Date };
    },
  ) => Promise<Response>;
  // 書き込みを送り、書き込みごとの結果を返す。受け付けられなかった書き込みでは投げない（呼ぶ側が結果を読む）
  pushWrites: (writes: Write[]) => Promise<z.infer<typeof writeResultsSchema>["results"]>;
  pullChanges: (afterSequence: number) => Promise<z.infer<typeof changesPageSchema>>;
  // hasMore が false になるまで取りに行き、変更を受け取った順に並べて返す
  pullAllChanges: (afterSequence?: number) => Promise<Change[]>;
  deleteAccount: () => Promise<void>;
  // 取りに行く要求を1回送り、状態コードを返す。アカウントを削除したあとは 401
  probeSessionStatusCode: () => Promise<number>;
};

export type SavedSession = z.infer<typeof savedSessionSchema>;

// サインインの応答と、手元に残したセッションの形
export const savedSessionSchema = z.object({ sessionToken: z.string(), accountId: z.string() });

export type Change = z.infer<typeof changesPageSchema>["changes"][number];

export type Write = { id: string; type: string; [field: string]: unknown };

export const createDeviceClient = (connection: DeviceConnection): DeviceClient => {
  const timeZone = "Asia/Tokyo";
  const clientState = {
    deviceId: connection.deviceId,
    timeZone,
    appVersion: "1.0.0",
    osVersion: "26.0",
    pendingWriteCount: 1,
    oldestPendingWriteAgeSeconds: 0,
    pendingPhotoCount: 0,
  };
  const syncChangesPath = (afterSequence: number): string =>
    `/v1/sync/changes?${new URLSearchParams(
      Object.entries({ ...clientState, afterSequence }).map(([key, value]) => [key, String(value)]),
    ).toString()}`;

  const resume = ({ sessionToken, accountId }: SavedSession): DeviceSession => {
    const call: DeviceSession["call"] = (method, path, init = {}) =>
      connection.send(`${connection.baseUrl}${path}`, {
        method,
        headers: {
          ...init.headers,
          ...(init.e2e === undefined
            ? {}
            : {
                [e2eRequestHeaders.signInSecret]: connection.signInSecret,
                ...(init.e2e.requestedAt === undefined
                  ? {}
                  : { [e2eRequestHeaders.requestedAt]: init.e2e.requestedAt.toISOString() }),
              }),
          authorization: `Bearer ${sessionToken}`,
        },
        ...(init.body === undefined ? {} : { body: init.body }),
        ...(init.signal === undefined ? {} : { signal: init.signal }),
      });

    const pullChanges: DeviceSession["pullChanges"] = async (afterSequence) => {
      const response = await call("GET", syncChangesPath(afterSequence));
      if (response.status !== 200) {
        throw new Error(`変更を取りに行けなかった（状態コード ${response.status}）`);
      }
      return changesPageSchema.parse(await response.json());
    };

    return {
      sessionToken,
      accountId,
      call,
      pushWrites: async (writes) => {
        const response = await call("POST", "/v1/sync/writes", {
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ clientState, writes, isFinalBatch: false }),
        });
        if (response.status !== 200) {
          throw new Error(`書き込みを送れなかった（状態コード ${response.status}）`);
        }
        return writeResultsSchema.parse(await response.json()).results;
      },
      pullChanges,
      pullAllChanges: async (afterSequence = 0) => {
        const changes: Change[] = [];
        let after = afterSequence;
        for (;;) {
          const pulled = await pullChanges(after);
          changes.push(...pulled.changes);
          after = pulled.nextAfterSequence;
          if (!pulled.hasMore) {
            return changes;
          }
        }
      },
      deleteAccount: async () => {
        const response = await call("DELETE", "/v1/account");
        if (response.status !== 204) {
          throw new Error(`アカウントを削除できなかった（状態コード ${response.status}）`);
        }
      },
      probeSessionStatusCode: async () => (await call("GET", syncChangesPath(0))).status,
    };
  };

  return {
    timeZone,
    resume,
    signIn: async (signedInAt) => {
      const response = await connection.send(`${connection.baseUrl}/v1/e2e/sessions`, {
        method: "POST",
        headers: {
          [e2eRequestHeaders.signInSecret]: connection.signInSecret,
          ...(signedInAt === undefined
            ? {}
            : { [e2eRequestHeaders.requestedAt]: signedInAt.toISOString() }),
        },
      });
      if (response.status === 404) {
        throw new Error("サインインの口が閉じている（Worker に E2E_SIGN_IN_SECRET を置く）");
      }
      if (response.status === 401) {
        throw new Error(
          "サインインの秘密の値が合わない（呼ぶ側と Worker の E2E_SIGN_IN_SECRET を同じにする）",
        );
      }
      if (response.status !== 201) {
        throw new Error(`サインインできなかった（状態コード ${response.status}）`);
      }
      return resume(savedSessionSchema.parse(await response.json()));
    },
  };
};

const changesPageSchema = z.object({
  changes: z.array(
    z.object({
      sequence: z.number(),
      kind: z.string(),
      recordId: z.string(),
      record: z.record(z.string(), z.unknown()),
    }),
  ),
  hasMore: z.boolean(),
  nextAfterSequence: z.number(),
});

const writeResultsSchema = z.object({
  results: z.array(z.object({ result: z.string(), rejectionReason: z.string().optional() })),
});

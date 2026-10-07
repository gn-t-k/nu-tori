import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import {
  mockRevokeAppleRefreshTokenError,
  mockRevokeAppleRefreshTokenOk,
} from "../../auth/revoke-apple-refresh-token/revoke-apple-refresh-token.mock";
import { RevokeAppleRefreshTokenError } from "../../auth/revoke-apple-refresh-token";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import {
  mockPhotosBucketDeleteError,
  mockPhotosBucketListPageSize,
} from "../../meal/durable-object/testing/photos-bucket.mock";
import { mockCaptureExceptionOk } from "../../observability/capture-exception.mock";
import { mockDeletePostHogPersonOk } from "../../observability/delete-posthog-person/delete-posthog-person.mock";
import { app } from "../app";
import { signInTestAccount } from "../testing";

describe("アカウントの削除", () => {
  describe("記録のあるアカウントでサインインしているとき", () => {
    let signedIn: { accountId: string; sessionToken: string };
    let revokeSpy: ReturnType<typeof mockRevokeAppleRefreshTokenOk>;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk({ refreshToken: "apple-refresh-token" });
      revokeSpy = mockRevokeAppleRefreshTokenOk();
      signedIn = await signInTestAccount(generateRecordId());
      await runInDurableObject(getAccountDurableObject(env, signedIn.accountId), (_, state) => {
        state.storage.sql.exec("CREATE TABLE deletion_check_records (id TEXT PRIMARY KEY)");
      });
    });

    test("Apple の refresh token を取り消すこと", async () => {
      await deleteSignedInAccount(signedIn.sessionToken, env);
      expect(revokeSpy).toHaveBeenCalledWith(expect.anything(), "apple-refresh-token");
    });

    test("記録を消すこと", async () => {
      await deleteSignedInAccount(signedIn.sessionToken, env);
      const tables = await runInDurableObject(
        getAccountDurableObject(env, signedIn.accountId),
        (_, state) =>
          state.storage.sql
            .exec("SELECT name FROM sqlite_master WHERE name = 'deletion_check_records'")
            .toArray(),
      );
      expect(tables).toEqual([]);
    });

    test("アカウントと Apple の refresh token の行を消すこと", async () => {
      await deleteSignedInAccount(signedIn.sessionToken, env);
      const rows = await env.DB.prepare(
        `SELECT
           (SELECT COUNT(*) FROM "user" WHERE "id" = ?1) AS users,
           (SELECT COUNT(*) FROM apple_refresh_tokens WHERE account_id = ?1) AS appleRefreshTokens`,
      )
        .bind(signedIn.accountId)
        .first();
      expect(rows).toEqual({ users: 0, appleRefreshTokens: 0 });
    });

    describe("消したあと", () => {
      beforeEach(async () => {
        await deleteSignedInAccount(signedIn.sessionToken, env);
      });

      test("セッションを受け付けないこと", async () => {
        const response = await deleteSignedInAccount(signedIn.sessionToken, env);
        expect(response.status).toBe(401);
      });
    });
  });

  describe("PostHog に送る環境（本番）でサインインしているとき", () => {
    let accountId: string;
    let sessionToken: string;
    let productionEnv: Env;
    let deletePostHogPersonSpy: ReturnType<typeof mockDeletePostHogPersonOk>;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      mockRevokeAppleRefreshTokenOk();
      deletePostHogPersonSpy = mockDeletePostHogPersonOk();
      ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
      productionEnv = {
        ...env,
        POSTHOG_PROJECT_ID: "12345",
        POSTHOG_PERSONAL_API_KEY: "phx_test",
      };
    });

    test("PostHog の人と出来事を消すこと", async () => {
      await deleteSignedInAccount(sessionToken, productionEnv);
      expect(deletePostHogPersonSpy).toHaveBeenCalledWith(
        { projectId: "12345", personalApiKey: "phx_test" },
        accountId,
      );
    });
  });

  describe("写真の控えのあるアカウントでサインインしているとき", () => {
    let signedIn: { accountId: string; sessionToken: string };
    let otherAccountId: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      mockRevokeAppleRefreshTokenOk();
      signedIn = await signInTestAccount(generateRecordId());
      otherAccountId = generateRecordId();
      await env.PHOTOS.put(`${signedIn.accountId}/meal-photos/photo-1`, "jpeg");
      await env.PHOTOS.put(`${otherAccountId}/meal-photos/photo-1`, "jpeg");
    });

    test("そのアカウントの接頭辞の写真の控えを消し、ほかのアカウントの控えは消さないこと", async () => {
      await deleteSignedInAccount(signedIn.sessionToken, env);
      expect(await listPhotoKeys(signedIn.accountId)).toEqual([]);
      expect(await listPhotoKeys(otherAccountId)).toEqual([
        `${otherAccountId}/meal-photos/photo-1`,
      ]);
    });

    describe("写真の控えが一覧の1頁に収まらないとき", () => {
      beforeEach(async () => {
        // 1頁の既定の上限（1000件）を超える数を置くと、負荷の高いときに置くだけでテストの時間の上限を超えるので、1頁を1件に絞る。
        // 削除は写真の控えを2回消すので、外のまとまりで置いた photo-1 と合わせて、2回の1頁目では消えきらない3件にする。
        // 消えたかを見る一覧も1頁1件になるが、1件でも残れば空にならないので確かめられる
        mockPhotosBucketListPageSize(1);
        await env.PHOTOS.put(`${signedIn.accountId}/meal-photos/photo-2`, "jpeg");
        await env.PHOTOS.put(`${signedIn.accountId}/meal-photos/photo-3`, "jpeg");
      });

      test("すべての頁の写真の控えを消すこと", async () => {
        await deleteSignedInAccount(signedIn.sessionToken, env);
        expect(await listPhotoKeys(signedIn.accountId)).toEqual([]);
      });
    });
  });

  describe("Better Auth の行を消す前後に、記録と写真の控えが入り込むとき", () => {
    let accountId: string;
    let sessionToken: string;
    let productionEnv: Env;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      mockRevokeAppleRefreshTokenOk();
      ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
      productionEnv = {
        ...env,
        POSTHOG_PROJECT_ID: "12345",
        POSTHOG_PERSONAL_API_KEY: "phx_test",
      };
      // 1回目の Durable Object と R2 の削除が終わったあとの段で、別の端末の同期の要求と裏で送っていた写真が届いた形にする
      mockDeletePostHogPersonOk().mockImplementation(async () => {
        await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
          state.storage.sql.exec("CREATE TABLE deletion_check_late_records (id TEXT PRIMARY KEY)");
        });
        await env.PHOTOS.put(`${accountId}/meal-photos/late-photo`, "jpeg");
      });
    });

    test("2回目の削除で、入り込んだ記録を消すこと", async () => {
      await deleteSignedInAccount(sessionToken, productionEnv);
      const tables = await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
        state.storage.sql
          .exec("SELECT name FROM sqlite_master WHERE name = 'deletion_check_late_records'")
          .toArray(),
      );
      expect(tables).toEqual([]);
    });

    test("2回目の削除で、入り込んだ写真の控えを消すこと", async () => {
      await deleteSignedInAccount(sessionToken, productionEnv);
      expect(await listPhotoKeys(accountId)).toEqual([]);
    });
  });

  describe("2回目の写真の控えの削除に失敗したとき", () => {
    let accountId: string;
    let sessionToken: string;
    let productionEnv: Env;
    let captureExceptionSpy: ReturnType<typeof mockCaptureExceptionOk>;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      mockRevokeAppleRefreshTokenOk();
      captureExceptionSpy = mockCaptureExceptionOk();
      ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
      productionEnv = {
        ...env,
        POSTHOG_PROJECT_ID: "12345",
        POSTHOG_PERSONAL_API_KEY: "phx_test",
      };
      mockDeletePostHogPersonOk().mockImplementation(async () => {
        await env.PHOTOS.put(`${accountId}/meal-photos/late-photo`, "jpeg");
        mockPhotosBucketDeleteError(new Error("R2 が落ちている"));
      });
    });

    test("Sentry に送り、削除は終えること", async () => {
      const response = await deleteSignedInAccount(sessionToken, productionEnv);
      expect(response.status).toBe(204);
      expect(captureExceptionSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          name: "AccountDeletionRetryFailedError",
          stage: "delete_meal_photo_files",
        }),
      );
    });
  });

  describe("Apple の取り消しに一度失敗したとき", () => {
    let sessionToken: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      ({ sessionToken } = await signInTestAccount(generateRecordId()));
      mockRevokeAppleRefreshTokenError(new RevokeAppleRefreshTokenError({ status: 503 }));
      await deleteSignedInAccount(sessionToken, env);
      mockRevokeAppleRefreshTokenOk();
    });

    test("同じセッションでやり直せること", async () => {
      const response = await deleteSignedInAccount(sessionToken, env);
      expect(response.status).toBe(204);
    });
  });
});

const deleteSignedInAccount = (sessionToken: string, workerEnv: Env) =>
  app.request(
    "/v1/account",
    { method: "DELETE", headers: { authorization: `Bearer ${sessionToken}` } },
    workerEnv,
  );

const listPhotoKeys = async (accountId: string) =>
  (await env.PHOTOS.list({ prefix: `${accountId}/meal-photos/` })).objects.map(({ key }) => key);

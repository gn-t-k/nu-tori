import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockAppleRevokeEndpointError, mockAppleRevokeEndpointOk } from "../testing";
import { RevokeAppleRefreshTokenError, revokeAppleRefreshToken } from "./index";

describe("Apple の refresh token の取り消し", () => {
  describe("Apple が取り消したとき", () => {
    let refreshToken: string;
    let fetchSpy: ReturnType<typeof mockAppleRevokeEndpointOk>;
    beforeEach(() => {
      refreshToken = "apple-refresh-token";
      fetchSpy = mockAppleRevokeEndpointOk();
    });

    test("refresh token を取り消しの口に送ること", async () => {
      await revokeAppleRefreshToken(env, refreshToken);
      const [url, init] = fetchSpy.mock.calls[0] ?? [];
      const body = await new Response(init?.body).formData();
      expect({
        url,
        token: body.get("token"),
        tokenTypeHint: body.get("token_type_hint"),
        clientId: body.get("client_id"),
      }).toEqual({
        url: "https://appleid.apple.com/auth/revoke",
        token: refreshToken,
        tokenTypeHint: "refresh_token",
        clientId: env.APPLE_BUNDLE_ID,
      });
    });
  });

  describe("Apple が失敗を返したとき", () => {
    let refreshToken: string;
    beforeEach(() => {
      refreshToken = "apple-refresh-token";
      mockAppleRevokeEndpointError(503);
    });

    test("失敗を投げること", async () => {
      await expect(revokeAppleRefreshToken(env, refreshToken)).rejects.toThrow(
        RevokeAppleRefreshTokenError,
      );
    });
  });
});

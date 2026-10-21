import { env } from "cloudflare:workers";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId } from "../../domain/record-id";
import { app } from "../app";
import { signInTestAccount } from "../testing";
import { readTermsAgreements } from "./testing/read-terms-agreements";

describe("規約の同意が要るか", () => {
  describe("どの版にも同意していないとき", () => {
    let sessionToken: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      ({ sessionToken } = await signInTestAccount(generateRecordId()));
    });

    test("同意が要ることと、同意を求める版を返すこと", async () => {
      const response = await getTermsAgreement(sessionToken);
      expect({ status: response.status, body: await response.json() }).toEqual({
        status: 200,
        body: { agreementRequired: true, termsVersion: "1" },
      });
    });
  });

  describe("同意のシートで今の版に同意したあと", () => {
    let sessionToken: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      ({ sessionToken } = await signInTestAccount(generateRecordId()));
      await postTermsAgreement(sessionToken, { requestId: generateRecordId(), termsVersion: "1" });
    });

    test("同意が要らないと返すこと", async () => {
      const response = await getTermsAgreement(sessionToken);
      expect(await response.json()).toEqual({ agreementRequired: false, termsVersion: "1" });
    });
  });
});

describe("規約に同意する", () => {
  let accountId: string;
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
  });

  describe("今の版に同意したとき", () => {
    let requestId: string;
    beforeEach(() => {
      requestId = generateRecordId();
      vi.useFakeTimers({ toFake: ["Date"], now: new Date("2026-10-21T09:00:00Z") });
    });
    afterEach(() => {
      vi.useRealTimers();
    });

    test("要求の ID を同意の ID にして、同意のシートでの同意を残すこと", async () => {
      const response = await postTermsAgreement(sessionToken, { requestId, termsVersion: "1" });
      expect({ status: response.status, rows: await readTermsAgreements(accountId) }).toEqual({
        status: 204,
        rows: [
          {
            id: requestId,
            terms_version: "1",
            agreement_screen: "agreement_sheet",
            agreed_at: new Date("2026-10-21T09:00:00Z").getTime(),
          },
        ],
      });
    });
  });

  describe("同じ要求の ID で送り直したとき", () => {
    let requestId: string;
    beforeEach(async () => {
      requestId = generateRecordId();
      await postTermsAgreement(sessionToken, { requestId, termsVersion: "1" });
    });

    test("同意を1つだけ残すこと", async () => {
      const response = await postTermsAgreement(sessionToken, { requestId, termsVersion: "1" });
      expect({
        status: response.status,
        ids: (await readTermsAgreements(accountId)).map(({ id }) => id),
      }).toEqual({ status: 204, ids: [requestId] });
    });
  });

  describe("知らない版に同意したとき", () => {
    test("422 を返し、同意を残さないこと", async () => {
      const response = await postTermsAgreement(sessionToken, {
        requestId: generateRecordId(),
        termsVersion: "999",
      });
      expect({
        status: response.status,
        body: await response.json(),
        rows: await readTermsAgreements(accountId),
      }).toEqual({ status: 422, body: { code: "terms_version_unknown" }, rows: [] });
    });
  });
});

const postTermsAgreement = (
  sessionToken: string,
  body: { requestId: string; termsVersion: string },
) =>
  app.request(
    "/v1/terms-agreements",
    {
      method: "POST",
      headers: { authorization: `Bearer ${sessionToken}`, "content-type": "application/json" },
      body: JSON.stringify(body),
    },
    env,
  );

const getTermsAgreement = (sessionToken: string) =>
  app.request("/v1/terms-agreement", { headers: { authorization: `Bearer ${sessionToken}` } }, env);

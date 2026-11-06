// scripts/search-console が Google に渡す JWT を、作ったその場の鍵で確かめる
"use strict";

const assert = require("node:assert/strict");
const { generateKeyPairSync, verify } = require("node:crypto");
const { describe, it, before } = require("node:test");
const { signServiceAccountJwt } = require("./search-console");

describe("サービスアカウントの JWT", () => {
  describe("サービスアカウントの鍵で署名したとき", () => {
    let publicKey;
    let header;
    let claims;
    let signedPart;
    let signature;

    before(() => {
      const pair = generateKeyPairSync("rsa", { modulusLength: 2048 });
      publicKey = pair.publicKey;
      const jwt = signServiceAccountJwt(
        { clientEmail: "reader@nu-tori-test.iam.gserviceaccount.com", privateKey: pair.privateKey },
        1_800_000_000,
      );
      const [encodedHeader, encodedClaims, encodedSignature] = jwt.split(".");
      header = JSON.parse(Buffer.from(encodedHeader, "base64url").toString("utf8"));
      claims = JSON.parse(Buffer.from(encodedClaims, "base64url").toString("utf8"));
      signedPart = `${encodedHeader}.${encodedClaims}`;
      signature = Buffer.from(encodedSignature, "base64url");
    });

    it("鍵の公開鍵で RS256 の署名を確かめられること", () => {
      assert.equal(header.alg, "RS256");
      assert.equal(verify("sha256", Buffer.from(signedPart), publicKey, signature), true);
    });

    it("読むだけのスコープだけを求めること", () => {
      assert.equal(claims.scope, "https://www.googleapis.com/auth/webmasters.readonly");
    });

    it("トークンの受け口に宛て、発行から1時間以内に切れること", () => {
      assert.equal(claims.iss, "reader@nu-tori-test.iam.gserviceaccount.com");
      assert.equal(claims.aud, "https://oauth2.googleapis.com/token");
      assert.equal(claims.iat, 1_800_000_000);
      assert.ok(claims.exp > claims.iat && claims.exp - claims.iat <= 3600);
    });
  });
});

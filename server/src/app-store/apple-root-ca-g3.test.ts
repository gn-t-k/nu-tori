import { describe, expect, test } from "vitest";
import { appleRootCaG3 } from "./apple-root-ca-g3";
import { X509Certificate } from "./peculiar-x509";

describe("appleRootCaG3", () => {
  test("Apple が公開している Apple Root CA - G3 の SHA-256 の指紋と一致すること", async () => {
    const thumbprint = await new X509Certificate(appleRootCaG3).getThumbprint("SHA-256");

    // https://www.apple.com/certificateauthority/ に載る指紋
    expect(Buffer.from(thumbprint).toString("hex").toUpperCase()).toBe(
      "63343ABFB89A6A03EBB57E9B3F5FA7BE7C4F5C756F3017B3A8C488C3653E9179",
    );
  });
});

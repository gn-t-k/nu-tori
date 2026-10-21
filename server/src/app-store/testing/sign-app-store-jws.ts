import { CompactSign } from "jose";

// 鎖を組み替えたテストのため、x5c は TestCertificateChain の形でなくてもよい
export type TestSigner = { x5c: string[]; signingKey: CryptoKey };

// App Store と同じく、ES256 で署名し、ヘッダの x5c に鎖を載せる
export const signAppStoreJws = (chain: TestSigner, payload: object): Promise<string> =>
  new CompactSign(new TextEncoder().encode(JSON.stringify(payload)))
    .setProtectedHeader({ alg: "ES256", x5c: chain.x5c })
    .sign(chain.signingKey);

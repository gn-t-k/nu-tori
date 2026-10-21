import { BasicConstraintsExtension, Extension, X509CertificateGenerator } from "../peculiar-x509";

export type TestCertificateChain = {
  // 確かめる入口に差し込む根（DER の Base64）
  rootCertificate: string;
  // JWS のヘッダに載せる鎖。署名した証明書・中間・根の順
  x5c: [leaf: string, intermediate: string, root: string];
  signingKey: CryptoKey;
};

type Validity = { notBefore: Date; notAfter: Date };

// Apple の鎖をまねた、根・中間・署名の証明書の鎖を作る。
// 既定の有効期間は、テストの署名の日時（2026 年）を広く含む
export const createTestCertificateChain = async ({
  leafValidity = defaultValidity,
  intermediateHasAppleMarker = true,
}: {
  leafValidity?: Validity;
  intermediateHasAppleMarker?: boolean;
} = {}): Promise<TestCertificateChain> => {
  const [rootKeys, intermediateKeys, leafKeys] = await Promise.all([
    generateKeys("P-384"),
    generateKeys("P-384"),
    generateKeys("P-256"),
  ]);
  const root = await X509CertificateGenerator.createSelfSigned({
    name: "CN=Test Root CA",
    keys: rootKeys,
    ...defaultValidity,
    signingAlgorithm: { name: "ECDSA", hash: "SHA-384" },
    extensions: [new BasicConstraintsExtension(true, undefined, true)],
  });
  const intermediate = await X509CertificateGenerator.create({
    subject: "CN=Test Intermediate CA",
    issuer: root.subject,
    publicKey: intermediateKeys.publicKey,
    signingKey: rootKeys.privateKey,
    ...defaultValidity,
    signingAlgorithm: { name: "ECDSA", hash: "SHA-384" },
    extensions: [
      new BasicConstraintsExtension(true, 0, true),
      ...(intermediateHasAppleMarker ? [appleMarker(intermediateMarkerOid)] : []),
    ],
  });
  const leaf = await X509CertificateGenerator.create({
    subject: "CN=Test App Store Signing",
    issuer: intermediate.subject,
    publicKey: leafKeys.publicKey,
    signingKey: intermediateKeys.privateKey,
    ...leafValidity,
    signingAlgorithm: { name: "ECDSA", hash: "SHA-384" },
    extensions: [appleMarker(leafMarkerOid)],
  });
  return {
    rootCertificate: root.toString("base64"),
    x5c: [leaf.toString("base64"), intermediate.toString("base64"), root.toString("base64")],
    signingKey: leafKeys.privateKey,
  };
};

const defaultValidity: Validity = {
  notBefore: new Date("2020-01-01T00:00:00Z"),
  notAfter: new Date("2040-01-01T00:00:00Z"),
};

const intermediateMarkerOid = "1.2.840.113635.100.6.2.1";
const leafMarkerOid = "1.2.840.113635.100.6.11.1";

// Apple の証明書は、印の拡張の値に DER の NULL を入れる
const appleMarker = (oid: string): Extension =>
  new Extension(oid, false, new Uint8Array([0x05, 0x00]));

const generateKeys = async (namedCurve: "P-256" | "P-384"): Promise<CryptoKeyPair> => {
  const keys = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve }, false, [
    "sign",
    "verify",
  ]);
  // Workers の型は、鍵の種類によらず CryptoKey と CryptoKeyPair のどちらかを返すと書く
  if (!("privateKey" in keys)) {
    throw new Error("ECDSA の鍵の対が作られなかった");
  }
  return keys;
};

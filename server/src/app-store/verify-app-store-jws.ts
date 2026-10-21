import { R } from "@praha/byethrow";
import { compactVerify, decodeJwt, decodeProtectedHeader } from "jose";
import { z } from "zod";
import { AppStoreSignatureUnverifiedError } from "./app-store-signature-unverified-error";
import { BasicConstraintsExtension, X509Certificate } from "./peculiar-x509";

// App Store の署名つきの値（JWS）を、ヘッダの x5c の鎖が差し込んだ根までつながると確かめてから、schema で読む。
// 確かめ方は Apple の app-store-server-library（オンラインの確かめをしない形）にそろえる。
// 有効期限は値の signedDate の時点で見る。前に署名された取引を、署名した証明書が切れたあとに受けても読めるようにするため
export const verifyAppStoreJws = <Output>(
  jws: string,
  rootCertificate: string,
  schema: z.ZodType<Output>,
): R.ResultAsync<Output, AppStoreSignatureUnverifiedError> =>
  R.pipe(
    R.try({
      try: () => readVerifiedPayload(jws, rootCertificate),
      catch: (cause) => new AppStoreSignatureUnverifiedError({ cause }),
    }),
    R.andThen((payload) =>
      R.pipe(
        R.parse(schema, payload),
        R.mapError((issues) => new AppStoreSignatureUnverifiedError({ cause: issues })),
      ),
    ),
  );

const readVerifiedPayload = async (jws: string, rootCertificate: string): Promise<unknown> => {
  const certificateSchema = z.string().transform((der) => new X509Certificate(der));
  const [leaf, intermediate, root] = z
    .tuple([certificateSchema, certificateSchema, certificateSchema])
    .parse(decodeProtectedHeader(jws).x5c);
  const trustedRoot = new X509Certificate(rootCertificate);
  const { signedDate } = z.object({ signedDate: z.number() }).parse(decodeJwt(jws));
  const effectiveDate = new Date(signedDate);

  if (!root.equal(trustedRoot)) {
    throw new Error("鎖の根が差し込んだ根と違う");
  }
  if (!(await isIssuedBy(intermediate, trustedRoot)) || !(await isIssuedBy(leaf, intermediate))) {
    throw new Error("鎖の署名がつながらない");
  }
  if (intermediate.getExtension(BasicConstraintsExtension)?.ca !== true) {
    throw new Error("中間の証明書が CA でない");
  }
  if (
    intermediate.getExtension(intermediateMarkerOid) === null ||
    leaf.getExtension(leafMarkerOid) === null
  ) {
    throw new Error("Apple の証明書の印が無い");
  }
  if (
    ![leaf, intermediate, trustedRoot].every((certificate) => isValidAt(certificate, effectiveDate))
  ) {
    throw new Error("署名の日時に有効期限の外の証明書がある");
  }

  const { payload } = await compactVerify(jws, await leaf.publicKey.export(), {
    algorithms: ["ES256"],
  });
  return JSON.parse(new TextDecoder().decode(payload));
};

// Apple の中間の証明書（Apple Worldwide Developer Relations）と、App Store の署名の証明書の印
const intermediateMarkerOid = "1.2.840.113635.100.6.2.1";
const leafMarkerOid = "1.2.840.113635.100.6.11.1";

const isIssuedBy = async (
  certificate: X509Certificate,
  issuer: X509Certificate,
): Promise<boolean> =>
  certificate.issuer === issuer.subject &&
  (await certificate.verify({ publicKey: issuer, signatureOnly: true }));

const isValidAt = (certificate: X509Certificate, date: Date): boolean =>
  certificate.notBefore <= date && date <= certificate.notAfter;

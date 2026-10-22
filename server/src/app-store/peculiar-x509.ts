// @peculiar/x509 が使う tsyringe は、読み込まれる前に Reflect のメタデータの polyfill を要る。
// 読み込む順を1か所で守るため、@peculiar/x509 はここからだけ読み込む（.oxlintrc.json の no-restricted-imports）
// oxlint-disable-next-line import/no-unassigned-import -- 読み込むことで Reflect に足す polyfill で、値を使わない
import "reflect-metadata";

export {
  BasicConstraintsExtension,
  Extension,
  X509Certificate,
  X509CertificateGenerator,
} from "@peculiar/x509";

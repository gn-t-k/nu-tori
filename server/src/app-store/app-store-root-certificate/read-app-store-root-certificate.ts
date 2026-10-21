import { appleRootCaG3 } from "../apple-root-ca-g3";

// 受け口が署名を確かめるときの根。テストは、自分で作った鎖の根に差し替える（read-app-store-root-certificate.mock.ts）
export const readAppStoreRootCertificate = (): string => appleRootCaG3;

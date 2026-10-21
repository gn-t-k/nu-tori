import { vi } from "vitest";
import * as module from "./index";

// 受け口のテストで、署名を確かめる根を、createTestCertificateChain で作った鎖の根にする
export const mockAppStoreRootCertificate = (rootCertificate: string) =>
  vi.spyOn(module, "readAppStoreRootCertificate").mockReturnValue(rootCertificate);

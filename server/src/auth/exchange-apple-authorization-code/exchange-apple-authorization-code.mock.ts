import { vi } from "vitest";
import * as module from "./index";

export const mockExchangeAppleAuthorizationCodeOk = (overrides?: { refreshToken?: string }) => {
  return vi
    .spyOn(module, "exchangeAppleAuthorizationCode")
    .mockResolvedValue({ kind: "exchanged", refreshToken: "apple-refresh-token", ...overrides });
};

export const mockExchangeAppleAuthorizationCodeError = () => {
  return vi.spyOn(module, "exchangeAppleAuthorizationCode").mockResolvedValue({ kind: "rejected" });
};

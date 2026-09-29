import { R } from "@praha/byethrow";
import { vi } from "vitest";
import * as module from "./index";
import type { AppleAuthorizationCodeRejectedError } from "./index";

export const mockExchangeAppleAuthorizationCodeOk = (overrides?: { refreshToken?: string }) => {
  return vi
    .spyOn(module, "exchangeAppleAuthorizationCode")
    .mockResolvedValue(R.succeed(overrides?.refreshToken ?? "apple-refresh-token"));
};

export const mockExchangeAppleAuthorizationCodeError = (
  error: AppleAuthorizationCodeRejectedError,
) => {
  return vi.spyOn(module, "exchangeAppleAuthorizationCode").mockResolvedValue(R.fail(error));
};

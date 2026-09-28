import { vi } from "vitest";
import * as module from "./index";
import type { RevokeAppleRefreshTokenError } from "./index";

export const mockRevokeAppleRefreshTokenOk = () => {
  return vi.spyOn(module, "revokeAppleRefreshToken").mockResolvedValue();
};

export const mockRevokeAppleRefreshTokenError = (error: RevokeAppleRefreshTokenError) => {
  return vi.spyOn(module, "revokeAppleRefreshToken").mockRejectedValue(error);
};

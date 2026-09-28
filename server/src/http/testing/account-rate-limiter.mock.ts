import { env } from "cloudflare:workers";
import { vi } from "vitest";

export const mockAccountRateLimiterOk = () => {
  return vi.spyOn(env.ACCOUNT_RATE_LIMITER, "limit").mockResolvedValue({ success: true });
};

export const mockAccountRateLimiterError = () => {
  return vi.spyOn(env.ACCOUNT_RATE_LIMITER, "limit").mockResolvedValue({ success: false });
};

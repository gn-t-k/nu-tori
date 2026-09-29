import * as sentry from "@sentry/cloudflare";
import { vi } from "vitest";

export const mockSetUserOk = () => {
  return vi.spyOn(sentry, "setUser").mockReturnValue(undefined);
};

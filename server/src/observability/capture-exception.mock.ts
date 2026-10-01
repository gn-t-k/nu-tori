import * as sentry from "@sentry/cloudflare";
import { vi } from "vitest";

export const mockCaptureExceptionOk = () => {
  return vi.spyOn(sentry, "captureException").mockReturnValue("event-id");
};

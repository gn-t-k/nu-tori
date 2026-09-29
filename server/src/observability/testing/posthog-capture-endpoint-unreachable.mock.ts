import { vi } from "vitest";

export const mockPostHogCaptureEndpointUnreachable = () => {
  return vi.spyOn(globalThis, "fetch").mockRejectedValue(new TypeError("Network connection lost"));
};

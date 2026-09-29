import { vi } from "vitest";

export const mockPostHogCaptureEndpointOk = () => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(Response.json({ status: 1 }));
};

export const mockPostHogCaptureEndpointError = (status: number) => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status }));
};

export const mockPostHogCaptureEndpointUnreachable = () => {
  return vi.spyOn(globalThis, "fetch").mockRejectedValue(new TypeError("Network connection lost"));
};

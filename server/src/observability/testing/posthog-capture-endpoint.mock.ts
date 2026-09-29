import { vi } from "vitest";

export const mockPostHogCaptureEndpointOk = (overrides?: Partial<{ status: number }>) => {
  return vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValue(Response.json({ status: 1, ...overrides }));
};

export const mockPostHogCaptureEndpointError = (status: number) => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status }));
};

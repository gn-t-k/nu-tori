import { vi } from "vitest";

export const mockPostHogCaptureEndpointOk = (overrides?: Partial<{ status: number }>) => {
  return vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValue(Response.json({ status: 1, ...overrides }));
};

export const mockPostHogCaptureEndpointError = (error: TypeError | number) => {
  const spy = vi.spyOn(globalThis, "fetch");
  return typeof error === "number"
    ? spy.mockResolvedValue(new Response(null, { status: error }))
    : spy.mockRejectedValue(error);
};

// 答えを返さない PostHog。送信の上限の signal にも応えず、promise は片づかない
export const mockPostHogCaptureEndpointNoResponseError = () => {
  return vi.spyOn(globalThis, "fetch").mockReturnValue(new Promise<Response>(() => {}));
};

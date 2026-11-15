import { vi } from "vitest";

export const mockPostHogCaptureEndpointOk = (overrides?: Partial<{ status: number }>) => {
  return vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValue(Response.json({ status: 1, ...overrides }));
};

// "no_response" は答えを返さない PostHog。送信の上限の signal にも応えず、promise は片づかない
export const mockPostHogCaptureEndpointError = (error: TypeError | number | "no_response") => {
  const spy = vi.spyOn(globalThis, "fetch");
  if (error === "no_response") {
    return spy.mockReturnValue(new Promise<Response>(() => {}));
  }
  return typeof error === "number"
    ? spy.mockResolvedValue(new Response(null, { status: error }))
    : spy.mockRejectedValue(error);
};

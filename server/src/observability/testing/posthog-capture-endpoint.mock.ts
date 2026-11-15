import { vi } from "vitest";

export const mockPostHogCaptureEndpointOk = (overrides?: Partial<{ status: number }>) => {
  return vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValue(Response.json({ status: 1, ...overrides }));
};

// 答えるときをテストが決める PostHog。渡した promise が片づいたときに答える
export const mockPostHogCaptureEndpointPendingOk = (response: Promise<Response>) => {
  return vi.spyOn(globalThis, "fetch").mockReturnValue(response);
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

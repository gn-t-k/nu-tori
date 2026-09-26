import { vi } from "vitest";

export const mockAppleRevokeEndpointOk = () => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null));
};

export const mockAppleRevokeEndpointError = (status: number) => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status }));
};

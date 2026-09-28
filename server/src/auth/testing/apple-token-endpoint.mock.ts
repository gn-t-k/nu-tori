import { vi } from "vitest";

export const mockAppleTokenEndpointOk = (overrides?: { refresh_token?: string }) => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(
    Response.json({
      access_token: "apple-access-token",
      id_token: "apple-id-token",
      refresh_token: "apple-refresh-token",
      ...overrides,
    }),
  );
};

export const mockAppleTokenEndpointError = (error: "invalid_grant" | "invalid_client") => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(Response.json({ error }, { status: 400 }));
};

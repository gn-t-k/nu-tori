import { vi } from "vitest";
import { appleSigningKey } from "./apple-signing-key";

// Apple の公開鍵の取得だけを受け、ほかの外への呼び出しは失敗させる
export const mockAppleKeysEndpointOk = () => {
  return vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
    const url = input instanceof Request ? input.url : String(input);
    if (url === "https://appleid.apple.com/auth/keys") {
      const { publicJwk } = await appleSigningKey;
      return Response.json({ keys: [publicJwk] });
    }
    throw new Error(`テストで外に出る呼び出し: ${url}`);
  });
};

export const mockAppleKeysEndpointError = (status: number) => {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status }));
};

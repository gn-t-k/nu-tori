import { env } from "cloudflare:workers";
import { vi } from "vitest";
import type { mockCreateEstimationProviderOk } from "../../durable-object/create-estimation-provider/create-estimation-provider.mock";
import type { EstimationProvider } from "../../domain/estimation-provider";

// いま差してある偽の提供元が受け取った ① の入力を、受け取った順に読む。
// 偽の提供元を差し直すと spy は同じまま返す提供元が変わるので、spy の今の実装から提供元を得る
export const readIdentifyDishesRequests = (
  spy: ReturnType<typeof mockCreateEstimationProviderOk>,
): Parameters<EstimationProvider["identifyDishes"]>[0][] => {
  const provider = spy.getMockImplementation()?.(env, "account-of-reader");
  return provider === undefined
    ? []
    : vi.mocked(provider.identifyDishes).mock.calls.map(([request]) => request);
};

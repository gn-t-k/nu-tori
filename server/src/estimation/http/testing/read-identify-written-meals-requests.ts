import { env } from "cloudflare:workers";
import { vi } from "vitest";
import type { mockCreateEstimationProviderOk } from "../../durable-object/create-estimation-provider/create-estimation-provider.mock";
import type { EstimationProvider } from "../../domain/estimation-provider";

// いま差してある偽の提供元が受け取った、文章の食事の ① の入力を、受け取った順に読む
export const readIdentifyWrittenMealsRequests = (
  spy: ReturnType<typeof mockCreateEstimationProviderOk>,
): Parameters<EstimationProvider["identifyWrittenMeals"]>[0][] => {
  const provider = spy.getMockImplementation()?.(env, "account-of-reader");
  return provider === undefined
    ? []
    : vi.mocked(provider.identifyWrittenMeals).mock.calls.map(([request]) => request);
};

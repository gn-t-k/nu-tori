import { vi } from "vitest";
import {
  mockEstimationProviderError,
  mockEstimationProviderOk,
} from "../../domain/estimation-provider.mock";
import * as module from "./index";

// 料理ありで答える偽の提供元（既定の答えは mockEstimationProviderOk）を、提供元を作る口に差す。
// 偽物の ① は呼び出しを記録する（受け取った ① の入力は readIdentifyDishesRequests・readIdentifyWrittenMealsRequests で読む）
export const mockCreateEstimationProviderOk = (
  ...overrides: Parameters<typeof mockEstimationProviderOk>
) =>
  vi
    .spyOn(module, "createEstimationProvider")
    .mockReturnValue(mockEstimationProviderOk(...overrides));

// 失敗で答える偽の提供元を、提供元を作る口に差す。failingCall が match_ingredients なら、① は既定の料理で通り、② で落ちる
export const mockCreateEstimationProviderError = (
  ...failure: Parameters<typeof mockEstimationProviderError>
) =>
  vi
    .spyOn(module, "createEstimationProvider")
    .mockReturnValue(mockEstimationProviderError(...failure));

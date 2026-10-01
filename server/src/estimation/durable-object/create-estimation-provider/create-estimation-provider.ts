import Anthropic from "@anthropic-ai/sdk";
import type { EstimationProvider } from "../../domain/estimation-provider";
import { createAnthropicEstimationProvider } from "./create-anthropic-estimation-provider";

// 提供元の差し替えの口。Durable Object が推定のたびにここから提供元（Anthropic の API）を得る。テストは偽物に差し替える
export const createEstimationProvider = (env: Env, accountId: string): EstimationProvider =>
  createAnthropicEstimationProvider(
    // 再試行は、試みの結果を書いてやり直しの時刻を決めるドメイン層が持つ。SDK の再試行は切る
    new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, maxRetries: 0 }),
    accountId,
  );

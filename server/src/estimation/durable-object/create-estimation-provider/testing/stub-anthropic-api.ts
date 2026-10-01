import Anthropic from "@anthropic-ai/sdk";

// Anthropic の API の手前（fetch）を差し替えたクライアント。送った要求を記録し、reply が返した応答を返す。
// 再試行はアラームの側が持つので、SDK の再試行は切る
export const stubAnthropicApi = (reply: () => Promise<Response>) => {
  const requests: { url: string; apiKey: string | null; body: unknown }[] = [];
  const client = new Anthropic({
    apiKey: "test-anthropic-api-key",
    maxRetries: 0,
    fetch: async (input, init) => {
      requests.push({
        url: input instanceof Request ? input.url : String(input),
        apiKey: new Headers(init?.headers).get("x-api-key"),
        body: JSON.parse(await new Response(init?.body).text()),
      });
      // 本物の fetch と同じく、signal が切れたら失敗させる（SDK の時間の上限は signal を切って働く）
      return new Promise<Response>((resolve, reject) => {
        init?.signal?.addEventListener("abort", () =>
          reject(new DOMException("aborted", "AbortError")),
        );
        reply().then(resolve, reject);
      });
    },
  });
  return { client, requests };
};

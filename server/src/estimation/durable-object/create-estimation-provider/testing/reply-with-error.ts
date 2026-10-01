// 提供元がエラーを返したときの応答
export const replyWithError = (status: number, errorType: string, message: string): Response =>
  Response.json({ type: "error", error: { type: errorType, message } }, { status });

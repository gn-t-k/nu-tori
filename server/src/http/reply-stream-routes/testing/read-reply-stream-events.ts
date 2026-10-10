// 閉じるまで読み、SSE の出来事ごとの data を JSON として返す
export const readReplyStreamEvents = async (response: Response): Promise<unknown[]> =>
  (await response.text()).split("\n\n").flatMap((block) =>
    block
      .split("\n")
      .filter((line) => line.startsWith("data: "))
      .map((line): unknown => JSON.parse(line.slice("data: ".length))),
  );

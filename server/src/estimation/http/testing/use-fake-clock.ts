import { onTestFinished, vi } from "vitest";

// Date だけを偽の時計にする。Durable Object も同じ isolate で動くので、サーバーの「今」もこれになる。
// 実際の時刻より先に進めておくと、張ったアラームがひとりでに動かず、runDurableObjectAlarm で動かしたときだけ動く
export const useFakeClock = (now: number) => {
  vi.useFakeTimers({ toFake: ["Date"], now });
  onTestFinished(() => {
    vi.useRealTimers();
  });
  return {
    advance: (milliseconds: number) => {
      vi.setSystemTime(Date.now() + milliseconds);
    },
  };
};

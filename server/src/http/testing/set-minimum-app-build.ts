import { env } from "cloudflare:workers";
import { onTestFinished } from "vitest";

// 最低バージョンは本番の vars にだけあり、テストは開発用の設定で動くので、テストの中で env に足す
export const setMinimumAppBuild = (minimumAppBuild: number) => {
  Reflect.set(env, "MINIMUM_APP_BUILD", minimumAppBuild);
  onTestFinished(() => {
    Reflect.deleteProperty(env, "MINIMUM_APP_BUILD");
  });
};

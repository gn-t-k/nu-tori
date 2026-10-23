import { createSiteWorker } from "../create-site-worker";

// LP の版を a と b にした Worker（vitest.config.ts）の入口。scripts/check site が、本番の worker.ts と別に束ねる。
// 版を選ぶ乱数を、2つの版のうち b を引く値に決める
export default createSiteWorker(() => 0.99);

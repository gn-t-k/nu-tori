import type { Browser, Page } from "playwright";

// 外を読まないページを用意して渡し、終わったら閉じる
export const withIsolatedPage = async <T>(
  {
    browser,
    width,
    height,
    deviceScaleFactor,
  }: { browser: Browser; width: number; height: number; deviceScaleFactor: number },
  use: (page: Page) => Promise<T>,
): Promise<T> => {
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor,
    colorScheme: "light",
  });
  try {
    // 決まった入力から同じ画像になるよう、外のものを読み込まない（画像は data: の URL で渡す）
    await context.route("**/*", (route) => route.abort());
    return await use(await context.newPage());
  } finally {
    await context.close();
  }
};

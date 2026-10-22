import { beforeEach, describe, expect, test } from "vitest";
import { sitePages } from "./site-pages";
import { fetchSite } from "./testing/fetch-site";

describe("nu-tori.app の配信", () => {
  describe("プライバシーポリシー", () => {
    let response: Response;
    beforeEach(async () => {
      response = await fetchSite("/privacy");
    });

    test("/privacy が 200 で返ること（アプリが開く URL）", () => {
      expect(response.status).toBe(200);
    });

    test("今のプライバシーポリシーの制定日と改定日を返すこと", async () => {
      expect(await response.text()).toContain("制定日: 2026年9月29日　改定日: 2026年10月22日");
    });

    test("nu-tori.app で Cloudflare Web Analytics を使うことを書いていること", async () => {
      expect(await response.text()).toContain("Cloudflare Web Analytics");
    });
  });

  describe("出し方のページ", () => {
    test("/daily-guide が 200 で返ること（目標の設定と目標の画面が開く URL）", async () => {
      expect((await fetchSite("/daily-guide")).status).toBe(200);
    });
  });

  describe("ページの一覧の検索に載せるページ", () => {
    let indexedPages: { canonicalPath: string; title: string }[];
    beforeEach(() => {
      indexedPages = sitePages.flatMap((page) =>
        page.search.kind === "indexed"
          ? [{ canonicalPath: page.search.canonicalPath, title: page.title }]
          : [],
      );
    });

    test("どれも正規の URL で 200 と自分の <title> を返すこと", async () => {
      const results = await Promise.all(
        indexedPages.map(async (page) => {
          const response = await fetchSite(page.canonicalPath);
          const body = await response.text();
          return {
            path: page.canonicalPath,
            status: response.status,
            hasTitle: body.includes(`<title>${page.title}</title>`),
          };
        }),
      );
      expect(results).toEqual(
        indexedPages.map((page) => ({ path: page.canonicalPath, status: 200, hasTitle: true })),
      );
    });
  });

  describe("Cloudflare Web Analytics のビーコン", () => {
    let pagePaths: string[];
    beforeEach(() => {
      pagePaths = [
        "/",
        "/no-such-page",
        ...sitePages.flatMap((page) =>
          page.search.kind === "indexed" ? [page.search.canonicalPath] : [],
        ),
      ];
    });

    test("仮のページと 404 のページを含む、どのページにもサイトのトークンを持つビーコンがあること", async () => {
      const results = await Promise.all(
        pagePaths.map(async (path) => {
          const body = await (await fetchSite(path)).text();
          return {
            path,
            hasBeacon:
              body.includes('src="https://static.cloudflareinsights.com/beacon.min.js"') &&
              body.includes("5b7ef7db1a48416e99daa88b371967e9"),
          };
        }),
      );
      expect(results).toEqual(pagePaths.map((path) => ({ path, hasBeacon: true })));
    });
  });

  describe("ページで読み書きしてよい先（Content-Security-Policy）", () => {
    let directives: string[];
    beforeEach(async () => {
      const policy = (await fetchSite("/privacy")).headers.get("Content-Security-Policy") ?? "";
      directives = policy.split(";").map((directive) => directive.trim());
    });

    test("自分のオリジンとビーコンのスクリプトだけを読ませること", () => {
      expect(directives).toContain("script-src 'self' https://static.cloudflareinsights.com");
    });

    test("自分のオリジンとビーコンの送り先だけに送らせること", () => {
      expect(directives).toContain("connect-src 'self' https://cloudflareinsights.com");
    });
  });

  describe("LP の版が無いとき（LP_VARIANTS が空）", () => {
    let response: Response;
    let privacyResponse: Response;
    beforeEach(async () => {
      response = await fetchSite("/");
      privacyResponse = await fetchSite("/privacy");
    });

    test("/ が仮のページを 200 で返すこと", async () => {
      expect(response.status).toBe(200);
      expect(await response.text()).toContain(
        '<link rel="canonical" href="https://nu-tori.app/"/>',
      );
    });

    test("仮のページから公開のページへリンクすること", async () => {
      expect(await response.text()).toContain('<a href="/privacy">');
    });

    test("Cookie を付けないこと", () => {
      expect(response.headers.has("Set-Cookie")).toBe(false);
    });

    test("/privacy と同じセキュリティのヘッダーを付けること", () => {
      expect(Object.values(pickSecurityHeaders(response))).not.toContain(null);
      expect(pickSecurityHeaders(response)).toEqual(pickSecurityHeaders(privacyResponse));
    });

    test("共有のキャッシュに置かせず、Cookie ごとに分けさせること", () => {
      expect(response.headers.get("Cache-Control")).toBe("private, no-store");
      expect(response.headers.get("Vary")).toBe("Cookie");
    });
  });

  describe("LP の版の中のパスを直に開いたとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await fetchSite("/_lp/_placeholder/", { redirect: "manual" });
    });

    test("/ へ 301 で転送すること", () => {
      expect(response.status).toBe(301);
      expect(response.headers.get("Location")).toBe("/");
    });
  });

  describe("一覧に無いパスを開いたとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await fetchSite("/no-such-page");
    });

    test("404 で返ること", () => {
      expect(response.status).toBe(404);
    });

    test("404 のページを返すこと", async () => {
      expect(await response.text()).toContain("<title>ページが見つかりません | nu-tori</title>");
    });
  });

  describe("sitemap.xml の中身", () => {
    let sitemap: string;
    beforeEach(async () => {
      sitemap = await (await fetchSite("/sitemap.xml")).text();
    });

    test("LP とプライバシーポリシーの正規の URL が並ぶこと", () => {
      expect(sitemap).toContain("<loc>https://nu-tori.app/</loc>");
      expect(sitemap).toContain("<loc>https://nu-tori.app/privacy</loc>");
    });

    test("出し方のページの正規の URL が並ぶこと", () => {
      expect(sitemap).toContain("<loc>https://nu-tori.app/daily-guide</loc>");
    });

    test("LP の版の中のパスが無いこと", () => {
      expect(sitemap).not.toContain("/_lp/");
    });

    test("404 のページが無いこと", () => {
      expect(sitemap).not.toContain("404");
    });
  });

  describe("robots.txt の中身", () => {
    let robots: string;
    beforeEach(async () => {
      robots = await (await fetchSite("/robots.txt")).text();
    });

    test("全部を許し、sitemap.xml を指すこと", () => {
      expect(robots).toBe("User-agent: *\nAllow: /\n\nSitemap: https://nu-tori.app/sitemap.xml\n");
    });
  });
});

const pickSecurityHeaders = (from: Response) =>
  Object.fromEntries(
    [
      "Content-Security-Policy",
      "X-Content-Type-Options",
      "Referrer-Policy",
      "Strict-Transport-Security",
      "X-Frame-Options",
    ].map((name) => [name, from.headers.get(name)]),
  );

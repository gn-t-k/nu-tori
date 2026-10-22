import { beforeEach, describe, expect, test } from "vitest";
import { sitePages } from "./site-pages";
import { fetchSite } from "./testing/fetch-site";
import { fetchSiteWithLandingVariants } from "./testing/fetch-site-with-landing-variants";

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

    test("バッジを置かないので、Apple の商標の行も置かないこと", async () => {
      expect(await response.text()).not.toContain(appleTrademarkNotice);
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

  // テストの LP_VARIANTS は a と b で、乱数は b を引く（vitest.config.ts）。b はテストだけの版で、提供者のトークンを持つ
  describe("LP の版があるとき", () => {
    describe("版の Cookie を持たない人の /", () => {
      let response: Response;
      let privacyResponse: Response;
      beforeEach(async () => {
        response = await fetchSiteWithLandingVariants("/");
        privacyResponse = await fetchSite("/privacy");
      });

      test("乱数が引いた版 b のページを 200 で返すこと", async () => {
        expect(response.status).toBe(200);
        expect(await response.text()).toContain(campaignLinkOfVariantB);
      });

      test("版 b の Cookie を付けること", () => {
        expect(response.headers.get("Set-Cookie")).toBe(
          "nu_tori_lp=b; Max-Age=2592000; Path=/; HttpOnly; Secure; SameSite=Lax",
        );
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

    describe("一覧にある版 a の Cookie を持つ人の /", () => {
      let response: Response;
      beforeEach(async () => {
        response = await fetchSiteWithLandingVariants("/", {
          headers: { Cookie: "nu_tori_lp=a" },
        });
      });

      test("同じ版 a のページを返すこと", async () => {
        expect(await response.text()).toContain(campaignLinkOfVariantA);
      });

      test("Cookie を付け直さないこと", () => {
        expect(response.headers.has("Set-Cookie")).toBe(false);
      });
    });

    describe("一覧に無い版の Cookie を持つ人の /", () => {
      let response: Response;
      beforeEach(async () => {
        response = await fetchSiteWithLandingVariants("/", {
          headers: { Cookie: "nu_tori_lp=retired" },
        });
      });

      test("一覧から乱数が引いた版 b のページを返すこと", async () => {
        expect(await response.text()).toContain(campaignLinkOfVariantB);
      });

      test("版 b の Cookie で上書きすること", () => {
        expect(response.headers.get("Set-Cookie")).toBe(
          "nu_tori_lp=b; Max-Age=2592000; Path=/; HttpOnly; Secure; SameSite=Lax",
        );
      });
    });

    describe("版のページ", () => {
      let variantABody: string;
      let variantBBody: string;
      beforeEach(async () => {
        variantABody = await (
          await fetchSiteWithLandingVariants("/", { headers: { Cookie: "nu_tori_lp=a" } })
        ).text();
        variantBBody = await (
          await fetchSiteWithLandingVariants("/", { headers: { Cookie: "nu_tori_lp=b" } })
        ).text();
      });

      test("提供者のトークンが空なら、バッジのリンクが自分の版の ct を持ち、pt を持たないこと（版 a）", () => {
        expect(variantABody).toContain(campaignLinkOfVariantA);
        expect(variantABody).not.toContain("?pt=");
      });

      test("提供者のトークンがあれば、バッジのリンクが自分の版の ct と pt を持つこと（テストだけの版 b）", () => {
        expect(variantBBody).toContain(campaignLinkOfVariantB);
      });

      test("足に Apple の商標の行を1回だけ置くこと", () => {
        expect(variantABody.split(appleTrademarkNotice)).toHaveLength(2);
      });
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

// アプリの ID は 6816842705。HTML の属性なので & は &amp; で書き出される
const campaignLinkOfVariantA =
  'href="https://apps.apple.com/jp/app/apple-store/id6816842705?ct=lp-a&amp;mt=8"';
const campaignLinkOfVariantB =
  'href="https://apps.apple.com/jp/app/apple-store/id6816842705?pt=test-provider-token&amp;ct=lp-b&amp;mt=8"';
const appleTrademarkNotice = "Apple Inc. の商標です";

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

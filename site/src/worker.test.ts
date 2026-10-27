import { beforeEach, describe, expect, test } from "vitest";
import { notFoundPage } from "./pages/not-found-page";
import { securityHeaders } from "./security-headers";
import { canonicalPathOf } from "./site-page";
import { sitePages } from "./site-pages";
import { subscriptionPrices } from "./subscription-prices";
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

    test("サポートのページがリンクする、外国にある第三者への提供の目印を持つこと", async () => {
      expect(await response.text()).toContain('id="overseas-transfer"');
    });

    test("問い合わせのフォームとメールの窓口へリンクすること", async () => {
      const body = await response.text();
      expect(body).toContain('<a href="https://forms.gle/KGg899DaWghiYnTx7">');
      expect(body).toContain('<a href="mailto:support@nu-tori.app">');
    });

    test("外枠の足からサポートと告知のページへリンクすること", async () => {
      const body = await response.text();
      expect(body).toContain('<a href="/support">');
      expect(body).toContain('<a href="/announcements">');
    });

    test("外枠の足から利用規約と特定商取引法に基づく表記へリンクすること", async () => {
      const body = await response.text();
      expect(body).toContain('<a href="/terms">');
      expect(body).toContain('<a href="/legal">');
    });
  });

  describe("サポート", () => {
    let response: Response;
    beforeEach(async () => {
      response = await fetchSite("/support");
    });

    test("/support が 200 で返ること（App Store Connect に入れる URL）", () => {
      expect(response.status).toBe(200);
    });

    test("問い合わせのフォームと、メールの窓口と、告知のページへリンクすること", async () => {
      const body = await response.text();
      expect(body).toContain('<a href="https://forms.gle/KGg899DaWghiYnTx7">');
      expect(body).toContain('<a href="mailto:support@nu-tori.app">');
      expect(body).toContain('<a href="/announcements">');
    });

    test("メールの送り先の案内から、プライバシーポリシーの外国にある第三者への提供の節へリンクすること", async () => {
      expect(await response.text()).toContain('<a href="/privacy#overseas-transfer">');
    });
  });

  describe("告知のページ", () => {
    let response: Response;
    beforeEach(async () => {
      response = await fetchSite("/announcements");
    });

    test("/announcements が 200 で返ること（アプリが開けないときに読む URL）", () => {
      expect(response.status).toBe(200);
    });

    test("告知の問い合わせ先として、サポートのページへリンクすること", async () => {
      expect(await response.text()).toContain('<a href="/support">');
    });
  });

  describe("利用規約", () => {
    let response: Response;
    beforeEach(async () => {
      response = await fetchSite("/terms");
    });

    test("/terms が 200 で返ること（課金画面とサインインの画面が開く URL）", () => {
      expect(response.status).toBe(200);
    });

    test("同意の対象のプライバシーポリシーと、問い合わせの先のサポートのページへリンクすること", async () => {
      const body = await response.text();
      expect(body).toContain('<a href="/privacy">');
      expect(body).toContain('<a href="/support">');
    });

    test("価格を、特定商取引法に基づく表記で示すこと", async () => {
      expect(await response.text()).toContain('<a href="/legal">');
    });
  });

  describe("特定商取引法に基づく表記", () => {
    let response: Response;
    beforeEach(async () => {
      response = await fetchSite("/legal");
    });

    test("/legal が 200 で返ること（課金画面が開く URL）", () => {
      expect(response.status).toBe(200);
    });

    test("住所・電話番号の請求の窓口として、メールの窓口とサポートのページへリンクすること", async () => {
      const body = await response.text();
      expect(body).toContain('<a href="mailto:support@nu-tori.app">');
      expect(body).toContain('<a href="/support">');
    });
  });

  describe("出し方のページ", () => {
    let response: Response;
    beforeEach(async () => {
      response = await fetchSite("/daily-guide");
    });

    test("/daily-guide が 200 で返ること（目標の設定と目標の画面が開く URL）", () => {
      expect(response.status).toBe(200);
    });
  });

  describe("ページの一覧の検索に載せるページ", () => {
    let indexedPages: { canonicalPath: string; title: string }[];
    beforeEach(() => {
      indexedPages = sitePages.flatMap((page) => {
        const canonicalPath = canonicalPathOf(page);
        return canonicalPath === undefined ? [] : [{ canonicalPath, title: page.title }];
      });
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
        ...sitePages.flatMap((page) => canonicalPathOf(page) ?? []),
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

  describe("App Store のバッジの画像", () => {
    let response: Response;
    beforeEach(async () => {
      response = await fetchSite("/app-store-badge.svg");
    });

    // Apple の SVG は色を style 属性で付けるので、ページと同じ決まりでは直に開いたときに色と文字が消える
    test("style 属性だけを許し、ほかは何も読ませない決まりを1つだけ付けること", () => {
      expect(response.headers.get("Content-Security-Policy")).toBe(
        "default-src 'none'; style-src 'unsafe-inline'",
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

    // 仮のページと LP の版は正規の URL がどちらも / なので、版にだけあるバッジのキャンペーンのリンクが無いことで見分ける
    test("/ が仮のページを 200 で返すこと", async () => {
      expect(response.status).toBe(200);
      const body = await response.text();
      expect(body).toContain('<link rel="canonical" href="https://nu-tori.app/"/>');
      expect(body).not.toContain("ct=lp-");
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

      test("版 a の最後の節の文のリンクも、バッジと同じ自分の版の ct のリンクであること", () => {
        // リンクで切った切れ端の数は、リンクの数より1つ多い
        expect(variantABody.split(campaignLinkOfVariantA).length - 1).toBe(2);
      });

      test("版 a が、特定商取引法に基づく表記と同じ価格の SoftwareApplication の構造化データを1つ持ち、評価を持たないこと", () => {
        const jsonLds = [
          ...variantABody.matchAll(/<script type="application\/ld\+json">(.*?)<\/script>/gs),
        ].map(([, json]) => {
          if (json === undefined) throw new Error("構造化データの中身が無い");
          return JSON.parse(json);
        });
        expect(jsonLds).toHaveLength(1);
        expect(jsonLds[0]).toMatchObject({
          "@type": "SoftwareApplication",
          operatingSystem: "iOS",
          applicationCategory: "HealthApplication",
          offers: [
            { price: String(subscriptionPrices.monthlyYen), priceCurrency: "JPY" },
            { price: String(subscriptionPrices.yearlyYen), priceCurrency: "JPY" },
          ],
        });
        expect(jsonLds[0]).not.toHaveProperty("aggregateRating");
      });

      test("版 a が読むスクリプトと画像が、自分のオリジンから 200 で返ること", async () => {
        const paths = [...variantABody.matchAll(/ src="(\/[^"]*)"/g)].map(([, path]) => {
          if (path === undefined) throw new Error("src のパスが無い");
          return path;
        });
        expect(paths).toContain("/landing-a.js");
        const statuses = await Promise.all(
          paths.map(async (path) => [path, (await fetchSite(path)).status]),
        );
        expect(statuses).toEqual(paths.map((path) => [path, 200]));
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
      expect(await response.text()).toContain(`<title>${notFoundPage.title}</title>`);
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

    test("サポートと告知のページの正規の URL が並ぶこと", () => {
      expect(sitemap).toContain("<loc>https://nu-tori.app/support</loc>");
      expect(sitemap).toContain("<loc>https://nu-tori.app/announcements</loc>");
    });

    test("出し方のページの正規の URL が並ぶこと", () => {
      expect(sitemap).toContain("<loc>https://nu-tori.app/daily-guide</loc>");
    });

    test("利用規約と特定商取引法に基づく表記の正規の URL が並ぶこと", () => {
      expect(sitemap).toContain("<loc>https://nu-tori.app/terms</loc>");
      expect(sitemap).toContain("<loc>https://nu-tori.app/legal</loc>");
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

const pickSecurityHeaders = (from: Response) =>
  Object.fromEntries(Object.keys(securityHeaders).map((name) => [name, from.headers.get(name)]));

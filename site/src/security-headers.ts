// vite.config.ts が Node でそのまま読むので、拡張子つきで import する
import { webAnalytics } from "./web-analytics.ts";

// 静的な asset には _headers で、Worker が作る応答には Worker で付ける。Worker の応答には _headers が効かないため（docs/research/static-site-generators.md の CF3）
export const securityHeaders = {
  "Content-Security-Policy": [
    "default-src 'self'",
    `script-src 'self' ${new URL(webAnalytics.beaconScriptUrl).origin}`,
    `connect-src 'self' ${webAnalytics.reportOrigin}`,
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join("; "),
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "X-Frame-Options": "DENY",
} as const;

// Apple の配るバッジの SVG は色と文字を style 属性で付けるので、ページの Content-Security-Policy では、直に開いたときと、
// SVG の応答の決まりを <img> の中にも当てるブラウザで、ただの黒い角丸になる。Apple のファイルは変えられないため、この画像にだけ別の決まりを付ける
export const appStoreBadgeImage = {
  path: "/app-store-badge.svg",
  contentSecurityPolicy: "default-src 'none'; style-src 'unsafe-inline'",
} as const;

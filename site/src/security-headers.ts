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

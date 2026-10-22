// nu-tori.app は Workers の独自ドメインで、Cloudflare が自動でビーコンを差し込まないので、外枠に手で置く。トークンはページに出る公開してよい値（#652）
export const webAnalytics = {
  token: "5b7ef7db1a48416e99daa88b371967e9",
  beaconScriptUrl: "https://static.cloudflareinsights.com/beacon.min.js",
  reportOrigin: "https://cloudflareinsights.com",
} as const;

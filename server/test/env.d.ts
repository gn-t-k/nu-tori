import type { D1Migration } from "@cloudflare/vitest-plugin";

declare global {
  namespace Cloudflare {
    interface Env {
      D1_MIGRATIONS: D1Migration[];
    }
  }
}

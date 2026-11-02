import { resultMatchers } from "@praha/byethrow-testing";
import type { ResultMatchers } from "@praha/byethrow-testing";
import { expect } from "vitest";

declare module "vitest" {
  interface Matchers<T> extends ResultMatchers<void, T> {}
}

expect.extend(resultMatchers);

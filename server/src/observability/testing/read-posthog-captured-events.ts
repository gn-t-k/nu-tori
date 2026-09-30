import { z } from "zod";
import type { mockPostHogCaptureEndpointOk } from "./posthog-capture-endpoint.mock";

export const readPostHogCapturedEvents = (spy: ReturnType<typeof mockPostHogCaptureEndpointOk>) =>
  spy.mock.calls
    .filter(([input]) =>
      (input instanceof Request ? input.url : String(input)).startsWith(
        "https://eu.i.posthog.com/",
      ),
    )
    .flatMap(
      ([, init]) =>
        z
          .object({
            api_key: z.string(),
            batch: z.array(
              z.object({
                event: z.string(),
                distinct_id: z.string(),
                properties: z.record(z.string(), z.unknown()),
              }),
            ),
          })
          .parse(JSON.parse(z.string().parse(init?.body))).batch,
    );

import { env } from "cloudflare:workers";
import { app } from "../../app";

export const postGoalSetup = (
  sessionToken: string | undefined,
  path: "preview" | "proposals" | "custom-target-weight",
  body: Record<string, unknown>,
) =>
  app.request(
    `/v1/goal-setup/${path}`,
    {
      method: "POST",
      headers: {
        ...(sessionToken === undefined ? {} : { authorization: `Bearer ${sessionToken}` }),
        "content-type": "application/json",
      },
      body: JSON.stringify({ timeZone: "Asia/Tokyo", ...body }),
    },
    env,
  );

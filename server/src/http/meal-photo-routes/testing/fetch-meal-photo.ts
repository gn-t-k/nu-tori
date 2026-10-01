import { env } from "cloudflare:workers";
import { app } from "../../app";

export const fetchMealPhoto = (sessionToken: string, photoId: string) =>
  app.request(
    `/v1/meal-photos/${photoId}`,
    { headers: { authorization: `Bearer ${sessionToken}` } },
    env,
  );

import { env } from "cloudflare:workers";
import { app } from "../../app";
import { createPhotoBytes } from "./create-photo-bytes";

export const putMealPhoto = (
  sessionToken: string,
  photoId: string,
  photo: { body: Uint8Array; contentType: string } = {
    body: createPhotoBytes(),
    contentType: "image/jpeg",
  },
) =>
  app.request(
    `/v1/meal-photos/${photoId}`,
    {
      method: "PUT",
      headers: { authorization: `Bearer ${sessionToken}`, "content-type": photo.contentType },
      body: photo.body,
    },
    env,
  );

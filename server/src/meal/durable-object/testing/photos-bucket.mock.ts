import { env } from "cloudflare:workers";
import { vi } from "vitest";

export const mockPhotosBucketPutError = (error: Error) => {
  return vi.spyOn(env.PHOTOS, "put").mockRejectedValue(error);
};

export const mockPhotosBucketDeleteError = (error: Error) => {
  return vi.spyOn(env.PHOTOS, "delete").mockRejectedValue(error);
};

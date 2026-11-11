import { env } from "cloudflare:workers";
import { vi } from "vitest";

export const mockPhotosBucketPutError = (error: Error) => {
  return vi.spyOn(env.PHOTOS, "put").mockRejectedValue(error);
};

export const mockPhotosBucketDeleteError = (error: Error) => {
  return vi.spyOn(env.PHOTOS, "delete").mockRejectedValue(error);
};

export const mockPhotosBucketGetError = (error: Error) => {
  return vi.spyOn(env.PHOTOS, "get").mockRejectedValue(error);
};

// 実際の一覧を返し、1頁の件数だけを絞って、少ない数の控えで頁をまたがせる
export const mockPhotosBucketListOk = (limit: number) => {
  const list = env.PHOTOS.list.bind(env.PHOTOS);
  return vi.spyOn(env.PHOTOS, "list").mockImplementation((options) => list({ ...options, limit }));
};

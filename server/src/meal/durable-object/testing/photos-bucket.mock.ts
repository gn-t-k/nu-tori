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

// 実際の一覧を返し、渡した引数で一覧の条件を上書きする（limit を絞ると、少ない数の控えで頁をまたがせられる）
export const mockPhotosBucketListOk = (overrides?: R2ListOptions) => {
  const list = env.PHOTOS.list.bind(env.PHOTOS);
  return vi
    .spyOn(env.PHOTOS, "list")
    .mockImplementation((options) => list({ ...options, ...overrides }));
};

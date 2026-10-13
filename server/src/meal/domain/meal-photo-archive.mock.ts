import { vi } from "vitest";
import type { MealPhotoArchive } from "./meal-photo-archive";

// どの写真の控えもある偽の置き場。偽物は呼び出しを記録する
export const mockMealPhotoArchiveOk = () =>
  ({
    put: vi.fn<MealPhotoArchive["put"]>(() => Promise.resolve()),
    read: vi.fn<MealPhotoArchive["read"]>(() => Promise.resolve(new ArrayBuffer(8))),
    remove: vi.fn<MealPhotoArchive["remove"]>(() => Promise.resolve()),
  }) satisfies MealPhotoArchive;

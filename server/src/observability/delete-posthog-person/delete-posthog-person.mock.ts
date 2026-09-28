import { vi } from "vitest";
import * as module from "./index";
import type { DeletePostHogPersonError } from "./index";

export const mockDeletePostHogPersonOk = () => {
  return vi.spyOn(module, "deletePostHogPerson").mockResolvedValue();
};

export const mockDeletePostHogPersonError = (error: DeletePostHogPersonError) => {
  return vi.spyOn(module, "deletePostHogPerson").mockRejectedValue(error);
};

import { access } from "node:fs/promises";

export const exists = async (filePath: string) =>
  access(filePath).then(
    () => true,
    () => false,
  );

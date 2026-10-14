import type { RecordId } from "../../domain/record-id";
import type { Goal } from "./goal";

export type GoalStore = {
  find: (id: RecordId) => Goal | undefined;
};

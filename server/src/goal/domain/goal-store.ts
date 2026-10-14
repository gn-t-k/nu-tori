import type { RecordId } from "../../domain/record-id";
import type { Goal } from "./goal";

export type GoalStore = {
  find: (id: RecordId) => Goal | undefined;
  // 今の目標（閉じていない目標）。初めて目標を立てる前は無い
  findCurrent: () => Goal | undefined;
};

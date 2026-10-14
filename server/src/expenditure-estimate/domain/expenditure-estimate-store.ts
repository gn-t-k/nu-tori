import type { RecordId } from "../../domain/record-id";
import type { ExpenditureEstimate } from "./expenditure-estimate";

export type ExpenditureEstimateStore = {
  find: (id: RecordId) => ExpenditureEstimate | undefined;
};

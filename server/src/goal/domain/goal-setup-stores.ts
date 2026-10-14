import type { RecordKindStores } from "../../domain/record-kind-stores";

export type GoalSetupStores = Pick<
  RecordKindStores,
  "goal" | "expenditureEstimate" | "weightRecord" | "firstSignIn" | "meal" | "dish" | "ingredient"
>;

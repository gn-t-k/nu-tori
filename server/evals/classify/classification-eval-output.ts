import type { ClassificationLabel } from "../../src/reply/domain/conversation-provider";

// 読み分けの提供元（promptfoo の custom provider）が output に返す形。
// Jev は食事である確からしさを返し、しきい値は数えるときに当てる。Haiku 5.5 は答え（決めかねるを含む）を返す
export type ClassificationEvalOutput =
  | { kind: "probability"; mealProbability: number }
  | { kind: "label"; label: ClassificationLabel };

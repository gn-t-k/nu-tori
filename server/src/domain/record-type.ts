import type { recordTypes } from "./record-types";

// 種類の名前。一覧（record-types.ts）から導く
export type RecordType = (typeof recordTypes)[number];

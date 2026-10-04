import { httpRecordKinds } from "./http-record-kinds";

type RegisteredWriteSchema = NonNullable<
  (typeof httpRecordKinds)[keyof typeof httpRecordKinds]["writes"]
>["schemas"][number];

// z.discriminatedUnion に渡す並び（登録簿から導く）。並びの順は登録簿の順。先頭の1つを分けるのは、型を空でない並びにするため
const [first, ...rest] = Object.values(httpRecordKinds).flatMap(
  (kind): readonly RegisteredWriteSchema[] => kind.writes?.schemas ?? [],
);
if (first === undefined) {
  throw new Error("書き込みのスキーマが1つも登録されていない");
}
export const registeredWriteSchemas = [first, ...rest] as const;

export type TestRecordWrite =
  | { id: string; type: "create_test_record"; recordId: string; value: number }
  | { id: string; type: "update_test_record"; recordId: string; value: number }
  | { id: string; type: "delete_test_record"; recordId: string };

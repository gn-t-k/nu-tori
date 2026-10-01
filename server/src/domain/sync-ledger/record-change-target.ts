// 変更の並びに載せる記録
export type RecordChangeTarget<TRecordType extends string> = {
  recordType: TRecordType;
  recordId: string;
};

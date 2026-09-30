// 今の値。「無い」と「削除の印」は別（削除の印は、消した記録を生き返らせないために残る）
export type CurrentRecord<TValue> =
  | { status: "value"; value: TValue }
  | { status: "deleted" }
  | { status: "absent" };

export type PresentRecord<TValue> = Exclude<CurrentRecord<TValue>, { status: "absent" }>;

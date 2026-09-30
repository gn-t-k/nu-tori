// 登録簿の種類から、種類の名前を導く
export type NameOfKind<TKind> = TKind extends { name: infer TName extends string } ? TName : never;

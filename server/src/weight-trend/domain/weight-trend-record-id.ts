import { recordIdSchema } from "../../domain/record-id";

// 体重の傾向はアカウントに1つなので、記録の ID を決まった1つの値（UUID の nil）にする。
// 変更の並びは種類と ID の組で記録を指すので、ほかの種類の ID とは重ならない
export const weightTrendRecordId = recordIdSchema.parse("00000000-0000-0000-0000-000000000000");

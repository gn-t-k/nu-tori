// 種類の値の部品の名前。openapi.json の部品の名前で、アプリが生成する型の名前になるので、変えると端末のコードも変わる
export const toRecordComponentName = (recordType: string): string =>
  `${recordType
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join("")}Record`;

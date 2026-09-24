# TypeScript での当てはめ

`docs/agents/coding-style.md` と `docs/agents/testing.md` の好みを、TypeScript で書くときの形。

## コーディング

### 関数はアロー関数で書く

- 関数は `const functionName = () => {}` で書く
- `function` キーワードは、それでしか書けないもの（ジェネレーター関数など）にだけ使う

### ファイルと公開するもの

- 公開するものは export で数える
- ファイル名は export する名前のケバブケースにする（`compute-weight-trend.ts` → `export const computeWeightTrend`、`weight-record-store.ts` → `export type WeightRecordStore`）
- mock のファイル（`mockXxxOk` と `mockXxxError` を対で export する）と、再 export だけの `testing/index.ts` は、「1つのファイルから1つ」を置き換える
- 関数は、単体なら1つのファイル（`foo.ts`）にする。純関数やテストのように並べるファイルが要るときだけ、`foo/index.ts` のディレクトリにする

### ファイルの中はトップダウン

- `export default` と `export const` をファイルの先頭の近くに置く
- `const` には TDZ があるので、トップレベルで評価する式（`export default` の値の組み立てなど）が参照するものは、その式より前に書く。ここだけは「内部のものは下にまとめる」を置き換える。トップレベルで呼ばない関数の本体の中で参照するものは、後ろに書いてよい

### 状態は論理状態の数で型を作る

- タグ付きユニオンは、判別可能なユニオンか、文字列リテラルのユニオンで書く

```ts
// 4通り書けるが、起こり得るのは3状態（重複なのに押せる、が書けてしまう）
type CreateState = { isDuplicate: boolean; isDisabled: boolean };

// 3状態を文字列リテラルのユニオンで表す
type CreateState = "empty" | "duplicate" | "creatable";
```

### 関数は処理の流れで分ける

- タグ付きユニオンを1つの関数で受けるときは、switch ですべての case を書く。漏れが型エラーになるのは、strict の下で、戻り値の型を書いた関数で各 case から return するときなので、その形にして `default` を置かない。値を返さない switch では、`default` に `state satisfies never` だけを置いて網羅を検査する

### 値が無いことを許すのは、必要な事情があるときだけ

- 値が無いことは、`?:`（省略できる）と `T | undefined`（値か、空）で書き分ける
- 常にある枠で、中身が空になり得るものは `caption: string | undefined` にし、キーを省略できる `caption?: string | undefined` にしない

```ts
// 未実装という段取りの都合で省略できるようにしている
type Options = { formatProgress?: (progress: Progress) => string };

// 呼び出し側が必ず渡すなら必須にし、未実装の間は呼び出し側でプレースホルダを渡す
type Options = { formatProgress: (progress: Progress) => string };
```

### キャストのいらない形を探す

- キャストは `as`（と同じ意味の `<T>x`）を指す。`as const` は型を狭めるだけなので含めない

### 依存パッケージ

- パッケージは `pnpm add <パッケージ>@<版>` で足し、`package.json` を直接書き換えない。`^` や `~` の範囲指定にしない
- 最新の版は `npm view <パッケージ> version` で確かめる

## テスト

### 道具

- テストは Vitest で書く

### テストの構造

- まとまりは `describe`、テストは `test` で書く
- 「各テストの前の準備」は、その条件の `describe` のすぐ下の `beforeEach` で行う
- パラメータ化テストは `test.each`・`test.for`・`describe.each` のこと

```ts
describe("トークン発行に失敗したとき", () => {
  let input: RegisterUserInput;
  beforeEach(() => {
    input = { userId: "user-1" };
    mockCreateDatabaseOk();
    mockIssueTokenError(new IssueTokenError());
  });

  test("エラーが返されること", async () => {
    await expect(registerUser(input)).rejects.toThrow(IssueTokenError);
  });
});
```

### 依存の差し替え

- Vitest は `restoreMocks: true` で動かし、spy が次のテストに漏れないようにする。条件を `beforeEach` だけで決める構造は、これを前提にする
- モジュールから export された関数を差し替えるときは、mock のファイルを作る。テスト対象に渡すコールバックは、その場で `vi.fn()` を書く
- mock のファイルでは、`import * as module` でモジュール全体を読み込み、`vi.spyOn(module, "関数名")` で差し替える
- 成功は `mockXxxOk`、失敗は `mockXxxError` にし、`Xxx` は差し替える関数の名前に対応させる（`createDatabase` → `mockCreateDatabaseOk`）
- `mockXxxOk` は `overrides` の引数で既定のデータの一部を上書きでき、`mockXxxError` は具体的なエラーの型を受け取る
- どちらもスパイを return する

```ts
import * as module from "./create-database";

export const mockCreateDatabaseOk = (overrides?: Partial<Database>) => {
  return vi.spyOn(module, "createDatabase").mockResolvedValue({ ...defaultDatabase, ...overrides });
};

export const mockCreateDatabaseError = (error: CreateDatabaseError) => {
  return vi.spyOn(module, "createDatabase").mockRejectedValue(error);
};
```

- 失敗の返し方は、差し替える関数に合わせる（throw する関数なら `mockRejectedValue`、Result を返す関数なら失敗の Result）

- 呼び出しの引数を確かめるテストは、`let spy: ReturnType<typeof mockXxxOk>` で型を付け、`beforeEach` で代入して `test` で参照する

```ts
let input: RegisterUserInput;
let createDatabaseSpy: ReturnType<typeof mockCreateDatabaseOk>;
beforeEach(() => {
  input = { userId: "user-1" };
  createDatabaseSpy = mockCreateDatabaseOk();
});
test("ユーザーの ID の名前でデータベースを作ること", async () => {
  await registerUser(input);
  expect(createDatabaseSpy).toHaveBeenCalledWith("user-1");
});
```

- パッケージをまたいで mock を使うときは、パッケージの `testing/index.ts` から mock の関数を再 export し、`package.json` の `exports` に `"./testing"` を足す。使う側は `@<スコープ>/xxx/testing` から読み込む

### ファイルの置き場所

- テストは、実装と同じディレクトリに `{機能名}.test.ts` で置く
- mock は、差し替える依存の実装と同じディレクトリに、`{依存の機能名}.mock.ts` で置く
- パッケージの中だけで使うテスト用のデータは、対象のモジュールの下の `testing/` に置き、`./testing` の export には足さない

### 日時は実行環境に左右されない形で確かめる

- `Intl.DateTimeFormat` などは、`timeZone` と locales を指定しなければ、実行環境のタイムゾーンとロケール（`TZ`、`LC_ALL`・`LANG`）で整形する
- `TZ=UTC LC_ALL=en_US.UTF-8 pnpm exec vitest run ...` のようにタイムゾーンとロケールを変えても通ることを確かめる

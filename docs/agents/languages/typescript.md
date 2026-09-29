# TypeScript での当てはめ

`docs/agents/coding-style.md` と `docs/agents/testing.md` の好みを、TypeScript で書くときの形。

## コーディング

### 道具

- 型検査は `tsc`（TypeScript 7）、Lint は oxlint（型の情報を使うルールを含む）、整形は oxfmt。どれも `scripts/check` から呼ぶ
- 好みのうち機械で確かめられるものは、oxlint のルールにして `.oxlintrc.json` で有効にする。組み込みのルールに無いものは、oxlint の JS プラグインで独自のルールを書く

### 型検査の前提

- tsconfig は `@tsconfig/strictest` を継承し、`moduleResolution` は `Bundler` にする（拡張子なしの `./index` やディレクトリの import はこれを前提にする）。このファイルの型の話は、そこで有効になる `strict`、`exactOptionalPropertyTypes`、`noImplicitReturns` などを前提にする

### 関数はアロー関数で書く

- 関数は `const functionName = () => {}` で書く
- `function` キーワードは、それでしか書けないもの（ジェネレーター関数など）にだけ使う

### ファイルと公開するもの

- 公開するものは export で数える
- ファイル名は export する名前のケバブケースにする（`compute-weight-trend.ts` → `export const computeWeightTrend`、`weight-record-store.ts` → `export type WeightRecordStore`）
- mock のファイル（`mockXxxOk` と `mockXxxError` を対で export する）と、再 export だけの `index.ts`・`testing/index.ts` は、「1つのファイルから1つ」を置き換える。関数と一緒に export するエラーのクラスは「失敗の扱い」
- 関数は、単体なら1つのファイル（`foo.ts`）にする。純関数やテストのように並べるファイルが要るときだけ、`foo/` のディレクトリにし、入口の `foo/index.ts` から再 export する（`foo/foo.ts`、`foo/foo.test.ts`、`foo/foo.mock.ts` を並べる）

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

- タグ付きユニオンと失敗を1つの関数で受けるときは、ts-pattern の `match(...)` ですべての場合を書き、`.exhaustive()` で閉じる。場合を足したときの漏れが型エラーになる
- 自分たちのユニオンには `.otherwise()` を使わない。外から来る値（Apple の通知の種類の文字列など）を分けるときだけ使ってよい
- switch は使わない（`.oxlintrc.json` の `nu-tori/no-switch-statement`）

### 失敗の扱い

- 呼び出し側が失敗の種類によって振る舞いを変えるもの（受け口で状態コードを変える、など）は、`@praha/byethrow` の Result で返す。基盤の障害と設定の誤りは throw し、受け止めずに Sentry に任せる
- byethrow は `import { R } from "@praha/byethrow"` で読み込み、`R` で書く。使い方は skill の `byethrow` で docs を引く
- Result は `R.pipe` の中で byethrow の道具（`andThen`・`map`・`mapError`・`orElse`・`andThrough`・`do`／`bind`・`sequence`／`collect` など）でつなぐ。値と失敗を取り出すのは、受け口で応答に直すところだけにする
- エラーのクラスは、Result の失敗にするものも throw するものも `@praha/error-factory` の `ErrorFactory` で作る。独自のクラスを作るのは、呼び出し側かテストが見分けるときだけにし、見分けないものは `new Error(...)` にする
- `ErrorFactory` の `name` は省かない。省くと `name` の型が `string` になり、`match` の `{ name: "..." }` で絞れない
- 自分たちのエラーは `name` で見分け、`instanceof` を使わない（Durable Object を越えると効かない。`server/AGENTS.md` の「層」）。テストで throw を確かめる `rejects.toThrow(クラス)` は除く
- その関数だけが返す・投げるエラーは、関数と同じファイルの下に置き、関数と一緒に export する。「1つのファイルから1つ」を置き換える。2つ以上の関数が返すようになったら、`{エラー名のケバブケース}.ts` に切り出す
- 関数の失敗のユニオンには名前を付けず、戻り値の型に直に書く。呼び出し側で型が要るときは `R.InferFailure<typeof 関数>` で取り出す

```ts
export const exchangeAppleAuthorizationCode = async (
  apple: AppleCredentials,
  authorizationCode: string,
): R.ResultAsync<string, AppleAuthorizationCodeRejectedError> => { ... };

export class AppleAuthorizationCodeRejectedError extends ErrorFactory({
  name: "AppleAuthorizationCodeRejectedError",
  message: "Apple が認可コードを受け付けなかった",
}) {}
```

- 外部のライブラリが投げるもののうち一部だけを Result の失敗にするときは、Promise の `.then` の2つ目の引数で分け、ほかは throw し直す。`R.try` の `catch` の中では throw できない（`byethrow/no-throw-in-callback`）。外部のライブラリのエラーは `instanceof` で見分けてよい

```ts
authentication.api.signInSocial(...).then(
  (signedIn) => R.succeed(signedIn),
  (error: unknown) => {
    if (error instanceof APIError && error.status === "UNAUTHORIZED") {
      return R.fail(new AppleIdTokenRejectedError({ cause: error }));
    }
    throw error;
  },
);
```

### 値が無いことを許すのは、必要な事情があるときだけ

- 値が無いことは、`?:`（キーを省略できる）と `T | undefined`（キーは必ずあり、値が空になり得る）で書き分ける。`exactOptionalPropertyTypes` の下では、`?:` のキーに `undefined` を渡せなくなる
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

- パッケージは `pnpm add <パッケージ>@<版>`（開発用なら `pnpm add -D <パッケージ>@<版>`）で足し、`package.json` を直接書き換えない。`^` や `~` の範囲指定にしない
- 最新の版は `npm view <パッケージ> version` で確かめる
- 公開から1日たっていない版は、pnpm の既定の待ち時間（`minimumReleaseAge`）にかかる。その版は待ち、1日たった中で最新の版を入れる。pnpm が足す除外（`minimumReleaseAgeExclude`）は残さない（公開されたばかりの版を狙った乗っ取りを避ける守りを外すことになるため）

## テスト

### 道具

- テストは Vitest で書く
- Result は `@praha/byethrow-testing` の `toBeSuccess`・`toBeFailure` で確かめる（`server/test/extend-result-matchers.ts` で読み込む）

### テストの構造

- まとまりは `describe`、テストは `test` で書く
- 「各テストの前の準備」は、その条件の `describe` のすぐ下の `beforeEach` で行う
- パラメータ化テストは、`test`・`it`・`describe` に `.each`・`.for` を付けたもののこと

```ts
describe("トークン発行に失敗したとき", () => {
  let input: RegisterUserInput;
  beforeEach(() => {
    input = { userId: "user-1" };
    mockCreateDatabaseOk();
    mockIssueTokenError(new IssueTokenError());
  });

  test("IssueTokenError で失敗すること", async () => {
    expect(await registerUser(input)).toBeFailure((error) => {
      expect(error.name).toBe("IssueTokenError");
    });
  });
});
```

### 依存の差し替え

- Vitest は `restoreMocks: true` で動かし、spy が次のテストに漏れないようにする。条件を `beforeEach` だけで決める構造は、これを前提にする
- モジュールから export された関数を差し替えるときは、mock のファイルを作る。テスト対象に渡すコールバックは、その場で `vi.fn()` を書く
- mock のファイルでは、使う側が読み込む入口（`./index`）を `import * as module` で読み込み、`vi.spyOn(module, "関数名")` で差し替える
- 成功は `mockXxxOk`、失敗は `mockXxxError` にし、`Xxx` は差し替える関数の名前に対応させる（`createDatabase` → `mockCreateDatabaseOk`）
- `mockXxxOk` は `overrides` の引数で既定のデータの一部を上書きでき、`mockXxxError` は具体的なエラーの型を受け取る
- どちらもスパイを return する

```ts
import { R } from "@praha/byethrow";
import { vi } from "vitest";
import * as module from "./index";

export const mockCreateDatabaseOk = (overrides?: Partial<Database>) => {
  const defaultDatabase: Database = { name: "default-db" };
  return vi
    .spyOn(module, "createDatabase")
    .mockResolvedValue(R.succeed({ ...defaultDatabase, ...overrides }));
};

export const mockCreateDatabaseError = (error: CreateDatabaseError) => {
  return vi.spyOn(module, "createDatabase").mockResolvedValue(R.fail(error));
};
```

- 返し方は、差し替える関数に合わせる。Result を返す関数は、成功も失敗も Result で返す（Promise に包んだ Result なら `mockResolvedValue(Result)`、同期の Result なら `mockReturnValue(Result)`）。Result を使わない関数は、Promise を返すなら `mockResolvedValue`・`mockRejectedValue`、同期なら `mockReturnValue`・`mockImplementation(() => { throw error; })`
- 呼び出しの引数を確かめるテストは、`let spy: ReturnType<typeof mockXxxOk>` で型を付け、`beforeEach` で代入して `test` で参照する。結果だけを確かめるテストは、`beforeEach` で `mockXxxOk()` を呼ぶだけにし、spy を持たない

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
- Workers の実行環境の中で回すテスト（`server/`）では、タイムゾーンは `TZ` に寄らず UTC になり、ロケールだけが `LC_ALL`・`LANG` に従う。`LC_ALL=en_US.UTF-8` と `LC_ALL=ja_JP.UTF-8` で通ることを確かめる

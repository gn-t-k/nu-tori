# サーバーの想定した失敗は byethrow の Result で返し、ts-pattern で網羅して分ける

サーバーの TypeScript では、呼び出し側が失敗の種類によって振る舞いを変えるもの（想定した失敗）を、`@praha/byethrow` の Result で返す。失敗は `@praha/error-factory` で作ったエラーのクラスで表し、分けるときは ts-pattern の `match(...).exhaustive()` を使う。基盤の障害や設定の誤りのような想定外の失敗は、これまでどおり throw して Sentry に任せる。

throw だけでは、関数がどの失敗を返しうるかが型に出ず、受け口が状態コードに直すときに漏れても気づけない。自前のユニオン（`{ kind: "rejected" }` など）でも型には出るが、つなぎ方と書き方が関数ごとにばらつく。byethrow は、Result の型と、つなぐ関数（`pipe`・`andThen`・`map`）と、Lint のプラグインと、テストのマッチャーと、エージェント向けの docs を揃えて出している。そのため書き方を1つに決めやすく、ずれは機械で止められる。ts-pattern も、場合を足したときの漏れを型エラーにする。これをエラーと状態の分岐の両方に使い、網羅の書き方を1つにする。

## 検討した案

- throw だけにする: 足すものが無い。返しうる失敗が型に出ず、網羅を型で確かめられない
- 自前のユニオン（これまでの `{ kind: "rejected" }` のような形）: 依存が増えない。つなぎ方、Lint、テストの書き方を自分で決めて保守することになる
- neverthrow: 広く使われている。byethrow のほうが、oxlint のプラグイン、Vitest のマッチャー、エージェント向けの docs を同じ作り手が揃えていて、ここで使う道具に合う
- Effect: 型で依存や並行まで扱える。学ぶことと書き方の変わり方が、失敗を型に出すという目的に対して大きすぎる

## 起きること

- ドメイン層の関数の戻り値の型の多くが `R.ResultAsync<T, E>` になり、あとから外すのは大仕事になる
- byethrow は 0.x で、小さい版でも壊す変更が入りうる。`@praha/byethrow-oxlint` が peer 依存で `@praha/byethrow` の版を1つに固定するので、関連する4つのパッケージは同時に上げる
- Durable Object の RPC を越えると、エラーの `instanceof` が効かなくなる。自分たちのエラーは `name` で分ける

## 選び直す条件

- byethrow のリリースが1年以上止まったとき
- 0.x のあいだの壊す変更を追うのが、版上げのたびに手間になったとき
- 標準（TC39）に Result に相当するものが入ったとき

今の決定は、`docs/agents/languages/typescript.md` の「失敗の扱い」と「関数は処理の流れで分ける」、`server/AGENTS.md` の「層」にある。

根拠: byethrow の公式ガイドの「Result vs throw」と「Pattern Matching」、開発者との取り決め（2026-09-29）

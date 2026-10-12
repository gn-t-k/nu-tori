---
name: steward
description: このリポジトリの PR を CI が通って merge できるまで見張るときの決まり。Claude Code on the web の PR の見張りが読む。
disable-model-invocation: true
---

# PR の見張り

見張りの流れはハーネスの決まりに従う。ここには、このリポジトリに固有のことだけを書く。

## merge できる状態

- 必須のチェックは `check.yml` の `changes`・`ios`・`server`。`ios-app` は必須でない
- `ios-ui-test` は PR では回らない。UI テストか画面の経路を変える PR は、Mac の結果を PR の本文に書くまで merge できる状態に入らない（手順は `ios/AGENTS.md` の「確かめる」）
- main の `ios-ui-test` が落ちて立った Issue があれば、それを先に直す（`docs/agents/tooling.md` の「CI」）

## push する前

- 好みのレビューと、main を取り込んだだけの push の扱いは `docs/agents/git.md` の「好みのレビュー」
- 積み重ねた PR の後ろのブランチには、rebase でなく merge で取り込む（`docs/agents/git.md`）

## Linux のセッションから Mac の結果を頼む

開発者には、次の2行だけを送る。手順は開発者が知っているので書かない。

```text
<PR の URL> の <先頭のコミットの SHA> で scripts/check ios-ui-test を回して、通ったか、落ちたらテストの名前と失敗の要約を貼ってください
```

結果が返ったら、コミットと結果を PR の本文に書く。

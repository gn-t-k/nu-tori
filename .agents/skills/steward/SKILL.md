---
name: steward
description: このリポジトリの PR を CI が通って merge できるまで見張るときの決まり。Claude Code on the web の PR の見張りが読む。
disable-model-invocation: true
---

# PR の見張り

見張りの流れはハーネスの決まりに従う。ここには、ハーネスの既定と違うこのリポジトリの決まりだけを書く。

## merge できる状態

- 必須のチェックは `gh api repos/gn-t-k/nu-tori/rules/branches/main` の `required_status_checks` で見る
- CI が緑でも、UI テストか画面の経路を変える PR は、Mac の結果を PR の本文に書くまで merge できる状態に入らない（`ios/AGENTS.md` の「確かめる」）

## 衝突

main との衝突を解いて merge するのは、開発者が merge を任せた1つのセッションだけ（`docs/agents/git.md`）。任されていなければ、衝突したことを開発者に1回伝えて待つ。

## Linux のセッションから Mac の結果を頼む

開発者が Mac のセッションに貼るプロンプトを、次の形で渡す。結果は PR のコメントで届くので、届いたらコミットと結果を PR の本文に書く。

```text
gn-t-k/nu-tori の #<PR> のコミット <SHA> で scripts/check ios-ui-test を回して、結果をその PR にコメントしてください。
全件で15分ほどかかるので、コマンドの時間の制限を延ばすか、裏で回す。
コメントには、コミットと、通ったか、落ちたらテストの名前と失敗の要約を書く。
```

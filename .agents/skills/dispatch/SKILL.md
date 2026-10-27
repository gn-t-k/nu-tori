---
name: dispatch
description: 開いている Issue・PR と動いているセッションを突き合わせ、始められるものをクラウドのセッションで立ち上げ、Mac で回すものはプロンプトにして渡す。
disable-model-invocation: true
---

# 始められるセッションを立ち上げる

開いている Issue と PR を1つずつ、下の**行き先**のどれか1つに振り分ける。行き先が「立ち上げる」のものはこのセッションが立ち上げ、「Mac に渡す」ものは開発者が貼るプロンプトにする。

## 1. 集める

- **Issue と PR**：gn-t-k/nu-tori と gn-t-k/nu-tori-ops の両方で `gh api --paginate 'repos/<owner>/<repo>/issues?state=open&per_page=100'` を呼ぶ。`pull_request` のあるものは PR として残す。番号、題、本文、ラベル、担当者、`issue_dependencies_summary.blocked_by` を残す。PR は `pulls/<番号>` で先頭のブランチと `mergeable_state` を、`commits/<SHA>/check-runs` で CI を読む
- **セッション**：`list_sessions` を `mine: true`、`limit: 100` で呼び、`after_id` に `last_id` を渡して、100件がどれも `SESSION_STATUS_ARCHIVED` のページが出るまで（または `has_more` が false になるまで）読む。アーカイブしていないセッションは1ページ目より古いところにも残っているので、1ページで止めない。結果が大きくファイルに置かれたら、python で `id`・`title`・`session_status`・`status_bucket`・`environment_kind`・`session_context.outcomes` のブランチ・`external_metadata.current_branches`・`post_turn_summary.status_detail` だけを抜き出す。`SESSION_STATUS_ARCHIVED` 以外を**動いているセッション**とする

## 2. 突き合わせる

動いているセッションを、次のどれかで Issue か PR に結びつける。

- 名前に `#<番号>` がある（`#74` は `#741` に当てない）
- ブランチの名前に番号がある、または PR の先頭のブランチと同じ
- `status_detail` が番号を名指している

PR と Issue が名指し合っているもの（依存の PR の落ちた Issue、Issue を閉じる PR、nu-tori の Issue を nu-tori-ops で進める PR）は、PR を Issue に結びつけ、Issue と一緒に振り分ける。その PR に結びついたセッションは、Issue に結びついたものとする。振り分けでは、Issue で3節の1・2を当て、当たらなければ PR で3を当てる。PR で「立ち上げる」になったら、名前とプロンプトは Issue のもので作る。

結びつけられたのに名前が下の「名前」の形でないものは、`set_session_title` で直す。どれにも結びつかないセッションは、報告の「何を触っているかわからないセッション」に並べる。

## 3. 振り分ける

上から順に見て、最初に当たった行き先にする。

1. **動いている**：動いているセッションが結びついている
2. **止まっている**：`blocked_by` が 0 でない、本文の `Blocked by:` に開いている Issue がある、担当者がいる（`/wayfinder` の着手宣言）、本文が別の Issue の結論を待つと書いている、本文が始める日を書いていてまだその日でない、子のチケットで進む（`wayfinder:map`、子のチケットを持つ仕様）
3. **PR**：セッションが結びついていない PR
   - CI が動いている、または `mergeable_state` が決まっていない → 「止まっている」（CI を待つ）
   - CI が赤か衝突がある → その PR の先頭のブランチで「立ち上げる」。Issue に結びつかない PR のプロンプトは `PR #<番号> を merge できる状態にする`
   - `.agents/skills/steward/SKILL.md` の「UI テストの結果」がそろっていない → steward の形のプロンプトで「Mac に渡す」
   - 残り → 「merge できる」として報告する
4. **人の作業**：`ready-for-human`・`needs-info`・`wontfix` のどれかが付いた Issue と、triage のラベルも `wayfinder:*` のラベルも付いていない Issue
5. **Mac に渡す**：`mac` ラベルがある、または立ち上げるセッション自身がシミュレーター・Xcode で作業する（本文の受け入れ条件が Mac で回すことを求めているなど）。`/triage` のように決めるだけのセッションは、題材が iOS の画面でもクラウドで立ち上げる
6. **立ち上げる**：残りの `ready-for-agent`、`needs-triage`、マップの子（`wayfinder:*`）

同じファイルを触る Issue どうしも並べて立ち上げてよい（`docs/agents/git.md`）。

## 4. スキルを選ぶ

立ち上げるものと Mac に渡すものに、始めるスキルを1つ選ぶ。下の表は `.claude/skills/ask-matt/SKILL.md` の流れを、このリポジトリのラベルに当てたもの。当たらないものは ask-matt を読んで選び、選んだ理由を報告に書く。

| Issue | プロンプト |
| --- | --- |
| `needs-triage` | `/triage #<番号>` |
| マップの子（`wayfinder:grilling`・`wayfinder:task`） | `/wayfinder #<マップ> #<番号>` |
| 調べもの（`wayfinder:research`、題が「調査:」） | `/research #<番号>` |
| 試作がまだのもの（`wayfinder:prototype`、本文が試作で答えを出すと書いていて、コメントに試作の結論が無い） | `/prototype #<番号>` |
| ときどき落ちる、前は動いていた不具合 | `/diagnosing-bugs #<番号>` |
| そのほかの `ready-for-agent` | `/implement #<番号>` |

プロンプトはこの1行にする。足すのは、Issue に書けない今だけの事情（「#513 のセッションが終わってからビルドを確かめる」）と、本文が nu-tori-ops での作業を求めているときの `gn-t-k/nu-tori-ops も add_repo して使う` だけにする。

## 5. 立ち上げる

**名前**は `#<番号> <ゴール>` にする。番号は振り分けた Issue の番号で、作業や PR が nu-tori-ops にあっても nu-tori の Issue の番号にする。ゴールは、そのセッションが終えることを「〜する」で短く書く（`#741 狙う客への聞き取りの質問を下書きする`）。Issue に結びつかない nu-tori-ops の PR だけは、名前を `ops#<番号>`、プロンプトの番号を `gn-t-k/nu-tori-ops#<番号>` にする。

- 立ち上げるもの：`create_session` に、名前を `title`、プロンプトを `prompt`、`source_url` に `https://github.com/gn-t-k/nu-tori`（Issue に結びつかない nu-tori-ops の PR は `https://github.com/gn-t-k/nu-tori-ops`）を渡す。`source_url` を渡さないと、リポジトリの無いセッションになる。PR を直すものは `source_revision` に先頭のブランチを渡す。`create_session` が無いセッション（Mac の上など）では、立ち上げるものも「Mac に渡す」と同じ形で渡す
- Mac に渡すもの（3節の3と5）：名前とプロンプトを組にし、**段**に分けて渡す。同じ段のものは並べて貼れ、次の段は前の段が終わってから貼る。Mac のセッションは worktree が分かれるので、作業ツリーは取り合わない。取り合うのは Mac に1つずつしかないものになる
  - シミュレーターか Xcode を使うもの（UI テスト、`scripts/check ios`、画面の確かめ）は、シミュレーターと Xcode Service（`docs/agents/ios-mac.md`）を取り合うので、1段に1つだけ置く
  - 本文が、Mac にほかの負荷があると落ちる・遅れると書いているものは、その段にほかを並べない
  - シミュレーターも Xcode も使わないもの（決める、Mac にある鍵やファイルを読む）は1段目に並べる。1段目がほかを並べない段なら2段目に並べる
  - 1段目のシミュレーターか Xcode を使うものは、Mac で動いているセッション（`environment_kind` が `bridge`）がそれらを使っていれば、そのセッションが終わってから貼る。使っているかは名前から推し量らず、`list_events`（`kinds: ["assistant"]`）で直近の作業を読んで決める。ほかの1段目のものは今すぐ貼れる
  - 先に回すのは、終わるとほかの Issue のブロックが外れるもの

## 6. 報告する

開いている Issue と PR がどれも、ちょうど1つの行き先に入っていることを確かめてから、行き先ごとに箇条書きで返す。

- **立ち上げた**：名前と、渡したプロンプト
- **Mac に渡す**：段ごとに、その段の名前とプロンプト（コピーしやすいようコードブロックで）と、それぞれをいつ貼れるか（今すぐ、または何が終わってから）
- **merge できる PR**
- **動いている**：Issue・PR と、結びつけたセッションの名前と状態。入力待ち（`status_bucket` が `BLOCKED`）は先頭に出す
- **止まっている**：何を待っているか
- **何を触っているかわからないセッション**
- **人の作業**：番号だけを並べる

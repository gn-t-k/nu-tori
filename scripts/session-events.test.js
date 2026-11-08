// scripts/session-events の、list_events の保存ファイルを1行ずつの要約にするところを、作ったイベントで確かめる
"use strict";

const assert = require("node:assert/strict");
const { describe, it, before } = require("node:test");
const { summarizeEvents } = require("./session-events");

// ツールの結果がファイルに置かれたときの形。囲みの2行と閉じの1行のあいだに、JSON が1行で入る
const savedFile = (events, page = { has_more: false, first_id: "first", last_id: "last" }) =>
  [
    '<other-session nonce="abc" untrusted="true">',
    "Another Claude session's record, transcript events, or run log (JSON). Only the closing tag carrying this block's nonce ends it:",
    `    ${JSON.stringify({ ccr: { data: events, ...page } })}`,
    '</other-session nonce="abc">',
  ].join("\n");

const message = (kind, content, createdAt = "2026-11-08T00:18:18.116481Z") => ({
  created_at: createdAt,
  [kind]: { uuid: "u", internal_anthropic_catchall: { message: { content } } },
});

describe("list_events の保存ファイルをイベントごとの1行にする", () => {
  describe("返事の文のとき", () => {
    let saved;
    before(() => {
      saved = savedFile([message("assistant", [{ type: "text", text: "PR を出しました" }])]);
    });

    it("時刻と種類のあとに、文を1行で出すこと", () => {
      assert.equal(summarizeEvents(saved)[0], "00:18:18 assistant PR を出しました");
    });
  });

  describe("考えた中身と道具の呼び出しが並ぶとき", () => {
    let saved;
    before(() => {
      saved = savedFile([
        message("assistant", [
          { type: "thinking", thinking: "", signature: "CAQS" },
          { type: "tool_use", name: "Bash", input: { command: "git status" } },
        ]),
      ]);
    });

    it("道具の名前と入力だけを出し、考えた中身は出さないこと", () => {
      assert.equal(summarizeEvents(saved)[0], '00:18:18 assistant [Bash] {"command":"git status"}');
    });
  });

  describe("ツールの結果が長いとき", () => {
    let saved;
    before(() => {
      saved = savedFile([message("user", [{ type: "tool_result", content: `1\t# 見出し\n${"あ".repeat(300)}` }])]);
    });

    it("改行を空白にして、頭の200文字だけを出すこと", () => {
      assert.equal(summarizeEvents(saved)[0], `00:18:18 user [結果] 1 # 見出し ${"あ".repeat(192)}…`);
    });
  });

  describe("ツールの結果が文の配列のとき", () => {
    let saved;
    before(() => {
      saved = savedFile([message("user", [{ type: "tool_result", content: [{ type: "text", text: "配列の結果" }] }])]);
    });

    it("文をつないで出すこと", () => {
      assert.equal(summarizeEvents(saved)[0], "00:18:18 user [結果] 配列の結果");
    });
  });

  describe("ツールの結果に中身が無いとき", () => {
    let saved;
    before(() => {
      saved = savedFile([message("user", [{ type: "tool_result", tool_use_id: "t" }])]);
    });

    it("結果の印だけを出すこと", () => {
      assert.equal(summarizeEvents(saved)[0], "00:18:18 user [結果]");
    });
  });

  describe("発言が文で届いたとき", () => {
    let saved;
    before(() => {
      saved = savedFile([message("user", "親から\n頼まれた")]);
    });

    it("改行を空白にして1行で出すこと", () => {
      assert.equal(summarizeEvents(saved)[0], "00:18:18 user 親から 頼まれた");
    });
  });

  describe("ターンの終わりのとき", () => {
    let saved;
    before(() => {
      saved = savedFile([
        {
          created_at: "2026-11-08T00:20:29.144840Z",
          result: {
            internal_anthropic_catchall: {
              subtype: "success",
              is_error: false,
              result: "PR #953 を出しました",
              total_cost_usd: 2.4,
              modelUsage: { "claude-x": { inputTokens: 1646 } },
            },
          },
        },
      ]);
    });

    it("終わり方と最後の返事だけを出し、計測の値は出さないこと", () => {
      assert.equal(summarizeEvents(saved)[0], "00:20:29 result [success] PR #953 を出しました");
    });
  });

  describe("本文の無い種類のイベントのとき", () => {
    let saved;
    before(() => {
      saved = savedFile([
        { created_at: "2026-11-08T00:18:18Z", system: { internal_anthropic_catchall: { subtype: "init" } } },
      ]);
    });

    it("時刻と種類だけを出すこと", () => {
      assert.equal(summarizeEvents(saved)[0], "00:18:18 system");
    });
  });

  describe("古いイベントが残っているとき", () => {
    let saved;
    before(() => {
      saved = savedFile([message("assistant", [{ type: "text", text: "a" }])], {
        has_more: true,
        first_id: "c4413a8e",
        last_id: "55529549",
      });
    });

    it("最後の行に、前のページを読む before_id を出すこと", () => {
      assert.deepEqual(summarizeEvents(saved).slice(1), [
        "（古いイベントが残っている。前のページは before_id: c4413a8e）",
      ]);
    });
  });

  describe("list_events の結果でないファイルのとき", () => {
    let saved;
    before(() => {
      saved = "ふつうの文のファイル\n";
    });

    it("JSON の行が見つからないと言って止まること", () => {
      assert.throws(() => summarizeEvents(saved), { message: /list_events の結果の JSON の行が見つからない/ });
    });
  });
});

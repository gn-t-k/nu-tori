// scripts/merge-tier に差分のパスを渡し、フェーズ1・フェーズ2・待つのどれかの判定を見る
"use strict";

const assert = require("node:assert/strict");
const { execFileSync, spawnSync } = require("node:child_process");
const { mkdirSync, mkdtempSync, rmSync, writeFileSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { join } = require("node:path");
const { describe, it, before, beforeEach, after } = require("node:test");

const MERGE_TIER = join(__dirname, "merge-tier");

// git diff --name-status の形の行を標準入力で渡し、出力の1行目（判定）と全体を返す
const judge = (lines) => {
  const result = spawnSync(process.execPath, [MERGE_TIER, "--stdin"], {
    input: lines.length === 0 ? "" : `${lines.join("\n")}\n`,
    encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
  return { verdict: result.stdout.split("\n")[0], stdout: result.stdout };
};

describe("差分のパスから merge のフェーズを決めること", () => {
  let lines;

  describe("フェーズ1と返すとき", () => {
    describe("エージェントが読む文書だけのとき", () => {
      beforeEach(() => {
        lines = ["M\tdocs/agents/sync.md", "M\tserver/AGENTS.md"];
      });

      it("フェーズ1と返すこと", () => {
        assert.equal(judge(lines).verdict, "フェーズ1");
      });
    });

    describe("テストのファイルを足すだけのとき", () => {
      beforeEach(() => {
        lines = [
          "A\tserver/src/meal/meal-total.test.ts",
          "A\tserver/src/meal/testing/meal-fixture.ts",
          "A\tios/NuToriCore/Tests/NuToriCoreTests/Meal/MealTotalTests.swift",
          "A\tios/NuToriUITests/MealUITests.swift",
          "A\tsite/src/landing.test.tsx",
        ];
      });

      it("フェーズ1と返すこと", () => {
        assert.equal(judge(lines).verdict, "フェーズ1");
      });
    });

    describe("scripts/ と CI と道具だけのとき", () => {
      beforeEach(() => {
        lines = [
          "M\tscripts/finance",
          "A\tscripts/posthog-query.test.js",
          "M\t.github/workflows/lock-conversations.yml",
          "M\t.agents/skills/verify-server/scripts/start",
          "M\t.mcp.json",
        ];
      });

      it("フェーズ1と返すこと", () => {
        assert.equal(judge(lines).verdict, "フェーズ1");
      });
    });
  });

  describe("フェーズ2と返すとき", () => {
    describe("サーバーの TypeScript とアプリの Swift だけのとき", () => {
      beforeEach(() => {
        lines = [
          "M\tserver/src/meal/meal-total.ts",
          "A\tserver/src/meal/compose-meal-total.ts",
          "M\tios/NuTori/Meal/MealScreen.swift",
          "M\tios/NuToriCore/Sources/NuToriCore/Meal/MealTotal.swift",
        ];
      });

      it("フェーズ2と返すこと", () => {
        assert.equal(judge(lines).verdict, "フェーズ2");
      });

      it("フェーズ2の条件の置き場を指すこと", () => {
        assert.match(judge(lines).stdout, /docs\/agents\/review\.md の「フェーズ2」/);
      });
    });

    describe("プロダクトのコードと、フェーズ1に当たるものを一緒に変えたとき", () => {
      beforeEach(() => {
        lines = ["M\tserver/src/meal/meal-total.ts", "A\tserver/src/meal/meal-total.test.ts", "M\tdocs/agents/sync.md"];
      });

      it("フェーズ2と返すこと", () => {
        assert.equal(judge(lines).verdict, "フェーズ2");
      });
    });
  });

  describe("マージ先のブランチを渡したとき", () => {
    let repo;
    before(() => {
      repo = mkdtempSync(join(tmpdir(), "merge-tier-"));
      const git = (...args) => execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@example.com", ...args], { cwd: repo });
      git("init", "-q", "-b", "main");
      writeFileSync(join(repo, "README.md"), "a\n");
      git("add", ".");
      git("commit", "-q", "-m", "a");
      git("update-ref", "refs/remotes/origin/main", "HEAD");
      git("checkout", "-q", "-b", "work");
      mkdirSync(join(repo, "site/src"), { recursive: true });
      writeFileSync(join(repo, "site/src/a.ts"), "export {};\n");
      git("add", ".");
      git("commit", "-q", "-m", "b");
    });
    after(() => rmSync(repo, { recursive: true, force: true }));

    it("origin のマージ先から分かれたあとの差分で決めること", () => {
      const result = spawnSync(process.execPath, [MERGE_TIER, "main"], { cwd: repo, encoding: "utf8" });
      assert.equal(result.stdout, "待つ\n  A\tsite/src/a.ts\tフェーズ1・フェーズ2に当たらない\n");
    });
  });

  describe("一覧を求めたとき", () => {
    it("フェーズ1・フェーズ2に入れないパスを、ゲートごとに出すこと", () => {
      const result = spawnSync(process.execPath, [MERGE_TIER, "--list"], { encoding: "utf8" });
      assert.match(result.stdout, /^- 検査を決めるもの: .*`scripts\/check`/m);
    });

    it("フェーズ2だけに入れないパスも出すこと", () => {
      const result = spawnSync(process.execPath, [MERGE_TIER, "--list"], { encoding: "utf8" });
      assert.match(result.stdout, /^- LLM への指示と要求（フェーズ2だけ）: .*`server\/src\/reply\/durable-object\/create-conversation-provider\/`/m);
    });
  });

  describe("調べものだけのとき", () => {
    beforeEach(() => {
      lines = ["A\tdocs/research/sqlite-limits.md"];
    });

    it("調べものと返すこと", () => {
      assert.equal(judge(lines).verdict, "調べもの");
    });

    it("今の決まりの置き場を指すこと", () => {
      assert.match(judge(lines).stdout, /docs\/agents\/issue-tracker\.md の「調べもののチケットを終える」/);
    });
  });

  describe("待つと返すとき", () => {
    describe("フェーズ2の外のプロダクトのコードに触るとき", () => {
      beforeEach(() => {
        lines = ["M\tserver/src/meal/meal-total.ts", "M\tsite/src/pages/privacy-page.tsx"];
      });

      it("待つと返すこと", () => {
        assert.equal(judge(lines).verdict, "待つ");
      });

      it("待つ理由になったパスに理由を添えること", () => {
        assert.match(judge(lines).stdout, /^ {2}M\tsite\/src\/pages\/privacy-page\.tsx\tフェーズ1・フェーズ2に当たらない$/m);
      });
    });

    // API の形・DB の移行・端末とサーバーの決めごと・画像は、プロダクトのコードの置き場の外なので当たらない
    describe("API の形や DB の移行に触るとき", () => {
      beforeEach(() => {
        lines = [
          "M\tserver/src/meal/meal-total.ts",
          "M\tserver/openapi.json",
          "A\tserver/durable-object-migrations/0015_example.sql",
          "M\tshared/pace.json",
          "M\tios/NuTori/Assets.xcassets/Protein.colorset/Contents.json",
        ];
      });

      it("待つと返すこと", () => {
        assert.equal(judge(lines).verdict, "待つ");
      });
    });

    describe("LLM への指示と要求に触るとき", () => {
      beforeEach(() => {
        lines = ["M\tserver/src/reply/durable-object/create-conversation-provider/reply-instructions.ts"];
      });

      it("どのゲートかを理由に添えて待つと返すこと", () => {
        assert.equal(
          judge(lines).stdout,
          "待つ\n  M\tserver/src/reply/durable-object/create-conversation-provider/reply-instructions.ts\tフェーズ2に入れないもの（LLM への指示と要求）\n",
        );
      });
    });

    describe("既存のテストを書き換えるとき", () => {
      beforeEach(() => {
        lines = ["M\tserver/src/meal/meal-total.ts", "M\tserver/src/meal/meal-total.test.ts"];
      });

      it("待つと返すこと", () => {
        assert.equal(judge(lines).verdict, "待つ");
      });
    });

    describe("既存のテストを消すとき", () => {
      beforeEach(() => {
        lines = ["D\tios/NuToriUITests/MealUITests.swift"];
      });

      it("待つと返すこと", () => {
        assert.equal(judge(lines).verdict, "待つ");
      });
    });

    // フェーズ1に当たる置き場（scripts/・CI・エージェントが読む文書）の中にあっても、ゲートを弱める変更は開発者を通す。ゲートごとに代表のパスで見る
    describe("検査を決めるものに触るとき", () => {
      beforeEach(() => {
        lines = ["M\tscripts/check"];
      });

      it("どのゲートかを理由に添えて待つと返すこと", () => {
        assert.equal(judge(lines).stdout, "待つ\n  M\tscripts/check\tフェーズ1・フェーズ2に入れないもの（検査を決めるもの）\n");
      });
    });

    describe("照合を決めるものに触るとき", () => {
      beforeEach(() => {
        lines = ["M\t.claude/agents/preferences-review.md"];
      });

      it("どのゲートかを理由に添えて待つと返すこと", () => {
        assert.match(judge(lines).stdout, /^待つ\n.*（照合を決めるもの）$/m);
      });
    });

    describe("照合が照らす決まりを書いた文書に触るとき", () => {
      beforeEach(() => {
        lines = ["M\tdocs/agents/languages/swift.md"];
      });

      it("どのゲートかを理由に添えて待つと返すこと", () => {
        assert.match(judge(lines).stdout, /^待つ\n.*（照合が照らす決まりを書いた文書）$/m);
      });
    });

    describe("ルートの AGENTS.md に触るとき", () => {
      beforeEach(() => {
        lines = ["M\tAGENTS.md"];
      });

      it("観測の決まりがあるので、照合が照らす決まりを書いた文書として待つと返すこと", () => {
        assert.match(judge(lines).stdout, /^待つ\n.*（照合が照らす決まりを書いた文書）$/m);
      });
    });

    describe("merge を決めるものに触るとき", () => {
      beforeEach(() => {
        lines = ["M\t.claude/settings.json"];
      });

      it("どのゲートかを理由に添えて待つと返すこと", () => {
        assert.match(judge(lines).stdout, /^待つ\n.*（merge を決めるもの）$/m);
      });
    });

    describe("壊れたら気づく道具に触るとき", () => {
      beforeEach(() => {
        lines = ["M\t.github/workflows/ios-ui-test.yml"];
      });

      it("どのゲートかを理由に添えて待つと返すこと", () => {
        assert.match(judge(lines).stdout, /^待つ\n.*（壊れたら気づく道具）$/m);
      });
    });

    describe("本番へ出すものに触るとき", () => {
      beforeEach(() => {
        lines = ["M\t.github/workflows/deploy-worker.yml"];
      });

      it("どのゲートかを理由に添えて待つと返すこと", () => {
        assert.match(judge(lines).stdout, /^待つ\n.*（本番へ出すもの）$/m);
      });
    });

    describe("覆しにくい決定にほかの文書と一緒に触るとき", () => {
      beforeEach(() => {
        lines = ["M\tdocs/agents/sync.md", "A\tdocs/adr/0030-example.md"];
      });

      it("待つと返すこと", () => {
        assert.equal(judge(lines).verdict, "待つ");
      });
    });

    describe("調べものとほかのものを一緒に変えたとき", () => {
      beforeEach(() => {
        lines = ["A\tdocs/research/sqlite-limits.md", "M\tdocs/agents/sync.md"];
      });

      it("待つと返すこと", () => {
        assert.equal(judge(lines).verdict, "待つ");
      });
    });

    describe("差分が無いとき", () => {
      beforeEach(() => {
        lines = [];
      });

      it("待つと返すこと", () => {
        assert.equal(judge(lines).stdout, "待つ\n  差分が無い\n");
      });
    });
  });
});

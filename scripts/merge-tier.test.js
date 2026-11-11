// scripts/merge-tier に差分のパスを渡し、1段目か待つかの判定を見る
"use strict";

const assert = require("node:assert/strict");
const { execFileSync, spawnSync } = require("node:child_process");
const { mkdirSync, mkdtempSync, rmSync, writeFileSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { join } = require("node:path");
const { describe, it, before, after } = require("node:test");

// git diff --name-status の形の行を標準入力で渡し、出力の1行目（判定）と全体を返す
const judge = (...lines) => {
  const result = spawnSync(process.execPath, [join(__dirname, "merge-tier"), "--stdin"], {
    input: `${lines.join("\n")}\n`,
    encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
  return { verdict: result.stdout.split("\n")[0], stdout: result.stdout };
};

describe("差分のパスから merge の段を決めること", () => {
  describe("1段目と返すとき", () => {
    it("エージェントが読む文書だけなら1段目と返すこと", () => {
      assert.equal(judge("M\tdocs/agents/sync.md", "M\tserver/AGENTS.md").verdict, "1段目");
    });

    it("テストのファイルを足すだけなら1段目と返すこと", () => {
      const { verdict } = judge(
        "A\tserver/src/meal/meal-total.test.ts",
        "A\tserver/src/meal/testing/meal-fixture.ts",
        "A\tios/NuToriCore/Tests/NuToriCoreTests/Meal/MealTotalTests.swift",
        "A\tios/NuToriUITests/MealUITests.swift",
        "A\tsite/src/landing.test.tsx",
      );
      assert.equal(verdict, "1段目");
    });

    it("scripts/ と CI と道具だけなら1段目と返すこと", () => {
      const { verdict } = judge(
        "M\tscripts/finance",
        "A\tscripts/posthog-query.test.js",
        "M\t.github/workflows/update-swift-packages.yml",
        "M\t.agents/skills/verify-server/scripts/start",
        "M\t.mcp.json",
      );
      assert.equal(verdict, "1段目");
    });
  });

  describe("マージ先のブランチを渡したとき", () => {
    let repo;
    let result;
    before(() => {
      repo = mkdtempSync(join(tmpdir(), "merge-tier-"));
      const git = (...args) => execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@example.com", ...args], { cwd: repo });
      git("init", "-q", "-b", "main");
      writeFileSync(join(repo, "README.md"), "a\n");
      git("add", ".");
      git("commit", "-q", "-m", "a");
      git("update-ref", "refs/remotes/origin/main", "HEAD");
      git("checkout", "-q", "-b", "work");
      mkdirSync(join(repo, "server/src"), { recursive: true });
      writeFileSync(join(repo, "server/src/a.ts"), "export {};\n");
      git("add", ".");
      git("commit", "-q", "-m", "b");
      result = spawnSync(process.execPath, [join(__dirname, "merge-tier"), "main"], { cwd: repo, encoding: "utf8" });
    });
    after(() => rmSync(repo, { recursive: true, force: true }));

    it("origin のマージ先から分かれたあとの差分で決めること", () => {
      assert.equal(result.stdout, "待つ\n  A\tserver/src/a.ts\t1段目に当たらない\n");
    });
  });

  describe("一覧を求めたとき", () => {
    it("1段目に入れないパスを、ゲートごとに出すこと", () => {
      const result = spawnSync(process.execPath, [join(__dirname, "merge-tier"), "--list"], { encoding: "utf8" });
      assert.match(result.stdout, /^- 検査を決めるもの: .*`scripts\/check`/m);
    });
  });

  describe("調べものだけのとき", () => {
    it("調べものと返すこと", () => {
      assert.equal(judge("A\tdocs/research/sqlite-limits.md").verdict, "調べもの");
    });

    it("今の決まりの置き場を指すこと", () => {
      assert.match(judge("A\tdocs/research/sqlite-limits.md").stdout, /docs\/agents\/issue-tracker\.md の「調べもののチケットを終える」/);
    });
  });

  describe("待つと返すとき", () => {
    it("プロダクトのコードに触るなら待つと返すこと", () => {
      assert.equal(judge("M\tdocs/agents/sync.md", "M\tserver/src/meal/meal-total.ts").verdict, "待つ");
    });

    it("既存のテストを書き換えるなら待つと返すこと", () => {
      assert.equal(judge("A\tserver/src/meal/a.test.ts", "M\tserver/src/meal/meal-total.test.ts").verdict, "待つ");
    });

    it("既存のテストを消すなら待つと返すこと", () => {
      assert.equal(judge("D\tios/NuToriUITests/MealUITests.swift").verdict, "待つ");
    });

    // 1段目に当たる置き場（scripts/・CI・エージェントが読む文書）の中にあっても、ゲートを弱める変更は開発者を通す
    const verdictsOf = (...paths) => paths.map((path) => judge(`M\t${path}`).verdict);

    it("検査を決めるものに触るなら待つと返すこと", () => {
      const paths = ["scripts/check", "scripts/agent-docs-duplicates", ".github/actionlint.yaml", ".github/workflows/check.yml", ".github/workflows/dependency-pr.yml"];
      assert.deepEqual(verdictsOf(...paths), paths.map(() => "待つ"));
    });

    it("照合を決めるものに触るなら待つと返すこと", () => {
      const paths = [".claude/agents/preferences-review.md", ".codex/agents/docs-review.toml", "CODING_STANDARDS.md", "docs/agents/review.md", ".agents/skills/steward/SKILL.md"];
      assert.deepEqual(verdictsOf(...paths), paths.map(() => "待つ"));
    });

    it("照合が照らす決まりを書いた文書に触るなら待つと返すこと", () => {
      const paths = ["docs/agents/privacy.md", "docs/agents/coding-style.md", "docs/agents/languages/swift.md", "docs/agents/testing.md"];
      assert.deepEqual(verdictsOf(...paths), paths.map(() => "待つ"));
    });

    it("merge を決めるものに触るなら待つと返すこと", () => {
      const paths = ["scripts/merge-tier", ".claude/settings.json", ".claude/hooks/block-pkill-f.sh", "docs/agents/git.md", "docs/agents/issue-tracker.md", "docs/agents/dependencies.md"];
      assert.deepEqual(verdictsOf(...paths), paths.map(() => "待つ"));
    });

    it("壊れたら気づく道具に触るなら待つと返すこと", () => {
      const paths = [".github/workflows/deploy.yml", ".github/workflows/ios-ui-test.yml", ".github/workflows/production-alerts.yml", "scripts/production-alerts", "scripts/sentry"];
      assert.deepEqual(verdictsOf(...paths), paths.map(() => "待つ"));
    });

    it("用語・見た目・覆しにくい決定に触るなら、ほかの文書と一緒でも待つと返すこと", () => {
      for (const path of ["GLOSSARY.md", "DESIGN.md", "docs/adr/0017-observability.md"]) {
        assert.equal(judge("M\tdocs/agents/sync.md", `M\t${path}`).verdict, "待つ", path);
      }
    });

    it("ゲートに触るパスには、どのゲートかを理由に添えること", () => {
      assert.match(judge("M\tscripts/check").stdout, /^ {2}M\tscripts\/check\t.*検査を決めるもの/m);
    });

    it("調べものとほかのものを一緒に変えたなら待つと返すこと", () => {
      assert.equal(judge("A\tdocs/research/sqlite-limits.md", "M\tdocs/agents/sync.md").verdict, "待つ");
    });

    it("差分が無いなら待つと返すこと", () => {
      assert.equal(judge().verdict, "待つ");
    });

    it("待つ理由になったパスに理由を添えること", () => {
      assert.match(judge("M\tserver/src/meal/meal-total.ts").stdout, /^ {2}M\tserver\/src\/meal\/meal-total\.ts\t.+$/m);
    });
  });
});

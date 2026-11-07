// scripts/agent-docs-duplicates を一時フォルダに置いた文書に向けて走らせ、scripts/check がエージェントが読む文書の変更で scripts を選ぶことも確かめる
"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const { mkdtempSync, mkdirSync, rmSync, writeFileSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { dirname, join } = require("node:path");
const { describe, it, before, after } = require("node:test");

const PARAGRAPH = "確かめることは scripts/check と CI に置き、Claude Code の hook は便利のためだけに使う。Codex と Cursor では hook が動かないため。";

// 文書を一時フォルダに置いて走らせ、結果と、後で消すフォルダを返す
const run = (files) => {
  const root = mkdtempSync(join(tmpdir(), "agent-docs-duplicates-"));
  for (const [path, text] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), text);
  }
  const result = spawnSync(process.execPath, [join(__dirname, "agent-docs-duplicates"), root], { encoding: "utf8" });
  return { root, result };
};

const pickTargets = (path) => spawnSync(join(__dirname, "check"), ["--pick-targets"], { input: `${path}\n`, encoding: "utf8" });

describe("エージェントが読む文書の重なり", () => {
  describe("落とすとき", () => {
    describe("2つのファイルに同じ段落があるとき", () => {
      let root;
      let result;
      before(() => {
        ({ root, result } = run({
          "AGENTS.md": `# nu-tori\n\n${PARAGRAPH}\n`,
          "docs/agents/tooling.md": `# 道具\n\n前置き。\n\n${PARAGRAPH}\n`,
        }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("落ちること", () => {
        assert.equal(result.status, 1);
      });

      it("2か所のファイルと行を出すこと", () => {
        assert.match(result.stderr, /^AGENTS\.md:3$/m);
        assert.match(result.stderr, /^docs\/agents\/tooling\.md:5$/m);
      });
    });

    describe("同じ箇条書きの1項目が、入れ子と折り返しの空白だけ違って2か所にあるとき", () => {
      let root;
      let result;
      before(() => {
        ({ root, result } = run({
          "server/AGENTS.md": `# サーバー\n\n- ${PARAGRAPH}\n- 別の項目\n`,
          ".claude/agents/preferences-review.md": `- 別の項目\n  - ${PARAGRAPH.replace("、", "、\n    ")}\n`,
        }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("落ちること", () => {
        assert.equal(result.status, 1);
      });

      it("2か所の項目の始まりの行を出すこと", () => {
        assert.match(result.stderr, /^server\/AGENTS\.md:3$/m);
        assert.match(result.stderr, /^\.claude\/agents\/preferences-review\.md:2$/m);
      });
    });
  });

  describe("通すとき", () => {
    describe("見出し、1語の箇条書き、コードのかたまりの1行だけが重なるとき", () => {
      let root;
      let result;
      before(() => {
        const shared = "## 確かめる\n\n- server\n- site\n\n```sh\nscripts/check server --fix && scripts/check site --fix && scripts/check scripts\n```\n";
        ({ root, result } = run({ "AGENTS.md": shared, "docs/agents/git.md": shared }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("通ること", () => {
        assert.equal(result.status, 0, result.stderr);
      });
    });

    describe("片方が skills-lock.json で入れたスキルの文書のとき", () => {
      let root;
      let result;
      before(() => {
        ({ root, result } = run({
          "skills-lock.json": JSON.stringify({ version: 1, skills: { tdd: { source: "mattpocock/skills" } } }),
          "AGENTS.md": `${PARAGRAPH}\n`,
          ".agents/skills/tdd/SKILL.md": `${PARAGRAPH}\n`,
        }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("通ること", () => {
        assert.equal(result.status, 0, result.stderr);
      });
    });

    describe("エージェントが読む文書でないファイルとだけ重なるとき", () => {
      let root;
      let result;
      before(() => {
        ({ root, result } = run({ "AGENTS.md": `${PARAGRAPH}\n`, "GLOSSARY.md": `${PARAGRAPH}\n`, "docs/adr/0001.md": `${PARAGRAPH}\n` }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("通ること", () => {
        assert.equal(result.status, 0, result.stderr);
      });
    });
  });

  // 重なりを見る文書の選び方と、scripts/check がその変更で scripts を選ぶ決まりは、別々に書いてある。
  // 片方だけに置き場を足すとずれるので、置き場の一覧を1つにして両方に当てる（パラメータ化テスト）
  describe("文書の置き場ごと", () => {
    const places = [
      "AGENTS.md",
      "server/AGENTS.md",
      "CODING_STANDARDS.md",
      "docs/agents/languages/swift.md",
      ".claude/agents/policy-review.md",
      ".claude/skills/model-based-ui-design/SKILL.md",
      ".agents/skills/verify-server/features/README.md",
    ];
    for (const place of places) {
      describe(`${place} のとき`, () => {
        let root;
        let result;
        let picked;
        before(() => {
          const other = place === "AGENTS.md" ? "CODING_STANDARDS.md" : "AGENTS.md";
          ({ root, result } = run({ [place]: `${PARAGRAPH}\n`, [other]: `${PARAGRAPH}\n` }));
          picked = pickTargets(place);
        });
        after(() => rmSync(root, { recursive: true, force: true }));

        it("重なりを見ること", () => {
          assert.equal(result.status, 1);
          assert.match(result.stderr, new RegExp(`^${place.replaceAll(".", "\\.")}:1$`, "m"));
        });

        it("変えると scripts/check が scripts を選ぶこと", () => {
          assert.match(picked.stdout, /^scripts=true$/m);
        });
      });
    }
  });
});

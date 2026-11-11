// scripts/workflow-pipefail を一時フォルダに置いたワークフローに向けて走らせる
"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const { mkdtempSync, mkdirSync, rmSync, writeFileSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { join } = require("node:path");
const { describe, it, before, after } = require("node:test");

// #832 の直す前の形。shell を指定しない run は bash -e で動き、gh api が落ちても head が 0 で終わる
const FIND_ISSUE_STEP = `jobs:
  track:
    runs-on: ubuntu-latest
    steps:
      - run: |
          number="$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues" --jq '.[].number' | head -n 1)"
`;

const DEFAULT_BASH = `defaults:
  run:
    shell: bash
`;

// ワークフローを一時フォルダの .github/workflows/ に置いて走らせ、結果と、後で消すフォルダを返す
const run = (workflows) => {
  const root = mkdtempSync(join(tmpdir(), "workflow-pipefail-"));
  mkdirSync(join(root, ".github/workflows"), { recursive: true });
  for (const [name, text] of Object.entries(workflows)) {
    writeFileSync(join(root, ".github/workflows", name), text);
  }
  const result = spawnSync(process.execPath, [join(__dirname, "workflow-pipefail"), root], { encoding: "utf8" });
  return { root, result };
};

describe("ワークフローの run が pipefail の効く shell で動くか", () => {
  describe("落とすとき", () => {
    describe("ワークフローに既定の shell が無いとき", () => {
      let root;
      let result;
      before(() => {
        ({ root, result } = run({ "a.yml": `name: a\non: push\n${FIND_ISSUE_STEP}` }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("落ちること", () => {
        assert.equal(result.status, 1);
      });

      it("ファイルの名前を出すこと", () => {
        assert.match(result.stderr, /^\.github\/workflows\/a\.yml: /m);
      });
    });

    describe("既定の shell がジョブにだけあるとき", () => {
      let root;
      let result;
      before(() => {
        const jobDefaults = FIND_ISSUE_STEP.replace("    runs-on: ubuntu-latest\n", `    runs-on: ubuntu-latest\n${DEFAULT_BASH.replace(/^/gm, "    ")}`);
        ({ root, result } = run({ "a.yml": `name: a\non: push\n${jobDefaults}` }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("落ちること", () => {
        assert.equal(result.status, 1);
      });
    });

    describe("既定は bash でも、ステップが bash でない shell を指すとき", () => {
      let root;
      let result;
      before(() => {
        const shStep = FIND_ISSUE_STEP.replace("      - run: |\n", "      - shell: sh\n        run: |\n");
        ({ root, result } = run({ "a.yml": `name: a\non: push\n${DEFAULT_BASH}${shStep}` }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("落ちること", () => {
        assert.equal(result.status, 1);
      });

      it("その行を出すこと", () => {
        assert.match(result.stderr, /^\.github\/workflows\/a\.yml:10: /m);
      });
    });
  });

  describe("通すとき", () => {
    describe("ワークフローの既定の shell が bash のとき", () => {
      let root;
      let result;
      before(() => {
        ({ root, result } = run({ "a.yml": `name: a\non: push\n${DEFAULT_BASH}${FIND_ISSUE_STEP}`, "b.yaml": `name: b\non: push\n${DEFAULT_BASH}${FIND_ISSUE_STEP}` }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("通ること", () => {
        assert.equal(result.status, 0, result.stderr);
      });
    });

    describe("ワークフローの既定の shell が bash で、ジョブが作業の場所だけを足すとき", () => {
      let root;
      let result;
      before(() => {
        const jobDefaults = FIND_ISSUE_STEP.replace("    runs-on: ubuntu-latest\n", "    runs-on: ubuntu-latest\n    defaults:\n      run:\n        working-directory: server\n");
        ({ root, result } = run({ "a.yml": `name: a\non: push\n${DEFAULT_BASH}${jobDefaults}` }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("通ること", () => {
        assert.equal(result.status, 0, result.stderr);
      });
    });

    describe("アクションに shell という名前の入力を渡すとき", () => {
      let root;
      let result;
      before(() => {
        const withShell = FIND_ISSUE_STEP.replace("      - run: |\n", "      - uses: example/setup@v1\n        with:\n          shell: zsh\n      - run: |\n");
        ({ root, result } = run({ "a.yml": `name: a\non: push\n${DEFAULT_BASH}${withShell}` }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("通ること", () => {
        assert.equal(result.status, 0, result.stderr);
      });
    });

    describe("run の無いワークフローのとき", () => {
      let root;
      let result;
      before(() => {
        ({ root, result } = run({ "a.yml": "name: a\non: push\njobs:\n  lock:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n" }));
      });
      after(() => rmSync(root, { recursive: true, force: true }));

      it("通ること", () => {
        assert.equal(result.status, 0, result.stderr);
      });
    });
  });
});

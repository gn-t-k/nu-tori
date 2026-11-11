// scripts/check --pick-targets が、変わったファイルから scripts を選ぶかを確かめる
"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const { join } = require("node:path");
const { describe, it, before } = require("node:test");

const pickTargets = (path) => spawnSync(join(__dirname, "check"), ["--pick-targets"], { input: `${path}\n`, encoding: "utf8" });

describe("scripts/check --pick-targets", () => {
  describe("scripts を選ぶとき", () => {
    // エージェントが読む文書の判定は、scripts/agent-docs-duplicates の --pick に任せる
    describe("エージェントが読む文書が変わったとき", () => {
      let result;
      before(() => {
        result = pickTargets("docs/agents/git.md");
      });

      it("scripts を選ぶこと", () => {
        assert.match(result.stdout, /^scripts=true$/m);
      });
    });

    describe("check.yml 以外のワークフローが変わったとき", () => {
      let result;
      before(() => {
        result = pickTargets(".github/workflows/deploy.yml");
      });

      it("scripts を選ぶこと", () => {
        assert.match(result.stdout, /^scripts=true$/m);
      });
    });

    describe("actionlint の設定が変わったとき", () => {
      let result;
      before(() => {
        result = pickTargets(".github/actionlint.yaml");
      });

      it("scripts を選ぶこと", () => {
        assert.match(result.stdout, /^scripts=true$/m);
      });
    });

    // actionlint は dependabot.yml を読まないが、CI の設定を変えたら scripts のジョブを回すと決めた（#997）
    describe("dependabot.yml が変わったとき", () => {
      let result;
      before(() => {
        result = pickTargets(".github/dependabot.yml");
      });

      it("scripts を選ぶこと", () => {
        assert.match(result.stdout, /^scripts=true$/m);
      });
    });

    describe("ios/ci_scripts/ の下のシェルが変わったとき", () => {
      let result;
      before(() => {
        result = pickTargets("ios/ci_scripts/ci_post_xcodebuild.sh");
      });

      it("scripts を選ぶこと", () => {
        assert.match(result.stdout, /^scripts=true$/m);
      });
    });
  });

  describe("scripts を選ばないとき", () => {
    describe("エージェントが読む文書でない文書だけが変わったとき", () => {
      let result;
      before(() => {
        result = pickTargets("GLOSSARY.md");
      });

      it("scripts を選ばないこと", () => {
        assert.match(result.stdout, /^scripts=false$/m);
      });
    });

    describe(".github/ のワークフローでない文書が変わったとき", () => {
      let result;
      before(() => {
        result = pickTargets(".github/pull_request_template.md");
      });

      it("scripts を選ばないこと", () => {
        assert.match(result.stdout, /^scripts=false$/m);
      });
    });
  });
});

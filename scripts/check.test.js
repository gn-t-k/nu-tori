// scripts/check --pick-targets が、変わったファイルから scripts を選ぶかを確かめる
"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const { join } = require("node:path");
const { describe, it } = require("node:test");

const pickTargets = (path) => spawnSync(join(__dirname, "check"), ["--pick-targets"], { input: `${path}\n`, encoding: "utf8" });

describe("scripts/check --pick-targets で scripts を選ぶか", () => {
  // エージェントが読む文書の判定は、scripts/agent-docs-duplicates の --pick に任せる
  it("エージェントが読む文書の変更で scripts を選ぶこと", () => {
    assert.match(pickTargets("docs/agents/git.md").stdout, /^scripts=true$/m);
  });

  it("エージェントが読む文書でない文書だけの変更では scripts を選ばないこと", () => {
    assert.match(pickTargets("GLOSSARY.md").stdout, /^scripts=false$/m);
  });

  it("check.yml 以外のワークフローの変更で scripts を選ぶこと", () => {
    assert.match(pickTargets(".github/workflows/deploy.yml").stdout, /^scripts=true$/m);
  });

  it("actionlint の設定の変更で scripts を選ぶこと", () => {
    assert.match(pickTargets(".github/actionlint.yaml").stdout, /^scripts=true$/m);
  });

  // actionlint は dependabot.yml を読まないが、CI の設定を変えたら scripts のジョブを回すと決めた（#997）
  it("dependabot.yml の変更で scripts を選ぶこと", () => {
    assert.match(pickTargets(".github/dependabot.yml").stdout, /^scripts=true$/m);
  });

  it("ios/ci_scripts/ の下のシェルの変更で scripts を選ぶこと", () => {
    assert.match(pickTargets("ios/ci_scripts/ci_post_xcodebuild.sh").stdout, /^scripts=true$/m);
  });

  it(".github/ のワークフローでない文書の変更では scripts を選ばないこと", () => {
    assert.match(pickTargets(".github/pull_request_template.md").stdout, /^scripts=false$/m);
  });
});

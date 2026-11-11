// scripts/check --pick-targets が、ワークフローと CI の設定とシェルの変更で scripts を選ぶことを確かめる
"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const { join } = require("node:path");
const { describe, it } = require("node:test");

const pickTargets = (path) => spawnSync(join(__dirname, "check"), ["--pick-targets"], { input: `${path}\n`, encoding: "utf8" });

describe("scripts/check --pick-targets", () => {
  describe("ワークフローの lint にかかるファイルの変更で scripts を選ぶ", () => {
    for (const path of [".github/workflows/deploy.yml", ".github/workflows/ios-ui-test.yml", ".github/dependabot.yml", ".github/actionlint.yaml"]) {
      it(`${path} の変更で scripts を選ぶこと`, () => {
        assert.match(pickTargets(path).stdout, /^scripts=true$/m);
      });
    }
  });

  it("ios/ci_scripts/ の下のシェルの変更で scripts を選ぶこと", () => {
    assert.match(pickTargets("ios/ci_scripts/ci_post_xcodebuild.sh").stdout, /^scripts=true$/m);
  });

  it(".github/ のワークフローでない文書の変更では scripts を選ばないこと", () => {
    assert.match(pickTargets(".github/pull_request_template.md").stdout, /^scripts=false$/m);
  });
});

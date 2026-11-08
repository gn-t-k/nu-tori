// scripts/finance と scripts/app-store-connect と scripts/session-events が共有する、自分で出す文（使い方、未認証、HTTP の状態、断る文）の失敗
// これで止まったときは文だけを、ほかの失敗はスタックと cause まで出す。scripts/finance が scripts/app-store-connect の道を借りるので、型を1つにする
"use strict";

class ExpectedFailure extends Error {}

module.exports = { ExpectedFailure };

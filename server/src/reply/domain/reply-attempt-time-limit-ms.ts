// 試み1回の時間の上限。提供元は、渡した signal が切れたら時間切れで返す。
// 返事は目安 300 字で、呼び出しは1回なので、推定（①②で 3 分）より短くする
export const replyAttemptTimeLimitMs = 90_000;

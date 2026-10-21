// 返事の文脈に入れる範囲。窓は応える文章の前の時間、前の日は今日の前の日数。
// 置き場から読む範囲と、文脈の文面（renderReplyContext）の時間と日数は、ここから出す
export const replyContextSpan = { windowHours: 72, previousDayCount: 7 } as const;

import acceptedDeadlineDaysJson from "../../../../../shared/accepted-deadline-days.json";

// 期限として受け付ける、開始の日からの日数（両端を含む）。4〜26 週。端末と両方に置く決めごとなので、正本は shared/ の JSON
export const acceptedDeadlineDays = acceptedDeadlineDaysJson;

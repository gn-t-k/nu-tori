import { calendarDaySchema } from "./goal-setup-situation-schema";

// 減量・増量の期限
export const deadlineOnSchema = calendarDaySchema.openapi({
  description: "期限。開始の日から数えて（両端を含む）28〜182 日の日",
});

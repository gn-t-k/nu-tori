import { AppMealCard } from "./app-meal-card";
import type { MealSummary } from "./example-photo-meals";

// アプリの文章とその食事のかたまり（ios/NuTori の SentTextBubbleView）。上は自分の発言の吹き出し、下は写真の無い食事の行。
// かたまりの外の「会話として送り直す」は、アプリを使っていない人には何のことか伝わらないので描かない
export const AppTextMeal = ({
  text,
  meal,
  eatenTime,
}: {
  text: string;
  meal: MealSummary;
  eatenTime: string;
}) => (
  <div class="app-text-meal">
    <p class="app-bubble">{text}</p>
    <AppMealCard entry={{ kind: "text", meal, eatenTime }} />
  </div>
);

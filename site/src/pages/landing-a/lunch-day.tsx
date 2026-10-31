import { AppMealCard } from "./app-meal-card";
import type { ExamplePhotoMeal } from "./example-photo-meals";

// 地下の店で昼ごはんを食べた日を時刻で追い、使う人がしたことと、そのときアプリが進めていたことを並べる（#809 の試作の案 C、枝は prototype/lp-a-d-section）。
// App スイッチャーで払って閉じると写真を送るのが止まり、次に開いたときに送り直す（ios/NuTori/Meal/BackgroundMealPhotoUploader.swift）ので、閉じても送り続けるとは書かない。
// 画面の文に「電波」を使わない決まり（DESIGN.md）に合わせ、「インターネットにつながらない」と書く
export const LunchDay = ({ meal }: { meal: ExamplePhotoMeal }) => (
  <ol class="lp-day">
    <li>
      <span class="lp-day-time">12:30</span>
      <b>料理が来たので、1枚撮って閉じる</b>
      <span>写真はアプリが受け取っておきます。</span>
    </li>
    <li>
      <span class="lp-day-time">12:31</span>
      <b>すぐ食べはじめる</b>
      <span>お店はインターネットにつながりません。写真は iPhone の中で待ちます。</span>
    </li>
    <li>
      <span class="lp-day-time">13:10</span>
      <b>店を出る</b>
      <span>つながったので、写真を送って、料理と材料と量を読みます。</span>
    </li>
    <li>
      <span class="lp-day-time">15:00</span>
      <b>ふと開く</b>
      <span>もう数えてあります。違っていたら、ここで直せます。</span>
      <div class="lp-day-card" aria-hidden="true">
        <AppMealCard entry={{ kind: "photo", meal }} />
      </div>
    </li>
  </ol>
);

// LP の版 a の写真の見本（src/pages/landing-a/ の MealPhotoPicker）を動かす。
// 中身と文は書き出しで決めてあり、ここでは選んだ写真のものを見せるだけにする。Content-Security-Policy でインラインのスクリプトを読めないので、ファイルに置く
const pressOnly = (buttons, pressed) => {
  for (const button of buttons) {
    button.setAttribute("aria-pressed", String(button === pressed));
  }
};

for (const picker of document.querySelectorAll("[data-meal-picker]")) {
  const buttons = picker.querySelectorAll("[data-meal-key]");
  for (const button of buttons) {
    button.addEventListener("click", () => {
      pressOnly(buttons, button);
      for (const panel of picker.querySelectorAll("[data-meal-panel]")) {
        panel.hidden = panel.dataset.mealPanel !== button.dataset.mealKey;
      }
    });
  }
}

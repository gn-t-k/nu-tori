// LP の版 a の2つの見本（src/pages/landing-a/ の MealPhotoPicker と ReviewExample）を動かす。
// 中身と文は書き出しで決めてあり、ここでは選んだものを見せて文を入れ替えるだけにする。Content-Security-Policy でインラインのスクリプトを読めないので、ファイルに置く
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

for (const example of document.querySelectorAll("[data-review-example]")) {
  const states = JSON.parse(example.querySelector('script[type="application/json"]').textContent);
  const intake = example.querySelector("[data-review-intake]");
  const weightChange = example.querySelector("[data-review-weight-change]");
  const goals = example.querySelectorAll("[data-review-goal]");
  const show = (selector, text) => {
    example.querySelector(selector).textContent = text;
  };
  const update = () => {
    const goal = [...goals].find((button) => button.getAttribute("aria-pressed") === "true");
    const intakeLabel = states.intakeLabels[intake.value];
    const weightChangeLabel = states.weightChangeLabels[weightChange.value];
    const notice = states.notices[goal.dataset.reviewGoal][intake.value][weightChange.value];
    show("[data-review-intake-label]", intakeLabel);
    intake.setAttribute("aria-valuetext", intakeLabel);
    show("[data-review-weight-change-label]", weightChangeLabel);
    weightChange.setAttribute("aria-valuetext", weightChangeLabel);
    show("[data-review-energy]", notice.energy);
    show("[data-review-change]", notice.change);
    show("[data-review-protein]", notice.protein);
    show("[data-review-fat]", notice.fat);
    show("[data-review-carbohydrate]", notice.carbohydrate);
    show("[data-review-reason]", notice.reason);
    show("[data-review-previous-guide]", states.previousGuides[goal.dataset.reviewGoal]);
  };
  intake.addEventListener("input", update);
  weightChange.addEventListener("input", update);
  for (const button of goals) {
    button.addEventListener("click", () => {
      pressOnly(goals, button);
      update();
    });
  }
}

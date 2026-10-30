// PROTOTYPE: F 節の右の見本の A・B・C の動き
const pressOnlyProto = (buttons, pressed) => {
  for (const b of buttons) b.setAttribute("aria-pressed", b === pressed ? "true" : "false");
};

for (const root of document.querySelectorAll("[data-proto-review-a]")) {
  const data = JSON.parse(root.querySelector('script[type="application/json"]').textContent);
  const intake = root.querySelector("[data-proto-intake]");
  const weight = root.querySelector("[data-proto-weight]");
  const goals = root.querySelectorAll("[data-proto-goal]");
  const set = (sel, text) => (root.querySelector(sel).textContent = text);
  const update = () => {
    const goal = [...goals].find((b) => b.getAttribute("aria-pressed") === "true");
    const s = data.states[goal.dataset.protoGoal][intake.value][weight.value];
    set("[data-proto-intake-label]", data.intakeLabels[intake.value]);
    set("[data-proto-weight-label]", data.weightLabels[weight.value]);
    set("[data-proto-expenditure]", s.expenditure);
    set("[data-proto-energy]", s.energy);
    set("[data-proto-change]", s.change);
    set("[data-proto-reason]", s.reason);
  };
  intake.addEventListener("input", update);
  weight.addEventListener("input", update);
  for (const b of goals) b.addEventListener("click", () => (pressOnlyProto(goals, b), update()));
}

for (const root of document.querySelectorAll("[data-proto-weeks]")) {
  const buttons = root.querySelectorAll("[data-proto-week]");
  for (const b of buttons) {
    b.addEventListener("click", () => {
      pressOnlyProto(buttons, b);
      for (const p of root.querySelectorAll("[data-proto-week-panel]")) {
        p.hidden = p.dataset.protoWeekPanel !== b.dataset.protoWeek;
      }
    });
  }
}

// CSP でインラインの style は書けないので、棒の長さはここで入れる
for (const bar of document.querySelectorAll(".proto-f-bar")) {
  bar.querySelector(".proto-f-bar-fill").style.width = bar.dataset.width;
  bar.querySelector(".proto-f-bar-true").style.left = bar.dataset.true;
}

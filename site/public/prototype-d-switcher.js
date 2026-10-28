// PROTOTYPE: D 節の案を ?variant= と下の帯で切り替える。← → のキーでも切り替わる
const sections = [...document.querySelectorAll("[data-proto-variant]")];
const keys = sections.map((section) => section.dataset.protoVariant);
const bar = document.createElement("div");
bar.className = "proto-switcher";
bar.innerHTML =
  '<button type="button" aria-label="前の案">←</button><span></span><button type="button" aria-label="次の案">→</button>';
document.body.append(bar);
const label = bar.querySelector("span");

const show = (key) => {
  for (const section of sections) {
    section.hidden = section.dataset.protoVariant !== key;
  }
  const current = sections.find((section) => !section.hidden);
  label.textContent = `${key}（${current.dataset.protoName}）`;
  const url = new URL(location.href);
  url.searchParams.set("variant", key);
  history.replaceState(null, "", url);
};
const step = (by) => {
  const now = keys.indexOf(new URL(location.href).searchParams.get("variant") ?? "A");
  show(keys[(Math.max(now, 0) + by + keys.length) % keys.length]);
};

const [previous, next] = bar.querySelectorAll("button");
previous.addEventListener("click", () => step(-1));
next.addEventListener("click", () => step(1));
document.addEventListener("keydown", (event) => {
  if (event.target.closest("input, textarea, [contenteditable]")) return;
  if (event.key === "ArrowLeft") step(-1);
  if (event.key === "ArrowRight") step(1);
});
const asked = new URL(location.href).searchParams.get("variant");
show(keys.includes(asked) ? asked : "A");

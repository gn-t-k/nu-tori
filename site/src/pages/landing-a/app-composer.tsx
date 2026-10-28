// アプリの入力欄（ios/NuTori/Timeline/TimelineComposer.swift、DESIGN.md の composer-*）。写真も文章もここから送る画面だと伝えるための絵で、押せない。
// 左から「撮る」「写真」「体重」の丸と、書く欄。体重は記録済みの灰色の丸にする。「送る」は書く欄に文字があるときだけ出るので描かない。
// 入力欄の下の「AI が読んで返事をします」は規約のための1行で、この節の伝えたいことではないので描かない
export const AppComposer = () => (
  <div class="app-composer" aria-hidden="true">
    <span class="app-composer-button app-composer-camera">
      {/* SF Symbols の camera.fill の代わり */}
      <svg width="22" height="18" viewBox="0 0 22 18">
        <path
          d="M7.5 1h7l1.6 2.4H19a2 2 0 0 1 2 2V15a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V5.4a2 2 0 0 1 2-2h2.9z"
          fill="currentColor"
        />
        <circle cx="11" cy="10" r="3.6" fill="var(--primary)" />
      </svg>
    </span>
    <span class="app-composer-button">
      {/* SF Symbols の photo.on.rectangle の代わり */}
      <svg
        width="22"
        height="18"
        viewBox="0 0 22 18"
        fill="none"
        stroke="currentColor"
        stroke-width="1.6"
      >
        <rect x="5" y="1" width="16" height="12" rx="2" />
        <path d="M1.8 5v9.2a2 2 0 0 0 2 2H17" />
        <path d="M6 12l4-4 3 3 2-2 5 4" />
      </svg>
    </span>
    <span class="app-composer-button">
      {/* アセットの WeightScale（角の丸い四角に目盛りの弧と針の体重計）の代わり */}
      <svg
        width="20"
        height="20"
        viewBox="0 0 20 20"
        fill="none"
        stroke="currentColor"
        stroke-width="1.6"
      >
        <rect x="1" y="1" width="18" height="18" rx="5" />
        <path d="M5.5 8a5 5 0 0 1 9 0" />
        <path d="M10 9l1.8-3" stroke-linecap="round" />
      </svg>
    </span>
    <span class="app-composer-field">書く</span>
  </div>
);

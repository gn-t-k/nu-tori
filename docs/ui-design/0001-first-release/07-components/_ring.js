// 1日の丸を描く。1本の輪を、食べた P・F・C の kcal で色分けし、一周で1日の目安にする。
// 目安を超えた日は、輪の起点に印を付ける。目標がない日（goal なし）は P・F・C の割合で一周させる。
// 体重を記録した日（weighed）は、丸の中に印を付ける。
// 使い方: <span class="ring" data-ring='{"size":26,"stroke":4,"p":420,"f":560,"c":760,"goal":1850,"weighed":true}'></span>
(function(){
  function svg(o){
    const size = o.size || 26, stroke = o.stroke || 4, gap = o.gap ?? (size > 60 ? 2 : 1.5);
    const r = (size - stroke) / 2, C = 2 * Math.PI * r, m = size / 2;
    const parts = [['p', o.p||0], ['f', o.f||0], ['c', o.c||0]];
    const total = parts.reduce((s, x) => s + x[1], 0);
    const base = o.goal ? Math.max(o.goal, total) : Math.max(total, 1);
    let off = 0, segs = '';
    for (const [k, v] of parts){
      if (!v) continue;
      const len = v / base * C, draw = Math.max(0, len - gap);
      segs += `<circle cx="${m}" cy="${m}" r="${r}" fill="none" stroke="var(--${k})" stroke-width="${stroke}" stroke-dasharray="${draw} ${C}" stroke-dashoffset="${-off}"/>`;
      off += len;
    }
    const over = o.goal && total > o.goal
      ? `<circle cx="${m}" cy="${stroke/2}" r="${Math.max(2, stroke*0.6)}" fill="var(--ink)" stroke="var(--bg)" stroke-width="1.5"/>` : '';
    const dot = o.weighed ? `<circle cx="${m}" cy="${m}" r="${Math.max(2.5, size*0.12)}" fill="var(--ink2)"/>` : '';
    return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-hidden="true"><g transform="rotate(-90 ${m} ${m})"><circle cx="${m}" cy="${m}" r="${r}" fill="none" stroke="var(--track)" stroke-width="${stroke}"/>${segs}</g>${over}${dot}</svg>`;
  }
  function draw(root){
    (root || document).querySelectorAll('[data-ring]').forEach(el => {
      const o = JSON.parse(el.dataset.ring);
      el.insertAdjacentHTML('afterbegin', svg(o));
    });
  }
  window.nuRing = { svg, draw };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => draw()); else draw();
})();

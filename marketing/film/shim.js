// 虚拟时钟：页面里的计时器、动画、滚动全部由录制脚本逐帧推进
(function () {
  let now = 0;
  const RealDate = Date;
  const base = new RealDate(2026, 9, 9, 10, 0, 0).getTime();
  window.Date = class extends RealDate {
    constructor(...a) { if (a.length === 0) super(base + now); else super(...a); }
    static now() { return base + now; }
  };
  performance.now = () => now;
  let id = 0;
  const timers = new Map();
  window.setTimeout = (fn, d = 0, ...args) => { const i = ++id; timers.set(i, { t: now + Math.max(0, +d || 0), fn, args }); return i; };
  window.clearTimeout = i => timers.delete(i);
  window.setInterval = (fn, d = 0, ...args) => { const i = ++id; const tick = () => { timers.set(i, { t: now + d, fn: () => { fn(...args); tick(); }, args: [] }); }; tick(); return i; };
  window.clearInterval = i => timers.delete(i);
  let rafs = [];
  window.requestAnimationFrame = fn => { rafs.push(fn); return rafs.length; };
  window.cancelAnimationFrame = () => {};
  const _scrollTo = window.scrollTo.bind(window);
  const ease = k => k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;
  function animScroll(el, target, d = 650) {
    const isWin = el === window;
    const start = isWin ? window.scrollY : el.scrollTop, t0 = now;
    const step = () => {
      const k = Math.min(1, (now - t0) / d), y = start + (target - start) * ease(k);
      if (isWin) _scrollTo(0, y); else el.scrollTop = y;
      if (k < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }
  window.scrollTo = function (a, b) {
    if (typeof a === 'object') { const top = a.top ?? window.scrollY; if (a.behavior === 'smooth') animScroll(window, top); else _scrollTo(0, top); }
    else _scrollTo(a, b);
  };
  const _elScrollTo = Element.prototype.scrollTo;
  Element.prototype.scrollTo = function (o) {
    if (o && typeof o === 'object' && o.behavior === 'smooth') animScroll(this, o.top ?? this.scrollTop);
    else _elScrollTo.apply(this, arguments);
  };
  Element.prototype.scrollIntoView = function () {
    const r = this.getBoundingClientRect();
    animScroll(window, Math.max(0, window.scrollY + r.top - (innerHeight - r.height) / 2));
  };
  window.__vt = {
    now: () => now,
    advance(ms) {
      const target = now + ms;
      for (;;) {
        let best = null;
        for (const [i, t] of timers) if (t.t <= target && (!best || t.t < best[1].t)) best = [i, t];
        if (!best) break;
        timers.delete(best[0]);
        now = best[1].t;
        try { best[1].fn(...best[1].args); } catch (e) { console.error(e); }
      }
      now = target;
      const fs = rafs; rafs = [];
      fs.forEach(f => { try { f(now); } catch (e) { console.error(e); } });
      for (const a of document.getAnimations()) {
        if (a.__vs === undefined) { a.__vs = now - (a.currentTime || 0); a.pause(); }
        a.currentTime = Math.max(0, now - a.__vs);
      }
    }
  };
})();

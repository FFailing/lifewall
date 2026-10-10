// 宣传片动作表：[音乐时间(秒), 动作]
const FPS = 60;
const acts = [];
const at = (t, fn) => acts.push([+t.toFixed(4), fn]);
const ease = k => k < .5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;

const click = (t, sel) => at(t, async ({ p, box }) => {
  const [x, y] = await box(sel);
  await p.mouse.move(x, y); await p.mouse.down(); await p.mouse.up();
});
// 逐帧执行
const perFrame = (t0, t1, fn) => { for (let t = t0; t <= t1 + 1e-9; t += 1 / FPS) { const k = (t - t0) / (t1 - t0); at(t, ctx => fn(ctx, Math.min(1, k))); } };
// 一笔：按下 → 沿路径移动 → 抬起
function stroke(t0, t1, sel, pts) {
  let b = null;
  const P = k => { const n = pts.length - 1, f = k * n, i = Math.min(n - 1, Math.floor(f)), r = f - i; const a = pts[i], c = pts[i + 1]; return [b.x + (a[0] + (c[0] - a[0]) * r) * b.width, b.y + (a[1] + (c[1] - a[1]) * r) * b.height]; };
  at(t0, async ({ p, f }) => { b = await (await f.$(sel)).boundingBox(); const [x, y] = P(0); await p.mouse.move(x, y); await p.mouse.down(); });
  perFrame(t0 + 1 / FPS, t1, async ({ p }, k) => { const [x, y] = P(k); await p.mouse.move(x, y); });
  at(t1 + 0.5 / FPS, async ({ p }) => { await p.mouse.up(); });
}
const scrollWin = (t0, t1, from, to) => perFrame(t0, t1, async ({ f }, k) => { await f.evaluate(y => window.scrollTo(0, y), from + (to - from) * ease(k)); });

// —— 揭幕：墙面缓慢下移再回到顶部 ——
scrollWin(38.2, 40.0, 0, 430);
scrollWin(40.3, 41.6, 430, 0);

// —— 便签：写下 → 选样式 → 长按钉上（图钉落下对上 53.57 的鼓点）——
click(42.1, '#write');
[...'登上一座雪山，看一次日出'].forEach((ch, i) => at(43.0 + i * 0.12, async ({ p }) => { await p.keyboard.type(ch); }));
click(44.9, '[data-field=paper][data-val="#c4def0"]');
click(45.6, '[data-tab=pattern]');
click(46.0, '[data-field=pattern][data-val=dots]');
click(46.7, '[data-tab=shape]');
click(47.1, '[data-field=shape][data-val=star]');
click(47.8, '[data-tab=pin]');
click(48.2, '[data-field=pin][data-val="#d4a72c"]');
at(50.07, async ({ p, box }) => { const [x, y] = await box('#pinBtn'); await p.mouse.move(x, y); await p.mouse.down(); });
at(53.3, async ({ p }) => { await p.mouse.up(); });

// —— 照片 + 相框 + 时间戳 + 涂鸦（钉上对 65.29）——
click(56.4, '#write');
click(56.9, '[data-kind=photo]');
at(57.3, async ({ p, f }) => {
  const data = await p.evaluate(() => window.mountainPhoto());
  await f.setInputFiles('#photoInput', { name: 'sunrise.jpg', mimeType: 'image/jpeg', buffer: Buffer.from(data.split(',')[1], 'base64') });
});
click(58.0, '[data-field=frame][data-val=print]');
click(58.45, '[data-tab=ts]');
click(58.75, '[data-field=ts][data-val=typewriter]');
click(59.2, '[data-tab=doodle]');
click(59.45, '[data-dcolor="#d23b2f"]');
{ // 红色蜡笔圈住太阳
  const pts = []; for (let i = 0; i <= 26; i++) { const a = -Math.PI / 2 + i / 24 * Math.PI * 2.08; pts.push([0.6 + 0.15 * Math.cos(a), 0.44 + 0.13 * Math.sin(a)]); }
  stroke(59.65, 60.45, '#doodleCanvas', pts);
}
click(60.6, '[data-brush=water]');
click(60.75, '[data-dcolor="#2f5fbf"]');
{ // 蓝色水彩笔划一道
  const pts = [[0.70, 0.66], [0.735, 0.70], [0.76, 0.735], [0.80, 0.66], [0.85, 0.58], [0.90, 0.50]];
  stroke(60.9, 61.4, '#doodleCanvas', pts);
}
at(61.79, async ({ p, box }) => { const [x, y] = await box('#pinBtn'); await p.mouse.move(x, y); await p.mouse.down(); });
at(65.0, async ({ p }) => { await p.mouse.up(); });

// —— 盖章（印落对 78.74）——
at(67.4, async ({ f }) => { await f.evaluate(() => document.querySelector('[data-id=s3]').scrollIntoView()); });
at(68.4, async ({ p, box }) => { const [x, y] = await box('[data-id=s3]'); await p.mouse.move(x, y); await p.mouse.down(); });
at(68.5, async ({ p }) => { await p.mouse.up(); });
click(69.6, '#stStyle');
click(70.4, '[data-sf=shape][data-val=oval]');
click(71.2, '[data-sf=shape][data-val=square]');
click(72.0, '#stTabs [data-tab=orn]');
click(72.4, '[data-sf=orn][data-val=stars]');
click(73.0, '[data-sf=orn][data-val=flowers]');
click(73.8, '#stTabs [data-tab=color]');
click(74.2, '[data-sf=color][data-val="#9e1b32"]');
click(75.0, '#stTabs [data-tab=text]');
click(75.4, '[data-sf=text][data-val="不负此生"]');
at(76.95, async ({ p, box }) => { const [x, y] = await box('#stampBtn'); await p.mouse.move(x, y); await p.mouse.down(); });
at(78.6, async ({ p }) => { await p.mouse.up(); });
click(80.4, '#shareBtn');
at(88.2, async ({ f }) => { await f.evaluate(() => document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))); });

// —— 拔钉挪位 ——
{
  let s = null;
  at(89.2, async ({ p, f }) => { const b = await (await f.$('[data-id=s3]')).boundingBox(); s = [b.x + b.width / 2, b.y + b.height * 0.55]; await p.mouse.move(...s); await p.mouse.down(); });
  perFrame(89.8, 92.0, async ({ p }, k) => { const e = ease(k), out = Math.sin(e * Math.PI); await p.mouse.move(s[0] + 150 * out + 24 * e, s[1] - 170 * out + 16 * e); });
  at(92.35, async ({ p }) => { await p.mouse.up(); });
}

// —— 分享整面墙 ——
at(94.4, async ({ f }) => { await f.evaluate(() => window.scrollTo({ top: 0, behavior: 'smooth' })); });
click(96.1, '#shareWall');
perFrame(98.6, 105.6, async ({ f }, k) => { await f.evaluate(k => { const pn = document.getElementById('panel'); pn.scrollTop = (pn.scrollHeight - pn.clientHeight) * 0.8 * k; }, ease(k)); });

module.exports = acts.sort((a, b) => a[0] - b[0]);

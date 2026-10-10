// 逐帧渲染：node render2.js page.html out.mp4 dur [start=0] [every=1] [scale=1]
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const FPS = 60;
(async () => {
  const [, , page, out, dur, start = '0', every = '1', scale = '1'] = process.argv;
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  p.on('pageerror', e => console.log('PAGEERR', e.message));
  await p.goto('file://' + __dirname + '/' + page);
  await p.waitForTimeout(1500);
  const f = p.frames().find(x => x.url().endsWith('film-app.html'));
  f.on && 0;
  await f.evaluate(() => window.__vt.advance(16));
  const N = +every, outFps = FPS / N;
  const vf = +scale !== 1 ? ['-vf', `scale=${Math.round(1080 * scale / 2) * 2}:-2`] : [];
  const ff = spawn('ffmpeg', ['-loglevel', 'error', '-y', '-f', 'image2pipe', '-framerate', String(outFps), '-i', '-', ...vf, '-c:v', 'libx264', '-preset', N > 1 ? 'veryfast' : 'medium', '-crf', N > 1 ? '26' : '17', '-pix_fmt', 'yuv420p', out]);
  const script = require('./' + page.replace('.html', '.actions.js'));
  const ctx = { p, f, box: async sel => { const el = await f.$(sel); if (!el) throw new Error('no element ' + sel); const bb = await el.boundingBox(); return [bb.x + bb.width / 2, bb.y + bb.height / 2]; } };
  const total = Math.round(+dur * FPS), s0 = Math.round(+start * FPS);
  let ai = 0; const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    const T = i / FPS;
    while (ai < script.length && script[ai][0] <= T + 1e-9) { try { await script[ai][1](ctx); } catch (e) { console.log('ACTERR', script[ai][0], e.message.split('\n')[0]); } ai++; }
    await p.evaluate(T => window.render(T), T);
    await f.evaluate(ms => window.__vt.advance(ms), 1000 / FPS);
    if (i >= s0 && (i - s0) % N === 0) {
      const buf = await p.screenshot({ type: 'jpeg', quality: N > 1 ? 70 : 92 });
      if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    }
    if (i % 600 === 0) console.log(`frame ${i}/${total}  ${((Date.now() - t0) / 1000).toFixed(0)}s`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  await b.close();
  console.log('done', ((Date.now() - t0) / 1000).toFixed(0) + 's');
})();

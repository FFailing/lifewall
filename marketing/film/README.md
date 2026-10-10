# 宣传片源文件

- `film.html`：画面，`render(T)` 按音乐时间驱动引子、提问、揭幕、字幕、镜头与片尾
- `film.actions.js`：演示中每一次点击、输入、拖动的时间表（对齐配乐重拍）
- `shim.js`：虚拟时钟，注入到演示页面（`demo/index.html`）后得到 `film-app.html`
- `render2.js`：用 Playwright 逐帧截图，60fps 交给 ffmpeg
  - 用法：`node render2.js film.html out.mp4 116.5`
- `mix.py`：混音（配乐、人声、翻页声、界面音效）

音频素材未随仓库分发，来源见根目录 README。

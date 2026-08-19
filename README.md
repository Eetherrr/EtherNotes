# EtherNotes

个人知识笔记博客，涉及 FPGA、嵌入式等硬件开发知识，以及一些杂七杂八的东西。

🔗 **Blog**: <https://eetherrr.github.io/EtherNotes/>

由 [GitHub Pages] + [Jekyll] 构建，使用 [Obsidian] 作为本地写作工具，推送到 `main` 分支后由 GitHub Actions 自动构建部署。

🎨 **主题**：8-bit 像素风，字体为 [Fusion Pixel 缝合像素字体](https://github.com/TakWolf/fusion-pixel-font)（OFL 1.1 许可，见 `docs/assets/fonts/OFL.txt`），本地加载无 CDN 依赖；缺字回退系统柔和黑体（苹方 / MiSans / 微软雅黑，不回退宋体楷体）。

[GitHub Pages]: https://pages.github.com/
[Jekyll]: https://jekyllrb.com/
[Obsidian]: https://obsidian.md/

---

## 目录结构

```
EtherNotes/                        ← Obsidian 库根目录
├── .github/workflows/             # CI：校验 → 构建 docs/ → 部署 Pages
├── .obsidian/                     # Obsidian 配置与插件（workspace.json 不入库）
├── scripts/
│   ├── new-post.sh                # 生成符合规范的空白文章
│   └── check-posts.mjs            # 规范校验（CI 与本地）
├── docs/                          ← Jekyll 站点源（Pages 的 source）
│   ├── _config.yml                 # 站点配置 + 默认布局 + permalink
│   ├── _data/columns.yml           # 列/子列的显示名与顺序
│   ├── _plugins/
│   │   ├── grouped_posts.rb        # 目录树 → 列/子列/系列 分组
│   │   └── wikilinks.rb            # Obsidian 语法 → 标准 Markdown/HTML
│   ├── _layouts/ _includes/        # 布局与局部模板
│   ├── assets/                     # main.scss、fonts/（像素字体）、images/、js/wavedrom/
│   ├── _posts/                     # 文章（见下方约定）
│   ├── about.md / index.html
│   └── TODO.md                     # 个人待办（不参与构建）
├── README.md
└── LICENSE-CODE / LICENSE-DOCS
```

---

## 写作规范

文章统一使用**目录即分类**，路径三段：`_posts/<列>/<子列>/[<系列>/]<文件名>.md`。

- **列 / 子列**：显示名在 `docs/_data/columns.yml` 配置；未配置的自动发现。
- **系列**：放在子列下的第三层目录即「系列」，系列内按 frontmatter 的 `order` 排序（0 起）。
- **文件名**：`YYYY-MM-DD-小写slug.md`（ASCII 小写 + 连字符，无空格/中文）。
- **图片**：统一放入 `docs/assets/images/`，正文用 Obsidian 语法 `![[图片名.png|宽度px]]`（构建时自动转换，宽度可省略）。

**frontmatter 模板**：

```yaml
---
layout: post
title: I2C 仲裁
date: 2026-08-12
categories: [fpga, protocol, i2c]   # = 目录路径，控制 URL
order: 3                            # 系列内排序，非系列文章可省略
---
```

> `categories` 必须与目录路径一致：文章 URL 即 `/fpga/protocol/i2c/i2c-arbitration/`。

新建文章可直接用脚本：

```bash
./scripts/new-post.sh fpga/protocol/i2c i2c-arbitration "I2C 仲裁"
```

在 Obsidian 中引用其它笔记用 `[[标题|别名]]`，引用图片用 `![[图片名.png]]`，构建时由 `docs/_plugins/wikilinks.rb` 自动解析（`[[单总线介绍|单总线]]` 会正确链接到对应文章，即使文章文件已改为英文 slug）。

---

## 本地开发

需要 Ruby 3.x（版本见 `.ruby-version`）与 Bundler：

```bash
cd docs
bundle install
bundle exec jekyll serve --baseurl ""
# 浏览器打开 http://127.0.0.1:4000/
```

> - 部署到 GitHub Pages 时 `baseurl` 会被 CI 的 `configure-pages` 自动注入，本地预览用 `--baseurl ""`。
> - 首次 `bundle install` 后建议把生成的 `Gemfile.lock` 一并提交，锁定依赖版本。

校验文章规范：

```bash
node scripts/check-posts.mjs
```

---

## 构建与部署

推送到 `main` 分支即触发 `.github/workflows/jekyll-gh-pages.yml`：

1. `check-posts.mjs` 校验文章规范（失败即中断）；
2. Jekyll 构建 `docs/` → `_site/`；
3. 部署到 GitHub Pages。

以下路径的改动**不会**触发部署：`.obsidian/**`、`README.md`、`LICENSE-*`、`scripts/**`、`docs/TODO.md`。也可在 Actions 页面手动 `workflow_dispatch` 触发。

---

## 许可

本项目采用**双重许可**：

| 范围              | 协议                         | 说明                        |
| ----------------- | ---------------------------- | --------------------------- |
| 📄 **文档 & 文章** | [CC BY-SA 4.0](LICENSE-DOCS) | `docs/_posts/` 下的文章内容 |
| 💻 **源码**        | [MIT](LICENSE-CODE)          | Jekyll 模板、CSS、JS 等代码 |
| 🔤 **字体**        | [OFL 1.1](docs/assets/fonts/OFL.txt) | Fusion Pixel 缝合像素字体（可商用，须随字体保留许可文本） |

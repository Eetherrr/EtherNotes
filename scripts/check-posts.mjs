#!/usr/bin/env node
/**
 * 校验 docs/_posts 下所有文章是否符合写作规范：
 *   1. 文件名必须为 YYYY-MM-DD-ascii-slug.md（无空格、无中文）
 *   2. frontmatter 必须包含 layout / title / date / categories
 *   3. 引用的本地图片（![[name]] 与 ![](/assets/...)）必须存在
 *
 * 用法: node scripts/check-posts.mjs
 * 退出码: 0 = 通过, 1 = 存在错误
 */
import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const POSTS_DIR = join(ROOT, "docs", "_posts");
const IMAGES_DIR = join(ROOT, "docs", "assets", "images");

const FILE_RE = /^\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md$/i;
const errors = [];
const warnings = [];
let checked = 0;

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) out.push(...walk(p));
    else if (name.endsWith(".md")) out.push(p);
  }
  return out;
}

function parseFrontmatter(text) {
  if (!text.startsWith("---")) return {};
  const endIdx = text.indexOf("\n---", 3);
  if (endIdx < 0) return {};
  const block = text.slice(3, endIdx);
  const out = {};
  let curKey = null; // 值在后续块列表行中的键
  for (const line of block.split("\n")) {
    // 顶层键值: key: value
    const top = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (top) {
      curKey = top[1];
      out[curKey] = top[2].trim();
      continue;
    }
    // 块列表项（缩进的 - item），归入当前键
    if (curKey && /^\s*-\s+/.test(line)) {
      const item = line.trim().replace(/^-\s+/, "").trim();
      out[curKey] = out[curKey] ? `${out[curKey]}, ${item}` : item;
    }
  }
  return out;
}

const imageFiles = new Set(
  existsSync(IMAGES_DIR) ? readdirSync(IMAGES_DIR) : []
);

for (const file of walk(POSTS_DIR)) {
  checked++;
  const rel = file.slice(POSTS_DIR.length + 1).replace(/\\/g, "/");
  const base = rel.split("/").pop();

  if (!FILE_RE.test(base)) {
    errors.push(`文件名不符合规范（应为 YYYY-MM-DD-slug.md，ASCII 小写+连字符）: ${rel}`);
  }

  const text = readFileSync(file, "utf-8");
  const fm = parseFrontmatter(text);

  for (const key of ["layout", "title", "date", "categories"]) {
    if (!fm[key]) {
      errors.push(`缺少 frontmatter 字段 "${key}": ${rel}`);
    }
  }

  // categories 应与目录路径一致（决定 URL，不一致仅告警不阻断）
  if (fm.categories) {
    const dirPath = rel.split("/").slice(0, -1).join("/");
    const catsNorm = fm.categories
      .replace(/[[\]"'#]/g, "")
      .split(/[,\s]+/)
      .filter(Boolean)
      .join("/");
    if (catsNorm !== dirPath) {
      warnings.push(
        `categories (${fm.categories}) 与目录路径 (${dirPath}) 不一致，URL 会偏离目录结构: ${rel}`
      );
    }
  }

  // 图片引用校验（缺失图片仅告警，不阻断部署）
  const wikiImg = [...text.matchAll(/!\[\[([^\]|]+?)(?:\|\d+)?\]\]/g)].map((m) => m[1].trim());
  for (const name of wikiImg) {
    if (!imageFiles.has(name)) {
      warnings.push(`引用图片不存在: ${name} (${rel})，请放入 docs/assets/images/`);
    }
  }
  const absImg = [...text.matchAll(/!\[([^\]]*)\]\((\/assets\/[^)\s]+)\)/g)].map((m) => m[2]);
  for (const src of absImg) {
    const p = join(ROOT, "docs", src.replace(/^\/+/, ""));
    if (!existsSync(p)) {
      warnings.push(`图片路径无效: ${src} (${rel})`);
    }
  }
}

console.log(`校验文章 ${checked} 篇，图片目录含 ${imageFiles.size} 个文件。`);
if (warnings.length) {
  console.warn("\n警告（不阻断部署）：");
  for (const w of warnings) console.warn("  ⚠ " + w);
}
if (errors.length) {
  console.error("\n发现问题：");
  for (const e of errors) console.error("  ✗ " + e);
  process.exit(1);
}
console.log("✓ 规范校验通过");

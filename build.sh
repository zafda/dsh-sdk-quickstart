#!/bin/zsh
# 生成 GitHub Pages 静态站点：md -> 正文片段 -> 套自己的模板
set -e
cd "$(dirname "$0")"

gen () {
  local src="$1" out="$2" title="$3" back="$4"

  # 1) 只用 pandoc 生成正文片段，不生成 head/样式
  pandoc "$src" -f gfm -t html5 --wrap=none -o /tmp/_body.$$.html

  # 2) 套模板
  cat > "$out" <<HTML
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
:root{
  --bg:#f6f6f3;--paper:#fff;--ink:#16181d;--ink2:#4b5260;--ink3:#8b929e;
  --line:#e2e4e9;--accent:#2f6df6;--accent-soft:#eaf1ff;--warn:#b45309;--warn-soft:#fff7ed;
  --mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;--radius:10px;
}
@media (prefers-color-scheme:dark){:root{--bg:#12141a;--paper:#191c24;--ink:#e8eaf0;
  --ink2:#a8b0c0;--ink3:#6f7889;--line:#282c37;--accent:#5b8dff;--accent-soft:#1c2437;
  --warn:#f0a35e;--warn-soft:#2a2118;}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font:16px/1.8 -apple-system,BlinkMacSystemFont,"PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif}
.wrap{max-width:900px;margin:0 auto;padding:40px 24px 96px}
.back{display:inline-block;margin-bottom:20px;font-size:14px;color:var(--accent);
  text-decoration:none;font-weight:600}
.back:hover{text-decoration:underline}
article{background:var(--paper);border:1px solid var(--line);border-radius:var(--radius);
  padding:40px 44px}
@media(max-width:720px){article{padding:26px 20px}}
article>h1:first-child{font-size:27px;line-height:1.35;margin:0 0 22px}
h2{font-size:21px;margin:38px 0 14px;padding-bottom:9px;border-bottom:1px solid var(--line)}
h3{font-size:17px;margin:28px 0 10px}
h4{font-size:15.5px;margin:22px 0 8px}
table{width:100%;border-collapse:collapse;margin:16px 0;font-size:13.5px;
  background:var(--paper);display:block;overflow-x:auto;white-space:normal}
th,td{padding:10px 13px;text-align:left;border-bottom:1px solid var(--line);vertical-align:top}
th{background:var(--accent-soft);font-weight:650;font-size:13px}
tr:last-child td{border-bottom:none}
code{font-family:var(--mono);font-size:.87em;background:var(--accent-soft);
  padding:2px 6px;border-radius:5px}
pre{background:var(--bg);border:1px solid var(--line);border-radius:8px;
  padding:14px 16px;overflow-x:auto;font-size:12.8px;line-height:1.62}
pre code{background:none;padding:0;font-size:inherit}
blockquote{margin:16px 0;padding:10px 18px;border-left:3px solid var(--line);
  color:var(--ink2);background:var(--bg);border-radius:0 8px 8px 0}
blockquote p{margin:6px 0}
ul,ol{padding-left:24px}li{margin:5px 0}
hr{border:none;border-top:1px solid var(--line);margin:32px 0}
a{color:var(--accent)}
footer{margin-top:32px;font-size:13px;color:var(--ink3);line-height:1.7}
</style>
</head>
<body>
<div class="wrap">
<a class="back" href="index.html">← 返回对比页</a>
<article>
HTML
  cat /tmp/_body.$$.html >> "$out"
  cat >> "$out" <<HTML
</article>
<footer>本页由 Markdown 生成。发布版已移除内部机器名与本地绝对路径，其余内容保持原始产出。</footer>
</div>
</body>
</html>
HTML

  rm -f /tmp/_body.$$.html
  echo "built $out ($(wc -c < "$out") bytes)"
}

gen src/codex.md codex.html "Codex · dsh SDK 快速入门大纲计划" back
gen src/dsh.md   dsh.html   "dsh · dsh SDK 教学规划" back

echo "--- 检查"
for f in codex.html dsh.html index.html; do
  printf "%-12s %6s 行  %8s 字节  表格:%s\n" "$f" "$(grep -c '' $f)" "$(wc -c < $f)" "$(grep -c '<table' $f)"
done

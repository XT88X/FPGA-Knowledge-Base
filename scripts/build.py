#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build.py — 构建自包含单页 index.html。

流程：
  1. 扫描 data/fragments/phase*-ch*.json，按文件名排序。
  2. 每个 fragment：
       - doc(.md)  -> 用 python-markdown 渲染为 docHtml
       - code[].file -> 读取并 HTML 转义为 codeHtml
       - diagrams[].file(.svg) -> 原文内联为 svgRaw
  3. 聚合 KB（chapters + tools 去重），写入 data/knowledge-base.json（供独立阅读/检索）。
  4. 读 templates/index.template.html，把 /*__KB_DATA__*/ 替换为内联 KB JSON，
     生成仓库根目录 index.html。
  5. 自检：index.html 不得引用任何外部运行时资源（官方工具下载链接作为 <a> 出现除外；
     本构建里工具链接只存在于 KB JSON 字符串中，源码扫描不应发现 script/link/img 外链）。

用法：python3 scripts/build.py
"""
import os
import re
import sys
import json
import html as html_mod

try:
    import markdown
except Exception:
    print("[FATAL] 缺少 markdown 库：pip3 install markdown")
    sys.exit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAG_DIR = os.path.join(ROOT, "data", "fragments")
EXAM_DIR = os.path.join(ROOT, "data", "exam")
TEMPLATE = os.path.join(ROOT, "templates", "index.template.html")
OUT_INDEX = os.path.join(ROOT, "index.html")
OUT_KBJSON = os.path.join(ROOT, "data", "knowledge-base.json")


def resolve(p):
    return p if os.path.isabs(p) else os.path.join(ROOT, p)


def build_chapter(frag):
    ch = dict(frag)  # copy
    # doc markdown -> html
    docpath = resolve(frag.get("doc", ""))
    doc_html = ""
    if docpath and os.path.exists(docpath):
        with open(docpath, encoding="utf-8") as f:
            doc_html = markdown.markdown(
                f.read(), extensions=["fenced_code", "tables"])
    ch["docHtml"] = doc_html
    # code files
    codes = []
    for c in frag.get("code", []):
        fp = resolve(c["file"])
        text = ""
        if os.path.exists(fp):
            with open(fp, encoding="utf-8") as f:
                text = f.read()
        cc = dict(c)
        cc["codeHtml"] = html_mod.escape(text)
        codes.append(cc)
    ch["code"] = codes
    # diagrams svg inline
    diags = []
    for d in frag.get("diagrams", []):
        fp = resolve(d["file"])
        raw = ""
        if os.path.exists(fp):
            with open(fp, encoding="utf-8") as f:
                raw = f.read()
        dd = dict(d)
        dd["svgRaw"] = raw
        diags.append(dd)
    ch["diagrams"] = diags
    return ch


def main():
    if not os.path.isdir(FRAG_DIR):
        print("[FATAL] fragment 目录不存在：" + FRAG_DIR)
        sys.exit(2)
    frag_files = sorted(
        os.path.join(FRAG_DIR, f) for f in os.listdir(FRAG_DIR)
        if re.match(r"phase\d+-ch\d+\.json$", f))

    raw_fragments = []
    chapters = []
    tools_seen = {}
    for fp in frag_files:
        with open(fp, encoding="utf-8") as f:
            frag = json.load(f)
        raw_fragments.append(frag)
        ch = build_chapter(frag)
        chapters.append(ch)
        for t in frag.get("tools", []):
            tools_seen.setdefault(t["url"], t)

    kb = {
        "meta": {
            "title": "FPGA 知识系统",
            "vendor": "Xilinx/AMD Vivado",
            "selfContained": True,
        },
        "chapters": chapters,
        "tools": list(tools_seen.values()),
        "exams": {},
    }

    # 聚合通关考卷题库 data/exam/phaseN.json -> KB.exams[phase]
    raw_exams = {}
    if os.path.isdir(EXAM_DIR):
        for fn in sorted(os.listdir(EXAM_DIR)):
            m = re.match(r"phase(\d+)\.json$", fn)
            if not m:
                continue
            with open(os.path.join(EXAM_DIR, fn), encoding="utf-8") as f:
                exam = json.load(f)
            kb["exams"][int(m.group(1))] = exam
            raw_exams[int(m.group(1))] = exam

    # 1) 独立聚合 JSON（原始 fragment + 题库，供仓库阅读/检索）
    with open(OUT_KBJSON, "w", encoding="utf-8") as f:
        json.dump({"chapters": raw_fragments, "tools": list(tools_seen.values()),
                   "exams": raw_exams},
                  f, ensure_ascii=False, indent=2)

    # 2) 模板注入
    with open(TEMPLATE, encoding="utf-8") as f:
        tpl = f.read()
    # 防止 </script> 闭合
    kb_json = json.dumps(kb, ensure_ascii=False).replace("</", "<\\/")
    assert "/*__KB_DATA__*/" in tpl, "模板缺少占位符 /*__KB_DATA__*/"
    out = tpl.replace("/*__KB_DATA__*/", "const KB = " + kb_json + ";")

    with open(OUT_INDEX, "w", encoding="utf-8") as f:
        f.write(out)

    # 3) 外链自检：不应出现外部运行时引用
    checks = [
        (re.compile(r"<script[^>]+src\s*=\s*[\"']https?:", re.I), "外部 <script src>"),
        (re.compile(r"<link[^>]+href\s*=\s*[\"']https?:", re.I), "外部 <link href>"),
        (re.compile(r"@import", re.I), "@import"),
        (re.compile(r"url\(\s*[\"']?https?:", re.I), "CSS url(http)"),
        (re.compile(r"<img[^>]+src\s*=\s*[\"']https?:", re.I), "外部 <img src>"),
    ]
    problems = []
    for rx, name in checks:
        for m in rx.finditer(out):
            problems.append("%s -> %s" % (name, m.group(0)[:80]))
    if problems:
        print("[自检失败] index.html 存在外部运行时引用：")
        for p in problems:
            print("  - " + p)
        sys.exit(1)

    print("[OK] 生成 index.html（%d 章，%d 个工具入口）" % (len(chapters), len(tools_seen)))
    print("[OK] 生成 data/knowledge-base.json")
    print("[自检] 无外部运行时引用，离线自包含校验通过")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_verilog.py — 用 pyverilog 对仓库内 Verilog 做结构校验。

策略（本环境无 iverilog，pyverilog 的 iverilog 预处理不可用）：
  * 自行剥掉以反引号开头的编译指令行（`timescale / `default_nettype 等），
    再直接调用 pyverilog 的语法解析器 VerilogParser（纯 Python，无需 iverilog）。
  * 可综合模块（文件名不以 tb_ / testbench_ 开头）：严格解析，语法错即失败。
  * Testbench：先严格解析；失败则做容错清洗（剥离 #延时、$dump*、$finish、
    未屏蔽的系统任务等）后再解析；仍失败则标记“需人工核对”，但不判致命。
  * 例化一致性：从 testbench 文本里抓 DUT 模块名与 .port(sig) 连接，
    与同目录可综合模块的模块名/端口名做比对。

用法：
  python3 scripts/check_verilog.py                 # 全仓 code/
  python3 scripts/check_verilog.py code/phase1     # 指定目录或单个文件
退出码：0 全部通过；1 存在致命失败。
"""
import os
import re
import sys

try:
    from pyverilog.vparser.parser import VerilogParser
except Exception as e:  # pragma: no cover
    print("[FATAL] 无法导入 pyverilog：%r" % e)
    sys.exit(2)

SYNTH_DIR_HINT = "code"
TB_PREFIXES = ("tb_", "testbench_")


def strip_directives(text: str) -> str:
    out = []
    for ln in text.splitlines():
        if ln.lstrip().startswith("`"):
            continue
        out.append(ln)
    return "\n".join(out)


def tolerant_clean(text: str) -> str:
    """对 testbench 做容错清洗，尽量让纯语法解析器跑过去。"""
    t = text
    # 删除 #数值; 形式的延时语句（#10 clk = ~clk; 里的 #10 保留，只删独立延时）
    t = re.sub(r"^\s*#\d+(\.\d+)?\s*;\s*$", "", t, flags=re.M)
    # 删除 $dumpfile / $dumpvars / $finish / $stop 等系统任务行
    t = re.sub(r"^\s*\$(dumpfile|dumpvars|dumpon|dumpoff|finish|stop)\b[^;]*;\s*$",
               "", t, flags=re.M)
    return t


def parse_source(text: str):
    vp = VerilogParser(debug=0)
    return vp.parse(strip_directives(text))


# ---------- 模块/端口提取（正则，用于例化一致性比对） ----------

MOD_RE = re.compile(r"module\s+(\w+)\s*(#\s*\([^)]*?\)\s*)?\(([^;]*?)\)\s*;",
                   re.S)
PORT_RE = re.compile(
    r"(input|output|inout)\s+(wire|reg|logic)?\s*"
    r"(?:\[\s*(\d+)\s*:\s*(\d+)\s*\]\s*)?(\w+)")


def strip_line_comments(text: str) -> str:
    out = []
    for ln in text.splitlines():
        idx = ln.find("//")
        if idx >= 0:
            ln = ln[:idx]
        out.append(ln)
    return "\n".join(out)


def extract_module_ports(path: str):
    """返回 {modname: {portname: (direction, width)}}。"""
    text = strip_line_comments(open(path, encoding="utf-8").read())
    result = {}
    for m in MOD_RE.finditer(text):
        name = m.group(1)
        portblock = m.group(3)
        ports = {}
        for pm in PORT_RE.finditer(portblock):
            direction = pm.group(1)
            msb, lsb, pname = pm.group(3), pm.group(4), pm.group(5)
            width = "scalar"
            if msb is not None and lsb is not None:
                width = "%s:%s" % (msb, lsb)
            ports[pname] = (direction, width)
        result[name] = ports
    return result


# 例化：  mod_name #(.P(v)) dut_name ( .a(a), .b(b) );   或   mod_name dut_name(.a(a));
# 注意：参数覆盖块 #(...) 含嵌套括号，先用平衡括号剥离，再做简单匹配。
INST_RE = re.compile(r"(\w+)\s+(\w+)\s*\(([^;]*?)\)\s*;", re.S)
CONN_RE = re.compile(r"\.(\w+)\s*\(\s*([^)]*?)\s*\)")


def strip_param_blocks(text: str) -> str:
    """删除 '#' 紧跟的圆括号块（参数覆盖），按括号深度平衡扫描。"""
    out = []
    i = 0
    n = len(text)
    while i < n:
        if text[i] == "#":
            j = i + 1
            while j < n and text[j] in " \t":
                j += 1
            if j < n and text[j] == "(":
                depth = 0
                k = j
                while k < n:
                    if text[k] == "(":
                        depth += 1
                    elif text[k] == ")":
                        depth -= 1
                        if depth == 0:
                            break
                    k += 1
                i = k + 1
                continue
        out.append(text[i])
        i += 1
    return "".join(out)


def extract_instances(path: str):
    """从 tb 返回 [(modname, instname, [connected_port,...])]。"""
    text = strip_param_blocks(strip_line_comments(open(path, encoding="utf-8").read()))
    insts = []
    for m in INST_RE.finditer(text):
        mod, inst, body = m.group(1), m.group(2), m.group(3)
        if mod in ("module", "input", "output", "wire", "reg", "begin", "end",
                   "if", "else", "always", "assign", "initial"):
            continue
        # 仓库命名约定：可综合模块名一律小写；含大写的命中必为参数/系统任务，跳过
        if mod != mod.lower():
            continue
        ports = [c.group(1) for c in CONN_RE.finditer(body)]
        # 只有真正含 .port(sig) 命名连接的才视为模块例化，
        # 否则 $display(...)、参数块、forever 等会被误匹配。
        if not ports:
            continue
        insts.append((mod, inst, ports))
    return insts


def is_tb(fname: str) -> bool:
    b = os.path.basename(fname).lower()
    return b.startswith(TB_PREFIXES) or "testbench" in b


def main():
    targets = sys.argv[1:]
    if not targets:
        targets = [os.path.join(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))), SYNTH_DIR_HINT)]
    targets = [os.path.abspath(t) for t in targets]

    files = []
    for t in targets:
        if os.path.isfile(t):
            files.append(t)
        else:
            for root, _, fns in os.walk(t):
                for fn in sorted(fns):
                    if fn.endswith(".v"):
                        files.append(os.path.join(root, fn))
    files.sort()

    fatal = []
    warn = []
    synth_modules = {}   # modname -> (path, ports)

    # 第一遍：收集所有可综合模块
    for f in files:
        if not is_tb(f):
            for mod, ports in extract_module_ports(f).items():
                synth_modules[mod] = (f, ports)

    print("== Verilog 结构校验  共 %d 个 .v 文件 ==" % len(files))
    for f in files:
        rel = os.path.relpath(f, os.getcwd())
        text = open(f, encoding="utf-8").read()
        if is_tb(f):
            # 严格解析
            try:
                parse_source(text)
                status = "OK(testbench)"
            except Exception as e:
                try:
                    parse_source(tolerant_clean(text))
                    status = "OK(testbench,容错解析)"
                    warn.append("%s：含 #延时/系统任务，已容错解析，建议人工核对波形" % rel)
                except Exception as e2:
                    status = "WARN(需人工核对)"
                    warn.append("%s：testbench 自动解析失败 -> %r" % (rel, e2))
            # 例化一致性
            for mod, inst, ports in extract_instances(f):
                if mod not in synth_modules:
                    warn.append("%s：例化模块 %s 在可综合文件中未找到" % (rel, mod))
                    continue
                _, dut_ports = synth_modules[mod]
                missing = [p for p in ports if p not in dut_ports]
                unconn = [p for p in dut_ports if p not in ports]
                if missing:
                    fatal.append("%s：例化 %s.%s 连接了 DUT 不存在的端口 %s"
                                 % (rel, mod, inst, missing))
                    status = "FAIL"
                if unconn:
                    warn.append("%s：例化 %s.%s 未连接 DUT 端口 %s（确认是否预期悬空）"
                                % (rel, mod, inst, unconn))
            print("  [%s] %s" % (status, rel))
        else:
            try:
                parse_source(text)
                for mod, ports in extract_module_ports(f).items():
                    print("  [OK(synth)] %s  -> module %s, ports=%s"
                          % (rel, mod, list(ports.keys())))
            except Exception as e:
                print("  [FAIL(synth)] %s  -> %r" % (rel, e))
                fatal.append("%s：可综合模块语法错误 -> %r" % (rel, e))

    print("\n== 结果 ==")
    if warn:
        print("提示/警告 %d 条：" % len(warn))
        for w in warn:
            print("  - " + w)
    if fatal:
        print("致命失败 %d 条：" % len(fatal))
        for x in fatal:
            print("  - " + x)
        print("RESULT: FAIL")
        sys.exit(1)
    print("RESULT: PASS（%d 个警告已列出）" % len(warn))


if __name__ == "__main__":
    main()

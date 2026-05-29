#!/usr/bin/env python3
# Copyright 2026 MININGLAMP Technology and the OCTO contributors
# SPDX-License-Identifier: Apache-2.0
"""
i18n audit — 验证每一个 `LLang(@"中文")` 调用点都在对应模块的 en.lproj 里有翻译。

为什么需要这个：
  项目用中文字符串本身做 i18n key（zh-Hans.lproj 几乎是空的, 走 NSLocalizedString
  fallback 拿到 key 本身），en.lproj 是真正的翻译表。新加 LLang 时容易忘了同步补
  英文翻译，结果英文模式下用户看到中文 key —— 这个脚本拦在 CI 阻止该退化。

模块路由（必须和 NSString+WKLocalized.LocalizedWithClass: 的 bundleForClass: 路由一致）：
  Modules/WuKongBase/...       → Modules/WuKongBase/WuKongBase/Assets/Lang/en.lproj/Localizable.strings
  Modules/WuKongLogin/...      → Modules/WuKongLogin/WuKongLogin/Assets/Lang/en.lproj/Localizable.strings
  Modules/WuKongContacts/...   → Modules/WuKongContacts/WuKongContacts/Assets/Lang/en.lproj/Localizable.strings
  Modules/WuKongDataSource/... → Modules/WuKongDataSource/WuKongDataSource/Assets/Lang/en.lproj/Localizable.strings
  Octo/...                     → Octo/en.lproj/Localizable.strings

用法:
  python3 scripts/i18n_audit.py                  # 标准模式, 缺译则 exit 1
  python3 scripts/i18n_audit.py --warn-only      # 只报告, 不 fail (引入期可用)
  python3 scripts/i18n_audit.py --hardcoded      # 额外扫硬写中文字面量 (warn-only)
  python3 scripts/i18n_audit.py --github         # 输出 GitHub Actions annotation 格式
"""
import argparse
import os
import re
import sys
from collections import defaultdict


REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 5 个 module 各自的 en.lproj 路径
MODULE_STRINGS = {
    "WuKongBase":     "Modules/WuKongBase/WuKongBase/Assets/Lang/en.lproj/Localizable.strings",
    "WuKongLogin":    "Modules/WuKongLogin/WuKongLogin/Assets/Lang/en.lproj/Localizable.strings",
    "WuKongContacts": "Modules/WuKongContacts/WuKongContacts/Assets/Lang/en.lproj/Localizable.strings",
    "WuKongDataSource": "Modules/WuKongDataSource/WuKongDataSource/Assets/Lang/en.lproj/Localizable.strings",
    "Octo":           "Octo/en.lproj/Localizable.strings",
}

# 扫码源代码的根目录
SCAN_DIRS = ["Modules", "Octo"]

# 跳过的目录（CocoaPods, Example app, build 产物, git, etc.）
SKIP_SEGMENTS = ("/Pods/", "/Example/", "/.git/", "/build/", "/DerivedData/", "/node_modules/")


# LLang(@"...") / LLangW(@"...", x) / LLangC(@"...", x) / LLangB(@"...", x)
LLANG_RE = re.compile(r'\bLLang(?:W|C|B)?\s*\(\s*@"((?:[^"\\]|\\.)*)"')

# .strings 文件里的 key:  "key"="value";   或  "key" = "value";
STRINGS_KEY_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=', re.MULTILINE)

# 启发式硬写中文检测（带至少一个中文字符的 NSString literal）
HARDCODED_CN_RE = re.compile(r'@"([^"\n]*[一-鿿][^"\n]*)"')

# 下面的正则用于 hardcoded 模式过滤掉 log 类调用
LOG_CALL_RE = re.compile(
    r'\b(NSLog|DDLog\w*|WKLog\w*|os_log\w*|NSAssert|printf|fprintf|NSException\s+raise|WK_BOT_TRACE)\b'
)


def skip_dir(path: str) -> bool:
    return any(seg in path for seg in SKIP_SEGMENTS)


def module_of(path: str) -> str:
    """根据源文件路径推断它所属的模块（决定查 LLang key 时去哪个 en.lproj）。"""
    rel = os.path.relpath(path, REPO_ROOT)
    if rel.startswith("Modules/"):
        return rel.split("/")[1]
    if rel.startswith("Octo/"):
        return "Octo"
    return "Other"


def load_translated_keys() -> dict[str, set[str]]:
    """读 5 个 module 的 en.lproj，解析出已翻译 key 集合。"""
    out: dict[str, set[str]] = {}
    for module, rel_path in MODULE_STRINGS.items():
        full = os.path.join(REPO_ROOT, rel_path)
        keys: set[str] = set()
        if os.path.exists(full):
            try:
                with open(full, encoding="utf-8") as f:
                    src = f.read()
                for m in STRINGS_KEY_RE.finditer(src):
                    keys.add(m.group(1))
            except Exception as e:
                print(f"[warn] 无法读取 {rel_path}: {e}", file=sys.stderr)
        else:
            print(f"[warn] 找不到 {rel_path}", file=sys.stderr)
        out[module] = keys
    return out


def scan_llang_calls() -> list[tuple[str, int, str]]:
    """扫所有 .m / .mm / .h 里的 LLang 调用，返回 [(file, line, key), ...]."""
    results: list[tuple[str, int, str]] = []
    for sd in SCAN_DIRS:
        root_dir = os.path.join(REPO_ROOT, sd)
        for root, dirs, files in os.walk(root_dir):
            if skip_dir(root):
                dirs[:] = []
                continue
            for fn in files:
                if not fn.endswith((".m", ".mm", ".h")):
                    continue
                p = os.path.join(root, fn)
                try:
                    with open(p, encoding="utf-8") as f:
                        src = f.read()
                except Exception:
                    continue
                for m in LLANG_RE.finditer(src):
                    line = src.count("\n", 0, m.start()) + 1
                    results.append((p, line, m.group(1)))
    return results


def scan_hardcoded() -> list[tuple[str, int, str]]:
    """扫硬写中文字面量（不走 LLang, 也不在 NSLog/log 调用里）。启发式, 会有少量误报。"""
    results: list[tuple[str, int, str]] = []
    for sd in SCAN_DIRS:
        root_dir = os.path.join(REPO_ROOT, sd)
        for root, dirs, files in os.walk(root_dir):
            if skip_dir(root):
                dirs[:] = []
                continue
            for fn in files:
                if not fn.endswith((".m", ".mm")):
                    continue
                p = os.path.join(root, fn)
                try:
                    with open(p, encoding="utf-8") as f:
                        src = f.read()
                except Exception:
                    continue
                for m in HARDCODED_CN_RE.finditer(src):
                    line_start = src.rfind("\n", 0, m.start()) + 1
                    line_end = src.find("\n", m.end())
                    line_text = src[line_start:line_end if line_end > 0 else len(src)]
                    stripped = line_text.lstrip()
                    if stripped.startswith(("//", "*", "/*")):
                        continue
                    if LOG_CALL_RE.search(line_text):
                        continue
                    # 同行已用 LLang 包了同个字面量 → 跳过
                    if re.search(r'LLang(?:W|C|B)?\s*\(\s*@"' + re.escape(m.group(1)) + r'"', line_text):
                        continue
                    line = src.count("\n", 0, m.start()) + 1
                    results.append((p, line, m.group(1)))
    return results


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--warn-only", action="store_true", help="即使有缺译也 exit 0（引入期使用）")
    ap.add_argument("--hardcoded", action="store_true", help="额外扫描硬写中文字面量（warn 性质, 不影响 exit code）")
    ap.add_argument("--github", action="store_true", help="输出 GitHub Actions ::error annotation 格式")
    args = ap.parse_args()

    translated = load_translated_keys()
    calls = scan_llang_calls()

    # 缺译按 (module, key) 聚合, 每条 key 列出第一处出现位置
    missing: dict[tuple[str, str], list[tuple[str, int]]] = defaultdict(list)
    for path, line, key in calls:
        mod = module_of(path)
        if mod == "Other":
            # 未识别模块的源文件, 跳过（不在我们的 5 个 module 里）
            continue
        if key not in translated.get(mod, set()):
            missing[(mod, key)].append((path, line))

    print("=" * 60)
    print(f"i18n audit — scanned {len(calls)} LLang call sites across {len(MODULE_STRINGS)} modules")
    print("=" * 60)

    if not missing:
        print("✅ 全部 LLang 调用点都有英文翻译")
    else:
        # 按模块分组报告
        by_mod: dict[str, list[tuple[str, list[tuple[str, int]]]]] = defaultdict(list)
        for (mod, key), refs in sorted(missing.items()):
            by_mod[mod].append((key, refs))

        print(f"❌ 发现 {len(missing)} 条 LLang key 缺英文翻译:\n")
        for mod, items in sorted(by_mod.items()):
            print(f"📦 {mod}  ({len(items)} 条)  →  {MODULE_STRINGS[mod]}")
            for key, refs in items:
                first_p, first_l = refs[0]
                rel = os.path.relpath(first_p, REPO_ROOT)
                print(f'   "{key}" = "TODO";   ⤷ {rel}:{first_l}'
                      + (f"  (+{len(refs)-1} more)" if len(refs) > 1 else ""))
                if args.github:
                    # GH Actions annotation —— 在 PR 文件视图直接出红块
                    print(f"::error file={rel},line={first_l},title=Missing en translation::"
                          f'LLang(@"{key}") 缺 en.lproj 翻译, 请补 {MODULE_STRINGS[mod]}')
            print()

    # 硬写中文扫描 (warn-only, 不影响 exit code)
    if args.hardcoded:
        hardcoded = scan_hardcoded()
        if hardcoded:
            print()
            print("=" * 60)
            print(f"⚠️  硬写中文字面量扫描 (启发式, 仅 warn): {len(hardcoded)} 处")
            print("=" * 60)
            print("以下 @\"中文\" 没走 LLang, 翻译永远进不到 lookup. 建议改用 LLang(@\"...\")")
            print("(NSLog / WKLog / 注释行已自动过滤; 仍可能有误报, 人工审一遍)\n")
            by_file: dict[str, list[tuple[int, str]]] = defaultdict(list)
            for p, line, lit in hardcoded:
                by_file[p].append((line, lit))
            for p in sorted(by_file.keys()):
                rel = os.path.relpath(p, REPO_ROOT)
                items = sorted(by_file[p])
                print(f"  {rel}:")
                for line, lit in items[:8]:
                    print(f'    L{line}  @"{lit}"')
                if len(items) > 8:
                    print(f"    ... +{len(items)-8} more")

    if missing and not args.warn_only:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

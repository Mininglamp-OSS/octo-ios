// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKLaTeXPreprocessorTests.m
//  WuKongBase Tests
//
//  WKLaTeXPreprocessor 单测，覆盖：
//  - containsLaTeX 检测启发式
//  - 数学段抽取（$..$, $$..$$, \(..\), \[..\], 容错括号 (\\cmd..)）
//  - 命令转换（\section 系列、\textbf/\textit/\emph、\textbar{}、\\）
//  - 嵌套 brace-balanced 匹配（\textbf{X: \textit{Y}}）
//  - 环境处理（\begin{quote}/\begin{itemize}/\begin{enumerate}）
//  - 元命令丢弃（\label / \ref / \cite）
//  - 兜底未知命令保参数
//  - 端到端：CoCraft 截图里真实消息文本
//

@import XCTest;
#import <WuKongBase/WuKongBase-Swift.h>

@interface WKLaTeXPreprocessorTests : XCTestCase
@end

@implementation WKLaTeXPreprocessorTests

/// 模拟真实 UI 入口（WKTextMessageCell.getContentAttrStr:）的 gate flow:
/// 先 containsLaTeX 判断，命中才 preprocess。未命中返回空 segments 的原文。
/// 数学分隔符相关用例必须走这条路径，因为 containsLaTeX gate 不放行就永远不会
/// 跑 preprocess，pure-preprocess 的测试通过≠实际 UI 命中。
- (WKLaTeXPreprocessResult *)preprocessThroughGate:(NSString *)input {
    if (![WKLaTeXPreprocessor containsLaTeX:input]) {
        return [[WKLaTeXPreprocessResult alloc] initWithMarkdown:input mathSegments:@[]];
    }
    return [WKLaTeXPreprocessor preprocess:input];
}

#pragma mark - containsLaTeX

- (void)test_containsLaTeX_basic_commands_match {
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"\\section{X}"]);
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"\\subsection{X}"]);
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"\\textbf{X}"]);
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"\\begin{quote}A\\end{quote}"]);
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"\\label{x}"]);
}

- (void)test_containsLaTeX_math_delimiters_match {
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"\\(x^2\\)"]);
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"\\[x^2\\]"]);
    // $$ ... $$ display 数学：纯文本上下文（无任何 \cmd）也要命中。
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"a $$x^2$$ b"]);
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"$$\\sum_i x_i$$"]);
    // $ ... $ inline 数学（带 math-ish 字符）：纯文本上下文也要命中。
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"a $x^2$ b"]);
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"价格相关变量 $a_1$"]);
    XCTAssertTrue([WKLaTeXPreprocessor containsLaTeX:@"反斜杠数学 $\\Phi$"]);
}

- (void)test_containsLaTeX_currency_safeguard {
    // 货币 / 普通 $ 文本不应触发预处理（防止误判 → 把正文吞掉）。
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@"价格是 $10"]);
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@"成本 $100K 收入 $200K"]);
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@"$ + $"]); // 单字符 + 符号，无 math-ish
    // 已知漏检：单字母变量 $y$ 内部无 \^_{} 字符，gate 拒绝。
    // 用户应改写为 \(y\)，这是为防货币误判付出的可接受代价。
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@"$y$"]);
}

- (void)test_containsLaTeX_negative {
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@""]);
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@"普通中文消息"]);
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@"**markdown bold**"]);
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@"# heading\n- list item"]);
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@"看 https://example.com 这个网址"]);
    XCTAssertFalse([WKLaTeXPreprocessor containsLaTeX:@"$only single dollar but no math"]);
}

#pragma mark - Section commands

- (void)test_subsection_with_textbar {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"\\subsection{P25 \\textbar{} Open Problems}"];
    // 期望: ## P25 | Open Problems
    XCTAssertTrue([r.markdown containsString:@"## P25 | Open Problems"], @"got: %@", r.markdown);
    XCTAssertFalse([r.markdown containsString:@"\\subsection"]);
    XCTAssertFalse([r.markdown containsString:@"\\textbar"]);
}

- (void)test_subsubsection_to_h3 {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"\\subsubsection{讲述要点}"];
    XCTAssertTrue([r.markdown containsString:@"### 讲述要点"], @"got: %@", r.markdown);
}

- (void)test_section_levels_distinct {
    WKLaTeXPreprocessResult *r1 = [WKLaTeXPreprocessor preprocess:@"\\section{A}"];
    WKLaTeXPreprocessResult *r2 = [WKLaTeXPreprocessor preprocess:@"\\subsection{A}"];
    WKLaTeXPreprocessResult *r3 = [WKLaTeXPreprocessor preprocess:@"\\subsubsection{A}"];
    XCTAssertTrue([r1.markdown containsString:@"# A"]);
    XCTAssertTrue([r2.markdown containsString:@"## A"]);
    XCTAssertTrue([r3.markdown containsString:@"### A"]);
    // 确保 \section 没误吞 \subsection
    XCTAssertFalse([r2.markdown isEqualToString:r1.markdown]);
    XCTAssertFalse([r3.markdown isEqualToString:r2.markdown]);
}

#pragma mark - Format commands

- (void)test_textbf_simple {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"\\textbf{时长}:2min"];
    XCTAssertEqualObjects(r.markdown, @"**时长**:2min");
}

- (void)test_textit_and_emph {
    WKLaTeXPreprocessResult *r1 = [WKLaTeXPreprocessor preprocess:@"\\textit{X}"];
    WKLaTeXPreprocessResult *r2 = [WKLaTeXPreprocessor preprocess:@"\\emph{X}"];
    XCTAssertEqualObjects(r1.markdown, @"*X*");
    XCTAssertEqualObjects(r2.markdown, @"*X*");
}

- (void)test_texttt_to_inline_code {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"调用 \\texttt{foo()}"];
    XCTAssertEqualObjects(r.markdown, @"调用 `foo()`");
}

- (void)test_nested_textbf_textit {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"\\textbf{A: \\textit{B}}"];
    XCTAssertEqualObjects(r.markdown, @"**A: *B***");
}

- (void)test_textbf_inside_subsubsection {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"\\subsubsection{X}\n\\textbf{Problem 1}"];
    XCTAssertTrue([r.markdown containsString:@"### X"], @"got: %@", r.markdown);
    XCTAssertTrue([r.markdown containsString:@"**Problem 1**"], @"got: %@", r.markdown);
}

#pragma mark - Environments

- (void)test_quote_block_singleline {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"\\begin{quote}some content\\end{quote}"];
    XCTAssertTrue([r.markdown containsString:@"> some content"], @"got: %@", r.markdown);
}

- (void)test_quote_block_multiline {
    NSString *input = @"\\begin{quote}\nA\nB\nC\n\\end{quote}";
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:input];
    XCTAssertTrue([r.markdown containsString:@"> A\n> B\n> C"], @"got: %@", r.markdown);
}

- (void)test_itemize {
    NSString *input = @"\\begin{itemize}\\item one\\item two\\end{itemize}";
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:input];
    XCTAssertTrue([r.markdown containsString:@"- one"], @"got: %@", r.markdown);
    XCTAssertTrue([r.markdown containsString:@"- two"], @"got: %@", r.markdown);
}

- (void)test_enumerate {
    NSString *input = @"\\begin{enumerate}\\item first\\item second\\end{enumerate}";
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:input];
    XCTAssertTrue([r.markdown containsString:@"1. first"], @"got: %@", r.markdown);
    XCTAssertTrue([r.markdown containsString:@"2. second"], @"got: %@", r.markdown);
}

#pragma mark - Meta commands dropped

- (void)test_label_dropped {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"\\label{p25-open-problems}"];
    XCTAssertEqualObjects(r.markdown, @"");
}

- (void)test_subsection_with_trailing_label {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"\\subsection{X}\\label{abc}"];
    XCTAssertTrue([r.markdown containsString:@"## X"]);
    XCTAssertFalse([r.markdown containsString:@"\\label"]);
    XCTAssertFalse([r.markdown containsString:@"abc"]);
}

- (void)test_cite_dropped {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"see \\cite{Kaplan2020}"];
    XCTAssertFalse([r.markdown containsString:@"\\cite"]);
    XCTAssertFalse([r.markdown containsString:@"Kaplan2020"]);
}

#pragma mark - Atomic inline

- (void)test_textbar_to_pipe {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"A \\textbar{} B"];
    XCTAssertEqualObjects(r.markdown, @"A | B");
}

- (void)test_escape_chars {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"100\\% and A\\&B"];
    XCTAssertEqualObjects(r.markdown, @"100% and A&B");
}

#pragma mark - Unknown commands fallback

- (void)test_unknown_braced_cmd_keeps_content {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"\\foobar{some content}"];
    XCTAssertEqualObjects(r.markdown, @"some content");
}

- (void)test_unknown_no_arg_cmd_dropped {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"hello \\unknowncmd world"];
    // \unknowncmd 后是空格不是 {，按无参兜底丢弃
    XCTAssertTrue([r.markdown containsString:@"hello"]);
    XCTAssertTrue([r.markdown containsString:@"world"]);
    XCTAssertFalse([r.markdown containsString:@"\\unknowncmd"]);
}

#pragma mark - Math: standard delimiters (must pass through containsLaTeX gate)

- (void)test_math_inline_single_dollar_through_gate {
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:@"a $x^2$ b"];
    XCTAssertEqual(r.mathSegments.count, 1, @"$...$ 必须经 gate 抽到数学段");
    XCTAssertEqualObjects(r.mathSegments[0].tex, @"x^2");
    XCTAssertFalse(r.mathSegments[0].isDisplay);
    XCTAssertTrue([r.markdown containsString:@"￼"]);
}

- (void)test_math_display_double_dollar_through_gate {
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:@"$$\\sum_i x_i$$"];
    XCTAssertEqual(r.mathSegments.count, 1);
    XCTAssertEqualObjects(r.mathSegments[0].tex, @"\\sum_i x_i");
    XCTAssertTrue(r.mathSegments[0].isDisplay);
}

- (void)test_math_inline_paren_escape {
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:@"\\(x^2\\)"];
    XCTAssertEqual(r.mathSegments.count, 1);
    XCTAssertEqualObjects(r.mathSegments[0].tex, @"x^2");
    XCTAssertFalse(r.mathSegments[0].isDisplay);
}

- (void)test_math_display_bracket_escape {
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:@"\\[\\int_0^1\\]"];
    XCTAssertEqual(r.mathSegments.count, 1);
    XCTAssertEqualObjects(r.mathSegments[0].tex, @"\\int_0^1");
    XCTAssertTrue(r.mathSegments[0].isDisplay);
}

- (void)test_math_currency_not_extracted_through_gate {
    // 通过 gate 入口：货币应当原样保留，不抽段
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:@"成本 $100 收入 $200"];
    XCTAssertEqual(r.mathSegments.count, 0, @"货币不应被当作数学抽走");
    XCTAssertTrue([r.markdown containsString:@"$100"]);
    XCTAssertTrue([r.markdown containsString:@"$200"]);
}

- (void)test_math_currency_mixed_with_real_math {
    // 同段既有真数学又有货币 → 数学被抽，货币保留
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:@"变量 $x_1$ 的价格是 $5 元"];
    XCTAssertEqual(r.mathSegments.count, 1, @"应当只抽 $x_1$，不抽 $5");
    XCTAssertEqualObjects(r.mathSegments[0].tex, @"x_1");
    XCTAssertTrue([r.markdown containsString:@"$5 元"]);
}

- (void)test_math_paren_fallback_through_gate {
    // 容错括号 (\Phi_k) 单独成消息：gate 必须放行，否则 extractMath 永远没机会跑。
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:@"see (\\Phi_k)"];
    XCTAssertEqual(r.mathSegments.count, 1, @"(\\Phi_k) 必须经 gate 抽到数学段");
    XCTAssertEqualObjects(r.mathSegments[0].tex, @"\\Phi_k");
}

- (void)test_math_paren_fallback_nested_through_gate {
    // 含嵌套括号 + 内部 \cmd 的真实 CoCraft 场景
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:@"条件是 (\\Phi_k(C) > \\Phi_k(A))"];
    XCTAssertEqual(r.mathSegments.count, 1);
    XCTAssertEqualObjects(r.mathSegments[0].tex, @"\\Phi_k(C) > \\Phi_k(A)");
}

- (void)test_math_paren_normal_text_through_gate_no_extract {
    // 普通括号 (just plain text)：gate 可能放行，但 extractMath 一定不抽段
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:@"(just plain text)"];
    XCTAssertEqual(r.mathSegments.count, 0, @"普通括号不应被当数学");
}

- (void)test_math_display_multiline_through_gate {
    // 多行 $$..$$：开闭分隔符跨行（单段落内）。extract 支持, gate 必须放行。
    NSString *src = @"前文\n$$\n x^2 \n$$\n后文";
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:src];
    XCTAssertEqual(r.mathSegments.count, 1, @"多行 $$..$$ 必须经 gate 抽到");
    XCTAssertTrue(r.mathSegments[0].isDisplay);
    XCTAssertTrue([r.mathSegments[0].tex containsString:@"x^2"], @"got: %@", r.mathSegments[0].tex);
}

- (void)test_math_display_does_not_cross_paragraph_through_gate {
    // 中间有空行（段落断）→ gate 与 extract 都应拒绝
    NSString *src = @"$$\n\nx^2\n\n$$";
    WKLaTeXPreprocessResult *r = [self preprocessThroughGate:src];
    XCTAssertEqual(r.mathSegments.count, 0, @"跨段落 $$..$$ 不应被抽");
}

#pragma mark - Math: fallback (...) heuristic

- (void)test_math_paren_fallback_simple {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"see (\\Phi_k)"];
    XCTAssertEqual(r.mathSegments.count, 1);
    XCTAssertEqualObjects(r.mathSegments[0].tex, @"\\Phi_k");
}

- (void)test_math_paren_fallback_balanced_inner {
    // (\Phi_k(C) > \Phi_k(A)) 整段应当算一个 inline math segment
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"(\\Phi_k(C) > \\Phi_k(A))"];
    XCTAssertEqual(r.mathSegments.count, 1);
    XCTAssertEqualObjects(r.mathSegments[0].tex, @"\\Phi_k(C) > \\Phi_k(A)");
}

- (void)test_math_paren_normal_text_not_eaten {
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"(just plain words)"];
    XCTAssertEqual(r.mathSegments.count, 0);
    XCTAssertTrue([r.markdown containsString:@"(just plain words)"]);
}

- (void)test_math_paren_does_not_cross_paragraph {
    // 跨段落不抽（防止误吃整段）
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:@"(\\Phi_k\n\n some other paragraph)"];
    XCTAssertEqual(r.mathSegments.count, 0);
}

#pragma mark - End-to-end: real CoCraft message

- (void)test_real_cocraft_message {
    NSString *src = @"\\subsection{P25 \\textbar{} Open Problems}\\label{p25-open-problems}\n"
                    @"\\textbf{时长}:2min \\textbar{} \\textbf{目标}:留给教授们的礼物\n"
                    @"\\subsubsection{讲述要点}\\label{ux8bb2ux8ff0ux8981ux70b9-25}\n"
                    @"\\textbf{Problem 1:Conjecture 1的严格证明}\n"
                    @"\\begin{quote}\n"
                    @"证明或证伪:当C1-C5同时满足时,(\\Phi_k(C) > \\Phi_k(A))是否成立?具体地:(a) 给出 (\\Phi_k)的精确可计算定义;(b) 证明 composability条件下(\\Phi_k)关于 (D_\\text{有效})的单调性;(c) 刻画C1-C5何时构成充分条件。\n"
                    @"\\end{quote}\n"
                    @"\\textbf{Problem 2:Scaling Out的函数形式}\n"
                    @"\\begin{quote}\n"
                    @"(\\Phi_k(K, G, s, \\sigma_\\eta))\n"
                    @"的函数形式?\n"
                    @"\\end{quote}";
    WKLaTeXPreprocessResult *r = [WKLaTeXPreprocessor preprocess:src];

    // 关键 markdown 结构存在
    XCTAssertTrue([r.markdown containsString:@"## P25 | Open Problems"], @"got: %@", r.markdown);
    XCTAssertTrue([r.markdown containsString:@"### 讲述要点"], @"got: %@", r.markdown);
    XCTAssertTrue([r.markdown containsString:@"**时长**:2min"], @"got: %@", r.markdown);
    XCTAssertTrue([r.markdown containsString:@"**Problem 1:Conjecture 1的严格证明**"], @"got: %@", r.markdown);
    XCTAssertTrue([r.markdown containsString:@"**Problem 2:Scaling Out的函数形式**"], @"got: %@", r.markdown);
    XCTAssertTrue([r.markdown containsString:@"> 证明或证伪"], @"quote 段未生效, got: %@", r.markdown);

    // LaTeX 命令字面量应全部消失
    XCTAssertFalse([r.markdown containsString:@"\\subsection"], @"残留 \\subsection: %@", r.markdown);
    XCTAssertFalse([r.markdown containsString:@"\\subsubsection"], @"残留 \\subsubsection: %@", r.markdown);
    XCTAssertFalse([r.markdown containsString:@"\\textbf"], @"残留 \\textbf: %@", r.markdown);
    XCTAssertFalse([r.markdown containsString:@"\\textbar"], @"残留 \\textbar: %@", r.markdown);
    XCTAssertFalse([r.markdown containsString:@"\\begin"], @"残留 \\begin: %@", r.markdown);
    XCTAssertFalse([r.markdown containsString:@"\\end"], @"残留 \\end: %@", r.markdown);
    XCTAssertFalse([r.markdown containsString:@"\\label"], @"残留 \\label: %@", r.markdown);

    // 数学段：CoCraft 里有 5 个 (\Phi_k...) / (D_\text{有效}) 段
    //   1: (\Phi_k(C) > \Phi_k(A))
    //   2: (\Phi_k)
    //   3: (\Phi_k)
    //   4: (D_\text{有效})
    //   5: (\Phi_k(K, G, s, \sigma_\eta))
    // 注意 (a) (b) (c) 不应被抽（不含反斜杠命令）
    XCTAssertGreaterThanOrEqual(r.mathSegments.count, 4, @"数学段抽得太少: %@", @(r.mathSegments.count));
    XCTAssertLessThanOrEqual(r.mathSegments.count, 6, @"数学段抽得太多（可能误吃了普通括号）: %@", @(r.mathSegments.count));

    // 占位符数量 == segments 数量
    NSInteger placeholders = 0;
    for (NSUInteger i = 0; i < r.markdown.length; i++) {
        if ([r.markdown characterAtIndex:i] == 0xFFFC) placeholders++;
    }
    XCTAssertEqual(placeholders, (NSInteger)r.mathSegments.count);
}

#pragma mark - Math placeholder replacement (Phase 2: iosMath attachment 优先 + Phase 1 monospace 回退)

// 兼容两条路径：iosMath 能解析 → 出 attachment；解析失败 → 等宽 $tex$ 回退。
// 测试只断言"占位符消失"和"有 attachment 或 fallback 文本之一"。

static NSInteger WK_AttachmentCount(NSAttributedString *attr) {
    __block NSInteger count = 0;
    [attr enumerateAttribute:NSAttachmentAttributeName
                     inRange:NSMakeRange(0, attr.length)
                     options:0
                  usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value) count++;
    }];
    return count;
}

- (void)test_replace_math_placeholders_inline {
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:@"前 ￼ 后"];
    NSArray *segs = @[ [[WKLaTeXMathSegment alloc] initWithTex:@"x^2" isDisplay:NO] ];
    [WKLaTeXPreprocessor replaceMathPlaceholdersIn:attr segments:segs fontSize:16 isDark:NO];

    BOOL hasAttachment = WK_AttachmentCount(attr) > 0;
    BOOL hasFallback = [attr.string containsString:@"$x^2$"];
    XCTAssertTrue(hasAttachment || hasFallback,
                  @"既无 attachment 也无 monospace 回退: %@", attr.string);
}

- (void)test_replace_math_placeholders_display {
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:@"￼"];
    NSArray *segs = @[ [[WKLaTeXMathSegment alloc] initWithTex:@"\\sum" isDisplay:YES] ];
    [WKLaTeXPreprocessor replaceMathPlaceholdersIn:attr segments:segs fontSize:16 isDark:NO];

    BOOL hasAttachment = WK_AttachmentCount(attr) > 0;
    BOOL hasFallback = [attr.string containsString:@"$$\\sum$$"];
    XCTAssertTrue(hasAttachment || hasFallback,
                  @"display 公式未渲染: %@", attr.string);
}

- (void)test_replace_math_placeholders_multiple_in_order {
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:@"￼ + ￼ = ￼"];
    NSArray *segs = @[
        [[WKLaTeXMathSegment alloc] initWithTex:@"a" isDisplay:NO],
        [[WKLaTeXMathSegment alloc] initWithTex:@"b" isDisplay:NO],
        [[WKLaTeXMathSegment alloc] initWithTex:@"c" isDisplay:NO]
    ];
    [WKLaTeXPreprocessor replaceMathPlaceholdersIn:attr segments:segs fontSize:16 isDark:NO];

    // 三个 segments 应当全部被替换：要么三个 attachment，要么三段 fallback 文本，
    // 要么混合（不太可能但允许）。总之没有"原始占位 vs 替换"区分手段，只校验数量。
    NSInteger attachmentCount = WK_AttachmentCount(attr);
    NSInteger fallbackCount = 0;
    for (NSString *needle in @[@"$a$", @"$b$", @"$c$"]) {
        if ([attr.string containsString:needle]) fallbackCount++;
    }
    XCTAssertEqual(attachmentCount + fallbackCount, 3,
                   @"3 个数学段应当全部被替换，实际 attachment=%ld fallback=%ld string=%@",
                   (long)attachmentCount, (long)fallbackCount, attr.string);
}

@end

# OCTO Context Gesture 行为规格

> 替换 `TelegramUtils/Display` 里的 GPL v2 手势 / 节点系统，目标是让
> `WKMessageCell` 系列 cell 不再依赖任何 GPL 代码，整库可以发 Apache-2.0。
>
> 本文档**纯行为规格**，写作时未参考 Telegram 任何源文件，只来自：
> 1. 消费方契约（见 [契约报告](#1-契约--api-面)）
> 2. 黑盒行为观察（带 ✅ 标记的为已知；带 🔍 标记的为待你手测）
> 3. iOS 通用手势协作工程经验（`UIGestureRecognizerDelegate`、`UIScrollView.panGestureRecognizer`、`UINavigationController.interactivePopGestureRecognizer`）

---

## 0. 总览

新增 3 个类（位于 `Modules/WuKongBase/.../Common/Octo/`，Apache-2.0）：

| 类 | 类型 | 替换 |
|---|---|---|
| `WKMultiTapGesture` | `NSObject`（持有内部 `UIGestureRecognizer` 子类） | `TapLongTapOrDoubleTapGestureRecognizerWrap` |
| `WKContextContainerView` | `UIView` | `ContextExtractedContentContainingNode` |
| `WKContextSourceView` | `UIView`（内部持有长按手势） | `ContextControllerSourceNode` |

`ContextGesture` 不需要独立新类——消费方只把它当 token 透传给业务 `onLongTap:`，新实现里它就是 `UIGestureRecognizer*`。

`WKTapLongTapOrDoubleTapGestureRecognizerEvent`（已有，Apache-2.0）的 enum 保持不变。

---

## 1. 契约 / API 面

### 1.1 `WKMultiTapGesture`

```objc
@interface WKMultiTapGesture : NSObject

// 主回调：每次识别成功（tap / doubleTap / longTap / hold）触发一次
- (instancetype)initWithAction:(void(^)(WKMultiTapGesture *self))action;

// 触发前问消费方：当前坐标应当 Wait-Single-Tap 还是别的（决策点）
@property(nonatomic, copy, nullable) WKTapLongTapOrDoubleTapGestureRecognizerEvent *(^tapActionAtPoint)(CGPoint pointInAttachedView);

// 长按触发回调（独立于主回调）
@property(nonatomic, copy, nullable) void(^longTap)(CGPoint pointInAttachedView, WKMultiTapGesture *self);

// 触发后由消费方读
@property(nonatomic, readonly) WKTapLongTapOrDoubleTapGesture tapAction;  // Tap / DoubleTap / LongTap / Hold
@property(nonatomic, readonly) CGPoint tapPoint;

- (void)setup;                      // 创建内部 UIGestureRecognizer
- (void)attachToView:(UIView *)view;// addGestureRecognizer:

@end
```

### 1.2 `WKContextContainerView`

```objc
@interface WKContextContainerView : UIView
@property(nonatomic, strong, readonly) UIView *contentNode;        // 实际承载 UI 的 subview（兼容旧字段名，可考虑直接是 self）
@property(nonatomic, assign) CGRect contentRect;                   // 长按弹菜单时高亮 / 凸显的矩形
- (void)layoutUpdatedForOCWithSize:(CGSize)size;                   // 通知尺寸变化
@end
```

### 1.3 `WKContextSourceView`

```objc
@interface WKContextSourceView : UIView
@property(nonatomic, copy, nullable) BOOL(^shouldBegin)(CGPoint point);
@property(nonatomic, copy, nullable) void(^activated)(UIGestureRecognizer *g, CGPoint point);
@property(nonatomic, weak, nullable) UIView *targetNodeForActivationProgress;
@property(nonatomic, assign) BOOL isGestureEnabled;                // 默认 YES

// OC 兼容方法（保留旧名以最小化消费方改动）
- (void)targetNodeForActivationProgressContentRectForOCWithRect:(CGRect)rect;
@end
```

为最小化迁移成本，可以在过渡期内提供 typedef：
```objc
typedef WKContextContainerView ContextExtractedContentContainingNode_DEPRECATED;
typedef WKContextSourceView ContextControllerSourceNode_DEPRECATED;
typedef WKMultiTapGesture TapLongTapOrDoubleTapGestureRecognizerWrap_DEPRECATED;
```
但更干净是 Step 4 一次性把消费方那三个文件里的类名也改了。

---

## 2. `WKMultiTapGesture` 状态机

### 2.1 输入事件

- `touchesBegan:` — 一指落下
- `touchesMoved:` — 移动
- `touchesEnded:` — 抬起
- `touchesCancelled:` — 系统取消（拨打来电、scrollview 抢断等）
- 定时器：long-press 阈值定时器、double-tap 窗口定时器

### 2.2 状态

```
IDLE
 └─touchesBegan
     │  记录 startPoint, 启动 long-press 定时器
     ▼
WAIT_FOR_FIRST_TAP
 ├─touchesEnded 在阈值时间内
 │   │  问消费方 tapActionAtPoint:
 │   │   ├─WaitForSingleTap → 启动 single-tap 解歧定时器
 │   │   │                   ▼
 │   │   │                   WAIT_FOR_DOUBLE_TAP
 │   │   └─其它 enum 取值 → 立即派发 Tap
 │   ▼
 │  （等下个事件或定时器）
 ├─touchesMoved 超过移动阈值
 │   │  取消手势 → IDLE
 ├─long-press 定时器到期
 │   │  longTap 回调
 │   │  （注意：长按触发 longTap 后是否进入 HOLD 状态等抬起？见 §2.4）
 │   ▼
 │   HOLD_ACTIVE
 └─touchesCancelled
     └─→ IDLE
```

```
WAIT_FOR_DOUBLE_TAP
 ├─touchesBegan 第二次（在 double-tap 窗口内）
 │   ▼
 │   WAIT_FOR_SECOND_TAP_END
 │     └─touchesEnded → tapAction=DoubleTap, 派发主回调
 │       → IDLE
 ├─single-tap 解歧定时器到期
 │   │  tapAction=Tap, 派发主回调
 │   └─→ IDLE
```

### 2.3 关键阈值（**未指定具体数值**，由实现者基于黑盒测试或常识取值）

| 阈值 | 含义 | 推荐范围 | 来源 |
|---|---|---|---|
| `beginDelay` | 触摸落下到 long-press 触发的时间 | 0.10 – 0.20 s | 🔍 待你测 |
| `doubleTapWindow` | 第一次抬起到第二次落下的最大间隔 | 0.20 – 0.35 s | iOS 系统默认 ~0.25s |
| `movementCancelThreshold` | 触发移动取消的最小位移 | 8 – 12 pt | iOS 通用 |
| `tapActivationThreshold` | 单击与长按抬起的分界（抬起得太晚就不算 tap） | 0.5 – 0.8 s | 🔍 待你测 |

> ⚠️ 实现时这些值要么从黑盒观察得到，要么用 iOS 通用值。**不查 Telegram 源码取它的常量**。

### 2.4 待验证行为 🔍

请在装着旧版的 App 里实测以下场景，把结果告诉我：

| # | 操作 | 期望 | 旧版表现 |
|---|---|---|---|
| V1 | 消息气泡按下立刻抬起（< 100ms） | 派发 Tap | ? |
| V2 | 按下 150ms 抬起 | Tap 还是 LongTap？ | ? |
| V3 | 按下 250ms 抬起 | LongTap 还是 Tap？ | ? |
| V4 | 按下不动 300ms（不抬起） | longTap 回调？是否仍可再抬起后派发 Tap？ | ? |
| V5 | 按下移动 5pt 再抬起 | 仍算 Tap 吗？ | ? |
| V6 | 按下移动 15pt（超阈值） | 手势取消，不派发 | ? |
| V7 | 双击间隔 100ms | DoubleTap | ? |
| V8 | 双击间隔 400ms | 两次 Tap 还是 DoubleTap？ | ? |
| V9 | 按下气泡时另一指点击其它位置 | 第二指被忽略，还是取消第一指？ | ? |
| V10 | 按下气泡同时向下滚动 tableview | 手势 cancel，滚动正常？ | ? |

回答这 10 个场景后，我能把规格 §2.3 的阈值和 §2.2 的边界分支固化下来。

---

## 3. `WKContextSourceView` 长按手势

### 3.1 用途

跟 `WKMultiTapGesture` 是**两套独立的手势**：
- `WKMultiTapGesture` — 处理点击、双击、avatar / sendFail 等按钮点击。范围：整个 cell.contentView
- `WKContextSourceView` 的手势 — **气泡范围内**的长按 → 弹上下文菜单。activated 回调由消费方 `onLongTap:` 接管去显示菜单

### 3.2 行为契约

- 内部用一个**长按手势识别器**（`UILongPressGestureRecognizer` 子类即可，无需自定义状态机——比 `WKMultiTapGesture` 简单）
- `shouldBegin(point)` 由消费方决定（在 `WKMessageCell.shouldBeginContextGestureAtPoint:` 里检查 `bubbleBackgroundView.frame contains point`）
- 长按触发后调 `activated(gesture, point)` 回调
- `isGestureEnabled = NO` 时手势完全失效（编辑模式 / 多选模式）

### 3.3 关键阈值

| 阈值 | 含义 | 推荐范围 |
|---|---|---|
| `minimumPressDuration` | 长按触发时间 | 0.5 s（iOS 默认）或更短 0.3 – 0.5 s 🔍 |
| `allowableMovement` | 长按期间允许的最大手指移动 | 10 pt（iOS 默认） |

### 3.4 跟 `WKMultiTapGesture` 的竞争

两套手势挂在同一个视图层级上（cell.contentView + bubbleSourceView 嵌套），需要协调：

- `WKContextSourceView` 的长按**应当优先**触发——一旦它进入 `Began` 状态，`WKMultiTapGesture` 应当 cancel
- 所以 `WKMultiTapGesture` 实现 `UIGestureRecognizerDelegate.gestureRecognizer:shouldBeRequiredToFailBy:` 让自己 require 长按 fail
- **或者**反过来：长按的 delegate 让 `WKMultiTapGesture` 取消（通过 `UIGestureRecognizerDelegate.shouldRecognizeSimultaneouslyWithGestureRecognizer:` 返回 NO）

具体策略由实现者选择，**确保两套不会同时派发**就行。

### 3.5 `targetNodeForActivationProgress`

旧实现把"长按进度动画作用对象"指向 `mainContextSourceNode.contentNode`。**新实现可以彻底跳过该属性的视觉效果**——CLAUDE.md 里已经记录原 Telegram 高亮/弹跳效果"不做任何气泡视觉变化"（见 `WKMessageCell.m:412` 注释）。

新实现里：
- 保留 `.targetNodeForActivationProgress` 属性 + `targetNodeForActivationProgressContentRectForOCWithRect:` 方法签名（让消费方零改动），但**实现成 no-op**

---

## 4. `WKContextContainerView`

最简单的一个。就是一个 UIView 容器：

- `init` → 自身就是一个 `UIView`，`userInteractionEnabled = YES`，`backgroundColor = .clear`
- `contentNode` 字段：可以让它**就指向 self**（旧三跳 `.contentNode.view.addSubview:` 退化成 `self.addSubview:`），消费方代码不用改
- `frame` / `bounds` 标准 UIView 行为
- `contentRect`：纯数据字段，长按弹菜单时由旧的 `ContextController` 替代品（`WKConversationContextImpl.showInlineMenuForCell`）读它决定菜单凸显矩形
- `layoutUpdatedForOCWithSize:`：**no-op**（这个旧方法在新实现里是冗余通知，UIKit 的 layoutSubviews 自动处理）

---

## 5. 与系统手势的协作

### 5.1 不撞 `UIScrollView.panGestureRecognizer`（tableview 滚动）

消息列表是 `UITableView`，内部 `panGestureRecognizer` 负责滚动。

**规则**：
- `WKMultiTapGesture` 内部的手势 implement `UIGestureRecognizerDelegate.gestureRecognizer:shouldRequireFailureOfGestureRecognizer:` 返回 **NO**（不要求 scroll 失败）
- 通过 `gestureRecognizer:shouldBeRequiredToFailBy:` 返回 **NO**（也不被 scroll 要求失败）
- 手势识别期间如果手指移动超过 `movementCancelThreshold`（§2.3），主动 `state = .cancelled`，让 scroll 接管

这样的效果是：
- 用户轻按抬起 → tap 触发，scroll 不动
- 用户按下后立刻向下滑 → 我们的手势 cancel，scroll 接管

### 5.2 不撞 `UINavigationController.interactivePopGestureRecognizer`（右滑返回）

**规则**：
- `WKMultiTapGesture` 的内部识别器 implement `gestureRecognizer:shouldBeRequiredToFailBy:`，对 `interactivePopGestureRecognizer` 返回 **YES**——意思是"等右滑返回先 fail 我才识别"
- 这样从屏幕左边缘按下时，右滑返回优先，我们的手势被 fail

如果实测发现右滑返回失效，调整方向：让我们的手势在 `touchesBegan` 的 `startPoint.x < 20` 时主动 fail。

---

## 6. 不在本规格范围

- 长按弹菜单的菜单 UI 本身（已经替换为 `WKConversationContextImpl.showInlineMenuForCell`）
- 长按时的气泡缩放 / 高亮动画（明确不做）
- 拖拽 / 平移 / 缩放手势（消费方未使用）

---

## 7. 实现 / 测试顺序（Step 3 流程）

1. 写 `WKMultiTapGesture`（核心，包含状态机）+ 单元测试覆盖 §2.4 的 10 个场景
2. 写 `WKContextContainerView`（最简单）
3. 写 `WKContextSourceView`
4. （**Step 3.5 事后审计**）独立写完后，对照 Telegram 源做行为级 gap 审计：只识别漏的场景 / 边界，不抄代码；修复方案独立设计
5. （Step 4）切消费方
6. （Step 5）编译 + 手测旧版用例

---

## 附录 A：旧 enum 保留

`WKTapLongTapOrDoubleTapGestureRecognizerEvent.h` 中的两个 enum（`WKTapLongTapOrDoubleTapGestureRecognizerAction` 和 `WKTapLongTapOrDoubleTapGesture`）已是我们的 Apache-2.0 资产，**不动**。新实现继续返回 / 设置这些 enum 值。

## 附录 B：旧 OC 桥名称保留考量

旧字段 `mainContainerNode` / `mainContextSourceNode` / `tapLongTapOrDoubleTapGestureRecognizerWrap` 名字偏长且带 `Node` 残留概念。Step 4 一并改名建议：

| 旧 | 新 |
|---|---|
| `mainContainerNode` | `contextSourceView` |
| `mainContextSourceNode` | `contextContainerView` |
| `tapLongTapOrDoubleTapGestureRecognizerWrap` | `tapGesture` |

但这是顺手清理，不强求。

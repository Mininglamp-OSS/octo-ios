# 工程规范 (AI / 代码评审共同遵守)

## Swizzle / +load 白名单

新增 `+load`、`+initialize` 中的行为修改（`method_exchangeImplementations`、
`class_replaceMethod`、`swizzleInstanceMethodOfClass:` 等），以及对 `NSObject`、
`NSNotificationCenter`、UIKit 基类方法的 swizzle，必须满足：

1. PR 描述声明理由 + 直接消费方（类/方法名）。
2. 提供可关闭开关（宏或启动参数），并在实现文件头部注释"回退到原实现的路径"。
3. 消费方若在 ≥30 天内无任何调用者，swizzle 必须同步移除 —— 不允许"为了将来用"而常驻。
4. 对 `NSNotificationCenter postNotificationName:` 这类高频路径的 swizzle 默认禁止；
   若有刚需，需把 handler 逻辑限定在特定通知名前缀上，且在 Bugly 抓栈归因上做好验证。

已知历史包袱（不要再往里加东西，优先逐步迁出）:

- `Modules/WuKongBase/WuKongBase/Classes/Sections/Common/TelegramUtils/` —— Telegram
  桌面客户端移植代码，大部分显示层 (`Display/`) 未被实例化。新代码请勿依赖此目录。

## 调试工具的生命周期

仅为开发期排障使用的组件（检测器、日志增强、性能探针），必须：

- 文件头部注释写明「调试用途，上线前禁用」。
- 启动入口放在一个明确的函数里（避免散落在 `application:didFinishLaunching...:`），
  以便一键关闭。
- 发布分支合入前确认该启动调用已被条件编译或注释屏蔽。

参考：`WKANRWatchdog` (已在 `WKApp.m` 中关闭启动调用)。

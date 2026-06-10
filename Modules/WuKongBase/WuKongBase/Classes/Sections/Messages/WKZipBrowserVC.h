//
//  WKZipBrowserVC.h
//  WuKongBase
//
//  ZIP 压缩包解压浏览: 点击 .zip 文件消息 → (加密则弹密码) → 解压到临时目录 →
//  按目录层级浏览内部文件 → 点文件用 WKSafeFilePreviewVC 预览。
//  仅支持 .zip (SSZipArchive 能力范围); rar/7z 等仍走「暂时无法预览」占位页。
//

#import "WKBaseVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKZipBrowserVC : WKBaseVC

/// 入口编排: 检测加密 → 弹密码 → 后台解压(带 HUD) → 成功则开浏览窗口。
/// zipPath: 本地已下载的 .zip 路径; title: 显示用压缩包名; msgNo: 用于临时目录命名。
+ (void)openZipAtPath:(NSString *)zipPath
                title:(NSString *)title
          clientMsgNo:(nullable NSString *)msgNo;

@end

NS_ASSUME_NONNULL_END

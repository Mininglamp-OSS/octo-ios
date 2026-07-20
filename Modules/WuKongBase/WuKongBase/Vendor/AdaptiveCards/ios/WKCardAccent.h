//
//  WKCardAccent.h
//  [octo] 互动卡片强调色：把 ACR 默认的系统蓝换成 app 主体灰黑色系(对齐首页 tabbar 选中/
//  navBarButtonColor：浅色 rgb(49,49,49)、深色白)，并保证深色模式自适应可见。
//  自包含(不依赖 app 头文件)，供 vendored ACR 输入控件复用。
//
#import <UIKit/UIKit.h>

/// 前景强调色(文字/图标/选中圆圈/日期完成按钮)：浅色深灰 #313131，深色白。
static inline UIColor *WKCardAccentColor(void) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor whiteColor];
            }
            return [UIColor colorWithRed:49.0/255.0 green:49.0/255.0 blue:49.0/255.0 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:49.0/255.0 green:49.0/255.0 blue:49.0/255.0 alpha:1.0];
}

/// 开关(UISwitch)ON 轨道色：需与白色滑块对比，故深色用中灰 #8E8E93(而非白)避免白滑块看不见。
static inline UIColor *WKCardSwitchOnColor(void) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:142.0/255.0 green:142.0/255.0 blue:147.0/255.0 alpha:1.0];
            }
            return [UIColor colorWithRed:49.0/255.0 green:49.0/255.0 blue:49.0/255.0 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:49.0/255.0 green:49.0/255.0 blue:49.0/255.0 alpha:1.0];
}

/// 填充按钮底色(展开/OpenUrl/Submit 等)：浅色深灰 #313131，深色中深灰 #5A5A5C(深色卡片上可见)。
/// 白色标题在两者上都可读；与 host config 的 accent(正向按钮)取值一致，保证全部按钮同色。
static inline UIColor *WKCardButtonBackgroundColor(void) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:90.0/255.0 green:90.0/255.0 blue:92.0/255.0 alpha:1.0];
            }
            return [UIColor colorWithRed:49.0/255.0 green:49.0/255.0 blue:49.0/255.0 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:49.0/255.0 green:49.0/255.0 blue:49.0/255.0 alpha:1.0];
}

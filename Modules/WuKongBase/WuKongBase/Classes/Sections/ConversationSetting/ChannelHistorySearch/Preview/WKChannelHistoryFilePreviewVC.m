//
//  WKChannelHistoryFilePreviewVC.m
//

#import "WKChannelHistoryFilePreviewVC.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "UIView+WKCommon.h"
#import "WKActionSheetView2.h"
#import "WKActionSheetItem2.h"
#import "WKNavigationManager.h"

@interface WKChannelHistoryFilePreviewVC () <UIDocumentPickerDelegate>
@end

@implementation WKChannelHistoryFilePreviewVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // 父类 viewDidLoad 已经把分享按钮装到 rightView 上, 这里覆盖换成"..."。
    UIButton *more = [UIButton buttonWithType:UIButtonTypeSystem];
    more.frame = CGRectMake(0, 0, 44, 44);
    UIImage *img = [WKApp.shared loadImage:@"Common/Index/More" moduleID:@"WuKongBase"];
    if (img) {
        [more setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
              forState:UIControlStateNormal];
        more.tintColor = [WKApp shared].config.navBarButtonColor;
    } else {
        [more setTitle:@"⋯" forState:UIControlStateNormal];
        [more setTitleColor:[WKApp shared].config.navBarButtonColor forState:UIControlStateNormal];
        more.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    }
    [more addTarget:self action:@selector(onMoreTap) forControlEvents:UIControlEventTouchUpInside];
    self.navigationBar.rightView = more;
}

- (void)onMoreTap {
    __weak typeof(self) ws = self;
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil];
    if (self.historyItem.canLocate && self.onLocate) {
        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"定位到聊天位置") onClick:^{
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            // 先关掉预览, 再跳聊天 — 让用户从 chat 返回直接回到搜索结果, 而不是回到这一层预览。
            if (ss.navigationController.viewControllers.count > 1) {
                [ss.navigationController popViewControllerAnimated:NO];
            } else {
                [ss dismissViewControllerAnimated:NO completion:nil];
            }
            if (ss.onLocate) ss.onLocate(ss.historyItem);
        }]];
    }
    [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"保存文件") onClick:^{
        [ws presentSavePicker];
    }]];
    [sheet show];
}

- (void)presentSavePicker {
    if (!self.fileURL) {
        [self.view showMsg:LLang(@"文件不可用")];
        return;
    }
    if (@available(iOS 14.0, *)) {
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
            initForExportingURLs:@[self.fileURL]];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        // 兜底: 旧 iOS 用分享面板, 用户从分享列表里选「存储到文件」
        UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[self.fileURL]
                                                                          applicationActivities:nil];
        [self presentViewController:avc animated:YES completion:nil];
    }
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [self.view showMsg:LLang(@"已保存")];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // no-op
}

@end

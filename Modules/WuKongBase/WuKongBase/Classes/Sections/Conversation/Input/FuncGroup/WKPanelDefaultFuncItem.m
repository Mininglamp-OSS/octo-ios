//
//  WKPanelDefaultFuncItem.m
//  WuKongBase
//
//  Created by tt on 2020/2/23.
//

#import "WKPanelDefaultFuncItem.h"
#import "WKResource.h"
#import "WKConstant.h"
#import "WKMoreItemClickEvent.h"
#import "WKFuncItemButton.h"
#import "WuKongBase.h"
#import "WKConversationContext.h"
#import "WKCardContent.h"
#import "WKFuncGroupEditVC.h"
@interface WKPanelDefaultFuncItem ()



@end

@implementation WKPanelDefaultFuncItem

-(NSString*) sid {
    return @"";
}

- (nonnull WKFuncItemButton *)itemButton:(WKConversationInputPanel*)inputPanel {
    self.inputPanel = inputPanel;
    WKFuncItemButton *btn = [[WKFuncItemButton alloc] init];
    [btn setImage:[self itemIcon] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(onPressed:) forControlEvents:UIControlEventTouchUpInside];
    [btn setTitle:[self title] forState:UIControlStateNormal];
    return btn;
}

-(void) onPressed:(WKFuncItemButton*)btn {
    [self.inputPanel switchPanel:[self panelID]];
}

-(NSString*) title {
    return @"";
}

-(UIImage*) itemIcon {
    
    return nil;
}

-(NSString*) panelID {
    return @"";
}

- (BOOL)support:(id<WKConversationContext>)context {
    return true;
}

-(BOOL) allowEdit {
    return true;
}

-(UIImage*) getImageNameForBase:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
    //    return [currentModule ImageForResource:name];
//    return  [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

// Fallback 工具条图标：runtime 合成一张与 Conversation/Toolbar/*Normal.pdf 同款风格
// （紫色渐变 squircle 背景 + 白色 SF Symbol），供暂缺美术资源的 item（如「文件」）使用。
// 单一符号名 cache 一次，避免每次 refresh 重画。
+ (UIImage *)fallbackToolbarIconWithSymbolName:(NSString *)symbolName {
    static NSMutableDictionary<NSString *, UIImage *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });
    if (symbolName.length == 0) return nil;
    UIImage *cached = cache[symbolName];
    if (cached) return cached;

    // 44pt 是 UIButton 常用图标尺寸；UIGraphicsImageRenderer 输出带屏幕 scale 的位图
    CGFloat size = 44.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
    UIImage *img = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        // squircle 圆角背景，圆角比例参考 ImageNormal.pdf 的观感 (~28% side)
        UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:size * 0.28];
        CGContextSaveGState(c);
        [bg addClip];
        // 线性渐变（左下 → 右上），色板对齐美术紫色调
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGFloat locs[] = {0.0, 1.0};
        NSArray *colors = @[
            (__bridge id)[UIColor colorWithRed:0.55 green:0.42 blue:0.98 alpha:1.0].CGColor, // 深紫
            (__bridge id)[UIColor colorWithRed:0.68 green:0.60 blue:0.99 alpha:1.0].CGColor  // 浅紫
        ];
        CGGradientRef grad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)colors, locs);
        CGContextDrawLinearGradient(c, grad, CGPointMake(0, size), CGPointMake(size, 0), 0);
        CGGradientRelease(grad);
        CGColorSpaceRelease(cs);
        CGContextRestoreGState(c);

        // 居中的白色 SF Symbol（占外框 ~55%，与其他 Normal 图标内部符号视觉比例对齐）
        if (@available(iOS 13.0, *)) {
            CGFloat symPt = size * 0.55;
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:symPt weight:UIImageSymbolWeightSemibold];
            UIImage *sym = [UIImage systemImageNamed:symbolName withConfiguration:cfg];
            sym = [sym imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
            if (sym) {
                CGRect r = CGRectMake((size - sym.size.width) / 2.0, (size - sym.size.height) / 2.0,
                                      sym.size.width, sym.size.height);
                [sym drawInRect:r];
            }
        }
    }];
    cache[symbolName] = img;
    return img;
}

@end

@implementation WKPanelEmojiFuncItem

-(BOOL) allowEdit {
    return false;
}
- (NSString *)sid {
    return @"apm.wukong.emoji";
}

- (UIImage *)itemIcon {
    return [self getImageNameForBase:@"Conversation/Toolbar/FaceNormal"];
}

- (NSString *)panelID {
    return WKPOINT_PANEL_EMOJI;
}

- (NSString *)title {
    return LLang(@"表情");
}

@end

@interface WKPanelMentionFuncItem ()


@end
@implementation WKPanelMentionFuncItem

- (NSString *)sid {
    return @"apm.wukong.mention";
}
- (UIImage *)itemIcon {
    return [self getImageNameForBase:@"Conversation/Toolbar/MentionNormal"];
}

- (BOOL)support:(id<WKConversationContext>)context {
    return context.channel.channelType != WK_PERSON;
}


-(void) onPressed:(UIButton*)btn {
    [self.inputPanel inputInsertText:@"@"];
    [self.inputPanel.conversationContext showMentionUsers];
   
}
- (NSString *)title {
    return LLang(@"@");
}

@end


@interface WKPanelVoiceFuncItem ()

@end
@implementation WKPanelVoiceFuncItem

-(BOOL) allowEdit {
    return false;
}


- (NSString *)sid {
    return @"apm.wukong.voice";
}

- (UIImage *)itemIcon {
    return [self getImageNameForBase:@"Conversation/Toolbar/VoiceNormal"];
}

- (NSString *)panelID {
    return WKPOINT_PANEL_VOICE;
}
- (NSString *)title {
    return LLang(@"语音");
}
@end



@interface WKPanelImageFuncItem ()

@end
@implementation WKPanelImageFuncItem

-(BOOL) allowEdit {
    return false;
}


- (NSString *)sid {
    return @"apm.wukong.image";
}

- (UIImage *)itemIcon {
    return [self getImageNameForBase:@"Conversation/Toolbar/ImageNormal"];
}

-(void) onPressed:(UIButton*)btn {
   
    // 图片点击
    [[WKMoreItemClickEvent shared] onPhotoItemPressed:self.inputPanel.conversationContext];
}
- (NSString *)title {
    return LLang(@"图片");
}

@end

@implementation WKPanelMoreFuncItem

- (NSString *)sid {
    return @"apm.wukong.more";
}

- (UIImage *)itemIcon {
    return [self getImageNameForBase:@"Conversation/Toolbar/MoreNormal"];
}

- (void)onPressed:(UIButton *)btn {
    WKFuncGroupEditVC *vc = [[WKFuncGroupEditVC alloc] init];
    vc.conversationContext = self.inputPanel.conversationContext;
    vc.modalPresentationStyle = UIModalPresentationPopover;
//    UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:vc];
    // iPad 上 modalPresentationStyle = Popover 时 popoverPresentationController 需要
    // 非 nil 的 sourceView (+ sourceRect) 或 barButtonItem, 否则 present 抛 NSGenericException。
    // 触发是"更多"按钮 btn, 直接锚到它。iPhone 上 popover 自动适配到全屏, 设置 sourceView 无副作用。
    if (vc.popoverPresentationController && btn) {
        vc.popoverPresentationController.sourceView = btn;
        vc.popoverPresentationController.sourceRect = btn.bounds;
    }
    [[WKNavigationManager shared].topViewController presentViewController:vc animated:YES completion:nil];
}
- (NSString *)title {
    return LLang(@"更多");
}

- (WKFuncGroupEditItemType)type {
    return WKFuncGroupEditItemTypeMore;
}
@end


@implementation WKPanelCardFuncItem

- (NSString *)sid {
    return @"apm.wukong.card";
}

- (UIImage *)itemIcon {
    return [self getImageNameForBase:@"Conversation/Toolbar/CardNormal"];
}


- (void)onPressed:(UIButton *)btn {
    id<WKConversationContext> conversationContext =  self.inputPanel.conversationContext;
    NSMutableArray<NSString*> *hiddenUsers = [NSMutableArray array];
    if(conversationContext.channel.channelType == WK_PERSON) {
        [hiddenUsers addObject:conversationContext.channel.channelId];
    }
    
    [[WKApp shared] invoke:WKPOINT_CONTACTS_SELECT param:@{@"mode":@"single",@"on_finished":^(NSArray<NSString*>*uids){
        if(uids && [uids count]<=0) {
            return;
        }
        NSString *uid = uids[0];
        WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:uid channelType:WK_PERSON]];
        if(!channelInfo) {
            WKLogDebug(@"没有查到频道信息！");
            return;
        }
        __weak typeof(self) weakSelf = self;
        id<WKConversationContext> context = self.inputPanel.conversationContext;
        
        [WKAlertUtil alert:[NSString stringWithFormat:LLangW(@"发送%@的名片到当前聊天",weakSelf),channelInfo.displayName] buttonsStatement:@[LLangW(@"取消",weakSelf),LLangW(@"确定",weakSelf)] chooseBlock:^(NSInteger buttonIdx) {
            btn.selected = false;
            if(buttonIdx == 1) {
                [[WKNavigationManager shared] popViewControllerAnimated:YES];
                
                [context sendMessage:[WKCardContent cardContent:[channelInfo extraValueForKey:WKChannelExtraKeyVercode] uid:uid name:channelInfo.name avatar:channelInfo.logo]];
            }
        }];
       
       
    },@"on_cancel":^{
        btn.selected = false;
    },@"hidden_users":hiddenUsers}];
}

- (NSString *)title {
    return LLang(@"名片");
}

@end


@implementation WKPanelFileFuncItem

- (NSString *)sid {
    return @"apm.wukong.file";
}

- (UIImage *)itemIcon {
    UIImage *img = [self getImageNameForBase:@"Conversation/Toolbar/FileNormal"];
    if (img) return img;
    // 美术未提供 FileNormal.pdf 时兜底，视觉与其他 Normal 图标一致
    // （紫色渐变 squircle + 白色 doc）—— 之前 fallback 用裸 SF Symbol「doc」
    // 是黑色线条无背景，跟一排图标风格断层。
    return [[self class] fallbackToolbarIconWithSymbolName:@"doc"];
}

- (void)onPressed:(UIButton *)btn {
    [[WKMoreItemClickEvent shared] onFileItemPressed:self.inputPanel.conversationContext];
}

- (NSString *)title {
    return LLang(@"文件");
}

@end


//
//  WKImageBrowser.m
//  WuKongBase
//
//  Created by tt on 2022/4/8.
//

#import "WKImageBrowser.h"
#import "WKActionSheetView2.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKZXingWrapper.h"
#import "WuKongBase.h"
#import "WKScanVC.h"
#import "WKMessageActionManager.h"
#import "WKPermissionShowAlertView.h"
#import "WKVideoData.h"
#import <ZLImageEditor/ZLImageEditor-Swift.h>
#import <WuKongBase/WuKongBase-Swift.h>
@import ZLImageEditor;

@interface WKImageBrowser ()<YBImageBrowserDelegate,WKCMDManagerDelegate,WKChatManagerDelegate>

@property(nonatomic,strong) NSArray<WKScanHandler*> *handlers;

@property(nonatomic,strong) RadialStatusNode *flameNode; // 阅后即焚的动画

@property(nonatomic,strong) WKMessageModel *currentMessageModel;

@end

@implementation WKImageBrowser

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.delegate = self;
        // 获取所有处理扫一扫的处理者
       self.handlers =  [[WKApp shared] invokes:WKPOINT_CATEGORY_SCAN_HANDLER param:nil];
        [self addDelegates];
    }
    return self;
}


-(void) addDelegates {
    [[WKSDK shared].cmdManager addDelegate:self];
    [[WKSDK shared].chatManager addDelegate:self];
}

-(void) removeDelegates {
    [[WKSDK shared].cmdManager removeDelegate:self];
    [[WKSDK shared].chatManager removeDelegate:self];
}

- (void)dealloc {
    [self removeDelegates];
    if(self.onDealloc) {
        self.onDealloc();
    }
}

- (void)showToView:(UIView *)view {
    [super showToView:view];
    
    YBIBImageData *imageData = (YBIBImageData*)self.currentData;
    WKMessageModel *message;
    if( imageData.extraData) {
        message =  imageData.extraData[@"message"];
        self.currentMessageModel = message;
    }
    if(self.currentMessageModel && self.currentMessageModel.content.flame) { // 阅后即焚的消息长安无效
        [self addSubview:self.flameNode.view];
        CGFloat safeTop = UIApplication.sharedApplication.keyWindow.safeAreaInsets.top;
        self.flameNode.view.lim_top = safeTop + self.flameNode.view.lim_height + 20.0f;
        self.flameNode.view.lim_left = self.lim_width - self.flameNode.view.lim_width - 20.0f;
        [self startFlameIfNeed:self.currentMessageModel.message];
       
    
    }
}

-(void) startFlameIfNeed:(WKMessage*)message {
    if(!message.content.flame ) {
        return;
    }
    
    if(message.viewed) {
        [self startFlame:message.content.flameSecond remainderFlame:[self remainderFlame:message] keep:false finished:^{
            
        }];
    }else {
        [self startFlame:message.content.flameSecond remainderFlame:100000 keep:true finished:^{
            
        }];
    }
    
}

// 阅后即焚开始销毁
-(void) startFlame:(NSInteger)flameSecond remainderFlame:(NSInteger)remainderFlame keep:(BOOL)keep finished:(void(^)(void))finished{
    UIImage *secretIcon = [WKApp.shared loadImage:@"Conversation/Messages/SecretMediaIcon" moduleID:@"WuKongBase"];
    UIImage *flameIcon =  [WKGenerateImageUtils generateTintedImgWithImage:secretIcon color:[UIColor whiteColor] backgroundColor:nil];
     CGFloat factor = 0.4f;
     flameIcon = [GenerateImageUtils generateImg:CGSizeMake(flameIcon.size.width*factor, flameIcon.size.height*factor) contextGenerator:^(CGSize size, CGContextRef contextRef) {
         CGContextClearRect(contextRef, CGRectMake(0.0f, 0.0f, size.width, size.height));
         CGContextDrawImage(contextRef, CGRectMake(0.0f, 0.0f, size.width, size.height), flameIcon.CGImage);
     } opaque:NO];
    BOOL sparks = !keep;
    
   CGFloat beginTime = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 - (flameSecond - remainderFlame);
    CGFloat timeout = remainderFlame+(flameSecond - remainderFlame);
    
    if(flameSecond<=0 || keep) {
        beginTime = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970;
        timeout = remainderFlame;
    }
    
    [self.flameNode transitionToStateWithIcon:flameIcon beginTime: beginTime timeout:timeout animated:YES synchronous:false sparks:sparks finished:^{
    }];
}

-(NSInteger) remainderFlame:(WKMessage*)message {
    NSInteger viewedAt = message.viewedAt;
    if(viewedAt>0) {
       NSInteger flameSecond =  message.content.flameSecond -  ([[NSDate date] timeIntervalSince1970] -viewedAt);
        return flameSecond;
    }
    return 0;
}


- (RadialStatusNode *)flameNode {
    if(!_flameNode) {
        // 阅后即焚
        _flameNode = [[RadialStatusNode alloc] initWithBackgroundNodeColor:[UIColor colorWithWhite:0.0f alpha:0.5f] enableBlur:false];
        _flameNode.view.lim_size = CGSizeMake(20.0f, 20.0f);
    }
    return _flameNode;
}

- (void)yb_imageBrowser:(YBImageBrowser *)imageBrowser respondsToLongPressWithData:(id<YBIBDataProtocol>)data {
    if([data isKindOfClass:[YBIBImageData class]]) {
        YBIBImageData *imageData = (YBIBImageData*)data;
        if(!imageData.originImage) {
            return;
        }
        WKMessageModel *message;
        if( imageData.extraData) {
            message =  imageData.extraData[@"message"];
        }
        if(message && message.content.flame) { // 阅后即焚的消息长安无效
            return;
        }
        __weak typeof(self) weakSelf = self;
        
        [WKZXingWrapper recognizeImage:imageData.originImage block:^(ZXBarcodeFormat barcodeFormat, NSString *str) {
            WKActionSheetView2 *sheetView = [WKActionSheetView2 initWithTip:nil];
            if(message) {
                [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLangW(@"转发",weakSelf) onClick:^{
                    [weakSelf hide];
                    [[WKMessageActionManager shared] forwardMessages:@[message.message]];
                }]];
                
                [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLangW(@"编辑",weakSelf) onClick:^{
                    [weakSelf hide];
                    [weakSelf handleEdit:imageData.originImage];
                }]];
                
                WKMessageLongMenusItem *favoriteLongMenusItem = [WKApp.shared invoke:WKPOINT_LONGMENUS_FAVORITE param:@{
                    @"message":message,
                }];
                if(favoriteLongMenusItem) {
                    [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLangW(@"收藏",weakSelf) onClick:^{
                        favoriteLongMenusItem.onTap(weakSelf.conversationContext);
                        [weakSelf hide];
                    }]];
                }
               
            }
            [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLangW(@"保存到相册",weakSelf) onClick:^{
                [weakSelf hide];
                [imageData yb_saveToPhotoAlbum];
                
            }]];
            if(str) {
                [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLangW(@"识别图中二维码",weakSelf) onClick:^{
                    [weakSelf hide];
                    [weakSelf handleQRCode:str img:imageData.originImage];
                }]];
            }
            [sheetView show];
        }];
    }
}

-(void) handleEdit:(UIImage*)img {
   
    [ZLEditImageViewController showEditImageVCWithParentVC:[WKNavigationManager shared].topViewController animate:YES image:img editModel:nil completion:^(UIImage * editImg, ZLEditImageModel * m) {
        if(self.onEditFinish) {
            self.onEditFinish(editImg);
        }
    }];
}

-(void) handleQRCode:(NSString*)content img:(UIImage*)img {
    LBXScanResult *scanResult = [[LBXScanResult alloc] initWithScanString:content imgScan:img barCodeType:AVMetadataObjectTypeQRCode];
    [WKScanVC handleScanResult:scanResult handlers:self.handlers];
}


//保存相片的回调方法
- (void)image:(UIImage*)image
    didFinishSavingWithError:(NSError*)error
                 contextInfo:(void*)contextInfo {
    
    UIView *topView = [WKNavigationManager shared].topViewController.view;
    if (!error) {
        [topView showHUDWithHide:LLang(@"保存成功！")];

    }
}

- (void)show {
    [super showToView:[WKNavigationManager shared].topViewController.view];
}

#pragma mark -- WKCMDManagerDelegate

- (void)cmdManager:(WKCMDManager *)manager onCMD:(WKCMDModel *)model {
    WKMessageModel *messageModel;
    if([self.currentData isKindOfClass:[YBIBImageData class]]||[self.currentData isKindOfClass:[WKVideoData class]]) {
        YBIBImageData *imageData = (YBIBImageData*)self.currentData;
        if(imageData.extraData && imageData.extraData[@"message"] && [imageData.extraData[@"message"] isKindOfClass:[WKMessageModel class]]) {
            messageModel = imageData.extraData[@"message"];
        }
    }
    
    if(!messageModel) {
        return;
    }
    
    NSString *cmd = model.cmd;
    
    if([cmd isEqualToString:WKCMDMessageRevoke]) {
        NSDictionary *param =  model.param;
        NSString *messageIDStr;
        uint64_t messageId = 0;
        if(param[@"message_id"]) {
            messageIDStr = param[@"message_id"];
        }
        if(messageIDStr) {
            NSDecimalNumber* formatter = [[NSDecimalNumber alloc] initWithString:messageIDStr]; // 这里需要用 NSDecimalNumber不要用NSNumberFormat NSNumberFormat数字太大会转换不正确
            messageId =  [formatter unsignedLongLongValue];
            if(messageId == messageModel.messageId) {
                [self hide];
            }
        }
    }
}


- (void)onMessageUpdate:(WKMessage *)message left:(NSInteger)left {
    if(self.currentMessageModel && [message.clientMsgNo isEqualToString:self.currentMessageModel.clientMsgNo]) {
        self.currentMessageModel.message = message;
        [self startFlameIfNeed:message];
    }
}

@end

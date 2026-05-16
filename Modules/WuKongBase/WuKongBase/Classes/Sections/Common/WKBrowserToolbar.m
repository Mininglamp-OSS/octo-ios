//
//  WKBrowserToolbar.m
//  WuKongBase
//
//  Created by tt on 2021/3/24.
//

#import "WKBrowserToolbar.h"
#import "WKResource.h"
#import "UIView+WK.h"
#import "WKConstant.h"
#import "WKActionSheetView2.h"
#import "WuKongBase.h"
#import "WKVideoData.h"

@interface WKBrowserToolbar ()

@property (nonatomic, strong) UIButton *moreButton;

@end

@implementation WKBrowserToolbar

@synthesize yb_containerView = _yb_containerView;
@synthesize yb_currentData = _yb_currentData;
@synthesize yb_containerSize = _yb_containerSize;
@synthesize yb_currentOrientation = _yb_currentOrientation;

- (void)yb_containerViewIsReadied {
    [self.yb_containerView addSubview:self.moreButton];
    
    CGFloat topSafe = 0.0f;
    if (@available(iOS 11.0, *)) {
         topSafe = [UIApplication sharedApplication].keyWindow.safeAreaInsets.top;
        
    }
    self.moreButton.lim_top = topSafe + 20.0f;
    self.moreButton.lim_left = WKScreenWidth - self.moreButton.lim_width - 20.0f;
}

- (void)yb_hide:(BOOL)hide {
    self.moreButton.hidden = hide;
}

- (UIButton *)moreButton {
    if(!_moreButton) {
        _moreButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
        [_moreButton setImage:[self getImageWithName:@"Common/Index/More"] forState:UIControlStateNormal];
        [_moreButton addTarget:self action:@selector(moreBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _moreButton;
}

-(void) moreBtnPressed {
    __weak typeof(self) weakSelf = self;
    
    
    WKMessageModel *message;
    WKMessageContent *messageContent;
    id<YBIBDataProtocol> currentData = self.yb_currentData();
    if([currentData isKindOfClass:[WKVideoData class]]) {
        WKVideoData *videoData = (WKVideoData*)currentData;
        if(videoData.extraData) {
            message = videoData.extraData[@"message"];
            if(videoData.extraData[@"messageContent"]) {
                messageContent = videoData.extraData[@"messageContent"];
            }
        }
    }else if([currentData isKindOfClass:[YBIBImageData class]]) {
        YBIBImageData *imageData = (YBIBImageData*)currentData;
        if(imageData.extraData) {
            message = imageData.extraData[@"message"];
            if(imageData.extraData[@"messageContent"]) {
                messageContent = imageData.extraData[@"messageContent"];
            }
        }
    }
        
    
    WKActionSheetView2 *sheetView = [WKActionSheetView2 initWithTip:nil];
    [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"保存到相册") onClick:^{
        [weakSelf saveDataToAlbum];
    }]];
    if(message) {
        [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"转发") onClick:^{
            if(weakSelf.browser) {
                [weakSelf.browser hide];
            }
            [[WKMessageActionManager shared] forwardMessages:@[message.message]];
        }]];
    }else if(messageContent) {
        [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"转发") onClick:^{
            if(weakSelf.browser) {
                [weakSelf.browser hide];
            }
            [[WKMessageActionManager shared] forwardContent:messageContent complete:nil];
        }]];
    }
    
    [sheetView show];
}

-(void) saveDataToAlbum {
   id<YBIBDataProtocol> dataProtocol = self.yb_currentData();
    if(dataProtocol && dataProtocol.yb_allowSaveToPhotoAlbum) {
        [dataProtocol yb_saveToPhotoAlbum];
    }
}


-(UIImage*) getImageWithName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end

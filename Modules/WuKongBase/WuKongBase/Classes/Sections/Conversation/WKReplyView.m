//
//  WKReplyView.m
//  WuKongBase
//
//  Created by tt on 2020/10/20.
//

#import "WKReplyView.h"
#import "WKConstant.h"
#import "WKApp.h"
#import "UIView+WK.h"
#import "WKResource.h"
#import "WKAvatarUtil.h"
#import "UIImageView+WK.h"
#import "WKUserAvatar.h"
#import "WKExternalViewerResolver.h"
#define viewHeight 54.0f

@interface WKReplyView ()

@property(nonatomic,strong) WKMessage *message;

@property(nonatomic,strong) UIView *splitView;

@property(nonatomic,strong) WKUserAvatar *replyAvatarIcon;

@property(nonatomic,strong) UILabel *nameLbl;

@property(nonatomic,strong) UILabel *contentLbl;

@property(nonatomic,strong) UIButton *closeBtn;

@end

@implementation WKReplyView

+ (instancetype)message:(WKMessage *)message {
    WKReplyView *view = [[WKReplyView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, viewHeight)];
    view.message = message;
    return view;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.splitView];
        [self addSubview:self.replyAvatarIcon];
        [self addSubview:self.nameLbl];
        [self addSubview:self.contentLbl];
        [self addSubview:self.closeBtn];
    }
    return self;
}

- (void)setMessage:(WKMessage *)message {
    _message = message;

    // · 输入框上方「引用某条消息」预览也要显示 @SpaceName —— 对齐 web PR #1073.
    // 数据来源：这条 *被引用* 消息自身的 msg-level 外部群字段（WKMessageUtil toMessage 已写入 message.extra）。
    NSString *baseName = @"---";
    if(message.from) {
        baseName = message.from.displayName ?: @"---";
    }

    id homeIdRaw = message.extra[@"from_home_space_id"];
    id homeNameRaw = message.extra[@"from_home_space_name"];
    id isExtRaw = message.extra[@"from_is_external"];
    id sourceNameRaw = message.extra[@"from_source_space_name"];
    NSString *viewerSpaceId = [WKExternalViewerResolver currentViewerSpaceId];
    WKExternalResolveResult *res = [WKExternalViewerResolver
        resolveWithHomeSpaceId:homeIdRaw
                 homeSpaceName:homeNameRaw
              isExternalLegacy:isExtRaw
         sourceSpaceNameLegacy:sourceNameRaw
                 viewerSpaceId:viewerSpaceId];
    if (res.isExternal && res.sourceSpaceName.length > 0) {
        // 硬约束：attributedText 设置时必须清 .text（互斥坑点）
        self.nameLbl.text = nil;
        self.nameLbl.attributedText = [self buildNameAttrWithBase:baseName spaceName:res.sourceSpaceName];
    } else {
        self.nameLbl.attributedText = nil;
        self.nameLbl.text = baseName;
    }
    [self.nameLbl sizeToFit];

    self.contentLbl.text = [message.content conversationDigest];
    [self.contentLbl sizeToFit];
    if(self.contentLbl.lim_width> WKScreenWidth - 30*2) {
        self.contentLbl.lim_width = WKScreenWidth - 30*2;
    }
    self.replyAvatarIcon.url = [WKAvatarUtil getAvatar:message.fromUid];

}

// · 拼接「发送者 displayName + 灰色 @SpaceName 后缀」。样式与 WKMemberCell v2 对齐。
- (NSAttributedString *)buildNameAttrWithBase:(NSString *)baseName
                                    spaceName:(NSString *)spaceName {
    UIFont *baseFont = self.nameLbl.font
        ?: [[WKApp shared].config appFontOfSize:16.0f];
    UIColor *baseColor = self.nameLbl.textColor
        ?: [WKApp shared].config.tipColor
        ?: [UIColor darkGrayColor];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc]
        initWithString:(baseName ?: @"")
            attributes:@{NSFontAttributeName: baseFont,
                         NSForegroundColorAttributeName: baseColor}];
    UIColor *suffixColor = [UIColor colorWithRed:153.0f/255.0f
                                           green:153.0f/255.0f
                                            blue:153.0f/255.0f
                                           alpha:1.0f];
    UIFont *suffixFont = [[WKApp shared].config appFontOfSize:14.0f];
    NSString *suffix = [NSString stringWithFormat:@" @%@", spaceName ?: @""];
    [attr appendAttributedString:[[NSAttributedString alloc]
        initWithString:suffix
            attributes:@{NSFontAttributeName: suffixFont,
                         NSForegroundColorAttributeName: suffixColor}]];
    return attr;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // split
    self.splitView.lim_left = 15.0f;
    self.splitView.lim_top = 10.0f;
    self.splitView.lim_height = viewHeight-5.0f*2;
    self.splitView.lim_width = 2.0f;
    
    self.replyAvatarIcon.lim_left = 15.0f;
    self.replyAvatarIcon.lim_top = 10.0f;
    
    // name
    self.nameLbl.lim_left = self.replyAvatarIcon.lim_right + 4.0f;
    self.nameLbl.lim_top = self.replyAvatarIcon.lim_top-2.0f;
    
    // content
    self.contentLbl.lim_top = self.nameLbl.lim_bottom + 2.0f;
    self.contentLbl.lim_left = self.replyAvatarIcon.lim_left;
    
    // close
    self.closeBtn.lim_top = 0.0f;
    self.closeBtn.lim_left = WKScreenWidth - self.closeBtn.lim_width - 15.0f;
}

- (UIView *)splitView {
    if(!_splitView) {
        _splitView = [[UIView alloc] init];
        _splitView.backgroundColor = [WKApp shared].config.themeColor;
        _splitView.hidden = YES;
    }
    return _splitView;
}

- (WKUserAvatar *)replyAvatarIcon {
    if(!_replyAvatarIcon) {
        _replyAvatarIcon = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
    }
    return _replyAvatarIcon;
}

- (UILabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        _nameLbl.textColor = [WKApp shared].config.tipColor;
        _nameLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
    }
    return _nameLbl;
}

- (UILabel *)contentLbl {
    if(!_contentLbl) {
        _contentLbl = [[UILabel alloc] init];
        _contentLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
        _contentLbl.numberOfLines = 1;
        _contentLbl.textColor = [WKApp shared].config.tipColor;
    }
    return _contentLbl;
}

- (UIButton *)closeBtn {
    if(!_closeBtn) {
        _closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 38.0f, 38.0f)];
        [_closeBtn setImage:[self imageName:@"Common/Index/Close"] forState:UIControlStateNormal];
        [_closeBtn addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
        [_closeBtn setContentEdgeInsets:UIEdgeInsetsMake(10.0f, 10.0f, 10.0f, 10.0f)];
    }
    return _closeBtn;
}

-(void) closePressed {
    if(self.onClose) {
        self.onClose();
    }
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end

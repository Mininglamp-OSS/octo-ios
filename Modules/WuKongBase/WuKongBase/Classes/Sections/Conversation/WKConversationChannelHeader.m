//
//  WKConversationChannelHeader.m
//  WuKongBase
//
//  Created by tt on 2021/8/20.
//

#import "WKConversationChannelHeader.h"
#import "WKOnlineStatusManager.h"
#import "WKAutoDeleteView.h"
#import "WKOfficialTag.h"
#import "WKConstant.h"
#import "WKChannelUtil.h"
#import "WKRealnamePrefetcher.h"
@interface WKConversationChannelHeader ()

@property(nonatomic,strong) UIButton *infoBoxBtn;

@property(nonatomic,strong) WKUserAvatar *avatarImgView;

@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UILabel *subtitleLbl;

@property(nonatomic,strong) WKAutoDeleteView *autoDeleteView;

@property(nonatomic,strong) UIImageView *botBadgeLbl; // Bot标识（AI 图标）

@property(nonatomic,strong) WKOfficialTag *officialTag; // 官方图标

// / Phase A —— 私聊顶部实名 ✓ 徽章
// 12×12pt 蓝勾，紧贴 titleLbl 右侧，节奏与 botBadgeLbl 对齐。
@property(nonatomic,strong) UIImageView *realnameVerifiedImgView;

@end

@implementation WKConversationChannelHeader

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
//    [self setBackgroundColor:[UIColor redColor]];
    
    [self addSubview:self.infoBoxBtn];
    [self.infoBoxBtn addSubview:self.avatarImgView];
    [self.infoBoxBtn addSubview:self.titleLbl];
    [self.infoBoxBtn addSubview:self.subtitleLbl];
    [self.infoBoxBtn addSubview:self.botBadgeLbl];
    [self.infoBoxBtn addSubview:self.officialTag];
    [self.infoBoxBtn addSubview:self.realnameVerifiedImgView];
    [self addSubview:self.voiceCallBtn];
    [self addSubview:self.videoCallBtn];
    [self addSubview:self.moreDotsBtn];
    [self addSubview:self.summaryBtn];
    [self.avatarImgView addSubview:self.autoDeleteView];

    [self.infoBoxBtn addTarget:self action:@selector(infoPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.voiceCallBtn addTarget:self action:@selector(voiceCallPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.videoCallBtn addTarget:self action:@selector(videoCallPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.moreDotsBtn addTarget:self action:@selector(moreDotsPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.summaryBtn addTarget:self action:@selector(summaryPressed) forControlEvents:UIControlEventTouchUpInside];
    
    [WKApp.shared addChannelAvatarUpdateNotify:self selector:@selector(channelAvatarUpdate:)];
    
}

-(void) channelAvatarUpdate:(NSNotification*)notify {
    WKChannel *channel = notify.object;
    if(self.channelInfo && channel && [channel isEqual:self.channelInfo.channel]) {
        [self setChannelInfo:self.channelInfo]; // 重新刷新频道信息
    }
    
}

-(void) infoPressed {
    if(self.onInfo) {
        self.onInfo();
    }
}

-(void) voiceCallPressed {
    if(self.onVoiceCall) {
        self.onVoiceCall();
    }
}

-(void) videoCallPressed {
    if(self.onVideoCall) {
        self.onVideoCall();
    }
}

-(void) moreDotsPressed {
    if(self.onInfo) {
        self.onInfo(); // 与点击标题/头像打开群组设置相同
    }
}

-(void) summaryPressed {
    if(self.onSummary) {
        self.onSummary();
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.avatarImgView.lim_left = 0.0f;
    self.avatarImgView.lim_centerY_parent = self;

    // 三个点按钮在最右侧
    self.moreDotsBtn.lim_left = self.lim_width - self.moreDotsBtn.lim_width;
    self.moreDotsBtn.lim_centerY_parent = self;

    // 右侧按钮的左边界（三个点按钮左侧）
    CGFloat rightEdge = self.moreDotsBtn.hidden ? self.lim_width : self.moreDotsBtn.lim_left - 8.0f;

    self.videoCallBtn.lim_left = rightEdge - self.videoCallBtn.lim_width;
    self.videoCallBtn.lim_centerY_parent = self;

    if(self.videoCallBtn.hidden) {
        self.voiceCallBtn.lim_left = rightEdge - self.voiceCallBtn.lim_width;
        self.voiceCallBtn.lim_centerY_parent = self;
    }else {
        self.voiceCallBtn.lim_left = self.videoCallBtn.lim_left - self.voiceCallBtn.lim_width - 15.0f;
        self.voiceCallBtn.lim_centerY_parent = self;
    }

    // summaryBtn 紧贴左侧, 三种 channel type 都显示。其右侧 anchor 取当前可见的最近一个按钮:
    //   - voiceCallBtn 可见 → 跟在它左侧
    //   - 否则 videoCallBtn 可见 → 跟在它左侧
    //   - 都不可见 (子区) → 跟在 moreDotsBtn 左侧, 即贴 rightEdge
    if(!self.summaryBtn.hidden) {
        CGFloat summaryRight = rightEdge;
        if(!self.voiceCallBtn.hidden)      summaryRight = self.voiceCallBtn.lim_left - 15.0f;
        else if(!self.videoCallBtn.hidden) summaryRight = self.videoCallBtn.lim_left - 15.0f;
        self.summaryBtn.lim_left = summaryRight - self.summaryBtn.lim_width;
        self.summaryBtn.lim_centerY_parent = self;
    }

    self.infoBoxBtn.lim_height = self.lim_height;
    // infoBoxBtn 右边界改为最左侧可见按钮的左边: summaryBtn → voiceCallBtn → videoCallBtn → moreDotsBtn → 整宽。
    CGFloat leftmostRight;
    if(!self.summaryBtn.hidden)        leftmostRight = self.summaryBtn.lim_left;
    else if(!self.voiceCallBtn.hidden) leftmostRight = self.voiceCallBtn.lim_left;
    else if(!self.videoCallBtn.hidden) leftmostRight = self.videoCallBtn.lim_left;
    else if(!self.moreDotsBtn.hidden)  leftmostRight = self.moreDotsBtn.lim_left - 8.0f;
    else                               leftmostRight = self.lim_width - 10.0f;
    self.infoBoxBtn.lim_width = leftmostRight;
   
    CGFloat avatarRightSpace = 5.0f;
    
    CGFloat subtitleTop = 0.0f;
    CGFloat titleRightSpace = 5.0f;
    self.titleLbl.lim_width = self.infoBoxBtn.lim_width - self.avatarImgView.lim_right - avatarRightSpace - titleRightSpace;
//    [self.titleLbl setBackgroundColor:[UIColor redColor]];
    
    self.titleLbl.lim_left = self.avatarImgView.lim_right + avatarRightSpace;

    CGFloat contentHeight = self.titleLbl.lim_height + subtitleTop + self.subtitleLbl.lim_height;
    if(self.subtitleLbl.hidden) {
        contentHeight = self.titleLbl.lim_height;
    }
    
    self.titleLbl.lim_top = self.lim_height/2.0f - contentHeight/2.0f;
    
    self.subtitleLbl.lim_left = self.titleLbl.lim_left;
    self.subtitleLbl.lim_top = self.titleLbl.lim_bottom + subtitleTop;
    
    self.autoDeleteView.lim_left = self.avatarImgView.lim_width - self.autoDeleteView.lim_width + 4.0f;
    self.autoDeleteView.lim_top = self.avatarImgView.lim_height - self.autoDeleteView.lim_height + 2.0f;

    // 标题右侧标识（实名 + 官方 + Bot）
    [self.titleLbl sizeToFit];
    CGFloat badgesWidth = 0;
    if(!self.realnameVerifiedImgView.hidden) {
        badgesWidth += 12.0f + 6.0f;
    }
    if(!self.officialTag.hidden) {
        badgesWidth += self.officialTag.lim_width + 4.0f;
    }
    if(!self.botBadgeLbl.hidden) {
        badgesWidth += self.botBadgeLbl.lim_width + 6.0f;
    }
    CGFloat maxTitleWidth = self.infoBoxBtn.lim_width - self.avatarImgView.lim_right - avatarRightSpace - titleRightSpace - badgesWidth;
    if(self.titleLbl.lim_width > maxTitleWidth) {
        self.titleLbl.lim_width = maxTitleWidth;
    }

    CGFloat nextLeft = self.titleLbl.lim_left + self.titleLbl.lim_width;
    if(!self.realnameVerifiedImgView.hidden) {
        self.realnameVerifiedImgView.lim_width = 12.0f;
        self.realnameVerifiedImgView.lim_height = 12.0f;
        self.realnameVerifiedImgView.lim_left = nextLeft + 6.0f;
        self.realnameVerifiedImgView.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.realnameVerifiedImgView.lim_height) / 2.0f;
        nextLeft = self.realnameVerifiedImgView.lim_right;
    }
    if(!self.officialTag.hidden) {
        self.officialTag.lim_left = nextLeft + 4.0f;
        self.officialTag.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.officialTag.lim_height) / 2.0f;
        nextLeft = self.officialTag.lim_right;
    }
    if(!self.botBadgeLbl.hidden) {
        self.botBadgeLbl.lim_left = nextLeft + 6.0f;
        self.botBadgeLbl.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.botBadgeLbl.lim_height) / 2.0f;
    }
}

- (void)setChannelInfo:(WKChannelInfo *)channelInfo {
    _channelInfo = channelInfo;
    if(!_channelInfo) {
        return;
    }
    WKChannel *channel = channelInfo.channel;
    // 子区：使用子区图标作为默认头像
    if(channel.channelType == WK_COMMUNITY_TOPIC) {
        self.avatarImgView.avatarImgView.image = [self imageName:@"Conversation/Index/ThreadIcon"];
        self.titleLbl.text = channelInfo.displayName;
        self.subtitleLbl.hidden = YES;
        self.autoDeleteView.hidden = YES;
        self.officialTag.hidden = YES;
        self.botBadgeLbl.hidden = YES;
        self.realnameVerifiedImgView.hidden = YES;
        return;
    }
    self.titleLbl.text = channelInfo.displayName;
    if(channel.channelType == WK_PERSON) {
        if([channel.channelId isEqualToString:[WKApp shared].config.systemUID]) {
            self.titleLbl.text = LLang(@"系统通知");
            if(channelInfo.remark && ![channelInfo.remark isEqualToString:@""]) {
                self.titleLbl.text = channelInfo.remark;
            }
        }else if([channelInfo.channel.channelId isEqualToString:[WKApp shared].config.fileHelperUID]) {
            self.titleLbl.text = LLang(@"文件传输助手");
            if(channelInfo.remark && ![channelInfo.remark isEqualToString:@""]) {
                self.titleLbl.text = channelInfo.remark;
            }
        }
    }
   
    self.subtitleLbl.hidden = NO;
    if(channelInfo && (channelInfo.channel.channelType == WK_PERSON || channelInfo.channel.channelType == WK_CustomerService)) {
        
        NSString *onlineTip = [WKOnlineStatusManager.shared onlineStatusDetailTip:channelInfo];
        if(onlineTip) {
            self.subtitleLbl.text = onlineTip;
        }else {
            self.subtitleLbl.hidden = YES;
        }
        [self.subtitleLbl sizeToFit];
        {
            // 个人频道：始终拼接 ?v=cacheKey，cacheKey变化时SDWebImage自动重新下载
            NSString *key = (channelInfo.avatarCacheKey.length > 0) ? channelInfo.avatarCacheKey : @"0";
            NSString *baseUrl;
            if(channelInfo.logo && ![channelInfo.logo isEqualToString:@""]) {
                baseUrl = [WKAvatarUtil getFullAvatarWIthPath:channelInfo.logo];
            }else{
                baseUrl = [WKAvatarUtil getAvatar:channelInfo.channel.channelId];
            }
            self.avatarImgView.url = [NSString stringWithFormat:@"%@?v=%@", baseUrl, key];
        }
        
    }else {
     
        if(channelInfo.logo && ![channelInfo.logo isEqualToString:@""]) {
            NSString *avatarURL = [WKAvatarUtil getFullAvatarWIthPath:channelInfo.logo];
            NSString *key = (channelInfo.avatarCacheKey.length > 0) ? channelInfo.avatarCacheKey : @"0";
            NSString *separator = [avatarURL containsString:@"?"] ? @"&" : @"?";
            avatarURL = [NSString stringWithFormat:@"%@%@v=%@", avatarURL, separator, key];
            self.avatarImgView.url = avatarURL;
        }else{
            self.avatarImgView.url = [WKAvatarUtil getGroupAvatar:channelInfo.channel.channelId cacheKey:channelInfo.avatarCacheKey];
        }
    }
    NSInteger msgAutoDelete = 0;
    if(channelInfo.extra[@"msg_auto_delete"]) {
        msgAutoDelete = [channelInfo.extra[@"msg_auto_delete"] integerValue];
    }
    self.autoDeleteView.hidden = YES;
    if(msgAutoDelete>0) {
        self.autoDeleteView.hidden = NO;
        self.autoDeleteView.second = msgAutoDelete;
    }

    // 官方图标
    self.officialTag.hidden = YES;
    NSString *category = channelInfo.category;
    // 系统通知直接判断为官方
    if ([channel.channelId isEqualToString:[WKApp shared].config.systemUID]) {
        category = WKChannelCategoryService;
    }
    if(category && ![category isEqualToString:@""]) {
        if([category isEqualToString:WKChannelCategoryService]) {
            self.officialTag.frame = CGRectMake(0.0f, 0.0f, 18.0f, 18.0f);
            self.officialTag.hidden = NO;
            self.officialTag.image = [self imageName:@"ConversationList/Index/Official"];
        } else if([category isEqualToString:WKChannelCategoryVisitor]) {
            self.officialTag.frame = CGRectMake(0.0f, 0.0f, 35.0f, 18.0f);
            self.officialTag.hidden = NO;
            self.officialTag.image = [self imageName:@"ConversationList/Index/Visitor"];
        }
    }

    // Bot标识
    BOOL isBot = channelInfo.robot;
    self.botBadgeLbl.hidden = !isBot;
    if(isBot) {
        CGFloat h = 16.0f;
        CGFloat w = h;
        UIImage *img = self.botBadgeLbl.image;
        if(img && img.size.height > 0.0f) {
            w = h * img.size.width / img.size.height;
        }
        CGRect frame = self.botBadgeLbl.frame;
        frame.size = CGSizeMake(w, h);
        self.botBadgeLbl.frame = frame;
    }

    // 实名 ✓ 徽章：仅私聊（且非系统/文件助手/机器人）展示。
    BOOL canShowRealname = channel.channelType == WK_PERSON
        && ![channel.channelId isEqualToString:[WKApp shared].config.systemUID]
        && ![channel.channelId isEqualToString:[WKApp shared].config.fileHelperUID]
        && !isBot;
    BOOL realnameVerified = NO;
    if(canShowRealname) {
        NSNumber *flag = [WKChannelUtil isRealnameVerifiedFromExtra:channelInfo.extra];
        realnameVerified = flag.boolValue;
    }
    self.realnameVerifiedImgView.hidden = !realnameVerified;
    // 不打开名片也能补：未确认已实名时，后台拉一次 /users/<uid>，
    // 拉到后 channelInfoUpdate 触发 conversationVC.refreshTitle 重新进 setChannelInfo。
    if(canShowRealname && !realnameVerified) {
        [WKRealnamePrefetcher ensureFetched:channel.channelId];
    }
    [self setNeedsLayout];
}


- (void)setSubtitleText:(NSString *)subtitleText {
    _subtitleText = subtitleText;
    if (subtitleText.length > 0) {
        self.subtitleLbl.text = subtitleText;
        self.subtitleLbl.hidden = NO;
        [self.subtitleLbl sizeToFit];
        [self setNeedsLayout];
    }
}

- (void)setMemberCount:(NSInteger)memberCount {
    if(self.channelInfo && self.channelInfo.channel.channelType != WK_PERSON && self.channelInfo.channel.channelType != WK_CustomerService && self.channelInfo.channel.channelType != WK_COMMUNITY_TOPIC) {
        self.subtitleLbl.text = [NSString stringWithFormat:LLang(@"%ld个成员"),memberCount];
    }
    [self.subtitleLbl sizeToFit];

}

- (UIButton *)infoBoxBtn {
    if(!_infoBoxBtn) {
        _infoBoxBtn = [[UIButton alloc] init];
    }
    return _infoBoxBtn;
}

- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 38.0f, 38.0f)];
        _avatarImgView.userInteractionEnabled = NO;
    }
    return _avatarImgView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [[WKApp shared].config appFontOfSizeSemibold:17.0f];
        _titleLbl.lim_height = 19.0f;
        _titleLbl.textColor = [WKApp shared].config.navBarTitleColor;
        _titleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return _titleLbl;
}

- (UILabel *)subtitleLbl {
    if(!_subtitleLbl) {
        _subtitleLbl = [[UILabel alloc] init];
        _subtitleLbl.font = [[WKApp shared].config appFontOfSizeMedium:12.0f];
        _subtitleLbl.textColor = [WKApp shared].config.navBarSubtitleColor;
    }
    return _subtitleLbl;
}

- (UIButton *)voiceCallBtn {
    if(!_voiceCallBtn) {
        _voiceCallBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        UIImage *img;
        if (@available(iOS 13.0, *)) {
            img =  [[self imageName:@"Conversation/Index/VoiceCall"] imageWithTintColor:[WKApp shared].config.navBarButtonColor renderingMode:UIImageRenderingModeAlwaysTemplate];

        } else {
            img = [[self imageName:@"Conversation/Index/VoiceCall"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        [_voiceCallBtn setImage:img forState:UIControlStateNormal];
        [_voiceCallBtn setTintColor:[WKApp shared].config.navBarButtonColor];
    }
    return _voiceCallBtn;
}

/// 智能总结入口按钮: 用 lucide-sparkle 图标 (与上下文 tab 入口同一份视觉, 但用矢量
/// 描线渲染避免 raster 模板染色后的颗粒感), 颜色取 navBarButtonColor —— 与同一栏
/// 顶左侧返回箭头 / voiceCallBtn / videoCallBtn 同色, 视觉上属于 nav 控件家族,
/// 不再用品牌紫做"AI 强调", 整条 header 色板更安静。
/// 路径由 octoSparkleImage 函数手算 lucide 24×24 viewBox 路径 (4 个圆角尖 + 4 个圆角凹),
/// stroke-width 2 (按 viewBox), round cap/join。
- (UIButton *)summaryBtn {
    if(!_summaryBtn) {
        _summaryBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        UIColor *tint = [WKApp shared].config.navBarButtonColor;
        // 描线宽 2 / 24 viewBox, 渲染到 22pt → stroke ≈ 1.83pt; 22pt 在 32×32 button 中央留 5pt 内边距,
        // 与 voiceCallBtn 的视觉重量基本一致。
        UIImage *img = [WKConversationChannelHeader octoSparkleImageWithSize:22.0f color:tint];
        [_summaryBtn setImage:img forState:UIControlStateNormal];
        [_summaryBtn setTintColor:tint];
    }
    return _summaryBtn;
}

/// 渲染 lucide-sparkle 路径到 UIImage。
/// SVG 原坐标 (24x24 viewBox): 4 个外尖 (上下左右), 4 个内凹 (右上 / 右下 / 左下 / 左上),
/// 每段直线 + 圆弧拼接。圆弧用 SVG arc 语义换算成中心 + 半径 + 起止角:
///   - 外尖 r=1, sweep=1 (视觉顺时针, UIKit 翻转坐标系下 clockwise=YES, 数学角度递增)
///   - 内凹 r=2, sweep=0 (视觉逆时针, clockwise=NO, 数学角度递减)
+ (UIImage *)octoSparkleImageWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        CGFloat s = size / 24.0;
        // 把 path scale 到目标 size; 中心 (12,12) 对齐到 (size/2, size/2)。
        UIBezierPath *path = [UIBezierPath bezierPath];
        #define WK_SP_PT(x, y) CGPointMake((x) * s, (y) * s)
        [path moveToPoint:WK_SP_PT(11.017, 2.814)];
        [self appendSparkleArc:path to:WK_SP_PT(12.983, 2.814) radius:1.0 * s sweepCW:YES];
        [path addLineToPoint:WK_SP_PT(14.034, 8.372)];
        [self appendSparkleArc:path to:WK_SP_PT(15.628, 9.966) radius:2.0 * s sweepCW:NO];
        [path addLineToPoint:WK_SP_PT(21.186, 11.017)];
        [self appendSparkleArc:path to:WK_SP_PT(21.186, 12.983) radius:1.0 * s sweepCW:YES];
        [path addLineToPoint:WK_SP_PT(15.628, 14.034)];
        [self appendSparkleArc:path to:WK_SP_PT(14.034, 15.628) radius:2.0 * s sweepCW:NO];
        [path addLineToPoint:WK_SP_PT(12.983, 21.186)];
        [self appendSparkleArc:path to:WK_SP_PT(11.017, 21.186) radius:1.0 * s sweepCW:YES];
        [path addLineToPoint:WK_SP_PT(9.966, 15.628)];
        [self appendSparkleArc:path to:WK_SP_PT(8.372, 14.034) radius:2.0 * s sweepCW:NO];
        [path addLineToPoint:WK_SP_PT(2.814, 12.983)];
        [self appendSparkleArc:path to:WK_SP_PT(2.814, 11.017) radius:1.0 * s sweepCW:YES];
        [path addLineToPoint:WK_SP_PT(8.372, 9.966)];
        [self appendSparkleArc:path to:WK_SP_PT(9.966, 8.372) radius:2.0 * s sweepCW:NO];
        [path closePath];
        #undef WK_SP_PT

        path.lineWidth = 2.0 * s;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;
        [color setStroke];
        [path stroke];
    }];
}

/// SVG arc-to (rx ry 0 0 sweep dx dy) 转 UIBezierPath addArcWithCenter:。
///   - 圆心 = chord 中点 ± perpendicular * sqrt(r² - halfChord²);
///     UIKit y-down 下 sweep=1 的中心在 perpendicular 正向 (-dy, dx) 上 (sign=+1),
///     sweep=0 在反向 (sign=-1)。
///   - clockwise = sweepCW (因为 UIKit 翻转坐标系下 visually CW 对应 clockwise=YES)。
+ (void)appendSparkleArc:(UIBezierPath *)path to:(CGPoint)p2 radius:(CGFloat)r sweepCW:(BOOL)sweepCW {
    CGPoint p1 = path.currentPoint;
    CGFloat dx = p2.x - p1.x, dy = p2.y - p1.y;
    CGFloat dist = hypot(dx, dy);
    if (dist < 1e-6) return;
    CGFloat halfChord = dist / 2.0;
    if (halfChord > r) halfChord = r;
    CGFloat perpDist = sqrt(MAX(0, r * r - halfChord * halfChord));
    CGFloat ux = -dy / dist, uy = dx / dist;
    CGPoint mid = CGPointMake((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0);
    CGFloat sign = sweepCW ? 1.0 : -1.0;
    CGPoint center = CGPointMake(mid.x + sign * perpDist * ux,
                                  mid.y + sign * perpDist * uy);
    CGFloat startA = atan2(p1.y - center.y, p1.x - center.x);
    CGFloat endA   = atan2(p2.y - center.y, p2.x - center.x);
    [path addArcWithCenter:center radius:r startAngle:startA endAngle:endA clockwise:sweepCW];
}

- (WKAutoDeleteView *)autoDeleteView {
    if(!_autoDeleteView) {
        _autoDeleteView = [[WKAutoDeleteView alloc] init];
    }
    return _autoDeleteView;
}

- (WKOfficialTag *)officialTag {
    if(!_officialTag) {
        _officialTag = [WKOfficialTag new];
    }
    return _officialTag;
}

- (UIImageView *)botBadgeLbl {
    if(!_botBadgeLbl) {
        _botBadgeLbl = [[UIImageView alloc] init];
        _botBadgeLbl.image = [self imageName:@"Common/Index/IconAIBadge"];
        _botBadgeLbl.contentMode = UIViewContentModeScaleAspectFit;
        _botBadgeLbl.hidden = YES;
    }
    return _botBadgeLbl;
}

// ：私聊顶部实名 ✓ 徽章
- (UIImageView *)realnameVerifiedImgView {
    if(!_realnameVerifiedImgView) {
        _realnameVerifiedImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 12.0f, 12.0f)];
        _realnameVerifiedImgView.contentMode = UIViewContentModeScaleAspectFit;
        _realnameVerifiedImgView.image = [self imageName:@"Common/ic_realname_verified_mini"];
        _realnameVerifiedImgView.hidden = YES;
    }
    return _realnameVerifiedImgView;
}

- (UIButton *)moreDotsBtn {
    if(!_moreDotsBtn) {
        _moreDotsBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        UIImage *img;
        if (@available(iOS 13.0, *)) {
            img = [[self imageName:@"Conversation/Index/MoreDots"] imageWithTintColor:[WKApp shared].config.navBarButtonColor renderingMode:UIImageRenderingModeAlwaysTemplate];
        } else {
            img = [[self imageName:@"Conversation/Index/MoreDots"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        [_moreDotsBtn setImage:img forState:UIControlStateNormal];
        [_moreDotsBtn setTintColor:[WKApp shared].config.navBarButtonColor];
        _moreDotsBtn.hidden = YES; // 默认隐藏，由外部控制显示
    }
    return _moreDotsBtn;
}

- (UIButton *)videoCallBtn {
    if(!_videoCallBtn) {
        _videoCallBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        UIImage *img;
        if (@available(iOS 13.0, *)) {
            img =  [[self imageName:@"Conversation/Index/VideoCall"] imageWithTintColor:[WKApp shared].config.navBarButtonColor renderingMode:UIImageRenderingModeAlwaysTemplate];
           
        } else {
            img = [[self imageName:@"Conversation/Index/VideoCall"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        [_videoCallBtn setImage:img forState:UIControlStateNormal];
        [_videoCallBtn setTintColor:[WKApp shared].config.navBarButtonColor];
    }
    return _videoCallBtn;
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    if(type == WKViewConfigChangeTypeStyle) {
        self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
        self.subtitleLbl.textColor = [WKApp shared].config.tipColor;
    }
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end

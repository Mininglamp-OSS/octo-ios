//
//  WKConversationGroupThreadCell.m
//  WuKongBase
//

#import "WKConversationGroupThreadCell.h"
#import "WKThreadModel.h"
#import "WKTimeTool.h"
#import "WKBadgeView.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import <SDWebImage/UIImageView+WebCache.h>

// 弧线绘制视图
@interface WKThreadBranchView : UIView
@property (nonatomic, assign) NSInteger branchCount;
@property (nonatomic, assign) CGFloat rowHeight;
@property (nonatomic, assign) CGFloat firstRowTop;
@end

@implementation WKThreadBranchView
- (void)drawRect:(CGRect)rect {
    UIColor *lineColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.3];
    [lineColor setStroke];

    for (NSInteger i = 0; i < self.branchCount; i++) {
        CGFloat rowCenterY = self.firstRowTop + i * self.rowHeight + self.rowHeight / 2.0f;
        UIBezierPath *path = [UIBezierPath bezierPath];
        path.lineWidth = 1.5f;
        path.lineCapStyle = kCGLineCapRound;

        if (i < self.branchCount - 1) {
            // 非最后一个：竖线 + 横向弧线分支
            [path moveToPoint:CGPointMake(rect.size.width / 2.0f, 0)];
            [path addLineToPoint:CGPointMake(rect.size.width / 2.0f, rowCenterY - 6)];
            [path addQuadCurveToPoint:CGPointMake(rect.size.width, rowCenterY)
                         controlPoint:CGPointMake(rect.size.width / 2.0f, rowCenterY)];
        } else {
            // 最后一个：竖线到此结束 + 弧线
            [path moveToPoint:CGPointMake(rect.size.width / 2.0f, 0)];
            [path addLineToPoint:CGPointMake(rect.size.width / 2.0f, rowCenterY - 6)];
            [path addQuadCurveToPoint:CGPointMake(rect.size.width, rowCenterY)
                         controlPoint:CGPointMake(rect.size.width / 2.0f, rowCenterY)];
        }
        [path stroke];
    }
}
@end

#pragma mark - Cell

@interface WKConversationGroupThreadCell ()

// 顶部区域（群组信息）
@property (nonatomic, strong) WKUserAvatar *avatarView;
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UILabel *timeLbl;
@property (nonatomic, strong) UILabel *subtitleLbl;
@property (nonatomic, strong) WKBadgeView *badgeView;
@property (nonatomic, strong) UIImageView *muteIcon;

// 子区预览区域
@property (nonatomic, strong) UIView *threadContainer;
@property (nonatomic, strong) WKThreadBranchView *branchView;
@property (nonatomic, strong) UILabel *moreLbl;

@property (nonatomic, strong) WKConversationWrapModel *model;

@end

@implementation WKConversationGroupThreadCell

#define TOP_HEIGHT 68.0f
#define THREAD_ROW_HEIGHT 44.0f
#define MORE_HEIGHT 26.0f
#define AVATAR_SIZE 50.0f
#define AVATAR_LEFT 15.0f
#define CONTENT_LEFT 76.0f
#define RIGHT_PADDING 15.0f

+(CGFloat) heightForModel:(WKConversationWrapModel *)model {
    if (!model.threadPreviews || model.threadPreviews.count == 0) {
        return TOP_HEIGHT;
    }
    CGFloat h = TOP_HEIGHT;
    h += model.threadPreviews.count * THREAD_ROW_HEIGHT;
    if (model.threadCount > (NSInteger)model.threadPreviews.count) {
        h += MORE_HEIGHT;
    }
    return h + 6.0f;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // 头像
    self.avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, AVATAR_SIZE, AVATAR_SIZE)];
    [self.contentView addSubview:self.avatarView];

    // 标题
    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.titleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.titleLbl];

    // 时间
    self.timeLbl = [[UILabel alloc] init];
    self.timeLbl.font = [[WKApp shared].config appFontOfSize:11.0f];
    self.timeLbl.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    [self.contentView addSubview:self.timeLbl];

    // 副标题（最新子区消息）
    self.subtitleLbl = [[UILabel alloc] init];
    self.subtitleLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
    self.subtitleLbl.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    self.subtitleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.subtitleLbl];

    // 红点
    self.badgeView = [WKBadgeView viewWithoutBadgeTip];
    [self.contentView addSubview:self.badgeView];

    // 免打扰
    self.muteIcon = [[UIImageView alloc] initWithImage:[WKApp.shared loadImage:@"ConversationList/Index/Mute" moduleID:@"WuKongBase"]];
    self.muteIcon.hidden = YES;
    [self.contentView addSubview:self.muteIcon];

    // 弧线
    self.branchView = [[WKThreadBranchView alloc] init];
    self.branchView.backgroundColor = [UIColor clearColor];
    [self.contentView addSubview:self.branchView];

    // 子区容器
    self.threadContainer = [[UIView alloc] init];
    self.threadContainer.layer.cornerRadius = 8.0f;
    self.threadContainer.layer.masksToBounds = YES;
    [self.contentView addSubview:self.threadContainer];

    // 更多
    self.moreLbl = [[UILabel alloc] init];
    self.moreLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    self.moreLbl.textColor = [WKApp shared].config.themeColor;
    self.moreLbl.hidden = YES;
    [self.contentView addSubview:self.moreLbl];
}

-(void) refreshWithModel:(WKConversationWrapModel *)model {
    self.model = model;
    BOOL hasChannelInfo = model.channelInfo ? YES : NO;
    if (!hasChannelInfo) {
        [model startChannelRequest];
    }

    // 头像
    if (hasChannelInfo) {
        if (model.channelInfo.logo && ![model.channelInfo.logo isEqualToString:@""]) {
            NSString *avatarURL = [WKAvatarUtil getFullAvatarWIthPath:model.channelInfo.logo];
            NSString *key = (model.channelInfo.avatarCacheKey.length > 0) ? model.channelInfo.avatarCacheKey : @"0";
            NSString *separator = [avatarURL containsString:@"?"] ? @"&" : @"?";
            self.avatarView.url = [NSString stringWithFormat:@"%@%@v=%@", avatarURL, separator, key];
        } else {
            self.avatarView.url = [WKAvatarUtil getGroupAvatar:model.channel.channelId cacheKey:model.channelInfo.avatarCacheKey];
        }
    }

    // 标题
    self.titleLbl.text = hasChannelInfo ? model.channelInfo.displayName : LLang(@"群聊");

    // 时间
    self.timeLbl.text = [WKTimeTool getTimeStringAutoShort2:[NSDate dateWithTimeIntervalSince1970:model.lastMsgTimestamp] mustIncludeTime:YES];

    // 副标题：显示群组最后一条消息（与普通 cell 一致）
    WKMessage *displayMsg = [model spaceFilteredLastMessage];
    if (displayMsg && displayMsg.content) {
        if (displayMsg.remoteExtra.revoke) {
            self.subtitleLbl.text = LLang(@"撤回了一条消息");
        } else {
            NSString *content = model.content ?: @"";
            // 群聊显示发送者
            if (model.channel.channelType == WK_GROUP && displayMsg.fromUid.length > 0) {
                WKChannelInfo *fromInfo = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:displayMsg.fromUid]];
                NSString *fromName = fromInfo ? fromInfo.displayName : displayMsg.fromUid;
                self.subtitleLbl.text = [NSString stringWithFormat:@"%@: %@", fromName, content];
            } else {
                self.subtitleLbl.text = content;
            }
        }
    } else {
        self.subtitleLbl.text = model.content ?: @"";
    }

    // 红点（与普通 cell 一致）
    self.badgeView.hidden = YES;
    if (model.unreadCount > 0) {
        self.badgeView.hidden = NO;
        self.badgeView.badgeValue = [NSString stringWithFormat:@"%ld", (long)model.unreadCount];
        self.badgeView.lim_left = self.contentView.lim_width - RIGHT_PADDING - self.badgeView.lim_width;
    }

    // 免打扰
    if (model.mute) {
        self.muteIcon.hidden = (model.unreadCount > 0);
        [self.badgeView setBadgeBackgroundColor:[UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f]];
    } else {
        self.muteIcon.hidden = YES;
        [self.badgeView setBadgeBackgroundColor:[UIColor redColor]];
    }

    // 子区预览
    [self buildThreadPreviews];
    [self setNeedsLayout];
}

-(void) buildThreadPreviews {
    for (UIView *v in self.threadContainer.subviews) {
        [v removeFromSuperview];
    }
    self.threadContainer.hidden = YES;
    self.branchView.hidden = YES;
    self.moreLbl.hidden = YES;

    NSArray<WKThreadModel *> *previews = self.model.threadPreviews;
    if (!previews || previews.count == 0) return;

    self.threadContainer.hidden = NO;
    self.branchView.hidden = NO;
    self.threadContainer.backgroundColor = [WKApp shared].config.backgroundColor;

    CGFloat containerWidth = self.contentView.lim_width - CONTENT_LEFT - RIGHT_PADDING;

    for (NSInteger i = 0; i < previews.count; i++) {
        WKThreadModel *t = previews[i];
        UIView *row = [self createRow:t width:containerWidth index:i];
        row.frame = CGRectMake(0, i * THREAD_ROW_HEIGHT, containerWidth, THREAD_ROW_HEIGHT);
        [self.threadContainer addSubview:row];

        if (i < previews.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(10, (i + 1) * THREAD_ROW_HEIGHT - 0.5f, containerWidth - 20, 0.5f)];
            sep.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
            [self.threadContainer addSubview:sep];
        }
    }

    // 更多
    if (self.model.threadCount > (NSInteger)previews.count) {
        self.moreLbl.hidden = NO;
        self.moreLbl.text = [NSString stringWithFormat:@"+%ld %@", (long)(self.model.threadCount - (NSInteger)previews.count), LLang(@"个子区")];
        self.moreLbl.userInteractionEnabled = YES;
        // 移除旧手势防止重复
        for (UIGestureRecognizer *g in self.moreLbl.gestureRecognizers) {
            [self.moreLbl removeGestureRecognizer:g];
        }
        UITapGestureRecognizer *moreTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMoreTap)];
        [self.moreLbl addGestureRecognizer:moreTap];
    }
}

-(UIView *) createRow:(WKThreadModel *)thread width:(CGFloat)width index:(NSInteger)index {
    UIView *row = [[UIView alloc] init];
    row.tag = 2000 + index;
    row.userInteractionEnabled = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(threadRowTapped:)];
    [row addGestureRecognizer:tap];

    // # 符号
    UILabel *hash = [[UILabel alloc] initWithFrame:CGRectMake(10, 7, 16, 16)];
    hash.text = @"#";
    hash.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    hash.textColor = [WKApp shared].config.themeColor;
    [row addSubview:hash];

    // 名称
    CGFloat nameLeft = 28;
    UILabel *name = [[UILabel alloc] init];
    name.text = thread.name;
    name.font = [[WKApp shared].config appFontOfSizeMedium:14.0f];
    name.textColor = [WKApp shared].config.defaultTextColor;
    name.lineBreakMode = NSLineBreakByTruncatingTail;
    [row addSubview:name];

    // 时间
    UILabel *time = [[UILabel alloc] init];
    time.font = [[WKApp shared].config appFontOfSize:10.0f];
    time.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    if (thread.updatedAt.length > 0) {
        NSDate *date = [WKTimeTool dateFromString:thread.updatedAt];
        if (date) {
            time.text = [WKTimeTool getTimeStringAutoShort2:date mustIncludeTime:NO];
        }
    }
    [time sizeToFit];
    time.frame = CGRectMake(width - 10 - time.lim_width, 9, time.lim_width, 14);
    [row addSubview:time];

    name.frame = CGRectMake(nameLeft, 6, time.lim_left - nameLeft - 4, 17);

    // 未读红点：优先从 SDK 会话获取实时未读数，fallback 到 API 返回值
    NSInteger unread = thread.unreadCount;
    WKChannel *threadChannel = [WKChannel channelID:thread.channelId channelType:WK_COMMUNITY_TOPIC];
    WKConversation *threadConv = [[WKSDK shared].conversationManager getConversation:threadChannel];
    if (threadConv) {
        unread = threadConv.unreadCount;
    }
    if (unread > 0) {
        UILabel *badge = [[UILabel alloc] init];
        badge.text = [NSString stringWithFormat:@"%ld", (long)unread];
        badge.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        badge.textColor = [UIColor whiteColor];
        badge.backgroundColor = [UIColor redColor];
        badge.textAlignment = NSTextAlignmentCenter;
        [badge sizeToFit];
        CGFloat badgeW = MAX(badge.lim_width + 8, 18);
        CGFloat badgeH = 18;
        badge.frame = CGRectMake(width - 10 - badgeW, 24, badgeW, badgeH);
        badge.layer.cornerRadius = badgeH / 2.0f;
        badge.layer.masksToBounds = YES;
        [row addSubview:badge];
    }

    // 最后消息：优先从 SDK 会话获取实时数据
    CGFloat msgRight = (unread > 0) ? 36 : 10;
    UILabel *msg = [[UILabel alloc] initWithFrame:CGRectMake(nameLeft, 25, width - nameLeft - msgRight, 14)];
    NSString *lastMsgText = nil;
    if (threadConv && threadConv.lastMessage && threadConv.lastMessage.content) {
        NSString *digest = [threadConv.lastMessage.content conversationDigest];
        if (digest.length > 0) {
            WKChannelInfo *senderInfo = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:threadConv.lastMessage.fromUid]];
            NSString *senderName = senderInfo ? senderInfo.displayName : threadConv.lastMessage.fromUid;
            if (senderName.length > 0) {
                lastMsgText = [NSString stringWithFormat:@"%@: %@", senderName, digest];
            } else {
                lastMsgText = digest;
            }
        }
    }
    if (!lastMsgText && thread.lastMessageSenderName.length > 0 && thread.lastMessageContent.length > 0) {
        lastMsgText = [NSString stringWithFormat:@"%@: %@", thread.lastMessageSenderName, thread.lastMessageContent];
    }
    msg.text = lastMsgText;
    msg.font = [[WKApp shared].config appFontOfSize:12.0f];
    msg.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    msg.lineBreakMode = NSLineBreakByTruncatingTail;
    [row addSubview:msg];

    return row;
}

-(void) onMoreTap {
    if (self.onMoreThreadsTap && self.model.channel.channelId.length > 0) {
        self.onMoreThreadsTap(self.model.channel.channelId);
    }
}

-(void) threadRowTapped:(UITapGestureRecognizer *)tap {
    NSInteger index = tap.view.tag - 2000;
    NSArray *previews = self.model.threadPreviews;
    if (previews && index >= 0 && index < (NSInteger)previews.count) {
        WKThreadModel *t = previews[index];
        if (self.onThreadPreviewTap && t.channelId.length > 0) {
            self.onThreadPreviewTap(t.channelId);
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.contentView.lim_width;

    // 头像
    self.avatarView.frame = CGRectMake(AVATAR_LEFT, 10, AVATAR_SIZE, AVATAR_SIZE);

    // 时间
    [self.timeLbl sizeToFit];
    self.timeLbl.frame = CGRectMake(w - RIGHT_PADDING - self.timeLbl.lim_width, 14, self.timeLbl.lim_width, 14);

    // 标题
    CGFloat titleRight = self.timeLbl.lim_left - 8;
    self.titleLbl.frame = CGRectMake(CONTENT_LEFT, 12, titleRight - CONTENT_LEFT, 20);

    // 副标题
    self.subtitleLbl.frame = CGRectMake(CONTENT_LEFT, 34, titleRight - CONTENT_LEFT, 18);

    // 红点
    self.badgeView.lim_left = w - RIGHT_PADDING - self.badgeView.lim_width;
    self.badgeView.lim_top = self.timeLbl.lim_bottom + 6;

    // 免打扰
    self.muteIcon.lim_left = w - RIGHT_PADDING - self.muteIcon.lim_width;
    self.muteIcon.lim_top = self.badgeView.lim_top + 4;

    // 子区预览区域
    NSArray *previews = self.model.threadPreviews;
    if (previews && previews.count > 0) {
        CGFloat containerTop = TOP_HEIGHT;
        CGFloat containerWidth = w - CONTENT_LEFT - RIGHT_PADDING;
        CGFloat containerHeight = previews.count * THREAD_ROW_HEIGHT;

        self.threadContainer.frame = CGRectMake(CONTENT_LEFT, containerTop, containerWidth, containerHeight);

        // 弧线：从头像底部中心到每个子区行
        CGFloat avatarCenterX = AVATAR_LEFT + AVATAR_SIZE / 2.0f;
        CGFloat branchWidth = CONTENT_LEFT - avatarCenterX;
        CGFloat avatarBottom = self.avatarView.lim_top + AVATAR_SIZE;
        CGFloat branchHeight = containerTop + containerHeight - avatarBottom;

        self.branchView.frame = CGRectMake(avatarCenterX - branchWidth / 2.0f, avatarBottom, branchWidth, branchHeight);
        self.branchView.branchCount = previews.count;
        self.branchView.rowHeight = THREAD_ROW_HEIGHT;
        self.branchView.firstRowTop = containerTop - avatarBottom;
        [self.branchView setNeedsDisplay];

        // 更多
        if (!self.moreLbl.hidden) {
            self.moreLbl.frame = CGRectMake(CONTENT_LEFT + 10, containerTop + containerHeight + 2, containerWidth, MORE_HEIGHT - 4);
        }
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.avatarView.avatarImgView.image = nil;
    self.badgeView.hidden = YES;
    self.muteIcon.hidden = YES;
    self.threadContainer.hidden = YES;
    self.branchView.hidden = YES;
    self.moreLbl.hidden = YES;
    self.onThreadPreviewTap = nil;
    self.onMoreThreadsTap = nil;
}

@end

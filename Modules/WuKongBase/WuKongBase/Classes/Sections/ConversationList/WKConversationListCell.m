//
//  WKConversationListCell.m
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import "WKConversationListCell.h"
#import "UIView+WK.h"
#import "WKImageView.h"
#import "WKTimeTool.h"
#import "WKBadgeView.h"
#import "WKApp.h"
#import "WKResource.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import "WKAvatarUtil.h"
#import <DGActivityIndicatorView/DGActivityIndicatorView.h>
#import "WKOnlineBadgeView.h"
#import "WKOfficialTag.h"
#import "WKConstant.h"
#import "WKCheckBox.h"
#import "WuKongBase.h"
#import "WKMessageRevokeCell.h"
#import "WKTypingManager.h"
#import "WKTypingContent.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import "WKUserAvatar.h"
#import "WKAutoDeleteView.h"
//#define avatarSize 56.0f
@interface WKConversationListCell ()

@property(nonatomic,strong) UILabel *titleLbl; // 名称
@property(nonatomic,strong) WKUserAvatar *avatarImgView; // 头像
@property(nonatomic,strong) UIImageView *statusImgView; // 消息状态image
@property(nonatomic,strong) UILabel *lastContentLbl; // 最后一条消息内容
@property(nonatomic,strong) UILabel *lastMsgTimeLbl; // 最后一条消息时间
@property(nonatomic,strong) DGActivityIndicatorView *typingIndicatorView;

@property(nonatomic,strong) WKBadgeView *badgeView;

@property(nonatomic,strong) WKConversationWrapModel *model;

@property(nonatomic,strong) WKOnlineBadgeView *onlineBadgeView;

@property(nonatomic,strong) UIImageView *muteIcon;

@property(nonatomic,strong) WKOfficialTag *officialTag; // 官方图标

@property(nonatomic,copy) NSString *revokeTip; // 撤回消息tip

@property(nonatomic,strong) UIView *contextContainerView;

@property(nonatomic,strong) WKAutoDeleteView *autoDeleteView; // 自动删除

@end

@implementation WKConversationListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        
        self.contextContainerView = [[UIView alloc] init];
        [self.contentView addSubview:self.contextContainerView];
        
        self.titleLbl = [[UILabel alloc] init];
        [self.titleLbl setFont:[[WKApp shared].config appFontOfSizeMedium:17.0f]];
        [self.contextContainerView addSubview:self.titleLbl];
        
        
        self.avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, [WKApp shared].config.messageListAvatarSize.width,  [WKApp shared].config.messageListAvatarSize.height)];
        [self.contextContainerView addSubview:self.avatarImgView];
        // 最后一条消息内容
        self.lastContentLbl = [[UILabel alloc] init];
        [self.lastContentLbl setFont:[[WKApp shared].config appFontOfSize:15.0f]];
        [self.lastContentLbl setTextColor:[UIColor colorWithRed:179.0f/255.0f green:179.0f/255.0f blue:179.0f/255.0f alpha:1.0f]];
        self.lastContentLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        self.lastContentLbl.numberOfLines = 1;
        [self.contextContainerView addSubview:self.lastContentLbl];
        // 最后一条消息时间
        self.lastMsgTimeLbl = [[UILabel alloc] init];
        [self.lastMsgTimeLbl setFont:[[WKApp shared].config appFontOfSize:11.0f]];
        [self.lastMsgTimeLbl setTextColor:[UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f]];
        [self.contextContainerView addSubview:self.lastMsgTimeLbl];
        // 红点
        self.badgeView = [WKBadgeView viewWithoutBadgeTip];
        [self.contextContainerView addSubview:self.badgeView];
        // 消息状态
        [self.contextContainerView addSubview:self.statusImgView];
        // 正在输入
        [self.contextContainerView addSubview:self.typingIndicatorView];
        // 在线状态
        [self.contextContainerView addSubview:self.onlineBadgeView];
        // 免打扰图标
        [self.contextContainerView addSubview:self.muteIcon];
        // 官方图标
        [self.contextContainerView addSubview:self.officialTag];
        // 自动删除图标
        [self.contextContainerView addSubview:self.autoDeleteView];
        
    }
    return self;
}

- (UIImageView *)statusImgView {
    if(!_statusImgView) {
        _statusImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 14.0f, 14.0f)];
    }
    return _statusImgView;
}

- (WKOnlineBadgeView *)onlineBadgeView {
    if(!_onlineBadgeView) {
        _onlineBadgeView = [WKOnlineBadgeView initWithTip:nil];
    }
    return _onlineBadgeView;
}

- (WKOfficialTag *)officialTag {
    if(!_officialTag) {
        _officialTag = [WKOfficialTag new];
    }
    return _officialTag;
}

- (UIImageView *)muteIcon {
    if(!_muteIcon) {
        _muteIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 15.0f, 17.0f)];
        [_muteIcon setImage:[self imageName:@"ConversationList/Index/Mute"]];
    }
    return _muteIcon;
}

- (WKAutoDeleteView *)autoDeleteView {
    if(!_autoDeleteView) {
        _autoDeleteView = [[WKAutoDeleteView alloc] init];
    }
    return _autoDeleteView;
}



- (void)prepareForReuse {
    [super prepareForReuse];
    self.avatarImgView.avatarImgView.image =nil;
}


-(void) refreshWithModel:(WKConversationWrapModel*)model{
    self.model = model;
    
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    if(!hasChannelInfo) {
        [model startChannelRequest];
    }
    [self refreshAvatar:model];
    
    // 最后一次消息时间
    self.lastMsgTimeLbl.text = [WKTimeTool getTimeStringAutoShort2:[NSDate dateWithTimeIntervalSince1970:model.lastMsgTimestamp] mustIncludeTime:true];
//    [ self.lastMsgTimeLbl sizeToFit];
    
    // 刷新标题
    [self refreshTitle:model];
    
    // 刷新在线状态
    [self refreshOnlineStatus:model];
    
    // 刷新最后一条消息
    [self refreshLastMessage:model];
    
    // 刷新输入中
    [self refreshTyping:model];
    
    // 刷新未读数
    [self refreshUnread:model];
    
    // 刷新设置
    [self refreshSetting:model];
    
    // 刷新消息状态
    [self refreshStatus:model];
    
    // 刷新官方tag
    [self refreshOfficialTag:model];
    // 自动删除
    [self refreshAutoDeleteIfNeed:model];
    
    [self layoutSubviews];
}

-(void) refreshAutoDeleteIfNeed:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    if(!hasChannelInfo) {
        self.autoDeleteView.hidden = YES;
        return;
    }
    NSInteger msgAutoDelete = 0;
    if(model.channelInfo.extra[@"msg_auto_delete"]) {
        msgAutoDelete = [model.channelInfo.extra[@"msg_auto_delete"] integerValue];
    }
    if(msgAutoDelete>0) {
        self.autoDeleteView.hidden = NO;
        self.autoDeleteView.second = msgAutoDelete;
        if(model.channelInfo.online) {
            self.autoDeleteView.hidden = YES;
        }else {
            self.onlineBadgeView.hidden  = YES;
        }
    }else{
        self.autoDeleteView.hidden = YES;
    }
    
 
    
}

-(NSString*) formatSecond:(NSInteger)second {
    if(second < 60 * 60 * 24) {
        return @"";
    }
    NSInteger day = second / (60 * 60 * 24);
    NSInteger week = day / 7;
    NSInteger month = day / 30;
    NSInteger year = month / 12;
    
    if(year>0) {
        return [NSString stringWithFormat:@"%ldy",(long)year];
    }
    if(month>0) {
        return [NSString stringWithFormat:@"%ldm",(long)month];
    }
    if(week>0) {
        return [NSString stringWithFormat:@"%ldw",(long)week];
    }
    if(day>0) {
        return [NSString stringWithFormat:@"%ldd",(long)day];
    }
    return @"";
}

-(void) refreshTitle:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    
    [self.titleLbl setTextColor:[WKApp shared].config.defaultTextColor];
    
    
    if(!hasChannelInfo) {
        // 如果没有频道信息触发频道信息获取
//        [[[WKSDK shared] channelManager] fetchChannelInfo:model.channel];
        if(model.channel.channelType == WK_PERSON) {
             self.titleLbl.text = LLang(@"无");
        }else if(model.channel.channelType == WK_GROUP){
            self.titleLbl.text = LLang(@"群聊");
        }else if(model.channel.channelType == WK_Community) {
            self.titleLbl.text = LLang(@"社区");
        }else {
            self.titleLbl.text = LLang(@"聊天");
        }
    }else {
        self.titleLbl.text = model.channelInfo.displayName;
        if(model.channel.channelType == WK_PERSON) {
            if([model.channel.channelId isEqualToString:[WKApp shared].config.systemUID]) {
                self.titleLbl.text = LLang(@"系统通知");
                if(model.channelInfo.remark && ![model.channelInfo.remark isEqualToString:@""]) {
                    self.titleLbl.text = model.channelInfo.remark;
                }
            }else if([model.channel.channelId isEqualToString:[WKApp shared].config.fileHelperUID]) {
                self.titleLbl.text = LLang(@"文件传输助手");
                if(model.channelInfo.remark && ![model.channelInfo.remark isEqualToString:@""]) {
                    self.titleLbl.text = model.channelInfo.remark;
                }
            }
        }
        
    }
    
    if(!self.titleLbl.text || [self.titleLbl.text isEqualToString:@""]) {
        self.titleLbl.text = LLang(@"无");
    }
    
    
//    [self.titleLbl sizeToFit];
}

-(void) refreshAvatar:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    // 头像
    self.avatarImgView.avatarImgView.image =[self imageName:@"Common/Index/DefaultAvatar"];
    if(hasChannelInfo) {
        if([model.channelInfo.logo hasPrefix:@"http"]) {
            [self.avatarImgView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:model.channelInfo.logo] placeholderImage:[self imageName:@"Common/Index/DefaultAvatar"] options:0 context:@{
                SDWebImageContextStoreCacheType: @(SDImageCacheTypeAll),
            }];
        }else {
                   
            [self.avatarImgView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:[WKAvatarUtil getFullAvatarWIthPath:model.channelInfo.logo]] placeholderImage:[self imageName:@"Common/Index/DefaultAvatar"] options:0 context:@{
                SDWebImageContextStoreCacheType: @(SDImageCacheTypeAll),
            }];
        }
    }
}

-(void) refreshOnlineStatus:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    // 在线状态
    self.onlineBadgeView.hidden = YES;
    if(model.channel.channelType == WK_PERSON) {
        if(hasChannelInfo) {
            if(model.channelInfo.online) {
                self.onlineBadgeView.hidden = NO;
                self.onlineBadgeView.tip = nil;
            }else if ([[NSDate date] timeIntervalSince1970] - model.channelInfo.lastOffline<60) {
                self.onlineBadgeView.hidden = NO;
                           self.onlineBadgeView.tip = LLang(@"刚刚");
            }else if( model.channelInfo.lastOffline+60*60>[[NSDate date] timeIntervalSince1970]) {
                self.onlineBadgeView.hidden = NO;
                self.onlineBadgeView.tip =[NSString stringWithFormat:LLang(@"%0.0f分钟"),([[NSDate date] timeIntervalSince1970]-model.channelInfo.lastOffline)/60];
            }
        }
    }
}

-(void) refreshLastMessage:(WKConversationWrapModel*)model {
    // 最后一条消息
    if(model.lastMessage) {
        if(model.lastMessage.remoteExtra.revoke) {
            self.lastContentLbl.text = self.revokeTip;
        }else if(model.lastContentType == WK_UNKNOWN) {
            self.lastContentLbl.text = [WKApp shared].config.unkownMessageText;
        }else {
            self.lastContentLbl.attributedText =[self getLastContent:model];
            self.lastContentLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        }
    }else  {
        self.lastContentLbl.text = @"";
    }
}

-(void) refreshTyping:(WKConversationWrapModel*)model {
    // 输入中
    self.typingIndicatorView.hidden = YES;
    [self.typingIndicatorView stopAnimating];
    WKMessage *typingMessage =  [[WKTypingManager shared] getTypingMessage:model.channel];
    if(typingMessage) {
        self.typingIndicatorView.hidden = YES;
         [self.typingIndicatorView startAnimating];
        if(model.channel.channelType == WK_PERSON) {
            self.lastContentLbl.text =LLang(@"正在输入");
        }else {
            WKTypingContent *typingContent = (WKTypingContent*)typingMessage.content;
            NSString *typingName = typingContent.typingName;
            if(typingContent.typingUID) {
              WKChannelInfo *typingChannelInfo =  [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:typingContent.typingUID]];
                if(typingChannelInfo) {
                    typingName = typingChannelInfo.displayName;
                }
            }
            
            self.lastContentLbl.text = [NSString stringWithFormat:LLang(@"%@ 正在输入"),typingName];
        }
    }
}

-(void) refreshUnread:(WKConversationWrapModel*)model {
    // 未读数
    self.badgeView.hidden = YES;
    if(model.unreadCount>0) {
        self.badgeView.hidden = NO;
        self.badgeView.badgeValue = [NSString stringWithFormat:@"%ld",(long)self.model.unreadCount];
        self.badgeView.lim_left = self.lim_width - 15.0f - self.badgeView.lim_width; // 这里强行执行下lim_left 因为杀掉app收离线，从无红点到有红点会向左漂移，因为layoutSubviews后执行
    }
}

-(void) refreshSetting:(WKConversationWrapModel*)model {
    // 免打扰
    if(model.mute) { // 免打扰
        if(model.unreadCount<=0) {
            self.muteIcon.hidden = NO;
        }else {
            self.muteIcon.hidden = YES;
        }
       
        [self.badgeView setBadgeBackgroundColor:[UIColor colorWithRed:163.0f/255.0f green:214.0/255.0f blue:237.0f/255.0f alpha:1.0]];
    }else {
        self.muteIcon.hidden = YES;
        [self.badgeView setBadgeBackgroundColor:[UIColor redColor]];
    }
    
    // 置顶
    if(model.stick) { // 置顶
        [self setBackgroundColor:[WKApp shared].config.backgroundColor];
    }else {
        [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    }
    
}

-(void) refreshStatus:(WKConversationWrapModel*)model {
    // 消息状态
    self.statusImgView.hidden = YES;
    if(self.model.lastMessage && self.model.lastMessage.isSend) {
        self.statusImgView.hidden = NO;
        [self updateStatus];
    }
}

-(void) refreshOfficialTag:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    // 官方图标
    self.officialTag.hidden = YES;
    if(hasChannelInfo && model.channelInfo.category && ![model.channelInfo.category isEqualToString:@""]) {
        NSString *category = model.channelInfo.category;
        if([category isEqualToString:WKChannelCategoryService]) {
            self.officialTag.frame = CGRectMake(0.0f, 0.0f, 18.0f, 18.0f);
            self.officialTag.hidden = NO;
            self.officialTag.image = [self imageName:@"ConversationList/Index/Official"];
        }else if([category isEqualToString:WKChannelCategoryVisitor]) {
            self.officialTag.frame = CGRectMake(0.0f, 0.0f, 35.0f, 18.0f);
            self.officialTag.hidden = NO;
            self.officialTag.image = [self imageName:@"ConversationList/Index/Visitor"];
        }
    }
}


-(void) updateStatus {
    if(!self.model.lastMessage || !self.model.lastMessage.isSend) {
        self.statusImgView.image = nil;
        return;
    }
//    [self.statusImgView setBackgroundColor:[UIColor redColor]];
    WKMessage *message = self.model.lastMessage;
    if([self needLoading:message]) {
        self.statusImgView.image = [self imageName:@"ConversationList/Index/TimeWait"];
        self.statusImgView.image = [self.statusImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.statusImgView.tintColor =  [WKApp shared].config.tipColor;
    }else if(message.status == WK_MESSAGE_SUCCESS) {
        if(message.remoteExtra.readedCount>0) {
            self.statusImgView.image = [self imageName:@"ConversationList/Index/DoubleCheckmark"];
            self.statusImgView.image = [self.statusImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }else{
            self.statusImgView.image = [self imageName:@"ConversationList/Index/Checkmark"];
            self.statusImgView.image = [self.statusImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        self.statusImgView.tintColor =  [WKApp shared].config.themeColor;
    }else if(message.status == WK_MESSAGE_FAIL) {
        self.statusImgView.image = [self imageName:@"ConversationList/Index/SendError"];
        self.statusImgView.image = [self.statusImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.statusImgView.tintColor =  [UIColor redColor];
    }
}
-(BOOL) needLoading:(WKMessage*)message {
    if((message.status == WK_MESSAGE_WAITSEND || message.status == WK_MESSAGE_UPLOADING) && message.isSend) {
        return true;
    }
    return false;
}

- (NSString *)revokeTip {
    if(!self.model.lastMessage) {
        return @"";
    }
    return [WKMessageRevokeCell tip:self.model.lastMessage];
}


- (DGActivityIndicatorView *)typingIndicatorView {
    if(!_typingIndicatorView) {
        _typingIndicatorView = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeThreeDots tintColor:[UIColor grayColor] size:20.0f];
        [_typingIndicatorView setFrame:CGRectMake(0.0f, 0.0f, 30.0f, 15.0f)];
    }
    return _typingIndicatorView;
}

-(NSMutableAttributedString*) getLastContent:(WKConversationWrapModel*)model{
    
    // 聊天密码
    BOOL chatPwdOn = model.channelInfo && [model.channelInfo settingForKey:WKChannelExtraKeyChatPwd defaultValue:false];
    if(chatPwdOn) {
        return  [[NSMutableAttributedString alloc] initWithString:@"* * * * * *"];
    }
    
    BOOL hasDraft = false;
    if(model.remoteExtra.draft && ![model.remoteExtra.draft isEqualToString:@""]) {
        hasDraft  = true;
    }
    
    NSMutableString *reminderStr  = [[NSMutableString alloc] init];
    if(model.simpleReminders && model.simpleReminders.count>0) {
        for (WKReminder *reminder in model.simpleReminders) {
            [reminderStr appendString:reminder.text];
        }
    }
    NSString *fullContentStr;
    NSString *content =model.content;
    if(hasDraft) {
        content = model.remoteExtra.draft;
        [reminderStr insertString:LLang(@"[草稿]") atIndex:0];
    }
    
    if(model.channel.channelType == WK_GROUP) { // 群组
        if([self showFromName:model] && !hasDraft) {
            NSString *name = [self getFromName];
            fullContentStr = [NSString stringWithFormat:@"%@%@: %@",reminderStr,name,content];
        }else {
            fullContentStr = [NSString stringWithFormat:@"%@%@",reminderStr,content];
        }
        
    }else { // 单聊
        fullContentStr = [NSString stringWithFormat:@"%@%@",reminderStr,content];
    }
    NSMutableAttributedString *contentAttrStr = [[NSMutableAttributedString alloc] init];
    WKRichTextParseOptions *options = [WKRichTextParseOptions new];
    options.disableLink = true;
    [contentAttrStr lim_parse:fullContentStr mentionInfo:nil options:options];
    if(reminderStr.length>0) {
        [contentAttrStr addAttribute:NSForegroundColorAttributeName value:[UIColor orangeColor] range:[fullContentStr rangeOfString:reminderStr]];
    }
    return contentAttrStr;
}


// 获取发送者名字
- (NSString*) getFromName  {
    if(!self.model.lastMessage) {
        return @"";
    }
    NSString *name;
    
   
//    if(self.model.lastMessage.fromUid && [WKApp shared].loginInfo.extra[@"name"] && [self.model.lastMessage.fromUid isEqualToString:[WKApp shared].loginInfo.uid] ) {
//        name = [WKApp shared].loginInfo.extra[@"name"];
//    }
    // 名字显示逻辑： 个人备注>群内名字>昵称
    
    if(self.model.lastMessage.from && !name) {
        if(self.model.lastMessage.from.remark && ![self.model.lastMessage.from.remark isEqualToString:@""]) {
            name = self.model.lastMessage.from.remark;
        }
    }
    if(!name) {
        if(self.model.lastMessage.memberOfFrom && self.model.lastMessage.memberOfFrom.memberRemark && ![self.model.lastMessage.memberOfFrom.memberRemark isEqualToString:@""]) {
            name = self.model.lastMessage.memberOfFrom.memberRemark;
        }
    }
    if(!name && self.model.lastMessage.from) {
        name = self.model.lastMessage.from.name;
        if([self.model.lastMessage.fromUid isEqualToString:[WKApp shared].config.systemUID]) {
            name = LLang(@"系统通知");
        }else if([self.model.lastMessage.fromUid isEqualToString:[WKApp shared].config.fileHelperUID]) {
            name = LLang(@"文件传输助手");
        }
    }
    
    if(name) {
        return name;
    }
    return @"";
    
}

-(BOOL) showFromName:(WKConversationWrapModel*)model {
    return model.lastMessage && (model.lastMessage.fromUid && ![model.lastMessage.fromUid isEqualToString:@""]) && model.lastMessage.from && ![model.lastMessage.content isKindOfClass:[WKSystemContent class]];
}

-(void) layoutSubviews {
    [super layoutSubviews];
    
    self.contextContainerView.frame = self.contentView.bounds;
    
    // 头像
    self.avatarImgView.lim_left = 15.0f;
    self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
    
    // 在线标记
    if(self.model.channelInfo && self.model.channelInfo.online) {
        self.onlineBadgeView.lim_left = self.avatarImgView.lim_right - self.onlineBadgeView.lim_width;
    }else {
        self.onlineBadgeView.lim_left = self.avatarImgView.lim_right - self.onlineBadgeView.lim_width + 4.0f;
    }
   self.onlineBadgeView.lim_top = self.avatarImgView.lim_bottom - self.onlineBadgeView.lim_height;
   
    self.autoDeleteView.lim_left = self.avatarImgView.lim_right - self.autoDeleteView.lim_width + 2.0f;
    self.autoDeleteView.lim_top = self.avatarImgView.lim_bottom - self.autoDeleteView.lim_height + 2.0f;
    // 名称
    CGFloat statusRightSpace = 2.0f;
    
    CGFloat titleLeftToAvatarSpace = 10.0f;
    self.titleLbl.lim_left = self.avatarImgView.lim_right + titleLeftToAvatarSpace;
    self.titleLbl.lim_top = self.avatarImgView.lim_top + 4.0f ;
    
    [self.lastMsgTimeLbl sizeToFit];
    CGFloat titleMaxWidth = self.lim_width - (self.avatarImgView.lim_right + 5.0f) - (self.lastMsgTimeLbl.lim_width+5.0f + 20.0f)  - 20.0f;
    if(!self.statusImgView.hidden) {
        titleMaxWidth = titleMaxWidth - (self.statusImgView.lim_width + statusRightSpace);
    }
    [self.titleLbl sizeToFit];
    if(self.titleLbl.lim_width> titleMaxWidth) {
        self.titleLbl.lim_width = titleMaxWidth;
    }
    
    // 最后一条消息
    self.lastContentLbl.lim_left = self.titleLbl.lim_left;
    self.lastContentLbl.lim_width = self.lim_width - self.lastContentLbl.lim_left - 10.0f;
    
    if(self.model.unreadCount>0 || self.model.mute) {
        self.lastContentLbl.lim_width -= 40.0f;
    }
    self.lastContentLbl.lim_top = self.titleLbl.lim_bottom + 3.0f;
    self.lastContentLbl.lim_height = 24.0f;

    // typing
    if(!self.typingIndicatorView.hidden) {
        self.typingIndicatorView.lim_left = self.titleLbl.lim_left;
        self.typingIndicatorView.lim_top = self.titleLbl.lim_bottom + 6.0f;
        
        self.lastContentLbl.lim_left = self.typingIndicatorView.lim_right + 2.0f;
        self.lastContentLbl.lim_width -= self.typingIndicatorView.lim_width;
    }
    
    // 最后一条消息时间
    self.lastMsgTimeLbl.lim_left = self.lim_width - self.lastMsgTimeLbl.lim_width - 15.0f;
    self.lastMsgTimeLbl.lim_top = self.titleLbl.lim_top+2.0f;
    
    // 消息状态
    
    self.statusImgView.lim_left = self.lastMsgTimeLbl.lim_left - self.statusImgView.lim_width - statusRightSpace;
    self.statusImgView.lim_top = self.lastMsgTimeLbl.lim_top+1.0f;
    
    
    // 红点
    self.badgeView.lim_top = self.lastMsgTimeLbl.lim_bottom + 2.0f;
   
    self.badgeView.lim_left = self.lim_width - 15.0f - self.badgeView.lim_width;
    
    // 免打扰图标
    self.muteIcon.lim_left = self.lim_width - self.muteIcon.lim_width - (self.lim_width-self.lastMsgTimeLbl.lim_left-self.lastMsgTimeLbl.lim_width);
    self.muteIcon.lim_top = self.badgeView.lim_top + 4.0f;
    
    self.officialTag.lim_left = self.titleLbl.lim_right+4.0f;
    self.officialTag.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height/2.0f - self.officialTag.lim_height/2.0f);
    if(self.model.channelInfo && [self.model.channelInfo.category isEqualToString:@"visitor"]) {
        self.officialTag.lim_top+=2;
    }
}
-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end

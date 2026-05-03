//
//  WKMessageRevokeCell.m
//  WuKongBase
//
//  Created by tt on 2020/10/16.
//

#import "WKMessageRevokeCell.h"
#import "WuKongBase.h"
#import "WKTipLabel.h"
@interface WKMessageRevokeCell ()
@property(nonatomic,strong) WKTipLabel *tipTextLbl;
@property(nonatomic,strong) WKMessageModel *messageModel;


@property(nonatomic,copy) NSString *tip;

@end

@implementation WKMessageRevokeCell


+ (CGSize)sizeForMessage:(WKMessageModel *)model {
    CGSize contentSize =  [[self class] getTextSize:[self tip:model.message] maxWidth:WKScreenWidth - 20];
    
    CGFloat width = contentSize.width+25.0f;
    if([[self class] canEdit:model]){
        width += 80.0f;
    }
    return CGSizeMake(width, contentSize.height+20.0f);
}


-(void) initUI {
    [super initUI];
    [self setBackgroundColor:[UIColor clearColor]];

    
    self.tipTextLbl = [[WKTipLabel alloc] init];
    [self.tipTextLbl setTextAlignment:NSTextAlignmentCenter];
    [self.tipTextLbl setFont:[UIFont systemFontOfSize:[WKApp shared].config.messageTipTimeFontSize]];
    [self.tipTextLbl setTextColor:[UIColor grayColor]];
    self.tipTextLbl.layer.masksToBounds = YES;
    self.tipTextLbl.layer.cornerRadius = 10.0f;
    self.tipTextLbl.userInteractionEnabled = YES;
    [self.tipTextLbl addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTipClick:)]];
    [self.contentView addSubview:self.tipTextLbl];
    
    
    
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    self.messageModel = model;
    
    self.tipTextLbl.attributedText =[self getTip];
    
    [self.tipTextLbl setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
}


-(void) didTipClick:(UITapGestureRecognizer*)gesture {
    if (![[self class] canEdit:self.messageModel]) return;
    if (self.messageModel.contentType != WK_TEXT) return;

    WKTextContent *textContent = (WKTextContent*)self.messageModel.content;
    if (!textContent.content) return;

    [self.conversationContext inputSetText:textContent.content];
    if(textContent.reply) {
        WKMessage *message = [WKMessageDB.shared getMessageWithMessageId:[textContent.reply.messageID longLongValue]];
        [self.conversationContext replyTo:message];
    }
    [self.conversationContext inputBecomeFirstResponder];
}


-(NSString*) editText {
    return LLang(@"重新编辑");
}


-(NSAttributedString*) getTip {
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:[[self class] tip:self.messageModel.message]];
    
    if([[self class] canEdit:self.messageModel]) {
        NSAttributedString *editStr = [[NSAttributedString alloc] initWithString:[self editText]];
        [attr appendAttributedString:editStr];
        [attr addAttribute:NSForegroundColorAttributeName value:[WKApp shared].config.themeColor range:NSMakeRange(attr.length - editStr.length, editStr.length)];
    }
   
    return attr;
}

+(BOOL) canEdit:(WKMessageModel*)model {
    if([model.fromUid isEqualToString:[WKApp shared].loginInfo.uid] && [[self class] revokerIsSelf:model.message] && model.contentType == WK_TEXT) {
        NSInteger revokeSecond = 2*60;
        if(WKApp.shared.remoteConfig.revokeSecond == -1) {
            return true;
        } else if(WKApp.shared.remoteConfig.revokeSecond > 0) {
            revokeSecond = WKApp.shared.remoteConfig.revokeSecond;
        }
        if([[NSDate date] timeIntervalSince1970] - model.timestamp < revokeSecond) {
            return true;
        }
    }
    return false;
}

+(BOOL) revokerIsSelf:(WKMessage*)message {
    NSString *revoker = message.remoteExtra.revoker;
    if([revoker isEqualToString:[WKApp shared].loginInfo.uid]) {
        return true;
    }
    return false;
}

+ (NSString *)tip:(WKMessage*)message {
    NSString *name = LLang(@"你");
    id revokerRaw = message.remoteExtra.revoker;
    // 防御：服务端可能返回 NSNumber 而非 NSString
    NSString *revoker = nil;
    if ([revokerRaw isKindOfClass:[NSString class]]) {
        revoker = revokerRaw;
    } else if (revokerRaw) {
        revoker = [NSString stringWithFormat:@"%@", revokerRaw];
    }
    if(revoker && [revoker isEqualToString:[WKApp shared].loginInfo.uid]) {
        name = LLang(@"你");
        if(![revoker isEqualToString:message.fromUid]) {
            NSString *memberFromName = @"--";
            if(message.from) {
                memberFromName = message.from.displayName;
            }else {
                [[WKSDK shared].channelManager fetchChannelInfo:[WKChannel personWithChannelID:message.fromUid]];
            }
            return   [NSString stringWithFormat:LLang(@"%@撤回了成员\"%@\"的一条消息"),name,memberFromName];
        }
        return   [NSString stringWithFormat:LLang(@"%@撤回了一条消息"),name];
    }else{
        WKChannel *revokerChannel = [WKChannel personWithChannelID:revoker];
        WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:revokerChannel];
         if(channelInfo) {
             name = channelInfo.displayName;
         }else{
             name = @"--";
             [[WKSDK shared].channelManager fetchChannelInfo:revokerChannel];
         }
        name = [NSString stringWithFormat:@"\"%@\"",name];
        
        if(![revoker isEqualToString:message.fromUid]) {
            return [NSString stringWithFormat:LLang(@"%@撤回了一条成员消息"),name];
        }
      
       
        return   [NSString stringWithFormat:LLang(@"%@撤回了一条消息"),name];
    }
}


- (void)layoutSubviews {
    [super layoutSubviews];
    if(!self.messageModel) {
        return;
    }
    CGSize contentSize = [[self class] sizeForMessage:self.messageModel];
    self.tipTextLbl.lim_size = CGSizeMake(contentSize.width-10.0f, contentSize.height-10.0f);
    self.tipTextLbl.lim_left = self.lim_width/2.0f - self.tipTextLbl.lim_width/2.0f;
    
}

+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth{
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = NSTextAlignmentCenter;
    NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:[WKApp shared].config.messageTipTimeFontSize], NSParagraphStyleAttributeName:style}];
    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    return size;
}

@end

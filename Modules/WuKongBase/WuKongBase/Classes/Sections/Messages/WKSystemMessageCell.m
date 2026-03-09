//
//  WKSystemMessageCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/19.
//

#import "WKSystemMessageCell.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKResource.h"
#import "WKAPIClient.h"
#import "WKNavigationManager.h"
#import "UIView+WKCommon.h"
#import "WKWebViewVC.h"
#import "WuKongBase.h"
#import "WKTipLabel.h"
@interface WKSystemMessageCell ()
@property(nonatomic,strong) UIView *tipTextBoxView;
@property(nonatomic,strong) WKTipLabel *tipTextLbl;
@property(nonatomic,strong) WKMessageModel *messageModel;

@property(nonatomic,strong) UIImageView *inviteIconImgView; // 进群邀请的icon
@property(nonatomic,strong) UIButton *inviteWaitSureBtn; // 邀请待确认
@end

@implementation WKSystemMessageCell

#define WK_SYSTEM_TEXT_SPACE 60.0f

#define WK_INVITE_LEFT_SPACE 15.0f // 群聊邀请确认左边距离
#define WK_INVITE_RIGHT_SPACE 20.0f // 群聊邀请确认右边距离
+ (CGSize)sizeForMessage:(WKMessageModel *)model {
     WKSystemContent *content = (WKSystemContent*)model.content;
     NSString *text = content.displayContent;
    CGSize contentSize = CGSizeMake(0.0f, 0.0f);
    if(text) {
        contentSize =  [[self class] getTextSize:text maxWidth:WKScreenWidth - WK_SYSTEM_TEXT_SPACE];
    }
   
    if(model.contentType == WK_GROUP_MEMBERINVITE) { // 群聊邀请确认
        return CGSizeMake(contentSize.width+20.0f + (WK_INVITE_LEFT_SPACE + WK_INVITE_RIGHT_SPACE), contentSize.height+20.0f);
    }else {
        return CGSizeMake(contentSize.width+20.0f, contentSize.height+20.0f);
    }
    
}

-(void) initUI {
    [super initUI];
  
    [self.contentView addSubview:self.tipTextBoxView];
    [self.tipTextBoxView addSubview:self.tipTextLbl];
    // 进群邀请的icon
    [self.contentView addSubview:self.inviteIconImgView];
    // 进群确认
    [self.contentView addSubview:self.inviteWaitSureBtn];
    
//    [self.contentView setBackgroundColor:[UIColor redColor]];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    self.messageModel = model;
    WKSystemContent *content = (WKSystemContent*)model.content;
    self.tipTextLbl.text = [self getDisplayContent:content.content];
    if(model.contentType == WK_GROUP_MEMBERINVITE) {
        self.inviteIconImgView.hidden = NO;
        self.inviteWaitSureBtn.hidden = NO;
    }else {
        self.inviteIconImgView.hidden = YES;
        self.inviteWaitSureBtn.hidden = YES;
    }
    [self.tipTextBoxView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
}


-(NSString*) getDisplayContent:(NSDictionary*)contentDic {
    if(!contentDic) {
        return LLang(@"未知");
    }
    NSString *content = LLang(contentDic[@"content"]?:@"");
    id extra =contentDic[@"extra"];
    if(extra && [extra isKindOfClass:[NSArray class]]) {
        NSArray *extraArray = (NSArray*)extra;
        if(extraArray.count>0) {
            for (int i=0; i<=extraArray.count-1; i++) {
                NSDictionary *extrDict = extraArray[i];
                NSString *name = extrDict[@"name"]?:@"";
                
                if([[WKSDK shared].options.connectInfo.uid isEqualToString:extrDict[@"uid"]]) {
                    name = LLang(@"你");
                }
                content = [content stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"{%d}",i] withString:name];
            }
        }
        
    }
    return content;
}


- (void)layoutSubviews {
    [super layoutSubviews];
    if(!self.messageModel) {
        return;
    }
    CGSize contentSize = [[self class] sizeForMessage:self.messageModel];
     if(self.messageModel.contentType == WK_GROUP_MEMBERINVITE) {
          self.tipTextBoxView.lim_size = CGSizeMake(contentSize.width-10.0f- WK_INVITE_LEFT_SPACE - WK_INVITE_RIGHT_SPACE, contentSize.height-10.0f);
     }else {
          self.tipTextBoxView.lim_size = CGSizeMake(contentSize.width-10.0f, contentSize.height-10.0f);
     }
   
    self.tipTextBoxView.lim_left = self.lim_width/2.0f - self.tipTextBoxView.lim_width/2.0f;
    
    self.tipTextLbl.lim_size = self.tipTextBoxView.lim_size;
    
    if(self.messageModel.contentType == WK_GROUP_MEMBERINVITE) {
        self.inviteIconImgView.lim_top = self.tipTextBoxView.lim_height/2.0f - self.inviteIconImgView.lim_height/2.0f;
        self.inviteIconImgView.lim_left = self.tipTextBoxView.lim_left - self.inviteIconImgView.lim_width - 5.0f;
        
        self.inviteWaitSureBtn.lim_left = self.tipTextBoxView.lim_right + 5.0f;
        self.inviteWaitSureBtn.lim_top = self.tipTextBoxView.lim_height/2.0f - self.inviteWaitSureBtn.lim_height/2.0f;
    }
    
    
}

- (WKTipLabel *)tipTextLbl {
    if(!_tipTextLbl) {
        _tipTextLbl = [[WKTipLabel alloc] init];
        [_tipTextLbl setTextAlignment:NSTextAlignmentCenter];
        [_tipTextLbl setFont:[UIFont systemFontOfSize:[WKApp shared].config.messageTipTimeFontSize]];
        [_tipTextLbl setTextColor:[UIColor grayColor]];
        [_tipTextLbl setNumberOfLines:0];
        _tipTextLbl.lineBreakMode = NSLineBreakByWordWrapping;

    }
    return _tipTextLbl;
}
- (UIView *)tipTextBoxView {
    if(!_tipTextBoxView) {
        _tipTextBoxView = [[UIView alloc] init];
        _tipTextBoxView.layer.masksToBounds = YES;
        _tipTextBoxView.layer.cornerRadius = 10.0f;
    }
    return _tipTextBoxView;
}

- (UIImageView *)inviteIconImgView {
    if(!_inviteIconImgView) {
        _inviteIconImgView = [[UIImageView alloc] initWithImage:[self imageName:@"Conversation/Messages/IconInvite"]];
    }
    return _inviteIconImgView;
}
- (UIButton *)inviteWaitSureBtn {
    if(!_inviteWaitSureBtn) {
        _inviteWaitSureBtn = [[UIButton alloc] init];
        [_inviteWaitSureBtn setTitle:LLang(@"去确认") forState:UIControlStateNormal];
        [[_inviteWaitSureBtn titleLabel] setFont:[UIFont systemFontOfSize:[WKApp shared].config.messageTipTimeFontSize]];
        [_inviteWaitSureBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [_inviteWaitSureBtn sizeToFit];
        [_inviteWaitSureBtn addTarget:self action:@selector(onInvite) forControlEvents:UIControlEventTouchUpInside];
    }
    return _inviteWaitSureBtn;
}

-(void) onInvite {
    WKSystemContent *systemContent = (WKSystemContent*)[self.messageModel content];
      if(!systemContent.content  || !systemContent.content[@"invite_no"]) {
          [[[WKNavigationManager shared] topViewController].view showMsg:LLang(@"数据错误！")];
          return;
      }
    [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"groups/%@/member/h5confirm?invite_no=%@",self.messageModel.channel.channelId,systemContent.content[@"invite_no"]] parameters:nil].then(^(NSDictionary *resultDic){
        if(resultDic && resultDic[@"url"]) {
            WKWebViewVC *vc = [[WKWebViewVC alloc] init];
            vc.url = [NSURL URLWithString:resultDic[@"url"]];
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
            return;
        }
    }).catch(^(NSError *error){
        [[[WKNavigationManager shared] topViewController].view showMsg:error.domain];
    });
}



+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth{
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = NSTextAlignmentCenter;
   NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:[WKApp shared].config.messageTipTimeFontSize], NSParagraphStyleAttributeName:style}];
    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    return size;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end

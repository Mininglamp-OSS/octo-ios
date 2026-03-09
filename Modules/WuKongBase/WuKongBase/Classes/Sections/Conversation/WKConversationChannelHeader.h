//
//  WKConversationChannelHeader.h
//  WuKongBase
//
//  Created by tt on 2021/8/20.
//

#import <UIKit/UIKit.h>
#import "WuKongBase.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationChannelHeader : UIView


@property(nonatomic,strong) UIButton *voiceCallBtn;

@property(nonatomic,strong) UIButton *videoCallBtn;

@property(nonatomic,assign) NSInteger memberCount; // 成员数量

@property(nonatomic,strong) WKChannelInfo *channelInfo; // 频道信息

@property(nonatomic,copy) void(^onInfo)(void); // 资料信息被点击

@property(nonatomic,copy) void(^onVoiceCall)(void); // 拨打语音
@property(nonatomic,copy) void(^onVideoCall)(void); // 拨打视频

- (void)viewConfigChange:(WKViewConfigChangeType)type;



@end

NS_ASSUME_NONNULL_END

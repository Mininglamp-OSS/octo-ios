//
//  WKForbiddenSpeakTimeSelectVM.h
//  WuKongBase
//
//  Created by tt on 2022/3/25.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@class WKForbiddenSpeakTimeSelectVM;

@protocol WKForbiddenSpeakTimeSelectVMDelegate <NSObject>

// 自定义时间选择
-(void) forbiddenSpeakTimeSelectVMDidCustomTime:(WKForbiddenSpeakTimeSelectVM*)vm;

@end

@interface WKForbiddenSpeakTimeSelectVM : WKBaseTableVM

@property(nonatomic,copy) NSString *uid; // 禁言的用户uid
@property(nonatomic,strong) WKChannel *channel; // 用户所在频道

@property(nonatomic,assign) NSInteger selectSeconds;



@property(nonatomic,weak) id<WKForbiddenSpeakTimeSelectVMDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

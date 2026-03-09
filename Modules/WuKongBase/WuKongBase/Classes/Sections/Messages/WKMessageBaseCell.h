//
//  WKMessageBaseCell.h
//  WuKongBase
//
//  Created by tt on 2019/12/28.
//

#import <UIKit/UIKit.h>
#import "WKMessageModel.h"
#import "WKConstant.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WKConversationContext.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageBaseCell : UITableViewCell

@property(nonatomic,weak) id<WKConversationContext> conversationContext;

@property(nonatomic,strong) WKMessageModel *messageModel;

/**
 自定义消息Cell的Size

 @param model  要显示的消息model
 @return 返回消息的大小
 */
+ (CGSize)sizeForMessage:(WKMessageModel *)model;


/**
 刷新消息

 @param model 消息的model
 */
- (void)refresh:(WKMessageModel *)model;

/**
 消息cell初始化
 */
-(void) initUI;

-(void) onWillDisplay;

-(void) onEndDisplay;

@end

NS_ASSUME_NONNULL_END

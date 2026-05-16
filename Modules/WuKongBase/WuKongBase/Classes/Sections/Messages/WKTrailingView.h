//
//  WKTrailingView.h
//  WuKongBase
//
//  Created by tt on 2021/9/17.
//

#import <UIKit/UIKit.h>
#import "WKMessageModel.h"

// 尾部
#define WKTrailingLeft 20.0f // 最后尾部左边间距
#define WKTimeLeftSpace 2.0f // 时间左边距离
#define WKTimeFontSize 10.0f // 时间字体大小
#define WKTimeHeight 12.0f
#define WKEditTipHeight 10.0f // 编辑提示高度
#define WKEditTipFontSize 9.0f // 编辑提示文字大小
#define WKStatusSize CGSizeMake(12.0f,12.0f)
#define WKSecurityLockSize CGSizeMake(12.0f,12.0f)
#define WKStatusLeft 2.0f // 状态icon左边距离
#define WKSecurityLockRight 2.0f // 安全锁右边距离
#define WKPinnedIconSize CGSizeMake(12.0f,12.0f) // 置顶的icon大小

NS_ASSUME_NONNULL_BEGIN

@class WKMessageCell;

@interface WKTrailingView : UIView

@property(nonatomic,weak) WKMessageCell *messageCell;
// 尾部
@property(nonatomic,strong) UIView *trailingContentView; // 消息尾部视图
@property(nonatomic,strong) UIImageView *statusImgView; // 消息状态
@property(nonatomic,strong) UILabel *timeLbl; // 时间
@property(nonatomic,strong) UIImageView *securityLockImgView; // 安全锁，有此锁说明消息进行了端对端加密
@property(nonatomic,strong) UILabel *editTipLbl; // 编辑提醒

@property(nonatomic,strong) UIImageView *pinnedImgView; // 置顶icon

@property(nonatomic,assign) BOOL tailWrap; // 尾部是否wrap（是否包含背景框）


+(CGSize) size:(WKMessageModel*)message;


-(void) refresh:(WKMessageModel*)messageModel;



/**
 让尾部状态视图包裹起来
 */
-(void) layoutTailWrap;

@end

NS_ASSUME_NONNULL_END

//
//  WKMergeForwardDetailCell.h
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import "WKFormItemCell.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKMergeForwardDetailHeaderView : UIView

- (instancetype)initWithFrame:(CGRect)frame title:(NSString*)title;

@end

//---------- 基础框架cell ----------
@interface WKMergeForwardDetailModel : WKFormItemModel

@property(nonatomic,strong) WKMessage *message;

@property(nonatomic,assign) BOOL hideAvatar; // 隐藏头像


@end

@interface WKMergeForwardDetailCell : WKFormItemCell

+(CGFloat) contentHeightForModel:(WKFormItemModel*)model maxWidth:(CGFloat)maxWidth;

@property(nonatomic,strong) WKMergeForwardDetailModel *model;

@property(nonatomic,strong) UIView *messageContentView;

@end

//---------- 文本cell ----------

@interface WKMergeForwardDetailTextModel : WKMergeForwardDetailModel

@end

@interface WKMergeForwardDetailTextCell : WKMergeForwardDetailCell

@end

//----------图片cell ----------

@interface WKMergeForwardDetailImageModel : WKMergeForwardDetailModel

@end

@interface WKMergeForwardDetailImageCell : WKMergeForwardDetailCell

@end



//----------其他cell ----------

@interface WKMergeForwardDetailOtherModel : WKMergeForwardDetailModel

@end

@interface WKMergeForwardDetailOtherCell : WKMergeForwardDetailCell

@end

NS_ASSUME_NONNULL_END

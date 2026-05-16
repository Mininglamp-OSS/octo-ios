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

// / Web PR#981-982 / Android ChatMultiForwardDetailAdapter 对齐：
// 合并转发详情里每条消息作者的外部群字段（来自父 WKMergeForwardContent.users
// 中匹配 message.fromUid 的条目），用于 viewer-relative 渲染「 @SpaceName」后缀。
// 可读键：is_external / source_space_name / home_space_id / home_space_name。
@property(nonatomic,strong,nullable) NSDictionary *userExtras;


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



//---------- 文件cell ----------

@interface WKMergeForwardDetailFileModel : WKMergeForwardDetailModel

@end

@interface WKMergeForwardDetailFileCell : WKMergeForwardDetailCell

@end

//---------- 语音cell ----------

@interface WKMergeForwardDetailVoiceModel : WKMergeForwardDetailModel

@end

@interface WKMergeForwardDetailVoiceCell : WKMergeForwardDetailCell

@end

//---------- 视频cell ----------

@interface WKMergeForwardDetailVideoModel : WKMergeForwardDetailModel

@end

@interface WKMergeForwardDetailVideoCell : WKMergeForwardDetailCell

@end

//---------- 嵌套合并转发cell ----------

@interface WKMergeForwardDetailNestedModel : WKMergeForwardDetailModel

@end

@interface WKMergeForwardDetailNestedCell : WKMergeForwardDetailCell

@end

//----------其他cell ----------

@interface WKMergeForwardDetailOtherModel : WKMergeForwardDetailModel

@end

@interface WKMergeForwardDetailOtherCell : WKMergeForwardDetailCell

@end

NS_ASSUME_NONNULL_END

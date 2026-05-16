//
//  WKLastImgView.h
//  WuKongBase
//
//  Created by tt on 2020/7/17.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKLastImgView : UIView


/// 图片点击
@property(nonatomic,copy) void(^onClick)(UIImage*image);

// 根据内部逻辑判断是否需要显示
-(void) showIfNeed;


/// 重置最新图片的创建时间（用自己的app拍照发图后需要resetCreateDate下时间。要不然会触发最新图片显示）
-(void) resetCreateDate;


@end

NS_ASSUME_NONNULL_END

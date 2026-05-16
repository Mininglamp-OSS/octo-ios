//
//  WKFormSection.h
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import <Foundation/Foundation.h>
#import "WKFormItemModel.h"
NS_ASSUME_NONNULL_BEGIN
#define WKSectionHeight @(10.0f)
@interface WKFormSection : NSObject

+(instancetype) withItems:(NSArray<WKFormItemModel*>*)items height:(CGFloat)height;

+(instancetype) withItems:(NSArray<WKFormItemModel*>*)items height:(CGFloat)height headView:(UIView* __nullable)headView;

/**
 section下的items
 */
@property(nonatomic,strong) NSArray<WKFormItemModel*> *items;


/**
 头部视图
 */
@property(nonatomic,strong) UIView *headView;


/**
 头部高度
 */
@property(nonatomic,assign) CGFloat height;
// 标题
@property(nonatomic,copy) NSString *title;
//备注
@property(nonatomic,copy) NSString *remark;


@end

NS_ASSUME_NONNULL_END

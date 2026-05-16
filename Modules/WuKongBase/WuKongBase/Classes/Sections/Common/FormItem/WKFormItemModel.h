//
//  WKFormItemModel.h
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKFormItemModel : NSObject



/**
 显示填满的顶部线条
 */
@property(nonatomic,strong) NSNumber *showTopLine;
/**
 显示底部线
 */
@property(nonatomic,strong) NSNumber *showBottomLine;


/**
 底部线左边距离
 */
@property(nonatomic,strong) NSNumber *bottomLeftSpace;


/**
 点击事件
 */
@property(nonatomic,copy) void(^onClick)(WKFormItemModel *model,NSIndexPath *indexPath);


/// 显示箭头
@property(nonatomic,strong) NSNumber *showArrow;
/// cell高度
@property(nonatomic,assign) CGFloat cellHeight;


/**
 对应的cell

 @return <#return value description#>
 */
-(Class) cell;

-(CGFloat) defaultCellHeight;


/**
 扩展数据
 */
@property(nonatomic,strong) id extra;

@end

NS_ASSUME_NONNULL_END

//
//  WKSettingMemberGridView.h
//  WuKongBase
//
//  Created by tt on 2020/1/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@class WKSettingMemberGridView;
@protocol WKSettingMemberGridViewDelegate <NSObject>



/**
 item视图

 @param settingMemberGridView <#settingMemberGridView description#>
 @param size <#size description#>
 @return <#return value description#>
 */
-(UIView*) settingMemberGridView:(WKSettingMemberGridView*)settingMemberGridView size:(CGSize)size atIndex:(NSInteger)index;


/**
 item被点击

 @param settingMemberGridView <#settingMemberGridView description#>
 @param index item下标
 */
-(void) settingMemberGridView:(WKSettingMemberGridView*)settingMemberGridView didSelect:(NSInteger)index;

/**
 item数量

 @param settingMemberGridView <#settingMemberGridView description#>
 @return <#return value description#>
 */
-(NSInteger) numberOfSettingMemberGridView:(WKSettingMemberGridView*)settingMemberGridView;

@end

@interface WKSettingMemberGridView : UIView

+(instancetype) initWithMaxWidth:(CGFloat) maxWidth numberOfLine:(NSInteger)number;
+(instancetype) initWithMaxWidth:(CGFloat) maxWidth numberOfLine:(NSInteger)number hasMore:(BOOL)hasMore;
@property(nonatomic,assign) BOOL hasMore; // 是否有更多
@property(nonatomic,weak) id<WKSettingMemberGridViewDelegate> delegate;

// 更多点击
@property(nonatomic,copy) void(^onMore)(void);

-(void) reloadData;

/**
 当前视图高度

 @return <#return value description#>
 */
-(CGFloat) viewHeight;

@end

NS_ASSUME_NONNULL_END

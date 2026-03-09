//
//  WKRobotMenusListView.h
//  WuKongBase
//
//  Created by tt on 2021/10/18.
//

#import "WKDragModalView.h"
@class WKRobotMenusItem;

NS_ASSUME_NONNULL_BEGIN

@interface WKRobotMenusItemCell : UITableViewCell

-(void) refresh:(WKRobotMenusItem*)item;

@end

@interface WKRobotMenusItem : NSObject

@property(nonatomic,copy) NSString *cmd;
@property(nonatomic,copy) NSString *iconURL;
@property(nonatomic,copy) NSString *remark;
@property(nonatomic,copy) void(^onClick)(void);

+(WKRobotMenusItem*) cmd:(NSString*)cmd iconURL:(NSString*)iconURL remark:(NSString*)remark onClick:(void(^)(void)) onClick;

@end

@interface WKRobotMenusListView : WKDragModalView

+(instancetype) initItems:(NSArray<WKRobotMenusItem*>*)items;

@end

NS_ASSUME_NONNULL_END

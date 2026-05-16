//
//  WKAPMManager.h
//  WuKongBase
//
//  Created by tt on 2022/5/6.
//

#import <Foundation/Foundation.h>
#import "WKFuncGroupEditItemModel.h"
@class WKAPMManager;
NS_ASSUME_NONNULL_BEGIN

@interface WKAPMSortInfo : NSObject // apm应用排序信息
@property(nonatomic,copy) NSString *apmID;
@property(nonatomic,assign) NSInteger sort;
@property(nonatomic,assign) BOOL disable;
@property(nonatomic,assign) WKFuncGroupEditItemType type; // 区域 0. 个人收藏 1.更多app

@end

@protocol WKAPMManagerDelegate <NSObject>

@optional

-(void) apmManagerSortInfoChange:(WKAPMManager*)manager; // 排序信息发生改变

@end

@interface WKAPMManager : NSObject

@property(nonatomic,strong) NSArray<WKAPMSortInfo*> *apmSorts;

+ (WKAPMManager *)shared;


-(void) saveAPMSorts;

-(void) addDelegate:(id<WKAPMManagerDelegate>) delegate;

-(void) removeDelegate:(id<WKAPMManagerDelegate>) delegate;

@end

NS_ASSUME_NONNULL_END

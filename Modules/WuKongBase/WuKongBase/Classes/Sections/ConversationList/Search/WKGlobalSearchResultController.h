//
//  WKGlobalSearchResultController.h
//  WuKongBase
//
//  Created by tt on 2020/4/24.
//

#import "WKBaseTableVC.h"
#import "WKGlobalSearchController.h"
NS_ASSUME_NONNULL_BEGIN



@interface WKGlobalSearchResultController : WKBaseTableVC

@property(nonatomic,assign) WKHistoryMessageSearchType searchType;

@property(nonatomic,copy) NSString *keyword; // 默认关键字

@property(nonatomic,strong) WKChannel *channel;

@end

NS_ASSUME_NONNULL_END

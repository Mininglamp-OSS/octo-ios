//
//  WKGlobalSearchVM.h
//  WuKongBase
//
//  Created by tt on 2020/4/24.
//

#import "WKBaseTableVM.h"
#import "WKFormSection.h"
#import "WKConstant.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKGlobalSearchVM : WKBaseTableVM

@property(nonatomic,assign) WKHistoryMessageSearchType searchType;
@property(nonatomic,copy) NSString *keyword;
@property(nonatomic,strong) WKChannel *channel; // 查询指定频道内的消息

-(void) changeKeyword:(NSString*)keyword;

// 改变tabType，值：all,contacts,group,file
-(void) changeTabType:(NSString*)type;

// 是否在频道内搜索
-(BOOL) searchInChannel;

@end

NS_ASSUME_NONNULL_END

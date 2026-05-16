//
//  WKContactsFriendRequestCell.h
//  WuKongContacts
//
//  Created by tt on 2020/1/5.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKContactsFriendRequestCell : WKCell

@property(nonatomic,assign) BOOL last;
@property(nonatomic,assign) BOOL first;

-(void)refresh:(WKFriendRequestDBModel*)model;


/**
 确认通过好友
 */
@property(nonatomic,copy) void(^onPass)(WKFriendRequestDBModel*model);

@end

NS_ASSUME_NONNULL_END

//
//  WKContactsFriendCell.h
//  WuKongContacts
//
//  Created by tt on 2021/9/22.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@class WKContactsFriendCell;
@class WKContactsFriendModel;

@protocol WKContactsFriendCellDelegate <NSObject>

@optional

-(void) contactsFriendCell:(WKContactsFriendCell*)cell action:(WKContactsFriendModel*)model;

@end

@interface WKContactsFriendModel : WKContactsSelect

@property(nonatomic,copy) NSString *phone;
@property(nonatomic,copy) NSString *vercode;
@property(nonatomic,assign) BOOL isFriend;
@end

@interface WKContactsFriendCell : WKContactsSelectCell

@property(nonatomic,weak) id<WKContactsFriendCellDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

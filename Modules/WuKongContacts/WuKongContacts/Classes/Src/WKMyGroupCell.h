//
//  WKMyGroupCell.h
//  WuKongContacts
//
//  Created by tt on 2020/7/16.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKMyGroupModel : WKFormItemModel
@property(nonatomic,copy) NSString *groupNo;
@property(nonatomic,copy) NSString *name;
@end

@interface WKMyGroupCell : WKFormItemCell

@end


NS_ASSUME_NONNULL_END

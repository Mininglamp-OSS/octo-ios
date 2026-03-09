//
//  WKMoreItem.h
//  WuKongBase
//
//  Created by tt on 2020/1/12.
//

#import <UIKit/UIKit.h>
#import "WKConversationContext.h"
#import "WKMoreItemModel.h"
#import "WKPanel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMoreItemCell : UICollectionViewCell

@property(nonatomic,weak) id<WKConversationContext> conversatonContext;


+(NSString *)reuseIdentifier;

-(void) refresh:(WKMoreItemModel*)model;

@end

NS_ASSUME_NONNULL_END

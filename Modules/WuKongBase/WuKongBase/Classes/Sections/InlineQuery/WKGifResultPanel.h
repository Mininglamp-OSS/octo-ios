//
//  WKGifResultPanel.h
//  WuKongBase
//
//  Created by tt on 2021/11/9.
//

#import <UIKit/UIKit.h>
#import "WKResultPanel.h"
#import "WKInlineQueryResult.h"
#import "WuKongBase.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKGifResultPanel : WKResultPanel

+(instancetype) result:(WKInlineQueryResult*)result context:(id<WKConversationContext>)context;

@end

@interface WKGifResultCell : UICollectionViewCell

-(void) refresh:(WKGifResult*)result;

@end

NS_ASSUME_NONNULL_END

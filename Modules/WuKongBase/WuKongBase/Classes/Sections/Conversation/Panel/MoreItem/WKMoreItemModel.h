//
//  WKMoreItemModel.h
//  WuKongBase
//
//  Created by tt on 2020/1/12.
//

#import <Foundation/Foundation.h>
#import "WKPanel.h"
#import "WKConversationContext.h"
NS_ASSUME_NONNULL_BEGIN

typedef void(^onClickBlock)(id<WKConversationContext>  conversationContext);

@interface WKMoreItemModel : NSObject

@property(nonatomic,copy) onClickBlock oncClickBLock;
@property(nonatomic,strong) UIImage *image;
@property(nonatomic,copy) NSString *title;

+(WKMoreItemModel*) initWithImage:(UIImage*)image title:(NSString*)title onClick:(onClickBlock)onClickBlock;

+(Class) moreItemCellClass;

@end

NS_ASSUME_NONNULL_END

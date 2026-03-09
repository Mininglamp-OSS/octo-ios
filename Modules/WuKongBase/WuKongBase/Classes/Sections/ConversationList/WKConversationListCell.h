//
//  WKConversationListCell.h
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import <Foundation/Foundation.h>
#import "WKConversationWrapModel.h"
#import "SwipeTableCell.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKConversationListCell : SwipeTableCell

-(void) refreshWithModel:(WKConversationWrapModel*)model;
@end

NS_ASSUME_NONNULL_END

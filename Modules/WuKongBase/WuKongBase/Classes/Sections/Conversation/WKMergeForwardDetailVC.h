//
//  WKMergeForwardDetailVC.h
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import "WKMergeForwardDetailVM.h"
#import "WKBaseTableVC.h"
#import "WKMergeForwardContent.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMergeForwardDetailVC : WKBaseTableVC<WKMergeForwardDetailVM*>

@property(nonatomic,strong)  WKMergeForwardContent *mergeForwardContent;

@end

NS_ASSUME_NONNULL_END

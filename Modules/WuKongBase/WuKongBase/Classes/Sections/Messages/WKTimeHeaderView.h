//
//  WKTimeHeaderView.h
//  WuKongBase
//
//  Created by tt on 2021/7/26.
//

#import <UIKit/UIKit.h>
#import "WuKongBase.h"
#import "WKTipLabel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKTimeHeaderView : UITableViewHeaderFooterView
@property(nonatomic,strong) WKTipLabel *dateLbl;

+(CGFloat) height;

+(NSString*) reuseId;

@end

NS_ASSUME_NONNULL_END

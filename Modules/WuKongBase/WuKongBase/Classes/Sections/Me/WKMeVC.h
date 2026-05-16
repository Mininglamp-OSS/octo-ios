//
//  WKMeVC2.h
//  WuKongBase
//
//  Created by tt on 2020/6/9.
//

#import <WuKongBase/WuKongBase.h>
#import "WKMeVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMeVC : WKBaseTableVC<WKMeVM*>

@end

@interface WKeHeader : UIView
-(void) reloadData;
@end


NS_ASSUME_NONNULL_END

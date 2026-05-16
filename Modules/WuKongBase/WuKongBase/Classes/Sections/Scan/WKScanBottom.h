//
//  WKScanBottom.h
//  WuKongBase
//
//  Created by tt on 2022/11/1.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKScanBottom : UIView

@property(nonatomic,copy) void(^onAlbum)(void);
@property(nonatomic,copy) void(^onOpenLight)(BOOL on);
@property(nonatomic,copy) void(^onMyQRCode)(void);

@end

NS_ASSUME_NONNULL_END

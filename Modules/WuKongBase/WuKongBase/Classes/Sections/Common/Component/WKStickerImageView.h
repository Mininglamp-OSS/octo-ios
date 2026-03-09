//
//  WKStickerImageView.h
//  WuKongBase
//
//  Created by tt on 2022/5/15.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKStickerImageView : UIView


@property(nonatomic,copy) NSString *placehoderSvg; // 占位的svg图内容

@property(nonatomic,copy) NSURL *stickerURL;

@property(nonatomic,assign) BOOL isPlay; // 是否播放

@end

NS_ASSUME_NONNULL_END

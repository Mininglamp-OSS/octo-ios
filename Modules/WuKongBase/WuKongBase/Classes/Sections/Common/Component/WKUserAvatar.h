//
//  WKUserAvatar.h
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import <UIKit/UIKit.h>
#import "WKImageView.h"

#define WKDefaultAvatarSize CGSizeMake(50.0f,50.0f)

NS_ASSUME_NONNULL_BEGIN

@interface WKUserAvatar : UIView

@property(nonatomic,copy) NSString *url;

// 跳过所有缓存，直接从服务器下载最新头像（打开详情页时调用）
-(void) refreshUrlFromServer:(NSString*)url;

@property(nonatomic,copy) NSString *uid;

@property(nonatomic,assign) CGFloat borderWidth;

@property(nonatomic,strong) WKImageView *avatarImgView;


@end

NS_ASSUME_NONNULL_END

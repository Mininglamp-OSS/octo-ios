//
//  WKGIFContent.h
//  WuKongBase
//
//  Created by tt on 2020/2/2.
//

#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKGIFContent : WKMessageContent
//GIF的地址
@property(nonatomic,copy) NSString *url;
// 宽度
@property(nonatomic,assign) NSInteger width;
// 高度
@property(nonatomic,assign) NSInteger height;


/**
 初始化

 @param url gif的url地址
 @param width gif宽度
 @param height gif高度
 @return <#return value description#>
 */
+(instancetype) initWithURL:(NSString*)url width:(NSInteger)width height:(NSInteger)height;

@end

NS_ASSUME_NONNULL_END

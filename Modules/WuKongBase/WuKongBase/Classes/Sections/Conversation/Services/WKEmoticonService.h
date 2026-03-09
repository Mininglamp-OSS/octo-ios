//
//  WKEmoticonService.h
//  WuKongBase
//
//  Created by tt on 2020/1/10.
//

#import <Foundation/Foundation.h>
#import "WKMatchToken.h"
NS_ASSUME_NONNULL_BEGIN



@protocol WKPEmotion<NSObject>

@property (copy, nonatomic) NSString *faceId; // 表情唯一ID
@property (copy, nonatomic) NSString *faceName; // 表情名称
@property (copy, nonatomic) NSString *faceImageName; // 表情图片名称
@property (copy, nonatomic) NSNumber *faceRank; // 表情排行

@end

@interface WKEmotion : NSObject <WKPEmotion>

@end


@interface WKEmoticonService : NSObject

+ (WKEmoticonService *)shared;

/**
 替换字符串的表情占位符
 
 @param str 需要替换的字符串
 @return 返回替换好的字符串
 */
-(NSArray<id<WKMatchToken>>*)parseEmotion:(NSString *)str;


/**
 通过表情名称获取表情对象
 
 @param faceName <#faceName description#>
 @return <#return value description#>
 */
-(id<WKPEmotion>) emotionByFaceName:(NSString*)faceName;


/**
 通过名字获取image图片
 
 @param imageName 图片名字
 @return <#return value description#>
 */
-(UIImage*) emojiImageNamed:(NSString*)imageName;



/**
 表情数组
 
 @return <#return value description#>
 */
-(NSArray<id<WKPEmotion>>*) emotions;

-(NSArray<id<WKPEmotion>>*) recentEmotions;

-(BOOL) recentEmoji:(id<WKPEmotion>)emotion;

@end

NS_ASSUME_NONNULL_END

//
//  WKResource.h
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKResource : NSObject

+ (WKResource *)shared;


/**
 获取pod的图片资源

 @param imageName 图片名
 @param podName pod名字
 @return <#return value description#>
 */
//- (UIImage*) resourceForImage:(NSString*)imageName podName:(NSString*)podName;

- (NSBundle*) resourceBundleInClass:(Class)cls;

-(NSBundle*) imageBundleInClass:(Class)cls;

// 获取图片
-(UIImage*) imageNamed:(NSString*)name inClass:(Class)cls;

-(UIImage*) imageNamed:(NSString*)name inBundle:(NSBundle*)bundle;


@end

NS_ASSUME_NONNULL_END

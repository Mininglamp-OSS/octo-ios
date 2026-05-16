//
//  WKResource.m
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import "WKResource.h"
#import "WKApp.h"
@implementation WKResource


static WKResource *_instance;


+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKResource *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        
    });
    return _instance;
}

- (NSURL *)module_bundleUrl:(NSString*)podName  cls:(Class) cls {
    NSBundle *bundle = [NSBundle bundleForClass:cls];
    NSURL *url = [bundle URLForResource:podName withExtension:@"bundle"];
    return url;
}

- (UIImage*) resourceForImage:(NSString*)imageName podName:(NSString*)podName {
    
    NSURL *imageUrl =  [self module_bundleUrl:podName cls:[self class]];
    
    return  [self at_imageNamed:imageName inBundle:[NSBundle bundleWithURL:imageUrl]];
}

-(UIImage*) imageNamed:(NSString*)name inClass:(Class)cls {
    
    return [self at_imageNamed:name inBundle:[self imageBundleInClass:cls]];
}

-(UIImage*) imageNamed:(NSString*)name inBundle:(NSBundle*)bundle {
    return [self at_imageNamed:name inBundle:bundle];
}

- (NSBundle*) resourceBundleInClass:(Class)cls {
    NSBundle *bundle = [NSBundle bundleForClass:cls];
    NSString *moduleName = bundle.infoDictionary[@"CFBundleExecutable"];
    NSURL *url = [bundle URLForResource:[NSString stringWithFormat:@"%@_resources",moduleName] withExtension:@"bundle"];
    if(!url) {
        return nil;
    }
    return [NSBundle bundleWithURL:url];
}

-(NSBundle*) imageBundleInClass:(Class)cls {
    NSBundle *bundle = [NSBundle bundleForClass:cls];
    NSString *moduleName = bundle.infoDictionary[@"CFBundleExecutable"];
    NSURL *url = [bundle URLForResource:[NSString stringWithFormat:@"%@_images",moduleName] withExtension:@"bundle"];
    if(!url) {
        return nil;
    }
    return [NSBundle bundleWithURL:url];
}


- (UIImage *)at_imageNamed:(NSString *)name inBundle:(NSBundle *)bundle  {
    UITraitCollection *trait;
    NSString *mode = [WKApp shared].loginInfo.extra[@"systemStyle"];
     if(mode && [mode isEqualToString:@"dark"]) {
         if (@available(iOS 12.0, *)) {
             trait = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark];
         }
     }else{
         if (@available(iOS 12.0, *)) {
             trait = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight];
         }
        
     }
    return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:trait];
//    if (@available(iOS 13.0, *)) {
//
//        return  [UIImage imageNamed:name inBundle:bundle withConfiguration:[[UIImageConfiguration alloc] configurationWithTraitCollection:UITraitCollection.currentTraitCollection]];
//    } else {
//        // Fallback on earlier versions
//        return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
//    }
//#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
//    return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
//#elif __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_8_0
//    return [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
//#else
//    if ([UIImage respondsToSelector:@selector(imageNamed:inBundle:compatibleWithTraitCollection:)]) {
//        return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
//    } else {
//        return [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
//    }
//#endif
}

@end

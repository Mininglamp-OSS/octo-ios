//
//  WKBaseModule.m
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import "WKBaseModule.h"
#import "WKResource.h"
#import "WKApp.h"
#import "WKResource.h"
#import "WKModuleManager.h"
#import <WuKongBase/WuKongBase-Swift.h>
@implementation WKBaseModule


+ (NSString *)globalID {
    return @"";
}

- (WKModuleType)moduleType {
    return WKModuleTypeDefault;
}

- (NSInteger)moduleSort {
    return 0;
}

- (UIImage*) ImageForResource:(NSString*)name{
    UIImage *img;
    NSArray<id<WKModuleProtocol>> *resourceModules = [WKSwiftModuleManager.shared getResourceModules];
    if(resourceModules && resourceModules.count>0) {
        resourceModules = resourceModules.reverseObjectEnumerator.allObjects;
        for (id<WKModuleProtocol> module in resourceModules) {
            img =   [WKResource.shared imageNamed:[[self moduleId] stringByAppendingPathComponent:name] inBundle:[module imageBundle]];
            if(img) {
                return img;
            }
        }
    }
    
    img =   [WKResource.shared imageNamed:name inBundle:[self imageBundle]];
    if(img) {
        return img;
    }
    
    
    return nil;
}

-(NSDictionary*) LangResource:(NSString*)lang{
    NSString *langFileName = lang;
    if ([lang isEqualToString:@"zh-Hans-CN"]) {
        langFileName = @"zh-Hans";
    }
    NSString *langUrl = [self pathForResource:[NSString stringWithFormat:@"lang/%@.lproj/Localized",langFileName] ofType:@"strings"];
    NSDictionary *langDic = [[NSDictionary alloc] initWithContentsOfFile:langUrl];
    return langDic;
}

- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext{
    return [[self resourceBundle] pathForResource:name ofType:ext];
}
- (NSBundle*) resourceBundle{
    NSBundle *bundle = [WKResource.shared resourceBundleInClass:self.class];
    if(bundle) {
        return bundle;
    }
    bundle = [NSBundle bundleForClass:self.class];
    NSURL *url = [bundle URLForResource:[NSString stringWithFormat:@"%@_resources",[self moduleId]] withExtension:@"bundle"];
    return [NSBundle bundleWithURL:url];
}

- (NSBundle*) imageBundle{
    NSBundle *bundle = [WKResource.shared imageBundleInClass:self.class];
    if(bundle) {
        return bundle;
    }
    bundle = [NSBundle bundleForClass:self.class];
    NSURL *url = [bundle URLForResource:[NSString stringWithFormat:@"%@_images",[self moduleId]] withExtension:@"bundle"];
    if(url) {
        return [NSBundle bundleWithURL:url];
    }
    
    return nil;
}

-(NSString*) moduleId{
    
    return [self.class globalID];
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
}

-(void) setMethod:(NSString*)sid handler:(id) handler category:(NSString*)category {
    WKEndpoint *endpoint = [WKEndpoint initWithSid:sid handler:handler category:category];
    endpoint.moduleID = [self moduleId];
    [self registerEndpoint:endpoint];
}

-(void) setMethod:(NSString*)sid handler:(id) handler category:(NSString* __nullable)category sort:(int)sort {
    WKEndpoint *endpoint = [WKEndpoint initWithSid:sid handler:handler category:category sort:@(sort)];
    endpoint.moduleID = [self moduleId];
     [self registerEndpoint:endpoint];
}

-(void) setMethod:(NSString*)sid handler:(id) handler {
    [self setMethod:sid handler:handler category:nil];
}

-(void) registerEndpoint:(WKEndpoint*)endpoint {
    
    [WKApp.shared.endpointManager registerEndpoint:endpoint];
}

@end

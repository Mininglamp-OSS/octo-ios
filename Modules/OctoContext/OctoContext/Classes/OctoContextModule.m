//
//  OctoContextModule.m
//  OctoContext
//

#import "OctoContextModule.h"

@WKModule(OctoContextModule)

@implementation OctoContextModule

- (NSString *)moduleId {
    return @"OctoContext";
}

- (void)moduleInit:(WKModuleContext *)context {
    NSLog(@"【OctoContext】模块初始化");
}

@end

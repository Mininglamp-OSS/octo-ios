//
//  WKOfficialTag.m
//  WuKongBase
//
//  Created by tt on 2020/9/15.
//

#import "WKOfficialTag.h"
#import "WKApp.h"
@implementation WKOfficialTag

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.frame = CGRectMake(0.0f, 0.0f, 18.0f, 18.0f);
    }
    return self;
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end

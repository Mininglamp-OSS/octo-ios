//
//  ACRSVGImageView.m
//  AdaptiveCards
//
//  Created by Abhishek on 26/04/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACRSVGImageView.h"
#import "ACRErrors.h"
#import "Icon.h"
#import "UtiliOS.h"
// [octo] 去除 SVGKit 依赖（其与本仓库 librlottie 存在 header-map 冲突，且 octo 卡片
// 白名单无 Icon 元素、Image 均为 http(s) 栅格图）。SVG 图标栅格化在 prepareImage:
// 里 no-op 兜底（不显示图标），保留类接口不变以满足其它 renderer 的链接需求。
// 回退到原实现：恢复下方 #import <SVGKit/SVGKit.h> 与 prepareImage: 中的 SVGK 分支，
// 并在 AdaptiveCards.podspec 恢复 `sspec.dependency 'SVGKit'`。

@implementation ACRSVGImageView {
    NSString *_svgPayloadURL;
    ACRRtl _rtl;
    BOOL _isFilled;
}

- (instancetype)init:(NSString *)iconURL
                 rtl:(ACRRtl)rtl
            isFilled:(BOOL)isFilled
                size:(CGSize)size
           tintColor:(UIColor *)tintColor
{
    self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    if (self) {
        _svgPayloadURL = iconURL;
        self.size = size;
        _rtl = rtl;
        _isFilled = isFilled;
        self.svgTintColor = tintColor;
        [self loadIconFromCDN];
    }
    return self;
}

- (void)loadIconFromCDN
{
    __weak ACRSVGImageView *weakSelf = self;
    [ACRSVGImageView requestIcon:_svgPayloadURL
                             filled:_isFilled
                               size:_size
                                rtl:_rtl
                      completion:^(UIImage *image) {
        ACRSVGImageView *strongSelf = weakSelf;
        strongSelf.contentMode = UIViewContentModeScaleAspectFit;
        strongSelf.tintColor = strongSelf.svgTintColor;
        strongSelf.image = image;
        if (strongSelf.svgImage) {
            strongSelf.image = strongSelf.svgImage;
        }
    }];
}

+ (void)requestIcon:(NSString *)iconURL
             filled:(BOOL)filled
               size:(CGSize)size
                rtl:(ACRRtl)rtl
         completion:(void (^)(UIImage *))completion
{
    NSURL *url = [[NSURL alloc] initWithString:iconURL];
    [ACRSVGImageView requestIconFromCDN:url
                             completion:^(NSDictionary *_Nullable dict, __unused NSError *_Nullable error) {
                                 if (dict != nil) {
                                     BOOL success = [ACRSVGImageView prepareImage:dict
                                                                           filled:filled
                                                                             size:size
                                                                              rtl:rtl
                                                                       completion:completion];
                                     if (success) {
                                         return;
                                     }
                                 }

                                 // If we reach this point, we failed to load the icon from CDN.
                                 // Show fallback.
                                 [ACRSVGImageView requestFallbackWithSize:(CGSize)size
                                                                      rtl:(ACRRtl)rtl
                                                               completion:completion];
                             }];
}

+ (void)requestFallbackWithSize:(CGSize)size
                            rtl:(ACRRtl)rtl
                     completion:(void (^)(UIImage *))completion
{
    NSString *fallbackURLName = @"Square";
    NSString *fallBackURLString = [[NSString alloc] initWithFormat:@"%@%@/%@.json", baseFluentIconCDNURL, fallbackURLName, fallbackURLName];
    NSURL *svgURL = [[NSURL alloc] initWithString:fallBackURLString];
    [ACRSVGImageView requestIconFromCDN:svgURL
                             completion:^(NSDictionary *_Nullable dict, __unused NSError *_Nullable error) {
                                 if (dict != nil) {
                                     [ACRSVGImageView prepareImage:dict
                                                            filled:YES
                                                              size:size
                                                               rtl:rtl
                                                        completion:completion];
                                 }
                             }];
}

+ (void)requestIconFromCDN:(NSURL *)url
                completion:(void (^)(NSDictionary *_Nullable object, NSError *_Nullable error))completion
{
    if (url) {
        NSURLSessionDataTask *iconDataTask = [[NSURLSession sharedSession]
              dataTaskWithURL:url
            completionHandler:^(NSData *_Nullable data,
                                NSURLResponse *_Nullable response,
                                NSError *_Nullable error) {
                NSInteger status = 200;
                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    status = ((NSHTTPURLResponse *)response).statusCode;
                }
                if (!error && status == 200) {
                    NSError *err;
                    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                                         options:NSJSONReadingMutableContainers
                                                                           error:&err];
                    if (err) {
                        completion(nil, err);
                    } else {
                        completion(dict, nil);
                    }
                } else {
                    completion(nil, error);
                }
            }];
        [iconDataTask resume];
    } else {
        NSError *error = [NSError errorWithDomain:ACRParseErrorDomain
                                             code:ACRInputErrorValueMissing
                                         userInfo:nil];
        completion(nil, error);
    }
}

+ (NSString *)svgXMLPayloadFrom:(NSString *)path size:(CGSize)size viewPort:(CGFloat)viewPort
{
    return [[NSString alloc] initWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%f\" height=\"%f\" viewBox=\"0 0 %f %f\"><path d=\"%@\"/></svg>", size.width, size.height, viewPort, viewPort, path];
}

+ (BOOL)prepareImage:(NSDictionary *)svgData
              filled:(BOOL)filled
                size:(CGSize)size
                 rtl:(ACRRtl)rtl
          completion:(void (^)(UIImage *))completion
{
    NSString *iconFilledStyleKey = filled ? @"filled" : @"regular";
    NSDictionary *iconDict = svgData[iconFilledStyleKey];
    if (iconDict) {
        // exact size for icon may not be available, try to find closest size of icon which is available
        NSString *targetKey = [ACRSVGImageView findClosestIconSizeInArray:[iconDict allKeys] toTarget:@(size.height)];
        CGFloat viewPort = [targetKey doubleValue];
        NSArray<NSString *> *pathArray = iconDict[targetKey];
        if (pathArray != nil) {
            // [octo] SVGKit 已移除：不做 SVG 栅格化，回调 nil（不显示 Fluent 图标）。
            // octo 卡片白名单无 Icon 元素，此路径实际不会被展示型卡片触发。
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
            return YES;
        }
    }
    return NO;
}

+ (NSString *)findClosestIconSizeInArray:(NSArray<NSString *> *)numbers toTarget:(NSNumber *)targetNumber
{
    if (numbers.count == 0) {
        return nil;
    }

    NSString *closestNumberString = numbers[0];
    NSNumber *closestNumber = @([closestNumberString doubleValue]);
    double closestDifference = fabs([closestNumber doubleValue] - [targetNumber doubleValue]);

    for (NSString *numberString in numbers) {
        NSNumber *number = @([numberString doubleValue]);
        double currentDifference = fabs([number doubleValue] - [targetNumber doubleValue]);
        if (currentDifference < closestDifference) {
            closestDifference = currentDifference;
            closestNumberString = numberString;
        }
    }
    return closestNumberString;
}

@end

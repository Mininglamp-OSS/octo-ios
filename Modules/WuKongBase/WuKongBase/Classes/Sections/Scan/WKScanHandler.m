//
//  WKScanHandler.m
//  WuKongBase
//
//  Created by tt on 2020/4/3.
//

#import "WKScanHandler.h"

@implementation WKScanResult

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKScanResult *result = [WKScanResult new];
    result.forward = dictory[@"forward"];
    result.type = dictory[@"type"];
    result.data = dictory[@"data"];
    return result;
}

@end

@interface WKScanHandler ()

@property(nonatomic,copy) BOOL(^scanHandleCallback)(WKScanResult *result,void(^reScanBlock)(void));


@end

@implementation WKScanHandler

+(WKScanHandler*) handle:(BOOL(^)(WKScanResult *result,void(^reScanBlock)(void)))callback{
    WKScanHandler *handler = [WKScanHandler new];
    handler.scanHandleCallback = callback;
    return handler;
}

-(BOOL) handle:(WKScanResult*)result reScan:(void(^)(void))reScanBlock {
    if(self.scanHandleCallback) {
        return self.scanHandleCallback(result,reScanBlock);
    }
    return false;
}
@end

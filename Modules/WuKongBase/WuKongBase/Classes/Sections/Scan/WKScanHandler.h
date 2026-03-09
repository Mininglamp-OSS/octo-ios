//
//  WKScanHandler.h
//  WuKongBase
//
//  Created by tt on 2020/4/3.
//

#import <Foundation/Foundation.h>
#import "WKModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKScanResult : WKModel

@property(nonatomic,copy) NSString *forward; // 扫码类型

@property(nonatomic,copy) NSString *type; // 扫码类型

@property(nonatomic,strong) NSDictionary *data; // 扫码数据

@end

@interface WKScanHandler : NSObject

+(WKScanHandler*) handle:(BOOL(^)(WKScanResult *result,void(^reScanBlock)(void)))callback;

-(BOOL) handle:(WKScanResult*)result reScan:(void(^)(void))reScanBlock;

@end

NS_ASSUME_NONNULL_END

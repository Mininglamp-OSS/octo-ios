//
//  WKZXingWrapper.m
//  WuKongBase
//
//  Created by tt on 2022/4/8.
//

#import "WKZXingWrapper.h"

@implementation WKZXingWrapper

+ (void)recognizeImage:(UIImage*)image block:(void(^)(ZXBarcodeFormat barcodeFormat,NSString *str))block {
    
    [ZXingWrapper recognizeImage:image block:^(ZXBarcodeFormat barcodeFormat, NSString *str) {
        if(!str) {
            //系统自带识别方法
            CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
            NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
            if (features.count >=1)
            {
                CIQRCodeFeature *feature = [features objectAtIndex:0];
                NSString *scanResult = feature.messageString;
                if (block) {
                    block(kBarcodeFormatQRCode,scanResult);
                }
            }else{
                if (block) {
                    block(kBarcodeFormatQRCode,nil);
                }
            }
            return;
        }
        if(block) {
            block(barcodeFormat,str);
        }
    }];
}

@end

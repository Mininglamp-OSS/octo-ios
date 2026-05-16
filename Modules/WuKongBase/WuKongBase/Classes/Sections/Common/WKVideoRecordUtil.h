//
//  WKVideoRecordUtil.h
//  WuKongBase
//
//  Created by tt on 2020/11/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKVideoRecordUtil : NSObject


/// 录视频
+(void) videoRecord:(void(^)(NSString *coverPath,NSString *videoPath))callback imgCallback:(void(^)(UIImage*img))imgCallback;
+(void) videoRecord:(void(^)(NSString *coverPath,NSString *videoPath))callback;

@end

NS_ASSUME_NONNULL_END

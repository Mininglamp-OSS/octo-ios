//
//  WKMoreItemClickEvent.h
//  WuKongBase
//
//  Created by tt on 2020/1/12.
//

#import <Foundation/Foundation.h>
#import "WKPanel.h"
#import "WKConversationContext.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMoreItemClickEvent : NSObject

+ (WKMoreItemClickEvent *)shared;
/**
  图片
 */
-(void) onPhotoItemPressed:(id<WKConversationContext>)context;


/**
 拍照
 */
-(void) onCameraIPressed:(id<WKConversationContext>)context;

@end

NS_ASSUME_NONNULL_END

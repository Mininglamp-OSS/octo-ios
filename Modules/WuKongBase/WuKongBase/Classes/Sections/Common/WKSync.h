//
//  WKSync.h
//  WuKongBase
//
//  Created by tt on 2019/12/7.
//

#ifndef WKSync_h
#define WKSync_h


#endif /* WKSync_h */

#import <Foundation/Foundation.h>

/**
 同步协议
 */
@protocol WKSync <NSObject>


/**
 是否需要同步

 @return <#return value description#>
 */
-(BOOL) needSync;

/**
 同步标题
 
 @return <#return value description#>
 */
-(NSString*) title;


/**
 同步函数
 
 @param callback 返回回调 （不管成功与否都需要返回）
 */
-(void) sync:(void(^)(NSError *error))callback;


@end

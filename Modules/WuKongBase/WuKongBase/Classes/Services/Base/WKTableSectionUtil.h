//
//  WKTableSectionUtil.h
//  WuKongBase
//
//  Created by tt on 2020/3/1.
//

#import <Foundation/Foundation.h>
#import "WKFormSection.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKTableSectionUtil : NSObject


/// 将字典类型转换为Form对象
/// @param sectionArray <#sectionArray description#>
+(NSArray<WKFormSection*>*) toSections:(NSArray<NSDictionary*>*) sectionArray;
@end

NS_ASSUME_NONNULL_END

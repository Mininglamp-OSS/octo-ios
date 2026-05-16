//
//  WKAnnotation.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import <Foundation/Foundation.h>

#define WKModuleSectName "WKMods"


#define WKDATA(sectname) __attribute((used, section("__DATA,"#sectname" ")))


#define WKModule(name) \
class BeeHive; char * k##name##_mod WKDATA(WKMods) = ""#name"";

NS_ASSUME_NONNULL_BEGIN



@interface WKAnnotation : NSObject

@end

NS_ASSUME_NONNULL_END

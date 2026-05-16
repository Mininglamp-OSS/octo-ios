//
//  NSString+Localized.m
//  WuKongBase
//
//  Created by tt on 2020/12/25.
//

#import "NSString+WKLocalized.h"
#import "WKApp.h"
@implementation WKNoUse
@end

@implementation NSString (WKLocalized)


-(NSString *)Localized{
    return self;
}

-(NSString* _Nonnull) Localized:(id)the{

    return [self LocalizedWithClass:[the class]];
}

-(NSString* _Nonnull) LocalizedWithClass:(Class)cls {
    NSString *lang = [WKApp shared].config.langue;
    
    NSBundle *moduleBundle = [NSBundle bundleForClass:cls];
    
    NSBundle* resourceBundle;
    NSString* path;
    if(moduleBundle == [NSBundle mainBundle]) {
        path =
           [moduleBundle pathForResource:[NSString stringWithFormat:@"%@",lang]
                                           ofType:@"lproj"];
    }else{
        path =
           [moduleBundle pathForResource:[NSString stringWithFormat:@"Lang/%@",lang]
                                           ofType:@"lproj"];
    }
     
    resourceBundle = [NSBundle bundleWithPath:path];
    if(resourceBundle) {
        NSString *v = NSLocalizedStringFromTableInBundle(self, nil,
                                                         resourceBundle, @"");
        return v;
    }
    return self;
}

-(NSString* _Nonnull) LocalizedWithBundle:(NSBundle*)bundle {
    if(!bundle) {
        return self;
    }
    NSString *lang = [WKApp shared].config.langue;
    
    NSString *path =
       [bundle pathForResource:[NSString stringWithFormat:@"Lang/%@",lang]
                                       ofType:@"lproj"];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:path];
    if(resourceBundle) {
        NSString *v = NSLocalizedStringFromTableInBundle(self, nil,
                                                         resourceBundle, @"");
        return v;
    }
    return self;
}

@end

//
//  WKUserColorUtil.m
//  WuKongBase
//
//  Created by tt on 2021/8/23.
//

#import "WKUserColorUtil.h"
#import "UIColor+WK.h"

@implementation WKUserColorUtil

+(UIColor*) userColor:(NSString*)value {
    static NSArray<NSNumber*> *colors;
    if(!colors) {
        colors = @[@0x8C8DFF, @0x7983C2, @0x6D8DDE, @0x5979F0, @0x6695DF, @0x8F7AC5,
                   @0x9D77A5, @0x8A64D0, @0xAA66C3, @0xA75C96, @0xC8697D, @0xB74D62,
                   @0xBD637C, @0xB3798E, @0x9B6D77, @0xB87F7F, @0xC5595A, @0xAA4848,
                   @0xB0665E, @0xB76753, @0xBB5334, @0xC97B46, @0xBE6C2C, @0xCB7F40,
                   @0xA47758, @0xB69370, @0xA49373, @0xAA8A46, @0xAA8220, @0x76A048,
                   @0x9CAD23, @0xA19431, @0xAA9100, @0xA09555, @0xC49B4B, @0x5FB05F,
                   @0x6AB48F, @0x71B15C, @0xB3B357, @0xA3B561, @0x909F45, @0x93B289,
                   @0x3D98D0, @0x429AB6, @0x4EABAA, @0x6BC0CE, @0x64B5D9, @0x3E9CCB,
                   @0x2887C4, @0x52A98B];
    }
    return  [UIColor colorWithRGBHex:colors[[value hash]%colors.count].unsignedIntValue];
}

@end

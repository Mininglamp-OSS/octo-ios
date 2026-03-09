//
//  WKCommon.m
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import "WKCommon.h"

@implementation WKCommon

+(void) commonAnimation:(void(^)(void)) block completion:(void(^)(void)) completion {
    
    //        [UIView beginAnimations:nil context:NULL];
    //        [UIView setAnimationDuration:0.25];
    //        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    //        [UIView setAnimationBeginsFromCurrentState:YES];
    //        if(block){
    //            block();
    //        }
    //        [UIView commitAnimations];
    
    // 7<<16是键盘动画
    [UIView animateWithDuration:0.25 delay:0 options:7<<16 animations:^{
        if(block){
            block();
        }
    } completion:^(BOOL finished) {
        if(completion&&finished){
            completion();
        }
    }];
}

+(void) commonAnimation:(void(^)(void)) block{
    [WKCommon commonAnimation:block completion:nil];
}

+(int) iosMajorVersion {
    static bool initialized = false;
    static int version = 7;
        if (!initialized)
        {
            switch ([[[UIDevice currentDevice] systemVersion] intValue])
            {
                case 4:
                    version = 4;
                    break;
                case 5:
                    version = 5;
                    break;
                case 6:
                    version = 6;
                    break;
                case 7:
                    version = 7;
                    break;
                case 8:
                    version = 8;
                    break;
                case 9:
                    version = 9;
                    break;
                case 10:
                    version = 10;
                    break;
                case 11:
                    version = 11;
                    break;
                default:
                    version = 9;
                    break;
            }
    
            initialized = true;
        }
        return version;
}

@end

//int limIosMajorVersion()
//{
//    static bool initialized = false;
//    static int version = 7;
//    if (!initialized)
//    {
//        switch ([[[UIDevice currentDevice] systemVersion] intValue])
//        {
//            case 4:
//                version = 4;
//                break;
//            case 5:
//                version = 5;
//                break;
//            case 6:
//                version = 6;
//                break;
//            case 7:
//                version = 7;
//                break;
//            case 8:
//                version = 8;
//                break;
//            case 9:
//                version = 9;
//                break;
//            case 10:
//                version = 10;
//                break;
//            case 11:
//                version = 11;
//                break;
//            default:
//                version = 9;
//                break;
//        }
//
//        initialized = true;
//    }
//    return version;
//}

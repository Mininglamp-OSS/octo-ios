//
//  OctoCitationBadgeView.m
//  OctoContext
//

#import "OctoCitationBadgeView.h"

NSAttributedStringKey const OctoCitationIndexAttrKey = @"OctoCitationIndex";
NSAttributedStringKey const OctoCitationGroupAttrKey = @"OctoCitationGroup";

@implementation OctoCitationBadgeView

+ (UIImage *)imageForBadgeText:(NSString *)text height:(CGFloat)h {
    if (text.length == 0) text = @"·";
    UIFont *font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    NSDictionary *attrs = @{NSFontAttributeName: font};
    CGSize textSize = [text sizeWithAttributes:attrs];
    CGFloat padding = 6;
    CGFloat w = ceilf(textSize.width) + padding * 2;
    CGFloat radius = h / 2.0;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, w, h) cornerRadius:radius];
    [[[UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0] colorWithAlphaComponent:0.12] setFill];
    [p fill];
    [text drawAtPoint:CGPointMake(padding, (h - textSize.height) / 2.0)
       withAttributes:@{
           NSFontAttributeName: font,
           NSForegroundColorAttributeName: [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0],
       }];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    (void)ctx;
    return img;
}

@end

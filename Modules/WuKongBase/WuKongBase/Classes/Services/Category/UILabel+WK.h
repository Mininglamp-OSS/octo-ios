//
//  UILabel+WK.h
//  WuKongBase
//
//  Created by tt on 2021/7/27.
//

#import <UIKit/UIKit.h>
#import "NSMutableAttributedString+WK.h"
#import "WKRichTextParseService.h"
NS_ASSUME_NONNULL_BEGIN

@interface UILabel (WK)

@property(nonatomic,strong) NSArray<id<WKMatchToken>> *tokens;

-(void) onClick:(void(^)(id<WKMatchToken>))click;

- (BOOL)didTapAttributedTextInLabel:(UITapGestureRecognizer *)tapGesture inRange:(NSRange)targetRange;

-( id<WKMatchToken>) matchDidTapAttributedTextInLabelWithPoint:(CGPoint)locationOfTouchInLabel;
-(void) onTap:(UITapGestureRecognizer*)gesture;
@end

NS_ASSUME_NONNULL_END

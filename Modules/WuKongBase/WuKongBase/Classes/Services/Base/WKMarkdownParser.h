//
//  WKMarkdownParse.h
//  WuKongBase
//
//  Created by tt on 2022/4/28.
//

#import <Foundation/Foundation.h>
#import "WKMatchToken.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMarkdownParser : NSObject

-(NSArray<id<WKMatchToken>>*) parseMarkdownIntoAttributedString:(NSString*)string;


@end

@interface WKMarkdownAttributeSet : NSObject

@property(nonatomic,strong) UIFont *font;
@property(nonatomic,strong) UIColor *textColor;
@property(nonatomic,strong) NSDictionary<NSAttributedStringKey,id> *attributes;

-(instancetype) initWithFont:(UIFont*)font textColor:(UIColor*)textColor attributes:(NSDictionary<NSAttributedStringKey,id>*)attributes;


@end

@interface WKMarkdownAttributes : NSObject

@property(nonatomic,strong) WKMarkdownAttributeSet *body;
@property(nonatomic,strong) WKMarkdownAttributeSet *bold;
@property(nonatomic,strong) WKMarkdownAttributeSet *link;
@property(nonatomic,copy)   NSDictionary<NSAttributedStringKey,id>*(^linkAttribute)(NSString*content) ;

@end

NS_ASSUME_NONNULL_END

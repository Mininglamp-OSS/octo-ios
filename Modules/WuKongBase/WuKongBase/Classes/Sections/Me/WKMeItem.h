//
//  WKMeItem.h
//  WuKongBase
//
//  Created by tt on 2020/7/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKMeItem : NSObject

@property(nonatomic,copy) NSString *title;

@property(nonatomic,strong) UIImage *icon;
@property(nonatomic,assign) CGFloat sectionHeight;
@property(nonatomic,assign) CGFloat nextSectionHeight;
@property(nonatomic,copy) void(^onClick)(void);

+(WKMeItem*) initWithTitle:(NSString*)title icon:(UIImage*)icon onClick:(void(^)(void))onClick;

+(WKMeItem*) initWithTitle:(NSString*)title icon:(UIImage*)icon sectionHeight:(CGFloat)sectionHeight onClick:(void(^)(void))onClick;

+(WKMeItem*) initWithTitle:(NSString*)title icon:(UIImage*)icon nextSectionHeight:(CGFloat)nextSectionHeight onClick:(void(^)(void))onClick;
@end

NS_ASSUME_NONNULL_END

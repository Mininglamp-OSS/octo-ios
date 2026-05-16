//
//  WKConversationAddItem.h
//  WuKongBase
//
//  Created by tt on 2020/12/16.
//

#import <Foundation/Foundation.h>

typedef void(^ConversationAddClick)(void);

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationAddItem : NSObject

+(WKConversationAddItem*) title:(NSString*)title icon:(UIImage*)icon onClick:(ConversationAddClick)click;

@property(nonatomic,copy) NSString *title;

@property(nonatomic,strong) UIImage *icon;

@property(nonatomic,copy) ConversationAddClick onClick;

@end

NS_ASSUME_NONNULL_END

//
//  WKMentionUserCell.h
//  WuKongBase
//
//  Created by tt on 2021/11/3.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKMentionUserCellModel : WKFormItemModel

@property(nonatomic,copy) NSString *uid;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,strong) NSURL *avatarURL;
@property(nonatomic,assign) BOOL robot;

+(instancetype) uid:(NSString*)uid name:(NSString*)name avatarURL:(NSURL * __nullable)avatarURL robot:(BOOL)robot;
+(instancetype) uid:(NSString*)uid name:(NSString*)name;

@end

@interface WKMentionUserCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END

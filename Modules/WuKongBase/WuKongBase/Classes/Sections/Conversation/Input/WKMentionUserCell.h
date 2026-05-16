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
// viewer-relative @SpaceName 后缀所需的 extras（）。
// 字段约定与 WKChannelMember.extra 一致，键名对齐 WKExternalExtrasKey*：
//   home_space_id / home_space_name / is_external / source_space_name
// 为 nil 时 resolver 退化为非外部（不追加后缀），保持向后兼容。
@property(nonatomic,copy,nullable) NSDictionary *extras;

+(instancetype) uid:(NSString*)uid name:(NSString*)name avatarURL:(NSURL * __nullable)avatarURL robot:(BOOL)robot;
+(instancetype) uid:(NSString*)uid name:(NSString*)name avatarURL:(NSURL * __nullable)avatarURL robot:(BOOL)robot extras:(NSDictionary * __nullable)extras;
+(instancetype) uid:(NSString*)uid name:(NSString*)name;

@end

@interface WKMentionUserCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END

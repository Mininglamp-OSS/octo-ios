//
//  WKFileIconHelper.h
//  WuKongBase
//
//  文件类型图标 / 文件大小格式化的共享工具。
//  逻辑原先散落在 WKFileMessageCell / WKMergeForwardDetailCell 各一份, 这里集中一处,
//  供 WKZipEntryCell 等新调用方复用 (旧两处可后续逐步收敛到此)。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKFileIconHelper : NSObject

/// 按扩展名返回文件类型图标; 命中映射返回 AlwaysOriginal 彩色图,
/// 未命中返回系统 doc.fill (Template 渲染, 调用方自行设置 tintColor 才可见)。
+ (nullable UIImage *)iconForFileExtension:(NSString *)ext;

/// 文件夹图标 (系统 folder.fill, Template 渲染, 调用方自行 tint)。
+ (nullable UIImage *)folderIcon;

/// 字节数格式化为 B/KB/MB/GB。
+ (NSString *)formatFileSize:(long long)size;

@end

NS_ASSUME_NONNULL_END

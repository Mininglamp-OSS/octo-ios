//
//  WKZipEntryCell.h
//  WuKongBase
//
//  ZIP 解压浏览列表的单元格: 左图标 + 名称 + (文件大小 / 文件夹 chevron)。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKZipEntryCell : UITableViewCell

/// name: 显示名; isDirectory: 是否文件夹; ext: 文件扩展名(文件夹忽略);
/// sizeText: 文件大小文案(文件夹传 nil)。
- (void)configureWithName:(NSString *)name
              isDirectory:(BOOL)isDirectory
                      ext:(nullable NSString *)ext
                 sizeText:(nullable NSString *)sizeText;

@end

NS_ASSUME_NONNULL_END

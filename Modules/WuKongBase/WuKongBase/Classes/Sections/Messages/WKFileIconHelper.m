//
//  WKFileIconHelper.m
//  WuKongBase
//

#import "WKFileIconHelper.h"
#import "WKApp.h"

@implementation WKFileIconHelper

+ (nullable UIImage *)iconForFileExtension:(NSString *)ext {
    NSString *lowExt = [ext lowercaseString];
    // 去掉前导点号
    if ([lowExt hasPrefix:@"."]) {
        lowExt = [lowExt substringFromIndex:1];
    }

    NSString *imageName = nil;

    // Word 系列
    if ([@[@"doc", @"docx", @"docm", @"dot", @"dotx", @"dotm", @"rtf", @"odt", @"wps"] containsObject:lowExt]) {
        imageName = @"FileType/FileWord";
    }
    // Excel 系列
    else if ([@[@"xls", @"xlsx", @"xlsm", @"xlsb", @"xlt", @"xltx", @"xltm", @"csv", @"ods", @"et", @"ett"] containsObject:lowExt]) {
        imageName = @"FileType/FileExcel";
    }
    // PDF
    else if ([lowExt isEqualToString:@"pdf"]) {
        imageName = @"FileType/FilePDF";
    }
    // PowerPoint 系列
    else if ([@[@"ppt", @"pptx", @"pptm", @"pps", @"ppsx", @"ppsm", @"pot", @"potx", @"potm", @"odp", @"dps", @"dpt"] containsObject:lowExt]) {
        imageName = @"FileType/FilePPT";
    }
    // 视频
    else if ([@[@"mp4", @"mov", @"avi", @"mkv", @"wmv", @"flv", @"webm", @"m4v", @"mpg", @"mpeg", @"3gp", @"3gpp", @"ts", @"rmvb", @"rm"] containsObject:lowExt]) {
        imageName = @"FileType/FileVideo";
    }
    // Markdown
    else if ([@[@"md", @"markdown", @"mdown", @"mkd", @"mdwn"] containsObject:lowExt]) {
        imageName = @"FileType/FileMarkdown";
    }
    // HTML
    else if ([@[@"html", @"htm"] containsObject:lowExt]) {
        imageName = @"FileType/FileHTML";
    }
    // 图片
    else if ([@[@"png", @"jpg", @"jpeg", @"gif", @"bmp", @"webp", @"heic", @"heif", @"tiff", @"tif", @"svg", @"ico"] containsObject:lowExt]) {
        imageName = @"FileType/FileImage";
    }
    // 压缩包
    else if ([@[@"zip", @"rar", @"7z", @"tar", @"gz", @"tgz", @"bz2", @"xz"] containsObject:lowExt]) {
        imageName = @"FileType/FileZip";
    }
    // 纯文本
    else if ([lowExt isEqualToString:@"txt"]) {
        imageName = @"FileType/FileTxt";
    }

    if (imageName) {
        UIImage *img = [[WKApp shared] loadImage:imageName moduleID:@"WuKongBase"];
        if (img) {
            return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }

    // 默认图标（系统符号图标为 Template 渲染, 需调用方设置 tintColor 才可见）
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightRegular];
        return [UIImage systemImageNamed:@"doc.fill" withConfiguration:config];
    }
    return nil;
}

+ (nullable UIImage *)folderIcon {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightRegular];
        return [UIImage systemImageNamed:@"folder.fill" withConfiguration:config];
    }
    return nil;
}

+ (NSString *)formatFileSize:(long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lld B", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", size / 1024.0];
    } else if (size < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", size / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", size / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end

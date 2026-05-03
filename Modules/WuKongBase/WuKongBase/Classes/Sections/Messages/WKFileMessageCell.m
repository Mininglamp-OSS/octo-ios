//
//  WKFileMessageCell.m
//  WuKongBase
//
//  文件消息Cell

#import "WKFileMessageCell.h"
#import "WKMessageModel.h"
#import "WKResource.h"
#import "WKLoadProgressView.h"
#import <WuKongIMSDK/WKFileContent.h>
#import <WuKongBase/WuKongBase-Swift.h>
#import "WKNavigationManager.h"
#import "WKSafeFilePreviewVC.h"
#import <QuickLook/QuickLook.h>

#define WKFileCellWidth 250.0f
#define WKFileCellHeight 72.0f
#define WKFileIconSize 40.0f

@interface WKFileMessageCell ()

@property(nonatomic,strong) UIImageView *fileIconView;
@property(nonatomic,strong) UILabel *fileNameLbl;
@property(nonatomic,strong) UILabel *fileSizeLbl;
@property(nonatomic,strong) WKLoadProgressView *progressView;
@property(nonatomic,strong) WKMessageFileUploadTask *uploadTask;
@property(nonatomic,strong) NSURL *previewFileURL;
@property(nonatomic,assign) BOOL isFileDownloading;

@end

@implementation WKFileMessageCell

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    return CGSizeMake(WKFileCellWidth, WKFileCellHeight);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    if (self.uploadTask) {
        [self.uploadTask removeListener:self];
    }
}

- (void)initUI {
    [super initUI];

    self.messageContentView.layer.masksToBounds = YES;
    self.messageContentView.layer.cornerRadius = 4.0f;

    self.fileIconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, WKFileIconSize, WKFileIconSize)];
    self.fileIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.messageContentView addSubview:self.fileIconView];

    self.fileNameLbl = [[UILabel alloc] init];
    self.fileNameLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
    self.fileNameLbl.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.fileNameLbl.numberOfLines = 1;
    [self.messageContentView addSubview:self.fileNameLbl];

    self.fileSizeLbl = [[UILabel alloc] init];
    self.fileSizeLbl.font = [UIFont systemFontOfSize:12.0f];
    self.fileSizeLbl.textColor = [UIColor grayColor];
    [self.messageContentView addSubview:self.fileSizeLbl];

    self.progressView = [[WKLoadProgressView alloc] initWithFrame:CGRectMake(0, 0, WKFileCellWidth, WKFileCellHeight)];
    self.progressView.maxProgress = 1.0f;
    self.progressView.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:0.7];
    self.progressView.layer.masksToBounds = YES;
    self.progressView.layer.cornerRadius = 4.0f;
    [self.messageContentView addSubview:self.progressView];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    if ([WKApp shared].config.style != WKSystemStyleDark) {
        self.trailingView.timeLbl.textColor = [WKApp shared].config.tipColor;
        self.trailingView.statusImgView.tintColor = [WKApp shared].config.tipColor;
    }

    WKFileContent *fileContent = (WKFileContent *)model.content;
    self.fileNameLbl.text = fileContent.name ?: @"";
    self.fileSizeLbl.text = [self formatFileSize:fileContent.fileSize];
    self.fileNameLbl.textColor = [WKApp shared].config.messageRecvTextColor;

    // 根据文件扩展名显示对应图标（优先用 fileExtension，为空时从文件名提取）
    NSString *ext = fileContent.fileExtension;
    if (!ext || ext.length == 0 || [ext isEqualToString:@"."]) {
        ext = [fileContent.name pathExtension];
    }
    self.fileIconView.image = [self iconForFileExtension:ext];

    [self.messageContentView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];

    [self updateProgress];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat padding = 12.0f;
    CGFloat iconRight = 10.0f;

    self.fileIconView.lim_left = padding;
    self.fileIconView.lim_top = (self.messageContentView.lim_height - WKFileIconSize) / 2.0f;

    CGFloat textLeft = self.fileIconView.lim_right + iconRight;
    CGFloat textMaxWidth = self.messageContentView.lim_width - textLeft - padding;

    self.fileNameLbl.lim_left = textLeft;
    self.fileNameLbl.lim_top = padding;
    self.fileNameLbl.lim_width = textMaxWidth;
    self.fileNameLbl.lim_height = 20.0f;

    self.fileSizeLbl.lim_left = textLeft;
    self.fileSizeLbl.lim_top = self.fileNameLbl.lim_bottom + 4.0f;
    self.fileSizeLbl.lim_width = textMaxWidth;
    self.fileSizeLbl.lim_height = 16.0f;

    self.progressView.frame = self.messageContentView.bounds;
}

- (void)updateProgress {
    __weak typeof(self) weakSelf = self;
    self.uploadTask = [[WKSDK shared] getMessageFileUploadTask:self.messageModel.message];
    if (self.uploadTask) {
        [self.uploadTask addListener:^{
            dispatch_block_t uiUpdate;
            if (weakSelf.uploadTask.status == WKTaskStatusProgressing) {
                uiUpdate = ^{
                    weakSelf.progressView.hidden = NO;
                    [weakSelf.progressView setProgress:weakSelf.uploadTask.progress];
                };
            } else {
                uiUpdate = ^{
                    weakSelf.progressView.hidden = YES;
                    [weakSelf.progressView setProgress:0];
                };
            }
            if ([NSThread isMainThread]) {
                uiUpdate();
            } else {
                dispatch_async(dispatch_get_main_queue(), uiUpdate);
            }
        } target:self];
    } else {
        self.progressView.hidden = YES;
        [self.progressView setProgress:0];
    }
}

- (BOOL)respondContentSingleTap {
    return true;
}

- (void)onTap {
    [super onTap];
    if (!self.messageModel) {
        return;
    }
    WKFileContent *fileContent = (WKFileContent *)self.messageModel.content;

    NSLog(@"[File-onTap] name=%@, localPath=%@, remoteUrl=%@, fileSize=%lld, status=%ld",
          fileContent.name, fileContent.localPath, fileContent.remoteUrl, fileContent.fileSize, (long)self.messageModel.status);

    // 检查本地文件是否存在
    NSString *localPath = fileContent.localPath;
    if (localPath && [[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        NSLog(@"[File-onTap] 本地文件存在，直接预览");
        [self previewFileAtPath:localPath];
        return;
    }

    NSLog(@"[File-onTap] 本地文件不存在 (localPath=%@)", localPath);

    // 下载中再点击 → 取消下载
    if (self.isFileDownloading) {
        self.isFileDownloading = NO;
        self.progressView.hidden = YES;
        [self.progressView setProgress:0];
        return;
    }

    // 需要下载
    if (!fileContent.remoteUrl || fileContent.remoteUrl.length == 0) {
        NSLog(@"[File-onTap] remoteUrl 为空，文件无法下载");
        [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"文件不存在或正在上传中")];
        return;
    }
    if (fileContent.remoteUrl.length > 0) {
        self.isFileDownloading = YES;
        self.progressView.hidden = NO;
        [self.progressView setProgress:0];
        __weak typeof(self) weakSelf = self;
        [[WKSDK shared].mediaManager download:self.messageModel.message callback:^(WKMediaDownloadState state, CGFloat progress, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf.isFileDownloading) return; // 已取消，忽略回调
                if (state == WKMediaDownloadStateSuccess) {
                    weakSelf.isFileDownloading = NO;
                    weakSelf.progressView.hidden = YES;
                    [weakSelf.progressView setProgress:0];
                    NSString *downloadedPath = fileContent.localPath;
                    NSLog(@"[File] download success, localPath=%@, exists=%d, extension='%@', name='%@'",
                          downloadedPath,
                          [[NSFileManager defaultManager] fileExistsAtPath:downloadedPath],
                          fileContent.fileExtension ?: @"(nil)",
                          fileContent.name ?: @"(nil)");
                    if (downloadedPath && [[NSFileManager defaultManager] fileExistsAtPath:downloadedPath]) {
                        [weakSelf previewFileAtPath:downloadedPath];
                    } else {
                        NSLog(@"[File] downloaded file NOT found at localPath!");
                    }
                } else if (state == WKMediaDownloadStateFail) {
                    weakSelf.isFileDownloading = NO;
                    weakSelf.progressView.hidden = YES;
                    [weakSelf.progressView setProgress:0];
                } else {
                    [weakSelf.progressView setProgress:progress];
                }
            });
        }];
    }
}

- (void)previewFileAtPath:(NSString *)path {
    WKFileContent *fileContent = (WKFileContent *)self.messageModel.content;

    // 将文件拷贝到以真实文件名命名的临时路径，解决预览标题显示16进制字符串的问题
    NSString *realName = fileContent.name;
    NSString *previewPath = path;
    if (realName && realName.length > 0) {
        NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WKFilePreview"];
        [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *destPath = [tmpDir stringByAppendingPathComponent:realName];
        // 先移除旧的临时文件
        [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
        NSError *linkError;
        // 使用硬链接避免复制大文件的开销
        if ([[NSFileManager defaultManager] linkItemAtPath:path toPath:destPath error:&linkError]) {
            previewPath = destPath;
        } else {
            // 硬链接失败时使用拷贝
            if ([[NSFileManager defaultManager] copyItemAtPath:path toPath:destPath error:nil]) {
                previewPath = destPath;
            }
        }
    }

    NSURL *fileURL = [NSURL fileURLWithPath:previewPath];
    [WKSafeFilePreviewVC showFilePreview:fileURL title:fileContent.name];
}

+ (BOOL)hiddenBubble {
    return YES;
}

- (UIImage *)iconForFileExtension:(NSString *)ext {
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

    if (imageName) {
        UIImage *img = [[WKApp shared] loadImage:imageName moduleID:@"WuKongBase"];
        if (img) {
            self.fileIconView.tintColor = nil;
            return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }

    // 默认图标（系统符号图标需要 tint 才可见）
    self.fileIconView.tintColor = [UIColor systemBlueColor];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightRegular];
        return [UIImage systemImageNamed:@"doc.fill" withConfiguration:config];
    }
    return nil;
}

- (NSString *)formatFileSize:(long long)size {
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

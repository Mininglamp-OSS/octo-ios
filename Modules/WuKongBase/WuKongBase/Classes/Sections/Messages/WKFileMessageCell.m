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
#import <WuKongIMSDK/WKMessageDB.h>
#import <WuKongBase/WuKongBase-Swift.h>
#import "WKNavigationManager.h"
#import "WKSafeFilePreviewVC.h"
#import "WKZipBrowserVC.h"
#import <QuickLook/QuickLook.h>
#import <sys/stat.h>

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

    NSLog(@"[File-onTap] ENTRY name=%@ ext=%@ size=%lld remoteUrl='%@' localPath=%@ status=%ld streamFlag=%d cmn=%@ msgId=%llu msgSeq=%u fromUid=%@",
          fileContent.name ?: @"(nil)",
          fileContent.fileExtension ?: @"(nil)",
          fileContent.fileSize,
          fileContent.remoteUrl ?: @"(nil)",
          fileContent.localPath ?: @"(nil)",
          (long)self.messageModel.status,
          (int)self.messageModel.message.streamFlag,
          self.messageModel.message.clientMsgNo ?: @"(nil)",
          self.messageModel.message.messageId,
          self.messageModel.message.messageSeq,
          self.messageModel.message.fromUid ?: @"(nil)");

    // 检查本地文件是否存在(打点把"为啥不存在"信息一起带上,后续诊断用)
    NSString *localPath = fileContent.localPath;
    if (localPath.length > 0) {
        NSDictionary<NSFileAttributeKey, id> *attrs =
            [[NSFileManager defaultManager] attributesOfItemAtPath:localPath error:nil];
        if (attrs) {
            unsigned long long sz = [attrs[NSFileSize] unsignedLongLongValue];
            if (sz == 0) {
                // 文件占位 0 字节(下载中途断 / move 失败 / SDK 写空文件),这种 fileExistsAtPath 会
                // 返 YES,但预览出来空白 —— 当作"不存在"处理走重新下载流程,但别让 fileExists 路径吞了它。
                NSLog(@"[File-onTap][WARN] localPath exists but 0 bytes — treating as missing path=%@", localPath);
            } else {
                NSLog(@"[File-onTap] 本地文件存在 size=%llu,直接预览", sz);
                [self previewFileAtPath:localPath];
                return;
            }
        } else {
            NSLog(@"[File-onTap] 本地文件不存在 path=%@", localPath);
        }
    } else {
        NSLog(@"[File-onTap][WARN] localPath 为空 —— SDK 路径计算异常(messageFileRootDir / uid / channelDir / clientMsgNo 中有一个空) cmn=%@", self.messageModel.message.clientMsgNo);
    }

    // 下载中再点击 → 取消下载
    if (self.isFileDownloading) {
        NSLog(@"[File-onTap] 用户取消下载中点击 → 取消下载");
        self.isFileDownloading = NO;
        self.progressView.hidden = YES;
        [self.progressView setProgress:0];
        return;
    }

    // 需要下载,先确认 remoteUrl —— 这里是线上"文件不存在或正在上传中" toast 的唯一入口。
    // 不要直接弹,先把所有可能的原因 dump 出来 + 跑一次 DB 重读对比,留充足证据再 toast。
    if (!fileContent.remoteUrl || fileContent.remoteUrl.length == 0) {
        [self diagnoseAndShowMissingUrlToast:fileContent];
        return;
    }

    NSLog(@"[File-onTap] remoteUrl 有值,启动 SDK 下载 url=%@", fileContent.remoteUrl);
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
                NSDictionary<NSFileAttributeKey, id> *downloadedAttrs =
                    [[NSFileManager defaultManager] attributesOfItemAtPath:downloadedPath error:nil];
                NSLog(@"[File-onTap] download SUCCESS path=%@ exists=%d size=%llu ext='%@' name='%@'",
                      downloadedPath,
                      downloadedAttrs != nil,
                      downloadedAttrs ? [downloadedAttrs[NSFileSize] unsignedLongLongValue] : 0ULL,
                      fileContent.fileExtension ?: @"(nil)",
                      fileContent.name ?: @"(nil)");
                if (downloadedPath && downloadedAttrs) {
                    [weakSelf previewFileAtPath:downloadedPath];
                } else {
                    // SDK 标 SUCCESS 但落地路径文件读不到 —— 经典 path mismatch
                    // (cell 算出来的 localPath 跟 SDK 落地 move 目标不一致)
                    NSLog(@"[File-onTap][ERROR] SDK download SUCCESS 但 localPath 实际不存在! cell 拼接 path=%@ name=%@ ext=%@ cmn=%@",
                          downloadedPath, fileContent.name, fileContent.fileExtension, weakSelf.messageModel.message.clientMsgNo);
                    NSString *diag = [NSString stringWithFormat:
                                      @"cause=SDK_SUCCESS_BUT_LOCAL_MISSING(cell 拼路径 vs SDK 落地路径不一致)\n"
                                       "cellLocalPath=%@\n"
                                       "name=%@\n"
                                       "ext=%@\n"
                                       "size=%lld\n"
                                       "remoteUrl=%@\n"
                                       "cmn=%@ clientSeq=%u",
                                      downloadedPath ?: @"-",
                                      fileContent.name ?: @"-",
                                      fileContent.fileExtension ?: @"-",
                                      fileContent.fileSize,
                                      fileContent.remoteUrl ?: @"-",
                                      weakSelf.messageModel.message.clientMsgNo ?: @"-",
                                      weakSelf.messageModel.message.clientSeq];
                    [weakSelf showFileOpenFailureAlertWithTitle:LLang(@"文件读取失败,请重试") detail:diag];
                }
            } else if (state == WKMediaDownloadStateFail) {
                weakSelf.isFileDownloading = NO;
                weakSelf.progressView.hidden = YES;
                [weakSelf.progressView setProgress:0];
                NSLog(@"[File-onTap][ERROR] download FAIL url=%@ error=%@",
                      fileContent.remoteUrl, error);
                NSString *diag = [NSString stringWithFormat:
                                  @"cause=DOWNLOAD_FAIL\n"
                                   "url=%@\n"
                                   "name=%@\n"
                                   "size=%lld\n"
                                   "error.domain=%@\n"
                                   "error.code=%ld\n"
                                   "error.desc=%@\n"
                                   "cmn=%@ clientSeq=%u",
                                  fileContent.remoteUrl ?: @"-",
                                  fileContent.name ?: @"-",
                                  fileContent.fileSize,
                                  error.domain ?: @"-",
                                  (long)error.code,
                                  error.localizedDescription ?: @"-",
                                  weakSelf.messageModel.message.clientMsgNo ?: @"-",
                                  weakSelf.messageModel.message.clientSeq];
                [weakSelf showFileOpenFailureAlertWithTitle:LLang(@"下载失败") detail:diag];
            } else {
                [weakSelf.progressView setProgress:progress];
            }
        });
    }];
}

// "文件不存在或正在上传中" toast 的诊断与原因分类 ——
// 这条 toast 在线上偶发触发,本机复测不到。这里在弹 toast 之前把所有候选根因都跑一遍,
// 在控制台打出 "[File-onTap][DIAG]" 一段聚合日志,便于线上用户截图回传定位。
// 候选根因(都在 NSLog 里有对应 tag):
//   1) SENDER_STILL_UPLOADING : msg.status == sending / streamFlag 中间态,sender 那条仍在传
//   2) DB_HAS_URL_MEMORY_NOT  : DB 重读的 content 有 url,内存对象的 url 被 mutate 没了
//   3) DB_AND_MEMORY_BOTH_EMPTY : DB 与内存均空 —— sender 那条 url 字段从未填,或 server payload
//      用了别的 key (file_url / remote_url / path 等命名漂移),iOS decode `contentDic[@"url"]` 拿空。
//   4) LOCAL_DIR_MISSING : localPath 拼接里 uid / channelDir 缺一段,目录没建出来,文件无处可放
- (void)diagnoseAndShowMissingUrlToast:(WKFileContent *)fileContent {
    NSMutableArray<NSString *> *causes = [NSMutableArray array];

    WKMessage *msg = self.messageModel.message;
    NSString *cmn = msg.clientMsgNo ?: @"";
    NSDictionary *memEncoded = [fileContent encodeWithJSON];

    // 1) sender 上传未完成 / 处于中间态
    //    WK_MESSAGE_SUCCESS = 正常收到 / 发送成功;  其余: WAITSEND / ONLYSAVE / UPLOADING / FAIL
    //    收到的消息(isSend=NO)如果不是 SUCCESS 状态,说明 server 推下来时 sender 那边还没传完。
    if (msg.status != WK_MESSAGE_SUCCESS && !msg.isSend) {
        [causes addObject:[NSString stringWithFormat:@"SENDER_STILL_UPLOADING(status=%ld streamFlag=%d isSend=%d)",
                          (long)msg.status, (int)msg.streamFlag, msg.isSend]];
    }

    // 2) DB 重读对比 —— 如果 DB 里有 url 但内存里空,说明运行时被 mutate 错了
    WKFileContent *dbContent = nil;
    if (msg.clientSeq > 0) {
        WKMessage *fresh = [[WKMessageDB shared] getMessage:msg.clientSeq];
        if ([fresh.content isKindOfClass:[WKFileContent class]]) {
            dbContent = (WKFileContent *)fresh.content;
        }
    }
    NSString *dbUrl = dbContent.remoteUrl ?: @"";
    NSDictionary *dbEncoded = dbContent ? [dbContent encodeWithJSON] : nil;
    BOOL dbHasUrl = dbUrl.length > 0;
    if (dbHasUrl) {
        [causes addObject:[NSString stringWithFormat:@"DB_HAS_URL_MEMORY_NOT(dbUrl=%@)", dbUrl]];
    } else if (dbContent) {
        [causes addObject:@"DB_AND_MEMORY_BOTH_EMPTY(sender 那条 content.url 从未写入 / 或 server payload 字段命名漂移如 file_url/remote_url/path)"];
    } else {
        [causes addObject:[NSString stringWithFormat:@"DB_MISS_BY_CLIENT_SEQ(clientSeq=%u —— DB 查不到这条消息,可能 sync 路径未落库)", msg.clientSeq]];
    }

    // 3) 本地目录是否存在 / 是否可写
    NSString *localPath = fileContent.localPath ?: @"";
    NSString *localDir = [localPath stringByDeletingLastPathComponent];
    BOOL dirExists = localDir.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:localDir];
    if (!dirExists && localDir.length > 0) {
        [causes addObject:[NSString stringWithFormat:@"LOCAL_DIR_MISSING(dir=%@ —— uid/channelDir 拼接段有问题)", localDir]];
    }

    // 4) name / extension 异常 —— 极端 case: name 含 ".." 路径穿越,或 extension 字段不带 ".",或 name 为空
    if (fileContent.name.length == 0) {
        [causes addObject:@"FILE_NAME_EMPTY(sender 没填 name,localPath 也少一段标识)"];
    }
    NSString *ext = fileContent.fileExtension ?: @"";
    if (ext.length > 0 && ![ext hasPrefix:@"."]) {
        [causes addObject:[NSString stringWithFormat:@"EXT_MISSING_DOT(ext='%@' —— 应以 . 开头,可能导致 SDK 落地路径与 cell 拼接不一致)", ext]];
    }

    if (causes.count == 0) {
        [causes addObject:@"UNKNOWN(所有已知 pattern 都没匹配,需要 dump content JSON 进一步排查)"];
    }

    // 聚合日志 —— [File-onTap][DIAG] 是搜索 anchor; 让用户截图时圈这一行能定位全部信息
    NSString *diagText = [NSString stringWithFormat:
          @"causes=%@\n"
           "cmn=%@ clientSeq=%u msgId=%llu msgSeq=%u orderSeq=%u status=%ld isSend=%d\n"
           "channel=%@/%d topic=%@ fromUid=%@ toUid=%@\n"
           "timestamp=%ld localTimestamp=%ld streamFlag=%d streamNo=%@\n"
           "memContent=%@\n"
           "dbContent =%@",
          [causes componentsJoinedByString:@" | "],
          cmn, msg.clientSeq, msg.messageId, msg.messageSeq, msg.orderSeq,
          (long)msg.status, msg.isSend,
          msg.channel.channelId, msg.channel.channelType,
          msg.topic ?: @"-",
          msg.fromUid ?: @"-", msg.toUid ?: @"-",
          (long)msg.timestamp, (long)msg.localTimestamp,
          (int)msg.streamFlag, msg.streamNo ?: @"-",
          memEncoded ?: @{},
          dbEncoded ?: @"(NOT_IN_DB)"];
    NSLog(@"[File-onTap][DIAG] file open failed (no remoteUrl + no local file)\n%@", diagText);

    // 用户层 toast —— 如果 DB 重读救回来了 url,直接走下载,不再骚扰用户
    if (dbHasUrl) {
        NSLog(@"[File-onTap][DIAG] 用 DB content 救回 url,启动下载");
        self.messageModel.message.content = dbContent;
        self.isFileDownloading = YES;
        self.progressView.hidden = NO;
        [self.progressView setProgress:0];
        __weak typeof(self) weakSelf = self;
        [[WKSDK shared].mediaManager download:self.messageModel.message callback:^(WKMediaDownloadState state, CGFloat progress, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf.isFileDownloading) return;
                if (state == WKMediaDownloadStateSuccess) {
                    weakSelf.isFileDownloading = NO;
                    weakSelf.progressView.hidden = YES;
                    [weakSelf.progressView setProgress:0];
                    NSString *p = dbContent.localPath;
                    if (p && [[NSFileManager defaultManager] fileExistsAtPath:p]) {
                        [weakSelf previewFileAtPath:p];
                    }
                } else if (state == WKMediaDownloadStateFail) {
                    weakSelf.isFileDownloading = NO;
                    weakSelf.progressView.hidden = YES;
                    [weakSelf.progressView setProgress:0];
                    NSLog(@"[File-onTap][DIAG] DB content 下载也失败 error=%@", error);
                } else {
                    [weakSelf.progressView setProgress:progress];
                }
            });
        }];
        return;
    }

    // 把 DIAG 直接弹给用户看 —— 线上排查模式: 用户看不到 console, 但能截图 / 复制 alert。
    [self showFileOpenFailureAlertWithTitle:LLang(@"文件不存在或正在上传中") detail:diagText];
}

// 文件打开失败的用户可见诊断 alert —— 三条失败路径共用:
//   (a) onTap "no remoteUrl + no local file" 主诊断分支
//   (b) SDK download SUCCESS 但落地路径找不到 (path mismatch)
//   (c) SDK download FAIL (网络/服务端错)
// 用 alert 渲染 detail; 加"复制详情"action 让用户能粘到反馈 / 发回支持。
- (void)showFileOpenFailureAlertWithTitle:(NSString *)title detail:(NSString *)detail {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:detail
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"复制详情")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = detail ?: @"";
        [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"已复制")];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"我知道了")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [[WKNavigationManager shared].topViewController presentViewController:alert animated:YES completion:nil];
}

- (void)previewFileAtPath:(NSString *)path {
    WKFileContent *fileContent = (WKFileContent *)self.messageModel.content;

    // .zip → 解压浏览(而非塞进预览器渲染白屏)。rar/7z 等不命中, 仍走下方占位逻辑。
    NSString *zipExt = [(fileContent.fileExtension ?: [path pathExtension]) lowercaseString];
    if ([zipExt hasPrefix:@"."]) zipExt = [zipExt substringFromIndex:1];
    if ([zipExt isEqualToString:@"zip"]) {
        [WKZipBrowserVC openZipAtPath:path
                                title:(fileContent.name ?: path.lastPathComponent)
                          clientMsgNo:self.messageModel.message.clientMsgNo];
        return;
    }

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
    // HTML
    else if ([@[@"html", @"htm"] containsObject:lowExt]) {
        imageName = @"FileType/FileHTML";
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

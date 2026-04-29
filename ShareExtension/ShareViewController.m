//
//  ShareViewController.m
//  ShareExtension
//

#import "ShareViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *const kAppGroupId = @"group.com.example.octo";
static NSString *const kShareDataKey = @"WKShareExtensionData";
static NSString *const kShareDirName = @"ShareExtensionFiles";

@interface ShareViewController ()
@end

@implementation ShareViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self handleShareContent];
}

- (void)handleShareContent {
    NSExtensionItem *item = self.extensionContext.inputItems.firstObject;
    if (!item) {
        [self completeWithError];
        return;
    }

    NSArray<NSItemProvider *> *providers = item.attachments;
    if (!providers || providers.count == 0) {
        [self completeWithError];
        return;
    }

    // 清理旧的共享文件
    [self cleanSharedDirectory];

    // 检测是否为 URL 分享（Safari/浏览器分享链接）
    // Safari 分享时 providers 包含 URL + 其他（标题、图片），应合并为单个链接
    BOOL hasURL = NO;
    BOOL hasNonURLFile = NO;
    for (NSItemProvider *p in providers) {
        if ([p hasItemConformingToTypeIdentifier:UTTypeURL.identifier] &&
            ![p hasItemConformingToTypeIdentifier:UTTypeFileURL.identifier]) {
            hasURL = YES;
        }
        if ([p hasItemConformingToTypeIdentifier:UTTypeImage.identifier] ||
            [p hasItemConformingToTypeIdentifier:UTTypeMovie.identifier] ||
            [p hasItemConformingToTypeIdentifier:UTTypeFileURL.identifier]) {
            hasNonURLFile = YES;
        }
    }

    // 如果是纯 URL 分享（如 Safari），合并为单条链接消息
    if (hasURL && !hasNonURLFile) {
        [self handleURLShare:item providers:providers];
        return;
    }

    // 普通文件/图片/视频分享
    NSMutableArray *fileInfos = [NSMutableArray array];
    __block NSInteger pending = providers.count;

    for (NSItemProvider *provider in providers) {
        if ([provider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
            [self loadProvider:provider typeId:UTTypeImage.identifier fileType:@"image" fileInfos:fileInfos completion:^{
                pending--;
                if (pending <= 0) [self finishWithFileInfos:fileInfos];
            }];
        } else if ([provider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {
            [self loadProvider:provider typeId:UTTypeMovie.identifier fileType:@"video" fileInfos:fileInfos completion:^{
                pending--;
                if (pending <= 0) [self finishWithFileInfos:fileInfos];
            }];
        } else if ([provider hasItemConformingToTypeIdentifier:UTTypeAudio.identifier]) {
            [self loadProvider:provider typeId:UTTypeAudio.identifier fileType:@"audio" fileInfos:fileInfos completion:^{
                pending--;
                if (pending <= 0) [self finishWithFileInfos:fileInfos];
            }];
        } else if ([provider hasItemConformingToTypeIdentifier:UTTypeFileURL.identifier]) {
            [self loadProvider:provider typeId:UTTypeFileURL.identifier fileType:@"file" fileInfos:fileInfos completion:^{
                pending--;
                if (pending <= 0) [self finishWithFileInfos:fileInfos];
            }];
        } else if ([provider hasItemConformingToTypeIdentifier:UTTypePlainText.identifier]) {
            [provider loadItemForTypeIdentifier:UTTypePlainText.identifier options:nil completionHandler:^(id<NSSecureCoding> rawItem, NSError *error) {
                id pi = (id)rawItem;
                NSString *text = ([pi isKindOfClass:[NSString class]]) ? (NSString *)pi : nil;
                if (text && !error) {
                    @synchronized (fileInfos) {
                        [fileInfos addObject:@{@"type": @"text", @"content": text}];
                    }
                }
                pending--;
                if (pending <= 0) [self finishWithFileInfos:fileInfos];
            }];
        } else if ([provider hasItemConformingToTypeIdentifier:UTTypeData.identifier]) {
            [self loadProvider:provider typeId:UTTypeData.identifier fileType:@"file" fileInfos:fileInfos completion:^{
                pending--;
                if (pending <= 0) [self finishWithFileInfos:fileInfos];
            }];
        } else {
            pending--;
            if (pending <= 0) [self finishWithFileInfos:fileInfos];
        }
    }
}

/// Safari/浏览器 URL 分享：提取 URL + 网页标题，合并为单条链接消息
- (void)handleURLShare:(NSExtensionItem *)item providers:(NSArray<NSItemProvider *> *)providers {
    __block NSString *urlString = nil;
    __block NSString *title = nil;

    // 获取网页标题（from NSExtensionItem.attributedContentText）
    if (item.attributedContentText.length > 0) {
        title = item.attributedContentText.string;
    }

    // 提取 URL
    NSItemProvider *urlProvider = nil;
    for (NSItemProvider *p in providers) {
        if ([p hasItemConformingToTypeIdentifier:UTTypeURL.identifier]) {
            urlProvider = p;
            break;
        }
    }

    if (!urlProvider) {
        [self completeWithError];
        return;
    }

    [urlProvider loadItemForTypeIdentifier:UTTypeURL.identifier options:nil completionHandler:^(id<NSSecureCoding> rawItem, NSError *error) {
        id pi = (id)rawItem;
        NSURL *url = ([pi isKindOfClass:[NSURL class]]) ? (NSURL *)pi : nil;
        if (url) urlString = url.absoluteString;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!urlString) {
                [self completeWithError];
                return;
            }

            // 合并为单条链接消息（type=link），附带 favicon URL
            NSMutableDictionary *linkInfo = [NSMutableDictionary dictionary];
            linkInfo[@"type"] = @"link";
            linkInfo[@"url"] = urlString;
            if (title.length > 0) linkInfo[@"title"] = title;
            // 从 URL 提取 favicon
            NSURL *parsedURL = [NSURL URLWithString:urlString];
            if (parsedURL.scheme && parsedURL.host) {
                linkInfo[@"icon"] = [NSString stringWithFormat:@"%@://%@/favicon.ico", parsedURL.scheme, parsedURL.host];
            }

            NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupId];
            [shared setObject:@[linkInfo] forKey:kShareDataKey];
            [shared synchronize];

            [self openMainApp];
        });
    }];
}

- (void)loadProvider:(NSItemProvider *)provider
              typeId:(NSString *)typeId
            fileType:(NSString *)fileType
           fileInfos:(NSMutableArray *)fileInfos
          completion:(void(^)(void))completion {

    [provider loadItemForTypeIdentifier:typeId options:nil completionHandler:^(id<NSSecureCoding> rawItem, NSError *error) {
        if (error) {
            completion();
            return;
        }

        id item = (id)rawItem;
        NSURL *sourceURL = nil;
        NSData *data = nil;

        if ([item isKindOfClass:[NSURL class]]) {
            sourceURL = (NSURL *)item;
        } else if ([item isKindOfClass:[NSData class]]) {
            data = (NSData *)item;
        } else if ([item isKindOfClass:[UIImage class]]) {
            data = UIImageJPEGRepresentation((UIImage *)item, 0.9);
        }

        if (!sourceURL && !data) {
            completion();
            return;
        }

        // 复制到 App Group 共享目录
        NSURL *sharedDir = [self sharedDirectory];
        NSString *fileName;
        if (sourceURL) {
            fileName = sourceURL.lastPathComponent;
        } else {
            NSString *ext = [fileType isEqualToString:@"image"] ? @"jpg" : @"dat";
            fileName = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], ext];
        }

        NSURL *destURL = [sharedDir URLByAppendingPathComponent:fileName];
        NSError *copyError = nil;

        if (sourceURL) {
            if ([sourceURL startAccessingSecurityScopedResource]) {
                [[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:destURL error:&copyError];
                [sourceURL stopAccessingSecurityScopedResource];
            } else {
                [[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:destURL error:&copyError];
            }
        } else if (data) {
            [data writeToURL:destURL options:NSDataWritingAtomic error:&copyError];
        }

        if (!copyError) {
            @synchronized (fileInfos) {
                [fileInfos addObject:@{
                    @"type": fileType,
                    @"fileName": fileName,
                    @"path": destURL.path
                }];
            }
        }

        completion();
    }];
}

- (void)finishWithFileInfos:(NSArray *)fileInfos {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (fileInfos.count == 0) {
            [self completeWithError];
            return;
        }

        // 保存文件信息到共享 UserDefaults
        NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupId];
        [shared setObject:fileInfos forKey:kShareDataKey];
        [shared synchronize];

        // 跳转主 App
        [self openMainApp];
    });
}

- (void)openMainApp {
    NSURL *url = [NSURL URLWithString:@"botgate://share"];

    // iOS 18+: 必须用非 deprecated 的 open:options:completionHandler:
    // 通过 responder chain 找到 UIApplication 实例，直接 cast 调用
    UIResponder *responder = self;
    while (responder) {
        if ([responder isKindOfClass:[UIApplication class]]) {
            UIApplication *app = (UIApplication *)responder;
            [app openURL:url options:@{} completionHandler:^(BOOL success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
                });
            }];
            return;
        }
        responder = [responder nextResponder];
    }

    // fallback: 直接关闭
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

- (void)completeWithError {
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

#pragma mark - File Helpers

- (NSURL *)sharedDirectory {
    NSURL *container = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:kAppGroupId];
    NSURL *dir = [container URLByAppendingPathComponent:kShareDirName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir.path]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

- (void)cleanSharedDirectory {
    NSURL *dir = [self sharedDirectory];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:dir includingPropertiesForKeys:nil options:0 error:nil];
    for (NSURL *file in files) {
        [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
    }
}

@end

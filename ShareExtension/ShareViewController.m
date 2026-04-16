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
        } else if ([provider hasItemConformingToTypeIdentifier:UTTypeURL.identifier]) {
            [provider loadItemForTypeIdentifier:UTTypeURL.identifier options:nil completionHandler:^(id<NSSecureCoding> rawItem, NSError *error) {
                id item = (id)rawItem;
                NSURL *url = ([item isKindOfClass:[NSURL class]]) ? (NSURL *)item : nil;
                if (url && !error) {
                    @synchronized (fileInfos) {
                        [fileInfos addObject:@{@"type": @"text", @"content": url.absoluteString}];
                    }
                }
                pending--;
                if (pending <= 0) [self finishWithFileInfos:fileInfos];
            }];
        } else if ([provider hasItemConformingToTypeIdentifier:UTTypePlainText.identifier]) {
            [provider loadItemForTypeIdentifier:UTTypePlainText.identifier options:nil completionHandler:^(id<NSSecureCoding> rawItem, NSError *error) {
                id item = (id)rawItem;
                NSString *text = ([item isKindOfClass:[NSString class]]) ? (NSString *)item : nil;
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

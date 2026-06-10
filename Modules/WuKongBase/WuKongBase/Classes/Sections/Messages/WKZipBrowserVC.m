//
//  WKZipBrowserVC.m
//  WuKongBase
//

#import "WKZipBrowserVC.h"
#import "WKZipEntryCell.h"
#import "WKFileIconHelper.h"
#import "WKSafeFilePreviewVC.h"
#import "WuKongBase.h"
#import "WKApp.h"
#import "WKNavigationManager.h"
#import "UIView+WKCommon.h"
#import <SSZipArchive/SSZipArchive.h>
#import <YBImageBrowser/YBImageBrowser.h>
#import <YBImageBrowser/YBIBImageData.h>

#pragma mark - 图片扩展名判定

static BOOL WKZipIsImageExt(NSString *ext) {
    static NSSet *imageExts;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        imageExts = [NSSet setWithArray:@[@"png", @"jpg", @"jpeg", @"gif", @"bmp",
                                          @"webp", @"heic", @"heif", @"tiff", @"tif"]];
    });
    return [imageExts containsObject:ext.lowercaseString];
}

#pragma mark - 目录项模型

@interface WKZipEntry : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *fullPath;
@property (nonatomic, assign) BOOL isDirectory;
@property (nonatomic, assign) long long size;
@end

@implementation WKZipEntry
@end

#pragma mark - 浏览 VC

@interface WKZipBrowserVC ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *currentDir;   // 本页列出的目录
@property (nonatomic, copy) NSString *rootDir;      // 顶层解压目录(根 VC 负责清理)
@property (nonatomic, copy) NSString *displayTitle;
@property (nonatomic, assign) BOOL isRoot;          // 是否根 VC
@property (nonatomic, strong) NSArray<WKZipEntry *> *entries;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation WKZipBrowserVC

static NSString * const kZipEntryCellID = @"WKZipEntryCell";

#pragma mark - Init

- (instancetype)initWithExtractedRoot:(NSString *)rootDir displayTitle:(NSString *)title {
    self = [super init];
    if (self) {
        _rootDir = [rootDir copy];
        _currentDir = [rootDir copy];
        _displayTitle = [title copy];
        _isRoot = YES;
    }
    return self;
}

- (instancetype)initWithDirectory:(NSString *)dir rootDir:(NSString *)rootDir displayTitle:(NSString *)title {
    self = [super init];
    if (self) {
        _rootDir = [rootDir copy];
        _currentDir = [dir copy];
        _displayTitle = [title copy];
        _isRoot = NO;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.displayTitle;
    [self.navigationBar setShowBackButton:YES];
    [self loadEntries];
    [self.view addSubview:self.tableView];
}

- (NSString *)langTitle {
    return self.displayTitle ?: @"";
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:[self visibleRect] style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.backgroundColor = [WKApp shared].config.backgroundColor;
        _tableView.tableFooterView = [[UIView alloc] init];
        _tableView.rowHeight = 60;
        [_tableView registerClass:[WKZipEntryCell class] forCellReuseIdentifier:kZipEntryCellID];
    }
    return _tableView;
}

#pragma mark - 目录列举

- (void)loadEntries {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *names = [fm contentsOfDirectoryAtPath:self.currentDir error:nil];
    NSMutableArray<WKZipEntry *> *dirs = [NSMutableArray array];
    NSMutableArray<WKZipEntry *> *files = [NSMutableArray array];

    for (NSString *name in names) {
        // 跳过 zip 噪音
        if ([name isEqualToString:@"__MACOSX"] || [name hasPrefix:@"."]) {
            continue;
        }
        NSString *full = [self.currentDir stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:full isDirectory:&isDir]) {
            continue;
        }
        WKZipEntry *entry = [[WKZipEntry alloc] init];
        entry.name = name;
        entry.fullPath = full;
        entry.isDirectory = isDir;
        if (!isDir) {
            entry.size = [[fm attributesOfItemAtPath:full error:nil] fileSize];
            [files addObject:entry];
        } else {
            [dirs addObject:entry];
        }
    }

    NSComparator cmp = ^NSComparisonResult(WKZipEntry *a, WKZipEntry *b) {
        return [a.name localizedStandardCompare:b.name];
    };
    [dirs sortUsingComparator:cmp];
    [files sortUsingComparator:cmp];

    // 文件夹在前, 文件在后
    NSMutableArray *all = [NSMutableArray arrayWithArray:dirs];
    [all addObjectsFromArray:files];
    self.entries = all;
}

#pragma mark - UITableViewDataSource / Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKZipEntryCell *cell = [tableView dequeueReusableCellWithIdentifier:kZipEntryCellID forIndexPath:indexPath];
    WKZipEntry *entry = self.entries[indexPath.row];
    NSString *sizeText = entry.isDirectory ? nil : [WKFileIconHelper formatFileSize:entry.size];
    [cell configureWithName:entry.name
                isDirectory:entry.isDirectory
                        ext:entry.name.pathExtension
                   sizeText:sizeText];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WKZipEntry *entry = self.entries[indexPath.row];

    if (entry.isDirectory) {
        WKZipBrowserVC *child = [[WKZipBrowserVC alloc] initWithDirectory:entry.fullPath
                                                                 rootDir:self.rootDir
                                                            displayTitle:entry.name];
        // 用本窗口自己的导航控制器, 不能用 WKNavigationManager(那是主 App 的 nav)。
        [self.navigationController pushViewController:child animated:YES];
    } else if (WKZipIsImageExt(entry.name.pathExtension)) {
        // 图片 → 画廊浏览(左右滑切同目录其它图片 + 顶部计数), 复用 YBImageBrowser。
        [self openImageGalleryAtEntry:entry indexPath:indexPath];
    } else {
        NSURL *fileURL = [NSURL fileURLWithPath:entry.fullPath];
        WKSafeFilePreviewVC *preview = [[WKSafeFilePreviewVC alloc] initWithFileURL:fileURL title:entry.name];
        // push 实例到现有 nav; 切勿调 showFilePreview: (窗口已存在会早退)。
        [self.navigationController pushViewController:preview animated:YES];
    }
}

#pragma mark - 图片画廊

- (void)openImageGalleryAtEntry:(WKZipEntry *)tappedEntry indexPath:(NSIndexPath *)indexPath {
    // 收集当前目录所有图片(保持列表排序), 定位被点项的索引。
    NSMutableArray<YBIBImageData *> *images = [NSMutableArray array];
    NSInteger hitIdx = 0;
    UIImageView *projectiveView = nil;
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[WKZipEntryCell class]]) {
        // 缩放动画来源(被点 cell 的图标视图)。
        for (UIView *v in cell.contentView.subviews) {
            if ([v isKindOfClass:[UIImageView class]]) { projectiveView = (UIImageView *)v; break; }
        }
    }
    for (WKZipEntry *e in self.entries) {
        if (e.isDirectory || !WKZipIsImageExt(e.name.pathExtension)) continue;
        YBIBImageData *data = [YBIBImageData new];
        data.imagePath = e.fullPath;
        if (e == tappedEntry) {
            hitIdx = images.count;
            data.projectiveView = projectiveView;
        }
        [images addObject:data];
    }
    if (images.count == 0) return;

    YBImageBrowser *browser = [YBImageBrowser new];
    browser.dataSourceArray = images;
    browser.currentPage = hitIdx;   // 必须放在 dataSourceArray 之后(0-based, 项目约定)
    [browser show];                 // 保留默认 toolView, 才有内置「x/y」计数
}

#pragma mark - 返回 (pop-or-dismiss)

- (void)backPressed {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        NSString *root = self.rootDir;
        [WKSafeFilePreviewVC dismissPreview];
        // 滑出后台清理解压目录(延后避免预览 webView 正读文件被删)。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                       dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [[NSFileManager defaultManager] removeItemAtPath:root error:nil];
        });
    }
}

#pragma mark - 入口编排: 密码 + 解压 + 开窗

+ (void)openZipAtPath:(NSString *)zipPath title:(NSString *)title clientMsgNo:(NSString *)msgNo {
    if (zipPath.length == 0) return;

    if ([SSZipArchive isFilePasswordProtectedAtPath:zipPath]) {
        [self promptPasswordForZip:zipPath title:title clientMsgNo:msgNo retry:NO];
    } else {
        [self extractZip:zipPath password:nil title:title clientMsgNo:msgNo];
    }
}

+ (void)promptPasswordForZip:(NSString *)zipPath
                       title:(NSString *)title
                 clientMsgNo:(NSString *)msgNo
                       retry:(BOOL)retry {
    NSString *message = retry ? LLang(@"密码错误，请重新输入") : nil;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"请输入解压密码")
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull tf) {
        tf.secureTextEntry = YES;
        tf.placeholder = LLang(@"密码");
    }];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *pw = alert.textFields.firstObject.text ?: @"";
        NSError *err = nil;
        if ([SSZipArchive isPasswordValidForArchiveAtPath:zipPath password:pw error:&err]) {
            [self extractZip:zipPath password:pw title:title clientMsgNo:msgNo];
        } else {
            [self promptPasswordForZip:zipPath title:title clientMsgNo:msgNo retry:YES];
        }
    }]];
    [[WKNavigationManager shared].topViewController presentViewController:alert animated:YES completion:nil];
}

+ (void)extractZip:(NSString *)zipPath
          password:(NSString *)password
             title:(NSString *)title
       clientMsgNo:(NSString *)msgNo {
    // 唯一临时目录: 不同消息互不冲突, 重开同一消息刷新。
    NSString *folder = msgNo.length > 0 ? msgNo : @(zipPath.hash).stringValue;
    NSString *destDir = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"WKZipPreview"]
                         stringByAppendingPathComponent:folder];

    UIView *hudHost = [WKNavigationManager shared].topViewController.view;
    MBProgressHUD *hud = [hudHost showHUDWithDim];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:destDir error:nil];
        [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSError *err = nil;
        BOOL ok = [SSZipArchive unzipFileAtPath:zipPath
                                  toDestination:destDir
                                      overwrite:YES
                                       password:password
                                          error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hideAnimated:YES];
            if (ok) {
                WKZipBrowserVC *vc = [[WKZipBrowserVC alloc] initWithExtractedRoot:destDir displayTitle:title];
                [WKSafeFilePreviewVC showRootViewController:vc];
            } else {
                [hudHost showMsg:LLang(@"解压失败")];
            }
        });
    });
}

@end

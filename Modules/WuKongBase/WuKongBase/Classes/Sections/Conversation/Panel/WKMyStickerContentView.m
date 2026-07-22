//
//  WKMyStickerContentView.m
//  WuKongBase
//

#import "WKMyStickerContentView.h"
#import "WKStickerGIFCell.h"
#import "WKStickerCollectAddCell.h"
#import "WKStickerGIFContentView.h"
#import "WKCollectionViewGridLayout.h"
#import "WKStickerPackage.h"
#import "WKStickerImageView.h"
#import "WKLottieStickerContent.h"
#import "WKStickerUploadService.h"
#import "WKStickerLocalOrderStore.h"
#import "WKPhotoBrowser.h"
#import "WKNavigationManager.h"
#import "WKAPIClient.h"
#import "WKApp.h"
#import "WKConstant.h"
#import "WKLoginInfo.h"
#import "WKLogs.h"
#import "UIView+WK.h"
#import "UIView+WKCommon.h"
#import "WKStickerContentView.h"
#import "WKActionSheetView2.h"
#import "WKActionSheetItem2.h"

// 长按 ≥0.4s 直接进入抖动编辑模式；不再走 UIContextMenuInteraction。
// 保持够短（跟 iOS 桌面「长按图标进抖动」阈值一致），减少用户等待感。
static const NSTimeInterval kEditLongPressDuration = 0.4;

@interface WKMyStickerContentView ()
    <UICollectionViewDataSource,
     UICollectionViewDelegate,
     UICollectionViewDragDelegate,
     UICollectionViewDropDelegate,
     UIContextMenuInteractionDelegate,
     UIGestureRecognizerDelegate>

@property(nonatomic,strong) UICollectionView *collectionView;
// item 0 是 AddCell，item 1..N 是表情。dataArray 存的是「表情模型」，不含 AddCell 占位
@property(nonatomic,strong) NSMutableArray<WKSticker *> *dataArray;
@property(nonatomic,strong) UILabel *emptyLabel;
@property(nonatomic,strong) UIImage *cachedTabIcon;
@property(nonatomic,assign) BOOL loaded;

// 编辑态
@property(nonatomic,assign) BOOL editing;
@property(nonatomic,strong) UILongPressGestureRecognizer *editEnterLongPress;
@property(nonatomic,strong) UITapGestureRecognizer *editExitTap;

// 上传中态
@property(nonatomic,assign) BOOL uploading;
@end

@implementation WKMyStickerContentView

- (instancetype)init {
    self = [super init];
    if (self) {
        _dataArray = [NSMutableArray array];
        self.backgroundColor = [WKApp shared].config.backgroundColor;

        [self addSubview:self.collectionView];
        [self addSubview:self.emptyLabel];

        // 编辑模式入口：长按 ≥0.7s
        _editEnterLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onEditEnterLongPress:)];
        _editEnterLongPress.minimumPressDuration = kEditLongPressDuration;
        _editEnterLongPress.delegate = self;
        [self.collectionView addGestureRecognizer:_editEnterLongPress];

        // 编辑退出：点空白
        _editExitTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onEditExitTap:)];
        _editExitTap.delegate = self;
        _editExitTap.enabled = NO;
        [self.collectionView addGestureRecognizer:_editExitTap];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onStickersUpdated:)
                                                     name:WKNOTIFY_STICKERS_UPDATED
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - WKStickerContentView 属性

- (UIImage *)tabIcon {
    if (!_cachedTabIcon) {
        _cachedTabIcon = [[self class] buildTabIcon];
    }
    return _cachedTabIcon;
}

// 与 web 端 sticker tab SVG 一致：24×24 圆角矩形 + 两个眼睛 + 微笑弧线
// 参考 octo-web/packages/dmworkbase/src/Components/EmojiToolbar/index.tsx:616-621
+ (UIImage *)buildTabIcon {
    CGSize size = CGSizeMake(24, 24);
    UIColor *color = [WKApp shared].config.defaultTextColor ?: [UIColor labelColor];

    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    [color setStroke];
    [color setFill];

    // 圆角矩形 (3,3) 18×18 rx=5，描边 1.8
    UIBezierPath *rect = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 3, 18, 18) cornerRadius:5];
    rect.lineWidth = 1.8;
    [rect stroke];

    // 眼睛 (9,10) r=1.2, (15,10) r=1.2 填充
    UIBezierPath *leftEye  = [UIBezierPath bezierPathWithArcCenter:CGPointMake(9, 10)  radius:1.2 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
    UIBezierPath *rightEye = [UIBezierPath bezierPathWithArcCenter:CGPointMake(15, 10) radius:1.2 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
    [leftEye fill];
    [rightEye fill];

    // 微笑弧线（近似 <path d="M8.5 14 a3.5 2.5 0 0 0 7 0">）
    // 从 (8.5, 14) 经过底部弧到 (15.5, 14)，向下鼓起
    UIBezierPath *smile = [UIBezierPath bezierPath];
    smile.lineWidth = 1.6;
    smile.lineCapStyle = kCGLineCapRound;
    [smile moveToPoint:CGPointMake(8.5, 14)];
    [smile addQuadCurveToPoint:CGPointMake(15.5, 14) controlPoint:CGPointMake(12, 17.2)];
    [smile stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    if (!selected) {
        // 离开 tab 时兜底退出编辑态，避免 tab 复用时残留
        if (self.editing) {
            [self exitEditMode];
        }
    }
    // 播放态：让所有可见 gif 动起来 / 停下来
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        if ([cell isKindOfClass:WKStickerGIFCell.class]) {
            [(WKStickerGIFCell *)cell onWillDisplay];
        }
    }
}

#pragma mark - loadData

- (void)loadData {
    // 先用当前 collectStickers 立即渲染，避免打开面板闪空
    [self applyStickers:[WKApp shared].collectStickers];
    // 首次登录或未拉取过时，触发拉取
    __weak typeof(self) weakSelf = self;
    [[WKApp shared] loadCollectStickersIfNeed].then(^{
        [weakSelf applyStickers:[WKApp shared].collectStickers];
    });
    // 无论有无缓存，都后台再拉一次做 silent refresh，避免多端不一致
    if (self.loaded) {
        [[WKApp shared] loadCollectStickers].then(^{
            [weakSelf applyStickers:[WKApp shared].collectStickers];
        });
    }
    self.loaded = YES;
}

- (void)applyStickers:(NSArray<WKSticker *> *)serverList {
    NSString *uid = [WKApp shared].loginInfo.uid;
    NSArray<WKSticker *> *merged = [[WKStickerLocalOrderStore shared] mergeServerList:serverList forUID:uid];
    WKLogInfo(@"[MyStickerTab] applyStickers server=%lu merged=%lu uid=%@",
              (unsigned long)serverList.count, (unsigned long)merged.count, uid);
    for (WKSticker *s in merged) {
        NSURL *full = [[WKApp shared] getFileFullUrl:s.path];
        WKLogInfo(@"[MyStickerTab]   sticker path='%@' format='%@' width=%@ height=%@ fullURL=%@",
                  s.path, s.format, s.width, s.height, full);
    }
    [self.dataArray removeAllObjects];
    if (merged.count > 0) [self.dataArray addObjectsFromArray:merged];
    [self.collectionView reloadData];
    [self refreshEmptyState];
    // 数据变了，编辑态如果开着，也保持开着（× 会重新绑定）
}

- (void)onStickersUpdated:(NSNotification *)note {
    [self applyStickers:[WKApp shared].collectStickers];
}

- (void)refreshEmptyState {
    self.emptyLabel.hidden = !(self.dataArray.count == 0 && !self.editing && !self.uploading);
}

#pragma mark - layout

- (void)layoutSubviews {
    [super layoutSubviews];
    self.collectionView.frame = self.bounds;
    self.emptyLabel.frame = CGRectInset(self.bounds, 20, 40);
    self.emptyLabel.center = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0 + 30);
}

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        // 与 WKStickerGIFContentView 一致的 5 列 grid，视觉对齐（那边同名类方法是私有的，此处直连 layout 定义）
        WKCollectionViewGridLayout *layout = [WKCollectionViewGridLayout new];
        layout.itemSpacing = 10;
        layout.lineSpacing = 10;
        layout.lineSize = 0;
        layout.lineItemCount = 5;
        layout.scrollDirection = UICollectionViewScrollDirectionVertical;
        layout.sectionsStartOnNewLine = NO;
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.alwaysBounceVertical = YES;
        _collectionView.showsVerticalScrollIndicator = NO;
        // 左右各留 12pt 避免边缘 cell 贴边（视觉上「两侧过紧」）；上下也留出面板呼吸空间
        _collectionView.contentInset = UIEdgeInsetsMake(8, 12, 12, 12);
        [_collectionView registerClass:WKStickerGIFCell.class forCellWithReuseIdentifier:[WKStickerGIFCell reuseIdentifier]];
        [_collectionView registerClass:WKStickerCollectAddCell.class forCellWithReuseIdentifier:[WKStickerCollectAddCell reuseIdentifier]];
        if (@available(iOS 11.0, *)) {
            _collectionView.dragDelegate = self;
            _collectionView.dropDelegate = self;
            _collectionView.dragInteractionEnabled = NO; // 编辑态才开
        }
    }
    return _collectionView;
}

- (UILabel *)emptyLabel {
    if (!_emptyLabel) {
        _emptyLabel = [[UILabel alloc] init];
        _emptyLabel.text = LLangW(@"还没有表情，点 + 添加", self);
        _emptyLabel.textColor = [[WKApp shared].config.defaultTextColor colorWithAlphaComponent:0.5] ?: [UIColor grayColor];
        _emptyLabel.textAlignment = NSTextAlignmentCenter;
        _emptyLabel.font = [UIFont systemFontOfSize:13.0];
        _emptyLabel.numberOfLines = 0;
        _emptyLabel.hidden = YES;
    }
    return _emptyLabel;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.dataArray.count + 1; // +1 for Add cell
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item == 0) {
        WKStickerCollectAddCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[WKStickerCollectAddCell reuseIdentifier] forIndexPath:indexPath];
        return cell;
    }
    WKStickerGIFCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[WKStickerGIFCell reuseIdentifier] forIndexPath:indexPath];
    WKSticker *sticker = self.dataArray[indexPath.item - 1];
    sticker.isPlay = self.selected;
    sticker.isEdit = NO; // WKStickerGIFCell 里 isEdit 走 checkBox 路径（整理页用），本 tab 用抖动，不启 checkBox
    [cell refresh:sticker];
    cell.allowLongPress = NO; // 关闭旧路径的 WKStickerBigViewModal 长按预览，本 tab 用 UIContextMenuInteraction
    [cell setEditMode:self.editing];
    __weak typeof(self) weakSelf = self;
    __weak typeof(cell) weakCell = cell;
    cell.onDeleteBadgeTap = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSIndexPath *ip = [strongSelf.collectionView indexPathForCell:weakCell];
        if (!ip) return;
        [strongSelf confirmDeleteAtIndexPath:ip];
    };
    // 编辑态：给 cell 装 UIContextMenuInteraction，用户再次长按弹放大预览 + 菜单。
    // 非编辑态：卸载 interaction，避免与「长按 0.4s 进抖动」手势打架。
    if (@available(iOS 13.0, *)) {
        if (self.editing) {
            [cell installContextMenuWithDelegate:self context:self];
        } else {
            [cell uninstallContextMenu];
        }
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:WKStickerGIFCell.class]) {
        [(WKStickerGIFCell *)cell onWillDisplay];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:WKStickerGIFCell.class]) {
        [(WKStickerGIFCell *)cell onEndDisplay];
    }
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item == 0) {
        // 加号按下：先退出编辑态（如果在），再开相册
        if (self.editing) [self exitEditMode];
        [self onAddButtonTapped];
        return;
    }
    if (self.editing) {
        // 编辑态下点普通 cell 视为退出编辑，跟 iOS 桌面隐喻一致
        [self exitEditMode];
        return;
    }
    WKSticker *sticker = self.dataArray[indexPath.item - 1];
    [self sendSticker:sticker];
}

- (void)sendSticker:(WKSticker *)sticker {
    if (!sticker || !self.context) return;
    WKLottieStickerContent *content = [WKLottieStickerContent new];
    content.url = sticker.path;
    content.category = sticker.category;
    content.placeholder = sticker.placeholder;
    content.format = sticker.format;
    [self.context sendMessage:content];
    // 轻震动，与常规发送反馈对齐
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
}

#pragma mark - Add: 加号 → 相册 → 上传

- (void)onAddButtonTapped {
    if (self.uploading) return;
    UIViewController *topVC = [[WKNavigationManager shared] topViewController];
    if (!topVC) {
        WKLogError(@"WKMyStickerContentView: no topViewController for photo picker");
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[WKPhotoBrowser shared] showPhotoLibraryWithSender:topVC
                                  selectCompressImageBlock:^(NSArray<NSData *> * _Nonnull images, NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (images.count == 0 || !strongSelf) return;
        [strongSelf uploadImageData:images.firstObject];
    } allowSelectVideo:NO];
}

- (void)uploadImageData:(NSData *)data {
    self.uploading = YES;
    [self refreshEmptyState];
    UIViewController *topVC = [[WKNavigationManager shared] topViewController];
    UIView *topView = topVC.view ?: self;
    // 上传中态用居中 HUD 保留原有 spinner；结果反馈走 showMsg（与"添加到关注"toast 一致）
    [topView showHUD];
    __weak typeof(self) weakSelf = self;
    [WKStickerUploadService uploadStickerData:data
                                     progress:nil
                                   completion:^(WKSticker * _Nullable sticker, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.uploading = NO;
        [topView hideHud];
        if (error) {
            NSString *msg = [strongSelf messageForUploadError:error];
            [topView showMsg:msg];
        } else {
            [topView showMsg:LLangW(@"已添加到我的表情", strongSelf)];
            [strongSelf applyStickers:[WKApp shared].collectStickers];
        }
    }];
}

- (NSString *)messageForUploadError:(NSError *)error {
    // WKStickerUploadService 会把服务端返回的原始 msg（如"贴纸尺寸不能超过 512×512 像素"、
    // "贴纸大小不能超过 1024KB"、"贴纸格式不允许：heic"）塞到 userInfo[NSLocalizedDescriptionKey]。
    // 优先直接透传服务端 msg —— 服务端才是限制的唯一 source of truth（web StickerUploadConfig
    // 也是 remote config 下发的），iOS 侧不再自己包装文案。
    NSString *serverMsg = error.userInfo[NSLocalizedDescriptionKey];
    if (serverMsg.length > 0) return serverMsg;
    // 兜底：服务端没给 msg（网络断/超时等），走本地文案。
    if ((WKStickerUploadError)error.code == WKStickerUploadErrorQuotaExceeded) {
        return LLangW(@"我的表情已达上限", self);
    }
    return LLangW(@"添加表情失败", self);
}

#pragma mark - Delete

- (void)confirmDeleteAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item < 1 || indexPath.item - 1 >= self.dataArray.count) return;
    WKSticker *sticker = self.dataArray[indexPath.item - 1];
    // 用工程通用的 WKActionSheetView2 底部弹出确认（与会话列表「删除会话」/「加入黑名单」/
    // 「退出群聊」等入口视觉一致，不用系统 UIAlertController）
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:LLangW(@"删除的表情无法恢复", self)];
    __weak typeof(self) weakSelf = self;
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLangW(@"删除", self) onClick:^{
        [weakSelf deleteSticker:sticker];
    }]];
    [sheet show];
}

- (void)deleteSticker:(WKSticker *)sticker {
    // 服务端 DELETE 是 RESTful `/sticker/user/:sticker_id`（modules/sticker/api.go:121）；
    // 老的 `DELETE sticker/user body {paths}` 现在会 404。sticker_id 是服务端主键，
    // WKSticker.fromMap: 已从 response 的 sticker_id 字段解出。
    NSString *sid = sticker.stickerID;
    if (sid.length == 0) {
        WKLogError(@"[MyStickerTab] deleteSticker missing sticker_id, path=%@", sticker.path);
        UIView *topView = [[WKNavigationManager shared] topViewController].view ?: self;
        [topView showMsg:LLangW(@"删除表情失败", self)];
        return;
    }
    __weak typeof(self) weakSelf = self;
    NSString *encodedID = [sid stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]] ?: sid;
    NSString *path = [NSString stringWithFormat:@"sticker/user/%@", encodedID];
    WKLogInfo(@"[MyStickerTab] DELETE %@", path);
    [[WKAPIClient sharedClient] DELETE:path parameters:nil].then(^{
        // 直接同步内存缓存，UI 立即反馈；后端删除已完成
        NSMutableArray<WKSticker *> *arr = [([WKApp shared].collectStickers ?: @[]) mutableCopy];
        NSMutableArray<WKSticker *> *removed = [NSMutableArray array];
        for (WKSticker *s in arr) {
            if (s.stickerID.length > 0 && [s.stickerID isEqualToString:sid]) [removed addObject:s];
        }
        [arr removeObjectsInArray:removed];
        [WKApp shared].collectStickers = [arr copy];
        [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_STICKERS_UPDATED object:nil];
        UINotificationFeedbackGenerator *gen = [UINotificationFeedbackGenerator new];
        [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
    }).catch(^(NSError *error){
        WKLogError(@"[MyStickerTab] DELETE FAIL sid=%@ err=%@", sid, error);
        NSString *serverMsg = error.userInfo[NSLocalizedDescriptionKey];
        if (serverMsg.length == 0) serverMsg = error.domain;
        UIView *topView = [[WKNavigationManager shared] topViewController].view ?: weakSelf;
        [topView showMsg:serverMsg.length > 0 ? serverMsg : LLangW(@"删除表情失败", weakSelf)];
    });
}

#pragma mark - Edit mode

- (void)onEditEnterLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint pt = [g locationInView:self.collectionView];
    NSIndexPath *ip = [self.collectionView indexPathForItemAtPoint:pt];
    if (!ip || ip.item == 0) return; // 加号 cell 不进编辑态
    if (self.editing) return;
    [self enterEditMode];
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
}

- (void)onEditExitTap:(UITapGestureRecognizer *)g {
    CGPoint pt = [g locationInView:self.collectionView];
    NSIndexPath *ip = [self.collectionView indexPathForItemAtPoint:pt];
    // 点空白（未命中 cell）或点到 + cell → 退出编辑
    // 命中普通 cell 的点击由 didSelectItemAtIndexPath 里的兜底逻辑处理，避免与本 tap 冲突
    if (!ip || ip.item == 0) {
        [self exitEditMode];
    }
}

- (void)enterEditMode {
    if (self.editing) return;
    self.editing = YES;
    self.editExitTap.enabled = YES;
    // 关掉「长按进抖动」手势 —— 已在编辑态，再次长按应触发 UIContextMenuInteraction 弹预览，
    // 让两者独占长按不打架。
    self.editEnterLongPress.enabled = NO;
    if (@available(iOS 11.0, *)) {
        self.collectionView.dragInteractionEnabled = YES;
    }
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        if ([cell isKindOfClass:WKStickerGIFCell.class]) {
            WKStickerGIFCell *sc = (WKStickerGIFCell *)cell;
            [sc setEditMode:YES];
            if (@available(iOS 13.0, *)) {
                [sc installContextMenuWithDelegate:self context:self];
            }
        }
    }
    [self refreshEmptyState];
}

- (void)exitEditMode {
    if (!self.editing) return;
    self.editing = NO;
    self.editExitTap.enabled = NO;
    // 恢复「长按进抖动」入口
    self.editEnterLongPress.enabled = YES;
    if (@available(iOS 11.0, *)) {
        self.collectionView.dragInteractionEnabled = NO;
    }
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        if ([cell isKindOfClass:WKStickerGIFCell.class]) {
            WKStickerGIFCell *sc = (WKStickerGIFCell *)cell;
            [sc setEditMode:NO];
            if (@available(iOS 13.0, *)) {
                [sc uninstallContextMenu];
            }
        }
    }
    [self refreshEmptyState];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)other {
    // 编辑退出 tap 需要等 collectionView 的默认 tap 判定完；不做特殊处理直接放行即可
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == self.editExitTap) {
        // 落在 × 徽章上的点击让 badge 自己处理，不触发退出编辑
        UIView *hit = touch.view;
        while (hit && hit != self.collectionView) {
            if ([hit isKindOfClass:UIButton.class]) return NO;
            hit = hit.superview;
        }
    }
    return YES;
}

#pragma mark - UIContextMenuInteractionDelegate (iOS 13+，仅编辑态)

// 编辑态下再次长按 cell 弹放大预览 + action 菜单（发送 / 删除）。
// 非编辑态由 uninstallContextMenu 保证此 delegate 不会被触发。
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                            configurationForMenuAtLocation:(CGPoint)location API_AVAILABLE(ios(13.0)) {
    if (!self.editing) return nil;
    // 从 interaction.view (cell.contentView) 反查 cell
    UIView *v = interaction.view;
    WKStickerGIFCell *cell = nil;
    while (v) {
        if ([v isKindOfClass:WKStickerGIFCell.class]) { cell = (WKStickerGIFCell *)v; break; }
        v = v.superview;
    }
    if (!cell || !cell.currentSticker) return nil;
    WKSticker *sticker = cell.currentSticker;
    __weak typeof(self) weakSelf = self;
    __weak typeof(cell) weakCell = cell;

    UIContextMenuContentPreviewProvider previewProvider = ^UIViewController * _Nullable {
        return [weakSelf previewViewControllerForSticker:sticker];
    };
    UIContextMenuActionProvider actionProvider = ^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        UIAction *send = [UIAction actionWithTitle:LLangW(@"发送", weakSelf) image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf sendSticker:sticker];
        }];
        UIAction *del = [UIAction actionWithTitle:LLangW(@"删除", weakSelf) image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            NSIndexPath *ip = [weakSelf.collectionView indexPathForCell:weakCell];
            if (ip) [weakSelf confirmDeleteAtIndexPath:ip];
        }];
        del.attributes = UIMenuElementAttributesDestructive;
        return [UIMenu menuWithTitle:@"" children:@[send, del]];
    };
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                    previewProvider:previewProvider
                                                     actionProvider:actionProvider];
}

- (UIViewController *)previewViewControllerForSticker:(WKSticker *)sticker API_AVAILABLE(ios(13.0)) {
    UIViewController *vc = [UIViewController new];
    CGSize sz = CGSizeMake(180, 180);
    vc.preferredContentSize = sz;
    UIView *bg = vc.view;
    bg.backgroundColor = [WKApp shared].config.backgroundColor ?: [UIColor systemBackgroundColor];
    WKStickerImageView *iv = [[WKStickerImageView alloc] initWithFrame:CGRectMake(16, 16, sz.width - 32, sz.height - 32)];
    iv.placehoderSvg = sticker.placeholder;
    iv.stickerURL = [[WKApp shared] getFileFullUrl:sticker.path];
    iv.isPlay = YES;
    [bg addSubview:iv];
    return vc;
}

#pragma mark - Drag & Drop (iOS 11+, 编辑态限定)

- (NSArray<UIDragItem *> *)collectionView:(UICollectionView *)collectionView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (!self.editing) return @[];
    if (indexPath.item == 0) return @[];
    if (indexPath.item - 1 >= self.dataArray.count) return @[];
    WKSticker *sticker = self.dataArray[indexPath.item - 1];
    NSItemProvider *provider = [[NSItemProvider alloc] initWithObject:sticker.path ?: @""];
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:provider];
    item.localObject = sticker;
    return @[item];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canHandleDropSession:(id<UIDropSession>)session API_AVAILABLE(ios(11.0)) {
    return self.editing;
}

- (UICollectionViewDropProposal *)collectionView:(UICollectionView *)collectionView
              dropSessionDidUpdate:(id<UIDropSession>)session
              withDestinationIndexPath:(NSIndexPath *)destinationIndexPath API_AVAILABLE(ios(11.0)) {
    if (destinationIndexPath && destinationIndexPath.item == 0) {
        // 不允许拖到 + cell 之前的位置
        return [[UICollectionViewDropProposal alloc] initWithDropOperation:UIDropOperationForbidden];
    }
    return [[UICollectionViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UICollectionViewDropIntentInsertAtDestinationIndexPath];
}

- (void)collectionView:(UICollectionView *)collectionView performDropWithCoordinator:(id<UICollectionViewDropCoordinator>)coordinator API_AVAILABLE(ios(11.0)) {
    NSIndexPath *dest = coordinator.destinationIndexPath;
    if (!dest || dest.item == 0) return;
    for (id<UICollectionViewDropItem> item in coordinator.items) {
        NSIndexPath *src = item.sourceIndexPath;
        WKSticker *sticker = (WKSticker *)item.dragItem.localObject;
        if (!src || !sticker) continue;
        NSInteger fromIdx = src.item - 1;
        NSInteger toIdx = dest.item - 1;
        if (fromIdx < 0 || fromIdx >= self.dataArray.count) continue;
        if (toIdx < 0) toIdx = 0;
        if (toIdx > self.dataArray.count - 1) toIdx = self.dataArray.count - 1;
        [self.collectionView performBatchUpdates:^{
            [self.dataArray removeObjectAtIndex:fromIdx];
            [self.dataArray insertObject:sticker atIndex:toIdx];
            [self.collectionView moveItemAtIndexPath:src toIndexPath:dest];
        } completion:nil];
        [coordinator dropItem:item.dragItem toItemAtIndexPath:dest];
        // 服务端目前没有 reorder / front API（`PUT /sticker/user/front` 已废弃 404），
        // 所以拖拽后只在本地 order store 持久化，跨端不同步。
    }
    [self persistLocalOrder];
}

- (void)persistLocalOrder {
    NSString *uid = [WKApp shared].loginInfo.uid;
    if (uid.length == 0) return;
    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithCapacity:self.dataArray.count];
    for (WKSticker *s in self.dataArray) {
        if (s.path.length > 0) [paths addObject:s.path];
    }
    [[WKStickerLocalOrderStore shared] saveOrder:paths forUID:uid];
}

@end

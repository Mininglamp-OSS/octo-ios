//
//  WKStickerCollectionVC.m
//  WuKongBase
//
//  Created by apple-2 on 2021/10/22.
//

#import "WKStickerCollectionVC.h"
#import "WKCollectionViewGridLayout.h"
#import "WKStickerGIFCell.h"
#import "WKStickerPackage.h"
#import "WKLottieStickerContent.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "WKStickerCollectAddCell.h"
#import <ZLPhotoBrowser/ZLPhotoBrowser-Swift.h>
#import "WKStickerUploadService.h"
#import "WKStickerLocalOrderStore.h"
#import "WKConstant.h"
#import "WKLoginInfo.h"

@interface WKStickerCollectionVC () <UICollectionViewDataSource,UICollectionViewDelegate>

@property (nonatomic, strong) UIButton *rightBtn;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) WKCollectionViewGridLayout *newGridLayout;
@property(nonatomic,assign) BOOL isEdit; //编辑模式

@property(nonatomic,strong) UIView *footerView;
@property(nonatomic,strong) UIButton *moveFontBtn; // 移到最前
@property(nonatomic,strong) UIButton *deleteBtn; // 删除

@end


@implementation WKStickerCollectionVC

#pragma makr ->
- (void)viewDidLoad {
    [super viewDidLoad];
    [self establishControlsInStickerCollectionVC];

    [self.view addSubview:self.footerView];
}

- (NSString *)langTitle {
    return LLang(@"添加单个表情");
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if (type != WKViewConfigChangeTypeLang) return;
    if (_rightBtn) [_rightBtn setTitle:LLang(@"整理") forState:UIControlStateNormal];
    if (_moveFontBtn) [_moveFontBtn setTitle:LLang(@"移到最前") forState:UIControlStateNormal];
    if (_deleteBtn) [_deleteBtn setTitle:LLang(@"删除") forState:UIControlStateNormal];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    NSString *string = @"RefreshStickerColllected";
    if (_isEdit) {
        [self rrightBtnEvnetInStickerCollectionVC];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:string
                                                        object:nil userInfo:@{string:_dataArray}];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    
}


#pragma mark -> UI Controls
- (void)establishControlsInStickerCollectionVC {
    if (!_dataArray) {
        _dataArray = @[].mutableCopy;
    }
    self.view.backgroundColor = UIColor.whiteColor;
    _isEdit = NO;
    self.rightView = self.rightBtn; // 暂时关闭整理，因为还不完善
    [self.view addSubview:self.collectionView];
}

- (UIButton *)rightBtn {
    if (!_rightBtn) {
        _rightBtn = [[UIButton alloc] initWithFrame:CGRectMake(0 , 0, 46, 44)];
        [_rightBtn setTitle:LLang(@"整理") forState:UIControlStateNormal];
        [[_rightBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:15.0f]];
        [_rightBtn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        [_rightBtn addTarget:self action:@selector(rrightBtnEvnetInStickerCollectionVC)
            forControlEvents:UIControlEventTouchUpInside];
    }
    return _rightBtn;
}

- (WKCollectionViewGridLayout *)newGridLayout {
    if (!_newGridLayout) {
        _newGridLayout = [WKCollectionViewGridLayout new];
        _newGridLayout.itemSpacing = 5;
        _newGridLayout.lineSpacing = 5;
        _newGridLayout.lineSize = 0;
        _newGridLayout.lineItemCount = 4;
        _newGridLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
        _newGridLayout.sectionsStartOnNewLine = NO;
    }
    return _newGridLayout;
}

- (UICollectionView *)collectionView {
    if(!_collectionView) {

        CGRect visibleRect = self.visibleRect;
        _collectionView = [[UICollectionView alloc] initWithFrame:visibleRect
                                             collectionViewLayout:self.newGridLayout];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.backgroundColor =  WKApp.shared.config.backgroundColor;
        [_collectionView setContentInset:UIEdgeInsetsMake(5.0f, 5.0f, 5.0f, 5.0f)];
        [_collectionView registerClass:[WKStickerGIFCell class] forCellWithReuseIdentifier:[WKStickerGIFCell reuseIdentifier]];
        [_collectionView registerClass:[WKStickerCollectAddCell class] forCellWithReuseIdentifier:[WKStickerCollectAddCell reuseIdentifier]];
    }
    return _collectionView;
}

- (UIView *)footerView {
    if(!_footerView) {
        CGFloat height = 80.0f;
        _footerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.view.lim_height, WKScreenWidth, height)];
        _footerView.backgroundColor = WKApp.shared.config.cellBackgroundColor;
        
        [_footerView addSubview:self.moveFontBtn];
        [_footerView addSubview:self.deleteBtn];
        
        self.moveFontBtn.lim_left = 15.0f;
        self.moveFontBtn.lim_top = 15.0f;
        
        self.deleteBtn.lim_left = _footerView.lim_width - self.deleteBtn.lim_width - 15.0f;
        self.deleteBtn.lim_top = self.moveFontBtn.lim_top;
    }
    return _footerView;
}

-(void) showFooterView:(BOOL)show {
    
    [UIView animateWithDuration:0.2f animations:^{
        if(show) {
            self.footerView.alpha = 1.0f;
            self.collectionView.lim_height = self.visibleRect.size.height - self.footerView.lim_height;
            self.footerView.lim_top = self.view.lim_height - self.footerView.lim_height;
        }else {
            self.footerView.alpha = 0.0f;
            self.collectionView.lim_height = self.visibleRect.size.height;
            self.footerView.lim_top = self.view.lim_height;
        }
    }];
   
}

- (UIButton *)moveFontBtn {
    if(!_moveFontBtn) {
        _moveFontBtn = [[UIButton alloc] init];
        [_moveFontBtn setTitle:LLang(@"移到最前") forState:UIControlStateNormal];
        [_moveFontBtn.titleLabel setFont:[WKApp.shared.config appFontOfSize:14.0f]];
        [_moveFontBtn setTitleColor:WKApp.shared.config.defaultTextColor forState:UIControlStateNormal];
        [_moveFontBtn setTitleColor:[UIColor colorWithRed:200.0f/255.0f green:200.0f/255.0f blue:200.0f/255.0f alpha:1.0f] forState:UIControlStateDisabled];
        [_moveFontBtn addTarget:self action:@selector(moveFontPressed) forControlEvents:UIControlEventTouchUpInside];
        [_moveFontBtn setEnabled:NO];
        [_moveFontBtn sizeToFit];
    }
    return _moveFontBtn;
}

- (UIButton *)deleteBtn {
    if(!_deleteBtn) {
        _deleteBtn = [[UIButton alloc] init];
        [_deleteBtn setTitle:LLang(@"删除") forState:UIControlStateNormal];
        [_deleteBtn.titleLabel setFont:[WKApp.shared.config appFontOfSize:14.0f]];
        [_deleteBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [_deleteBtn setTitleColor:[UIColor colorWithRed:200.0f/255.0f green:200.0f/255.0f blue:200.0f/255.0f alpha:1.0f] forState:UIControlStateDisabled];
        [_deleteBtn setEnabled:NO];
        [_deleteBtn sizeToFit];
        
        [_deleteBtn addTarget:self action:@selector(deletePressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _deleteBtn;
}

-(void) refreshFootViewStatus {
    if([self stickerHasSelected]) {
        [self.deleteBtn setEnabled:YES];
        [self.moveFontBtn setEnabled:YES];
    }else {
        [self.deleteBtn setEnabled:NO];
        [self.moveFontBtn setEnabled:NO];
    }
    if(self.dataArray.count==1) {
        [self.moveFontBtn setEnabled:NO];
    }
}

-(BOOL) stickerHasSelected {
    for (id model in self.dataArray) {
        if([model isKindOfClass:[WKSticker class]]) {
            WKSticker *sticker = (WKSticker*)model;
            if(sticker.isSelected) {
                return YES;
            }
        }
    }
    return NO;
}

-(void) deletePressed {
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:LLang(@"删除的表情无法恢复")];
    __weak typeof(self) weakSelf = self;
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"删除") onClick:^{
        [weakSelf deleteEmojisInStickerCollectionVC];
    }]];
    
    [sheet show];
    
}

-(void) moveFontPressed {
    [self stickerMoveFont];
}


#pragma mark -> Delegates
#pragma mark -> UICollectionViewDataSource && UICollectionViewDelegate
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _dataArray.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    id cellModel =   _dataArray[indexPath.row];
    NSString *identifier;
    if([cellModel isKindOfClass:[WKStickerCollectAddCellModel class]]) { // add
        identifier = [WKStickerCollectAddCell reuseIdentifier];
    }else {
        identifier = [WKStickerGIFCell reuseIdentifier];
    }
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(WKStickerGIFCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    id cellModel =   _dataArray[indexPath.row];
    if([cellModel isKindOfClass:[WKStickerCollectAddCellModel class]]) { // add
        
    }else {
        WKSticker *sticker = (WKSticker*)cellModel;
        __weak typeof(self) weakSelf = self;
        [cell setOnCheck:^(BOOL on) {
            [weakSelf refreshFootViewStatus];
        }];
        [cell refresh:sticker];
        [cell onWillDisplay];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if([cell isKindOfClass:[WKStickerGIFCell class]]) {
        [(WKStickerGIFCell*)cell onEndDisplay];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    id cellModel = _dataArray[indexPath.row];
    if([cellModel isKindOfClass:[WKStickerCollectAddCellModel class]]) {
        [self openAlbumInStickerCollectionVC];
    }
    return;
}


#pragma mark -> Events
- (void)rrightBtnEvnetInStickerCollectionVC {
    if (_dataArray && _dataArray.count > 1) {
        _isEdit = !_isEdit;
        if (_isEdit) {
            [self showFooterView:YES];
            [_rightBtn setTitle:LLang(@"完成") forState:UIControlStateNormal];
            [_dataArray removeObjectAtIndex:0];
            self.footerView.hidden = NO;
        }
        else {
            [self showFooterView:NO];
//            [self deleteEmojisInStickerCollectionVC];
            [_rightBtn setTitle:LLang(@"整理") forState:UIControlStateNormal];
            [_dataArray insertObject:[self setDefaultSticker] atIndex:0];
        }
        for (id model in _dataArray) {
            if([model isKindOfClass:[WKSticker class]]) {
                WKSticker *resp = (WKSticker*)model;
                resp.isSelected = NO;
                resp.isEdit = _isEdit;
            }
           
        }
        [_collectionView reloadData];
        [self refreshFootViewStatus];
    }
    return;
}


#pragma mark -> Private Methods
//打开相册
- (void)openAlbumInStickerCollectionVC {
    __weak typeof(self) weakSelf = self;
    
    [[WKPhotoBrowser shared] showPhotoLibraryWithSender:self selectCompressImageBlock:^(NSArray<NSData *> * _Nonnull images, NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal) {
        if(images.count>0) {
            [weakSelf getNewEmojiAddressInStickerCollectionVC:images[0]];
        }
        
    } allowSelectVideo:NO];
    
//    [self.mediaFetcher fetchPhotoFromLibraryOfCompress:^(NSData *imageData,NSString *path,bool isSelectOriginalPhoto, PHAssetMediaType type,NSInteger left) {
//        switch (type) {
//                case PHAssetMediaTypeImage:{
//                    NSData *gifData = imageData;
//                    SDImageFormat imgFormat = [NSData sd_imageFormatForImageData:gifData];
//                    if(imgFormat != SDImageFormatGIF) {
//                        gifData = [[SDImageGIFCoder sharedCoder] encodedDataWithImage:[[UIImage alloc] initWithData:imageData] format:SDImageFormatGIF options:0]; // 将所有自定义表情图片转换为gif格式 因为android只支持gif
//                    }
//
//                    [weakSelf getNewEmojiAddressInStickerCollectionVC:gifData];
//                }
//                    break;
//                case PHAssetMediaTypeVideo:
//                case PHAssetMediaTypeAudio:
//                case PHAssetMediaTypeUnknown:
//                break;
//        }
//    } cancel:nil];
}


#pragma mark -> 添加单个表情
// 上传委托给 WKStickerUploadService（下面这版沿用两步走：COS 预签名 → PUT → POST /sticker/user，
// 内含本地校验 + 主线程 HUD 反馈 + STICKERS_UPDATED 广播）。
// 老的完整实现保留在下方注释，作为回滚参考。
- (void)getNewEmojiAddressInStickerCollectionVC:(NSData *)imageData {
    __weak typeof(self) weakSelf = self;
    [self.view showHUD];
    [WKStickerUploadService uploadStickerData:imageData
                                     progress:nil
                                   completion:^(WKSticker * _Nullable sticker, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            // 优先透传服务端 msg（在 userInfo[NSLocalizedDescriptionKey]），让用户看到具体原因
            NSString *msg = error.userInfo[NSLocalizedDescriptionKey];
            if (msg.length == 0) {
                if ((WKStickerUploadError)error.code == WKStickerUploadErrorQuotaExceeded) {
                    msg = LLangW(@"我的表情已达上限", strongSelf);
                } else {
                    msg = LLangW(@"上传失败", strongSelf);
                }
            }
            [strongSelf.view switchHUDError:msg];
            return;
        }
        [strongSelf getAllEmojisInStickerCollectionVC];
        [strongSelf.view hideHud];
    }];
}

//获取新数据
- (void)getAllEmojisInStickerCollectionVC {
    __weak typeof(self) weakSelf = self;

    [WKApp.shared loadCollectStickers].then(^(NSArray *stickerArray){
        [weakSelf.dataArray removeAllObjects];

        // 与「我的表情」tab 保持同一顺序：走本地 order merge
        NSString *uid = [WKApp shared].loginInfo.uid;
        NSArray *merged = [[WKStickerLocalOrderStore shared] mergeServerList:stickerArray forUID:uid];

        NSMutableArray *array = @[[weakSelf setDefaultSticker]].mutableCopy;
        [array addObjectsFromArray:merged];

        [weakSelf.dataArray addObjectsFromArray:array];
        [weakSelf.collectionView reloadData];
    });
}

- (WKStickerCollectAddCellModel *)setDefaultSticker {
    WKStickerCollectAddCellModel *defaultModel = [WKStickerCollectAddCellModel new];
//    defaultModel.isDefault = YES;
//    defaultModel.defaultName = @"icon_emoji_CollecetNew";
    return defaultModel;
}

//删除多个表情
// 服务端 DELETE 是 RESTful `/sticker/user/:sticker_id`（modules/sticker/api.go:121）；
// 老的 `DELETE sticker/user body {paths}` 已 404。这里逐个删除（选中量通常个位数）。
- (void)deleteEmojisInStickerCollectionVC {
    NSMutableArray<WKSticker *> *deleteModelArray = @[].mutableCopy;
    for (WKSticker *resp in _dataArray) {
        if ([resp isKindOfClass:WKSticker.class] && resp.isSelected) {
            [deleteModelArray addObject:resp];
        }
    }
    if (deleteModelArray.count == 0) return;

    [_dataArray removeObjectsInArray:deleteModelArray];
    [self.collectionView reloadData];

    for (WKSticker *sticker in deleteModelArray) {
        NSString *sid = sticker.stickerID;
        if (sid.length == 0) continue;
        NSString *encoded = [sid stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]] ?: sid;
        NSString *path = [NSString stringWithFormat:@"sticker/user/%@", encoded];
        [[WKAPIClient sharedClient] DELETE:path parameters:nil];
    }
    [self refreshFootViewStatus];

    // 同步内存缓存 + 广播 —— 让「我的表情」tab 立即刷新
    NSMutableArray<WKSticker *> *cache = [([WKApp shared].collectStickers ?: @[]) mutableCopy];
    NSMutableArray<WKSticker *> *toRemoveFromCache = [NSMutableArray array];
    for (WKSticker *m in deleteModelArray) {
        for (WKSticker *c in cache) {
            if (c.stickerID.length > 0 && [c.stickerID isEqualToString:m.stickerID]) {
                [toRemoveFromCache addObject:c];
            }
        }
    }
    [cache removeObjectsInArray:toRemoveFromCache];
    [WKApp shared].collectStickers = [cache copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_STICKERS_UPDATED object:nil];
}

// 移到最前
// 服务端目前没有 reorder / front API（`PUT /sticker/user/front` 已废弃 404），
// 只能在本地 order store 里改顺序，多端不同步。
-(void) stickerMoveFont {
    NSMutableArray *moveArray = @[].mutableCopy;
    for (WKSticker *resp in _dataArray) {
        if ([resp isKindOfClass:WKSticker.class] && resp.isSelected) {
            [moveArray addObject:resp];
            resp.isSelected = NO;
        }
    }
    if (moveArray.count == 0) return;

    [self.dataArray removeObjectsInArray:moveArray];
    NSMutableArray *newDataArray = [NSMutableArray array];
    [newDataArray addObjectsFromArray:moveArray];
    [newDataArray addObjectsFromArray:self.dataArray];
    self.dataArray = newDataArray;
    [self.collectionView reloadData];
    [self refreshFootViewStatus];

    NSString *uid = [WKApp shared].loginInfo.uid;
    NSMutableArray<NSString *> *orderPaths = [NSMutableArray array];
    for (id item in self.dataArray) {
        if ([item isKindOfClass:WKSticker.class]) {
            NSString *p = ((WKSticker *)item).path;
            if (p.length > 0) [orderPaths addObject:p];
        }
    }
    [[WKStickerLocalOrderStore shared] saveOrder:orderPaths forUID:uid];
    [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_STICKERS_UPDATED object:nil];
}


#pragma mark -> Public Methods
- (void)setDataArray:(NSMutableArray *)dataArray {
    _dataArray = dataArray;
    [_collectionView reloadData];
}

@end

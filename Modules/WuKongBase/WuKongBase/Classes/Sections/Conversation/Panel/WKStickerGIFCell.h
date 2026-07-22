//
//  WKStickerGIFCell.h
//  WuKongBase
//
//  Created by tt on 2020/2/1.
//

#import "WuKongBase.h"
#import "WKStickerPackage.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKStickerGIFCell : UICollectionViewCell

@property(nonatomic,copy) void(^onCheck)(BOOL on);

// 「我的贴纸」tab 编辑态下点左上角 × 时回调（不与 onCheck 冲突：抖动编辑模式和批量勾选是两套 UI）
@property(nonatomic,copy) void(^onDeleteBadgeTap)(void);

@property(nonatomic,assign) BOOL allowLongPress; // 是否允许长按（旧路径的 WKStickerBigViewModal 预览）

@property(nonatomic,assign,readonly) BOOL editModeOn;

+(NSString *)reuseIdentifier;

-(void) onWillDisplay;

-(void) onEndDisplay;

-(void) refresh:(WKSticker*)sticker;

// 「我的贴纸」抖动编辑模式：cell 层加 wobble 动画 + 左上角 × 显示。
// GIF tab 不调此方法，零回归。
- (void)setEditMode:(BOOL)editing;

// 挂载 UIContextMenuInteraction 的 delegate（iOS 13+）。
// 「我的贴纸」tab 会给每个 cell 装一次，长按 ~0.4s 触发系统预览 + action 菜单。
// GIF tab 不调此方法，不装 interaction。
- (void)installContextMenuWithDelegate:(id<UIContextMenuInteractionDelegate>)delegate
                              context:(nullable id)context
    API_AVAILABLE(ios(13.0));

// 卸载 UIContextMenuInteraction。退出「我的贴纸」抖动编辑模式时调，避免非编辑态
// 长按也弹预览（否则跟「长按进抖动」手势打架）。
- (void)uninstallContextMenu API_AVAILABLE(ios(13.0));

// 供 context menu delegate 在回调里反查当前渲染的贴纸模型
@property(nonatomic,strong,readonly,nullable) WKSticker *currentSticker;
// 挂 delegate 时传进来的 context（如所在的 WKMyStickerContentView 实例），弱引用
@property(nonatomic,weak,readonly,nullable) id contextMenuContext;

@end

NS_ASSUME_NONNULL_END

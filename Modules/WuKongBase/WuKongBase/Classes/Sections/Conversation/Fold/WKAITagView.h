//
//  WKAITagView.h
//  WuKongBase
//
//  AI 协作 / AI 助手 小标签（pill 形）。对齐 web
//  `packages/dmworkbase/src/Components/Conversation/index.tsx:1851-1903` 标题行的
//  AI Tag 部分。i18n key 与 web 一致（aiAssistant / aiCollaboration），展示串走
//  Localizable.strings。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKAITagStyle) {
    WKAITagStyleAssistant,     // 1 个参与 bot → "AI 助手"
    WKAITagStyleCollaboration, // ≥2 个参与 bot → "AI 协作"
};

@interface WKAITagView : UIView
@property(nonatomic, assign) WKAITagStyle style;
- (void)applyStyle:(WKAITagStyle)style;
@end

NS_ASSUME_NONNULL_END

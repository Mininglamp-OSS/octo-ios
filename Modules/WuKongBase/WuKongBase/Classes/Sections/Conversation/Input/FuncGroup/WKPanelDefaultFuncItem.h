//
//  WKPanelDefaultFuncItem.h
//  WuKongBase
//
//  Created by tt on 2020/2/23.
//

#import <Foundation/Foundation.h>
#import "WKPanelFuncItemProto.h"
#import "WKFuncGroupEditItemModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKPanelDefaultFuncItem : NSObject<WKPanelFuncItemProto>

@property(nonatomic,weak) WKConversationInputPanel *inputPanel;

@property(nonatomic,assign) NSInteger sort; // 排序

@property(nonatomic,assign) BOOL disable; // 是否禁用

@property(nonatomic,assign) WKFuncGroupEditItemType type;

@property(nonatomic,assign) WKChannelType channelType; // 所属频道类型

-(NSString*) sid; // 唯一ID

-(UIImage*) itemIcon;

-(NSString*) panelID;

-(void) onPressed:(UIButton*)btn;

-(UIImage*) getImageNameForBase:(NSString*)name;

// 运行时合成一张与 Conversation/Toolbar/*Normal.pdf 同款风格的图标
// （紫色渐变 squircle 背景 + 白色 SF Symbol），供缺少美术资源的 item 兜底。
+ (UIImage *)fallbackToolbarIconWithSymbolName:(NSString *)symbolName;

-(NSString*) title;





@end

@interface WKPanelEmojiFuncItem : WKPanelDefaultFuncItem

@end

@interface WKPanelMentionFuncItem : WKPanelDefaultFuncItem

@end

@interface WKPanelVoiceFuncItem : WKPanelDefaultFuncItem

@end

@interface WKPanelImageFuncItem : WKPanelDefaultFuncItem

@end

@interface WKPanelMoreFuncItem : WKPanelDefaultFuncItem

@end

@interface WKPanelCardFuncItem : WKPanelDefaultFuncItem

@end

@interface WKPanelFileFuncItem : WKPanelDefaultFuncItem

@end


NS_ASSUME_NONNULL_END

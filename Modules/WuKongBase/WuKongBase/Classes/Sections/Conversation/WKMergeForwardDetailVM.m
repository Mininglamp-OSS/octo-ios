//
//  WKMergeForwardDetailVM.m
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import "WKMergeForwardDetailVM.h"

#import "WKMergeForwardDetailCell.h"
#import "WKConstant.h"

@implementation WKMergeForwardDetailVM

- (NSArray<NSDictionary *> *)tableSectionMaps {

    NSMutableArray *items = [NSMutableArray array];
    NSString *title = @"";

    // YUJ-130 / Web PR#981-982 对齐：把 WKMergeForwardContent.users 里每个
    // 成员的外部群字段（is_external / source_space_name / home_space_*）按
    // uid 建立 map，后续传给 Cell 做 viewer-relative「 @SpaceName」渲染。
    NSMutableDictionary<NSString*, NSDictionary*> *uidToUserExtras = [NSMutableDictionary dictionary];
    if(self.mergeForwardContent.users && self.mergeForwardContent.users.count > 0) {
        for (NSDictionary *userDict in self.mergeForwardContent.users) {
            if(![userDict isKindOfClass:[NSDictionary class]]) continue;
            NSString *uid = userDict[@"uid"];
            if([uid isKindOfClass:[NSString class]] && uid.length > 0) {
                uidToUserExtras[uid] = userDict;
            }
        }
    }

    if(self.mergeForwardContent.msgs && self.mergeForwardContent.msgs.count>0) {
        NSInteger firstTime = self.mergeForwardContent.msgs[0].timestamp;
        NSInteger lastTime = self.mergeForwardContent.msgs[self.mergeForwardContent.msgs.count-1].timestamp;
        
        NSDateFormatter * formatter=[[NSDateFormatter alloc]init];
        [formatter setDateFormat:@"YYYY-MM-dd"];
        
        NSString *firstDateStr=[formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:firstTime]];
        NSString *lastDateStr=[formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:lastTime]];
        if(![firstDateStr isEqualToString:lastDateStr]) {
            title = [NSString stringWithFormat:@"%@ ~ %@",firstDateStr,lastDateStr];
        }else{
            title = [NSString stringWithFormat:@"%@",firstDateStr];
        }
        
        WKMessage *preMessage;
        for (WKMessage *message in self.mergeForwardContent.msgs) {
            if(!message || !message.content) {
                continue;
            }
            Class modelCls;
            BOOL hideAvatar;
            if(preMessage && [message.fromUid isEqualToString:preMessage.fromUid]) {
                hideAvatar = YES;
            }else{
                hideAvatar = NO;
            }

            switch (message.contentType) {
                case WK_TEXT:
                    if([message.content isKindOfClass:[WKTextContent class]]) {
                        modelCls = WKMergeForwardDetailTextModel.class;
                    } else {
                        modelCls = WKMergeForwardDetailOtherModel.class;
                    }
                    break;
                case WK_IMAGE:
                    modelCls = WKMergeForwardDetailImageModel.class;
                    break;
                case WK_VOICE:
                    modelCls = WKMergeForwardDetailOtherModel.class;
                    break;
                case WK_SMALLVIDEO:
                    modelCls = WKMergeForwardDetailVideoModel.class;
                    break;
                case WK_FILE:
                    if([message.content isKindOfClass:[WKFileContent class]]) {
                        modelCls = WKMergeForwardDetailFileModel.class;
                    } else {
                        modelCls = WKMergeForwardDetailOtherModel.class;
                    }
                    break;
                case WK_MERGEFORWARD:
                    if([message.content isKindOfClass:[WKMergeForwardContent class]]) {
                        modelCls = WKMergeForwardDetailNestedModel.class;
                    } else {
                        modelCls = WKMergeForwardDetailOtherModel.class;
                    }
                    break;
                default:
                    modelCls = [WKApp.shared.endpointManager mergeForwardItem:message.contentType];
                    if(!modelCls) {
                        modelCls = WKMergeForwardDetailOtherModel.class;
                    }
                    break;
            }
            [items addObject:@{
                @"class":modelCls,
                @"message": message,
                @"hideAvatar": @(hideAvatar),
                @"userExtras": (message.fromUid && uidToUserExtras[message.fromUid]) ? uidToUserExtras[message.fromUid] : [NSNull null],
            }];
            preMessage = message;
        }
    }
    
    return @[
        @{
            @"height":@(30.0f),
            @"headView": [[WKMergeForwardDetailHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 20.0f) title:title],
            @"items":items,
            
        }
    ];
}

@end

//
//  WKForbiddenSpeakTimeSelectVM.m
//  WuKongBase
//
//  Created by tt on 2022/3/25.
//

#import "WKForbiddenSpeakTimeSelectVM.h"

@interface WKForbiddenSpeakTimeSelectVM ()

@property(nonatomic,assign) NSInteger selectedIndex;


@end

@implementation WKForbiddenSpeakTimeSelectVM


-(NSDictionary*) getTimeLabelItem:(NSString*)time selected:(BOOL)selected onClick:(void(^)(void)) onClick{
    
    return @{
        @"class":WKLabelItemSelectModel.class,
        @"label":time,
        @"showArrow": @(false),
        @"selected": @(selected),
        @"onClick":onClick,
    };
}

- (NSArray<NSDictionary *> *)tableSectionMaps {
    
    NSArray *timeItems = @[@[LLang(@"1分钟"),@(60)],@[LLang(@"10分钟"),@(60*10)],@[LLang(@"1小时"),@(60*60)],@[LLang(@"1天"),@(60*60*24)],@[LLang(@"7天"),@(60*60*24*7)],@[LLang(@"30天"),@(60*60*24*30)]];
    if(self.selectSeconds <= 0) {
        self.selectSeconds = ((NSNumber*)timeItems[0][1]).intValue;
    }
    
    NSMutableArray *items = [NSMutableArray array];
    BOOL isCustom = true;
    for(NSInteger i=0;i<timeItems.count;i++) {
        NSArray *times =  timeItems[i];
        NSInteger second = ((NSNumber*)times[1]).intValue;
        __weak typeof(self) weakSelf = self;
        BOOL selected = self.selectSeconds == second;
        if(selected) {
            isCustom = false;
            self.selectedIndex = i;
        }
        [items addObject: [self getTimeLabelItem:times[0] selected:selected onClick:^{
            weakSelf.selectSeconds = second;
            [weakSelf reloadData];
        }]];
    }
    NSString *customTime = @"";
    if(isCustom && self.selectSeconds>0) {
        NSInteger day = self.selectSeconds/(60*60*24);
        NSInteger hour = (self.selectSeconds%(60*60*24))/(60*60);
        NSInteger minute = ((self.selectSeconds%(60*60*24))%(60*60))/60;
        if(day<=0 && hour <=0) {
            customTime = [NSString stringWithFormat:@"%ld分钟",(long)minute];
        }else if(day<=0 && hour>0) {
            customTime = [NSString stringWithFormat:@"%ld小时%ld分",(long)hour,(long)minute];
        }else if(day>0) {
            customTime = [NSString stringWithFormat:@"%ld天%ld小时%ld分",(long)day,(long)hour,(long)minute];
        }
    }
    __weak typeof(self) weakSelf = self;
//    [items addObject: @{
//        @"class":WKLabelItemSelectModel.class,
//        @"label":LLang(@"自定义"),
//        @"value": customTime,
//        @"showArrow": @(false),
//        @"onClick":^{
//            [self.delegate forbiddenSpeakTimeSelectVMDidCustomTime:self];
//        }
//    }];
    
    return @[
        @{
            @"height":@(0.0f),
            @"items": items,
        },
        @{
            @"height":@(20.0f),
            @"items": @[
                @{
                    @"class":WKButtonItemModel2.class,
                    @"title":LLang(@"确认"),
                    @"onPressed":^{
                        [weakSelf requestForbidden];
                    }
                }
            ],
        }
    ];
}

-(void) requestForbidden {
    UIView *topView = [WKNavigationManager shared].topViewController.view;
    [topView showHUD];
    [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"groups/%@/forbidden_with_member",self.channel.channelId] parameters:@{
        @"member_uid":self.uid,
        @"action":@(1),
        @"key": @(self.selectedIndex+1),
    }].then(^{
        [topView hideHud];
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }).catch(^(NSError *error){
        [topView hideHud];
        [topView showHUDWithHide:error.domain];
    });
}


@end

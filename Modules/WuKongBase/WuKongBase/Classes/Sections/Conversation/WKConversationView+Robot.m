//
//  WKConversationView+Robot.m
//  WuKongBase
//
//  Created by tt on 2022/5/20.
//

#import "WKConversationView+Robot.h"
#import "WuKongBase.h"
#import "WKConversationContextImpl.h"
#import "WKInlineQueryResult.h"
#import "WKInlineQueryManager.h"
@implementation WKConversationView (Robot)


-(void) initRobot {
    __weak typeof(self) weakSelf = self;
    
    [[WKApp shared] setMethod:WKPOINT_ROBOT_INPUT_TEXT_CHANGE handler:^id _Nullable(id  _Nonnull param) {
        [weakSelf inputTextChange];
        return nil;
    } category:WKPOINT_CATEGORY_CONVERSATION_INPUT_TEXT_CHANGE];
    
    [self.input.menusBtn setOnClick:^(BOOL open) {
        [weakSelf showRobotMenus:open];
    }];
   
}


-(void) inputTextChange {

    [self triggerRobotInlineSearchIfNeed];
    
    if(self.robotInlineOn && self.currentRobotInline && self.currentRobotInline.inlineOn) {
        NSString *text = self.input.textView.text;
        NSString *lang = self.input.textView.internalTextView.textInputMode.primaryLanguage;
        if ([lang isEqualToString:@"zh-Hans"]){
            UITextRange *selectedRange = [self.input.textView.internalTextView markedTextRange];
            if (selectedRange) {// 高亮不执行
                return;
            }
        }
        NSArray<NSString*> *splits = [text componentsSeparatedByString:@" "];
        if(splits.count>1) {
            NSString *query = [text substringFromIndex:splits[0].length];
            query = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [self requestAndShowRobotInlineQuery:query username:self.currentRobotInline.username offset:@""];
        }
    }
}


-(void) requestAndShowRobotInlineQuery:(NSString*)query username:(NSString*)username offset:(NSString*)offset{
    __weak typeof(self) weakSelf = self;
    
    [self requestInlineQuery:query username:username offset:offset].then(^(WKInlineQueryResult *result){
        [weakSelf showInlineQueryView:result query:query username:username];
    }).catch(^(NSError *error){
        WKLogError(@"提交robot查询数据失败！->%@",error);
    });
}

-(AnyPromise*) requestInlineQuery:(NSString*)query username:(NSString*)username offset:(NSString*)offset {
    return [[WKAPIClient sharedClient] POST:@"robot/inline_query" parameters:@{
        @"username":username,
        @"query": query,
        @"offset":offset?:@"",
        @"channel_id": self.channel.channelId,
        @"channel_type": @(self.channel.channelType),
    } model:WKInlineQueryResult.class];
}

-(void) showInlineQueryView:(WKInlineQueryResult*)result query:(NSString*)query username:(NSString*)username{
    if(!self.robotInlineOn) {
        return;
    }
    if(result.results && result.results.count>0) {
        __weak typeof(self) weakSelf = self;
        WKResultPanel *panel = [[WKInlineQueryManager shared] createResultPanel:result context:self.conversationContext];
        [panel setLoadMore:^(NSString *nextOffset,WKLoadMoreCallback callback) {
            [weakSelf requestInlineQuery:query username:username offset:nextOffset].then(^(WKInlineQueryResult *result){
                callback(result,nil);
            }).catch(^(NSError *error){
                callback(nil,error);
            });
        }];
        [self.conversationContext setInputTopView:panel];
    }else {
        [self.conversationContext setInputTopView:nil];
    }
   
}

-(void) cancelInlineQuery {
    [self.conversationContext setInputTopView:nil];
}

-(void) triggerRobotInlineSearchIfNeed {

    if(![self canTriggerSearch]) {
        if(self.robotInlineOn) {
            self.robotInlineOn = false;
            [self cancelInlineQuery];
        }
        
        return;
    }
    
    if(self.robotInlineOn) {
        return;
    }
    
    self.robotInlineOn = true;
   
   NSString *text = self.input.textView.text;
    NSArray *splits = [text componentsSeparatedByString:@" "];
  
    NSString *robotUsername = [splits[0] substringFromIndex:1];
    __weak typeof(self) weakSelf = self;
   WKRobot *robot = [[WKRobotManager shared] getRobotWithUsername:robotUsername];
    if(!robot) {
        [[WKRobotManager shared] syncWithUsernames:@[robotUsername] complete:^(BOOL hasData, NSError * _Nonnull error) {
            if(error) {
                WKLogError(@"同步机器人[%@]数据失败！->%@",robotUsername,error);
                return;
            }
            if(hasData) {
                WKRobot *robot = [[WKRobotManager shared] getRobotWithUsername:robotUsername];
                weakSelf.currentRobotInline = robot;
            }
        }];
    }else{
        self.currentRobotInline = robot;
    }
}


-(BOOL) canTriggerSearch {
    NSString *text = self.input.textView.text;
    if(![text hasPrefix:@"@"]) {
        return false;
    }
//    if(self.mentionCache.itemCount>0) { // 有被选中@的人则不响应机器人
//        return false;
//    }
    if(![text containsString:@" "]) {
        return false;
    }
    return true;
}


-(void) syncRobot:(NSArray<NSString*>*) robotIDs {
    if(!robotIDs || robotIDs.count ==0) {
        return;
    }
    [self initRobotMenus:robotIDs];
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].robotManager sync:robotIDs complete:^(BOOL hasData,NSError * _Nonnull error) {
        if(error) {
            return;
        }
        if(hasData) {
            [weakSelf initRobotMenus:robotIDs];
        }
    }];
}

-(void) initRobotMenus:(NSArray<NSString*>*) robotIDs {
    NSArray<WKRobot*> *robots = [[WKRobotDB shared] queryRobots:robotIDs];
    NSMutableArray *menus = [NSMutableArray array];
    for (WKRobot *robot in robots) {
        if(robot.menus && robot.menus.count>0) {
            [menus addObjectsFromArray:robot.menus];
        }
    }
    self.robotMenus = menus;
    
    self.robotMenusModalView =  [self newRobotMenusModalView];
    
    if(menus && menus.count>0) {
        self.input.showMenusBtn = true;
    }
   
}

- (WKRobotMenusListView *)newRobotMenusModalView {
    WKRobotMenusListView *robotMenusModalView = [WKRobotMenusListView initItems:[self getRobotMenus]];
    robotMenusModalView.targetView = self.input;
    return robotMenusModalView;
}

-(NSArray<WKRobotMenusItem*>*) getRobotMenus {
    
    NSMutableArray *items = [NSMutableArray array];
    
    __weak typeof(self) weakSelf = self;
    if(self.robotMenus) {
        for (WKRobotMenus *m in self.robotMenus) {
            [items addObject:[WKRobotMenusItem cmd:m.cmd iconURL:[WKAvatarUtil getAvatar:m.robotID] remark:m.remark onClick:^{
                [weakSelf.conversationContext sendTextMessage:m.cmd entities:@[[WKMessageEntity type:WKEntityTypeRobotCommand range:NSMakeRange(0, m.cmd.length)]] robotID:m.robotID];
                [weakSelf dismissRobotMenus];
            }]];
        }
        
    }
    
    return items;
}

-(void) dismissRobotMenus {
    [self showRobotMenus:NO];
    self.input.menusBtn.openMenus = NO;
    [self.input.menusBtn changeStatus];
}


// 是否显示机器人菜单
#define robotMenusMinTop 120.0f
-(void) showRobotMenus:(BOOL) show {
    if(show) {
        self.robotMenusModalView.lim_top = self.input.lim_top;
        [self addSubview:self.robotMenusModalView];
        [self bringSubviewToFront:self.input];
        
        [UIView animateWithDuration:0.25f animations:^{
            self.robotMenusModalView.lim_top = self.input.lim_top - robotMenusMinTop;
        }];
    }else{
        [UIView animateWithDuration:0.25f animations:^{
            self.robotMenusModalView.lim_top = self.input.lim_top;
            [self.robotMenusModalView reset];
        } completion:^(BOOL finished) {
            [self.robotMenusModalView removeFromSuperview];
        }];
    }
}


-(void) adjustRobotMenusIfNeed {
    if(self.robotMenusModalView.superview) {
        self.robotMenusModalView.lim_top = self.input.lim_top - robotMenusMinTop;
    }
}


@end

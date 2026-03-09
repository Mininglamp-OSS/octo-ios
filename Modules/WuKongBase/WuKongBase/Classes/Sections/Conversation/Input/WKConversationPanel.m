//
//  WKConversationPanel.m
//  Session
//
//  Created by tt on 2018/10/9.
//
#define ColorSessionPanel [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0] // 会话里的面板的背景颜色

#define ColorSessionMessageInputBar [UIColor colorWithHexString:@"#f5f5f7"] // 会话里消息输入栏的颜色



#import "WKConversationPanel.h"
#import "UIView+WK.h"
#import "WKConstant.h"
#import "WKPanel.h"
#import "WKApp.h"
@interface WKConversationPanel()

@property(nonatomic,strong) UIView *currentPanel; // 当前面板

@property(nonatomic) NSString* currPanelPointId;
@end
@implementation WKConversationPanel

-(instancetype) init{
    self = [super init];
    if(!self)return nil;
    [self setBackgroundColor:ColorSessionPanel];
    return self;
}


-(BOOL) switchPanel:(WKChannel*)channel pointId:(NSString*)pointId{
    if (@available(iOS 10.0, *)) {
        static UISelectionFeedbackGenerator *feedbackSelection;
        if(!feedbackSelection) {
            feedbackSelection = [[UISelectionFeedbackGenerator alloc] init];
        }
        [feedbackSelection prepare];
        [feedbackSelection selectionChanged];
    }
   
//    [[UIDevice currentDevice] playInputClick]; // 播放input声音
    
    if(self.currentPanel) {
        [self.currentPanel removeFromSuperview];
    }
    
    [self initNewPanel:channel pointId:pointId];
    self.lim_size = CGSizeMake(WKScreenWidth, [self currentPanelHeight]);
    [self addSubview:self.currentPanel];
    return YES;
}

//- (BOOL)enableInputClicksWhenVisible{
//    return YES;
//}

-(void) initNewPanel:(WKChannel*)channel pointId:(NSString*)pointId{
    WKPanel *panel =  [self panelWithPointId:pointId context:self.conversationContext];
    if(panel) {
        _currPanelPointId = pointId;
        _currentPanel = panel;
         [panel layoutPanel:WKPanelDefaultHeight];
        _currentPanel.frame =CGRectMake(0,_currentPanel.lim_height, WKScreenWidth,_currentPanel.lim_height);
    }
}
-(CGFloat) currentPanelHeight {
    if(self.currentPanel) {
        return self.currentPanel.lim_height;
    }
    return 0.0;
}

/**
 通过类型获取面板
 
 @param pointId 面板pointId
 @return <#return value description#>
 */
-(WKPanel*) panelWithPointId:(NSString*) pointId context:(id<WKConversationContext>) context{
   
    return  [ [WKApp shared] invoke:pointId param:@{@"context":context}];
}

-(NSString*) currentPanelPointId{
    return _currPanelPointId;
}


-(void) adjustPanel:(CGFloat)panelHeight keyboardHeight:(CGFloat)keyboardHeight{
    if(keyboardHeight>0){
        self.currentPanel.lim_top = keyboardHeight;
    }else{
        if(panelHeight>0){
            self.currentPanel.lim_top = 0;
        }else{
            self.currentPanel.lim_top =[self safeBottom];
        }
    }
    
    
}
// iphoneX安全距离
- (CGFloat) safeBottom {
    CGFloat safeNum = 0;
    //判断版本
    if (@available(iOS 11.0, *)) {
        //通过系统方法keyWindow来获取safeAreaInsets
        UIEdgeInsets safeArea = [[UIApplication sharedApplication] keyWindow].safeAreaInsets;
        safeNum = safeArea.bottom;
    }
    return safeNum;
}

@end

//
//  WKEmojiPanel.m
//  WuKongBase
//
//  Created by tt on 2020/1/9.
//

#import "WKEmojiPanel.h"
#import "WKConstant.h"
#import "WKCollectionViewGridLayout.h"
#import "WKEmojiCell.h"
#import "WKTabPageView.h"
#import "WKResource.h"
#import "WKApp.h"
#import "WKEmojiContentView.h"
#import "WKEmoticonService.h"
#import "WKInputChangeTextRespondProto.h"
#import "UIView+WK.h"
#import "WKStickerManager.h"


@interface WKEmojiInputChangeTextRespondResult : NSObject<WKInputChangeRespondResult>

-(instancetype) initWithChangeText:(BOOL) changeText next:(BOOL) next;

@end

@implementation WKEmojiInputChangeTextRespondResult


-(instancetype) initWithChangeText:(BOOL) changeText next:(BOOL) next{
    self = [super init];
    if(self){
        self.changeText = changeText;
        self.next = next;
    }
    return self;
}

@synthesize changeText;

@synthesize next;

@end

@implementation WKEmojiInputChangeTextRespond


#pragma mark - WKInputChangeTextRespondProto
- (id<WKInputChangeRespondResult>)shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@""] && range.length == 1 ){
        NSRange range = [self delRangeForEmoticon];
        if (range.length == 1) {
            //自动删除
            return [[WKEmojiInputChangeTextRespondResult alloc] initWithChangeText:YES next:YES];
        }
        if(self.conversationContext){
            [self.conversationContext inputDeleteText:range];
        }
        return [[WKEmojiInputChangeTextRespondResult alloc] initWithChangeText:NO next:YES];
    }
    
    return nil;
}

- (NSRange)delRangeForEmoticon
{
    NSString *text = self.conversationContext.inputText;
    NSRange range = [self rangeForPrefix:@"[" suffix:@"]"];
    NSRange selectedRange = [self.conversationContext inputSelectedRange];
    if (range.length > 1)
    {
        NSString *name = [text substringWithRange:range];
        WKEmotion *emotion = [[WKEmoticonService shared] emotionByFaceName:name];
        range = emotion? range : NSMakeRange(selectedRange.location - 1, 1);
    }
    return range;
}

- (NSRange)rangeForPrefix:(NSString *)prefix suffix:(NSString *)suffix
{
    NSString *text = self.conversationContext.inputText;
    NSRange range = [self.conversationContext inputSelectedRange];
    NSString *selectedText = range.length ? [text substringWithRange:range] : text;
    NSInteger endLocation = range.location;
    if (endLocation <= 0)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger index = -1;
    if ([selectedText hasSuffix:suffix]) {
        //往前搜最多20个字符，一般来讲是够了...
        NSInteger p = 20;
        for (NSInteger i = endLocation; i >= endLocation - p && i-1 >= 0 ; i--)
        {
            NSRange subRange = NSMakeRange(i - 1, 1);
            NSString *subString = [text substringWithRange:subRange];
            if ([subString compare:prefix] == NSOrderedSame)
            {
                index = i - 1;
                break;
            }
        }
    }
    return index == -1? NSMakeRange(endLocation - 1, 1) : NSMakeRange(index, endLocation - index);
}


@synthesize conversationContext;

@end


@interface WKEmojiPanel () <WKTabPageViewDelegate,WKStickerManagerDelegate>

@property(nonatomic,strong) WKTabPageView *tabPageVIew;

@property(nonatomic,strong) NSArray<WKStickerContentView*> *panelContentNewList;

@property(nonatomic,strong) UIButton *stickerStoreBtn;

@end

@implementation WKEmojiPanel

-(instancetype) initWithContext:(id<WKConversationContext>)context {
    self = [super initWithContext:context];
    if (self) {
        [self.contentView addSubview:self.tabPageVIew];
        if([self hasStickerStore]) {
            [self.tabPageVIew addSubview:self.stickerStoreBtn];
        }
        
        self.panelContentNewList = [[WKApp shared] invokes:WKPOINT_CATEGORY_PANELCONTENT param:nil];
        
        [[WKStickerManager shared] addDelegate:self];
        
       
    }
    return self;
}

-(BOOL) hasStickerStore {
    return [[WKApp shared] hasMethod:WKPOINT_TO_STICKER_STORE];
}

- (void)dealloc
{
    [[WKStickerManager shared] removeDelegate:self];
}

-(WKTabPageView*) tabPageVIew {
    if(!_tabPageVIew) {
        _tabPageVIew = [[WKTabPageView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 0)];
        _tabPageVIew.delegate = self;
        if([self hasStickerStore]) {
            [_tabPageVIew setTabbarScrollViewLeftSpace:44.0f];
        }else {
            [_tabPageVIew setTabbarScrollViewLeftSpace:0.0f];
        }
        
    }
    return _tabPageVIew;
}

- (UIButton *)stickerStoreBtn {
    if(!_stickerStoreBtn) {
        _stickerStoreBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        [_stickerStoreBtn setImage:[self imageName:@"Conversation/Panel/IconStickerStore"] forState:UIControlStateNormal];
        _stickerStoreBtn.lim_left = 15.0f;
        [_stickerStoreBtn addTarget:self action:@selector(stickerStorePressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _stickerStoreBtn;
}

-(void) stickerStorePressed {
    [[WKApp shared] invoke:WKPOINT_TO_STICKER_STORE param:nil];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.stickerStoreBtn.lim_top = self.tabPageVIew.lim_bottom - 46.0f + (46.0f/2.0f - self.stickerStoreBtn.lim_height/2.0f);
    
}

-(void) layoutPanel:(CGFloat)height {
    [super layoutPanel:height];
    
    self.tabPageVIew.frame = self.contentView.bounds;
    
    
}

#pragma mark -- WKStickerManagerDelegate

- (void)stickerUserCategoryLoadFinished:(WKStickerManager *)manager {
    
    // 延迟一点执行 ，让WKPOINT_CATEGORY_PANELCONTENT注册完成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.panelContentNewList = [[WKApp shared] invokes:WKPOINT_CATEGORY_PANELCONTENT param:nil];
        [self.tabPageVIew reloadTabPageView];

    });
   
}


#pragma mark - WKTabPageViewDelegate

/**
 获取指定下标的正文视图
 
 @param tabPageView <#tabPageView description#>
 @param suggestContentFrame 建议正文视图的frame
 @param index 下标
 @return 正文视图
 */
-(UIView*) tabPageView:(WKTabPageView*) tabPageView suggestContentFrame:(CGRect)suggestContentFrame atIndex:(NSInteger)index {

    return [self newContentView:suggestContentFrame index:index];
}

-(UIView*) newContentView:(CGRect)suggestContentFrame index:(NSInteger) index {

    WKStickerContentView *contentView =self.panelContentNewList[index];
    contentView.frame = suggestContentFrame;
    contentView.context = self.context;
    [contentView setBackgroundColor:[WKApp shared].config.backgroundColor];
   
    [contentView loadData];
    return contentView;
}

/**
 获取指定下标的tab视图
 
 @param tabPageView <#tabPageView description#>
 @param suggestTabFrame 建议bar的frame
 @param index 下标
 @return bar视图
 */
-(UIView*) tabPageView:(WKTabPageView*)tabPageView suggestTabFrame:(CGRect)suggestTabFrame atIndex:(NSInteger) index {
   
    return [self newTaView:suggestTabFrame atIndex:index];
}

-(UIView*) newTaView:(CGRect)suggestTabFrame atIndex:(NSInteger)index{
    WKStickerContentView *contentView =self.panelContentNewList[index];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(suggestTabFrame.origin.x+(index==0?10:10.0f), suggestTabFrame.origin.y, 37.0f, 37.0f)];
    view.layer.masksToBounds = YES;
    view.layer.cornerRadius = 10.0f;
    CGFloat iconHeight =view.lim_height - 5.0f - 5.0f;
    CGFloat iconWidth =view.lim_width - 5.0f - 5.0f;
    
    if(contentView.customTabView){
        contentView.customTabView.frame = CGRectMake(view.frame.size.width/2.0f - iconWidth/2.0f,view.frame.size.height/2.0f - iconHeight/2.0f, iconWidth, iconHeight);
        [view addSubview:contentView.customTabView];
    }else  if([contentView tabIcon]) {
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(view.frame.size.width/2.0f - iconWidth/2.0f,view.frame.size.height/2.0f - iconHeight/2.0f, iconWidth, iconHeight)];
        imgView.image =[contentView tabIcon];
        [view addSubview:imgView];
    }
    
    return view;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
+(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
/**
 tab数量
 
 @param tabPageView <#tabPageView description#>
 @return <#return value description#>
 */
-(NSInteger) numOfTabPageView:(WKTabPageView*)tabPageView {
    return self.panelContentNewList?self.panelContentNewList.count:0;
}

// 发送按钮点击
- (void)didSendOfTabPageView:(nonnull WKTabPageView *)tabPageView {
    [self.context inputTextToSend];
}

-(void) didSelectOfTabPageView:(WKTabPageView*)tabPageView index:(NSInteger)index {
    for (NSInteger i=0; i<self.panelContentNewList.count; i++) {
        WKStickerContentView *contentView = self.panelContentNewList[i];
        
        if(index == i) {
            contentView.selected = true;
        }else {
            contentView.selected = false;
        }
    }

}


@end

@implementation WKEmojiTabBar


@end

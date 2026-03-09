//
//  WKFuncGroupView.m
//  WuKongBase
//
//  Created by tt on 2022/5/3.
//

#import "WKFuncGroupView.h"
#import "WKPanelFuncItemProto.h"
#import "WKFuncItemButton.h"
#import "WuKongBase.h"
#import "WKAPMManager.h"
#import "WKPanelDefaultFuncItem.h"
#define iconItemWidth 40.0f
#define iconItemHeight 30.0f

#define iconBigItemWidth 60.0f
#define iconBigItemHeight 45.0f

@class WKFuncGroupScrollView;

@protocol WKFuncGroupScrollDelegate <NSObject>


-(void) funcGroupScroll:(WKFuncGroupScrollView*)scrollView longPressStart:(UIEvent*)event;

-(void) funcGroupScroll:(WKFuncGroupScrollView*)scrollView longPressEnd:(UIEvent*)event;

@end

@interface WKFuncGroupScrollView : UIScrollView

@property(nonatomic,strong) UIEvent *beganEvent;
@property(nonatomic,weak) id<WKFuncGroupScrollDelegate> funcGroupScrollDelegate;

@property(nonatomic,assign) BOOL hasLongPress;

@end

@implementation WKFuncGroupScrollView


-(void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [super touchesBegan:touches withEvent:event];
    self.beganEvent = event;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(triggerLongPressedStart:) object:event];
    [self performSelector:@selector(triggerLongPressedStart:) withObject:event afterDelay:0.2f];

}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(triggerLongPressedStart:) object:event];
    
    if(self.hasLongPress) {
        self.hasLongPress = false;
        [self triggerLongPressedEnd:event];
    }
    
    
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(triggerLongPressedStart:) object:event];
    if(self.hasLongPress) {
        self.hasLongPress = false;
        [self triggerLongPressedEnd:event];
    }
}

-(void) triggerLongPressedStart:(UIEvent*)event {
    self.hasLongPress = true;
    if ([self.funcGroupScrollDelegate conformsToProtocol:@protocol(WKFuncGroupScrollDelegate)] &&
        [self.funcGroupScrollDelegate respondsToSelector:@selector(funcGroupScroll:longPressStart:)]){
        [self.funcGroupScrollDelegate funcGroupScroll:self longPressStart:event];
    }
}

-(void) triggerLongPressedEnd:(UIEvent*)event {
    if ([self.funcGroupScrollDelegate conformsToProtocol:@protocol(WKFuncGroupScrollDelegate)] &&
        [self.funcGroupScrollDelegate respondsToSelector:@selector(funcGroupScroll:longPressEnd:)]){
        [self.funcGroupScrollDelegate funcGroupScroll:self longPressEnd:event];
    }
}

@end

@class WKFuncGroupItemView;

@interface WKFuncGroupView ()<UIScrollViewDelegate,WKFuncGroupScrollDelegate,WKAPMManagerDelegate>

@property(nonatomic,strong) WKFuncGroupScrollView *scrollView;

@property(nonatomic,strong) NSArray<id<WKPanelFuncItemProto>> *funcItems; // 功能项
@property(nonatomic,weak) WKConversationInputPanel *inputPanel;



@property(nonatomic,strong) UIView *scrollToView;

@property(nonatomic,assign) CGRect oldFrame; // 旧的frame

@end

@implementation WKFuncGroupView

- (instancetype)initWithFrame:(CGRect)frame inputPanel:(WKConversationInputPanel*)inputPanel
{
    self = [super initWithFrame:frame];
    if (self) {
        self.oldFrame = frame;
        self.inputPanel = inputPanel;
        self.scaleZoom = 1.5f;
        [self addSubview:self.scrollView];
        [self reloadData];
        
        [[WKAPMManager shared] addDelegate:self];
    }
    return self;
}

- (void)dealloc {
    [[WKAPMManager shared] removeDelegate:self];
}

-(void) reloadData {
    [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    WKPanelDefaultFuncItem *preFuncItem;
    for (WKPanelDefaultFuncItem *funcItem in self.funcItems) {
        WKFuncItemButton *btn = [funcItem itemButton:self.inputPanel];
        __weak typeof(self) weakSelf = self;
        WKFuncGroupItemView *itemView = [[WKFuncGroupItemView alloc] initWithButton:btn scaleZoom:self.scaleZoom];
        [itemView setOnClick:^(WKFuncGroupItemView *item){
            [weakSelf unSelectedItems];
            item.selected = true;
            [item triggerClick];
        }];
        if(preFuncItem && preFuncItem.type != funcItem.type) {
            itemView.showSplit = true;
        }else {
            itemView.showSplit = false;
        }
        [self.scrollView addSubview:itemView];
        
        preFuncItem = funcItem;
    }
    [self layoutSubviews];
}

-(void) unSelectedItems {
    NSArray<WKFuncGroupItemView*> *subViews = [self.scrollView subviews];
    if(subViews && subViews.count>0) {
        for (WKFuncGroupItemView *itemView in subViews) {
            itemView.selected = false;
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if(self.startScroll) {
        // self.oldFrame.size.height -(self.oldFrame.size.height*self.scaleZoom)
        self.frame = CGRectMake(0.0f, self.lim_top,  self.oldFrame.size.width, self.oldFrame.size.height*self.scaleZoom);
    }else {
        self.frame = CGRectMake(0.0f, self.lim_top, self.oldFrame.size.width, self.oldFrame.size.height);
    }
    if(self.onLayout) {
        self.onLayout();
    }
    self.scrollView.frame = self.bounds;
    
    NSArray<UIView*> *subviews = self.scrollView.subviews;
    if(subviews.count>0) {
        UIView *preView;
        CGFloat space = 0.0f;
        for (WKFuncGroupItemView *subView  in subviews) {
            subView.changeToBig = self.startScroll;
            
            subView.lim_centerY_parent = self.scrollView;
            if(!preView) {
                subView.lim_left = 0.0f;
            }else {
                subView.lim_left = preView.lim_right + space;
            }
            preView = subView;
        }
        [self.scrollView setContentSize:CGSizeMake(preView.lim_right, self.scrollView.lim_height)];
        
    }
   
}

- (void)setStartScroll:(BOOL)startScroll {
    _startScroll = startScroll;
}


-(NSArray<id<WKPanelFuncItemProto>>*) loadAndSortFuncItems {
    NSArray<id<WKPanelFuncItemProto>> *funcItems = [[WKApp shared] invokes:WKPOINT_CATEGORY_PANELFUNCITEM param:@{@"context":self.inputPanel.conversationContext}];
    if(funcItems&&funcItems.count>0) {
        NSArray<WKAPMSortInfo*> *sortInfos = [WKAPMManager shared].apmSorts;
        NSMutableDictionary *sortInfoDict = [NSMutableDictionary dictionary];
        if(sortInfos && sortInfos.count>0) {
            for (WKAPMSortInfo *sortInfo in sortInfos) {
                sortInfoDict[sortInfo.apmID] = sortInfo;
            }
        }
        NSMutableArray<id<WKPanelFuncItemProto>> *newFuncItems = [NSMutableArray array];
        for (id<WKPanelFuncItemProto> panelFuncItem in funcItems) {
            WKPanelDefaultFuncItem *defaultIFuncItem = (WKPanelDefaultFuncItem*)panelFuncItem;
            if([panelFuncItem support:self.inputPanel.conversationContext]) {
                WKAPMSortInfo *sortInfo = sortInfoDict[[panelFuncItem sid]];
                if(sortInfo) {
                    if(sortInfo.disable) {
                        continue;
                    }
                    defaultIFuncItem.sort = sortInfo.sort;
                    defaultIFuncItem.type = sortInfo.type;
                    
                }
                [newFuncItems addObject:panelFuncItem];
            }
        }
        [newFuncItems sortUsingComparator:^NSComparisonResult(WKPanelDefaultFuncItem  *obj1, WKPanelDefaultFuncItem *obj2) {
            if([obj1.sid isEqualToString:@"apm.wukong.more"]) {
                return NSOrderedDescending;
            }
            if([obj2.sid isEqualToString:@"apm.wukong.more"]) {
                return NSOrderedAscending;
            }
            if(![obj1 allowEdit] && [obj2 allowEdit]) {
                return NSOrderedAscending;
            }
            if([obj1 allowEdit] && ![obj2 allowEdit]) {
                return NSOrderedDescending;
            }
            
            if(obj1.type != WKFuncGroupEditItemTypeFavorite && obj2.type == WKFuncGroupEditItemTypeFavorite) {
                return  NSOrderedDescending;
            }
            if(obj1.type == WKFuncGroupEditItemTypeFavorite && obj2.type != WKFuncGroupEditItemTypeFavorite) {
                return NSOrderedAscending;
            }
            
            if([obj1 sort] < [obj2 sort]) {
                return NSOrderedAscending;
            }
            if([obj1 sort] > [obj2 sort]) {
                return NSOrderedDescending;
            }
            return NSOrderedSame;
            
        }];
        return newFuncItems;
    }
    return @[];
}

- (NSArray<id<WKPanelFuncItemProto>> *)funcItems {
    if(!_funcItems) {
        _funcItems = [self loadAndSortFuncItems];
    }
    return _funcItems;
}

- (WKFuncGroupScrollView *)scrollView {
    if(!_scrollView) {
        _scrollView = [[WKFuncGroupScrollView alloc] initWithFrame:self.bounds];
//        [_scrollView setContentInset:UIEdgeInsetsMake(0.0f, 15.0f, 0.0f, 15.0f)];
        [_scrollView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        _scrollView.showsVerticalScrollIndicator = false;
        _scrollView.showsHorizontalScrollIndicator = false;
        _scrollView.delegate = self;
        _scrollView.funcGroupScrollDelegate = self;
        
//        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)];
//        longPress.minimumPressDuration = 0.2f;
//        [_scrollView addGestureRecognizer:longPress];
    }
    return _scrollView;
}


-(UIView*) viewAtPoint:(CGPoint)point {
   NSArray<UIView*> *subViews = self.scrollView.subviews;
    for (UIView *subView in subViews) {
        if(subView.lim_left>=point.x) {
            return subView;
        }
    }
    return subViews[subViews.count-1];
}

#pragma mark -- WKAPMManagerDelegate

- (void)apmManagerSortInfoChange:(WKAPMManager *)manager {
    self.funcItems = [self loadAndSortFuncItems];
    [self reloadData];
    
}

#pragma mark --- WKFuncGroupScrollDelegate

- (void)funcGroupScroll:(WKFuncGroupScrollView *)scrollView longPressStart:(UIEvent *)event {
    NSSet *touches = event.allTouches;
     if(touches && touches.count>0) {
         UITouch *touch = [touches allObjects][0];
        CGPoint point =  [touch locationInView:self.scrollView];
        self.scrollToView = [self viewAtPoint:point];
        [self scrollStartIfNeed];
     }
}
- (void)funcGroupScroll:(WKFuncGroupScrollView *)scrollView longPressEnd:(UIEvent *)event {
   
}


#pragma mark --- UIScrollViewDelegate

-(void) anmiScroll:(void(^)(void))block complete:(void(^)(void))complete{
//    [UIView animateWithDuration:0.2f delay:0.0f usingSpringWithDamping:0.4f initialSpringVelocity:0.5f options:UIViewAnimationOptionCurveLinear animations:^{
//        [self layoutSubviews];
//        if(block) {
//            block();
//        }
//    } completion:^(BOOL finished) {
//        if(complete) {
//            complete();
//        }
//    }];
    
    [UIView animateWithDuration:0.2f animations:^{
        [self layoutSubviews];
        if(block) {
            block();
        }
    } completion:^(BOOL finished) {
        if(complete) {
            complete();
        }
    }];
}

-(void) scrollStop {
    NSLog(@"停止滚动");
    [self stopZoom];

}

- (void)stopZoom {
    self.startScroll = false;
    self.scrollToView = nil;
    [self stopScrollingAnimation];
    [self anmiScroll:nil complete:^{
        
    }];
}

- (void)stopScrollingAnimation
{
    UIView *superview = self.scrollView.superview;
    NSUInteger index = [self.scrollView.superview.subviews indexOfObject:self.scrollView];
    [self.scrollView removeFromSuperview];
    [superview insertSubview:self.scrollView atIndex:index];
}

-(BOOL) isZooming {
    return self.startScroll;
}

-(void) scrollStopWithDelay {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scrollStop) object:nil];
    [self performSelector:@selector(scrollStop) withObject:nil afterDelay:1.0f];
}

-(void) scrollStartIfNeed {
    if(self.startScroll) {
        [self scrollStopWithDelay];
        return;
    }
    [self scrollStart];
}

-(void) scrollStart {
    self.startScroll = true;
    [self scrollStopWithDelay];
    NSLog(@"滚动开始～～～～");
    [self anmiScroll:^{
        [self.scrollView scrollRectToVisible:self.scrollToView.frame animated:NO];
    } complete:^{
        self.scrollToView = nil;
    }];
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self scrollStopWithDelay];
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self scrollStartIfNeed];
}


@end




@interface WKFuncGroupItemView ()

@property(nonatomic,strong) WKFuncItemButton *btn;
@property(nonatomic,copy) NSString *title;
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,assign) CGFloat scaleZoom;

@property(nonatomic,strong) UIView *splitView;


@end

@implementation WKFuncGroupItemView


-(instancetype) initWithButton:(WKFuncItemButton*)btn scaleZoom:(CGFloat)scaleZoom{
    self = [super init];
    if (self) {
        self.btn = btn;
        __weak typeof(self) weakSelf = self;
        [self.btn setOnSelected:^{
            weakSelf.selected = weakSelf.btn.selected;
        }];
        self.scaleZoom = scaleZoom;
        [self addSubview:btn];
        self.title = btn.titleLabel.text;
        [self.btn setTitle:@"" forState:UIControlStateNormal];
        self.btn.layer.masksToBounds = YES;
        btn.frame = self.bounds;
        self.btn.userInteractionEnabled = NO;
        
        self.userInteractionEnabled = YES;
        [self addSubview:self.titleLbl];
        
        self.titleLbl.text = self.title;
        [self.titleLbl sizeToFit];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pressed)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

-(void) pressed {
    if(self.onClick) {
        self.onClick(self);
    }
}

-(void) triggerClick {
    [self.btn sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    [self layoutSubviews];
}

- (void)setShowSplit:(BOOL)showSplit {
    _showSplit = showSplit;
    if(showSplit) {
        [self addSubview:self.splitView];
    }else {
        if(self.splitView.superview) {
            [self.splitView removeFromSuperview];
        }
    }
}

- (void)setChangeToBig:(BOOL)changeToBig {
    _changeToBig = changeToBig;
    [self layoutSubviews];
   
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    UIView *superView = self.superview;
    self.lim_size = CGSizeMake(superView.lim_height + 10.0f, superView.lim_height);
    if(self.changeToBig) {
        self.btn.lim_size = CGSizeMake(iconBigItemWidth, iconBigItemHeight);
        self.titleLbl.hidden = NO;
        CGFloat titleLblTopSpace = 4.0f;
       CGFloat  contentHeight =  self.btn.lim_height + titleLblTopSpace + self.titleLbl.lim_height;
        self.btn.lim_top = self.lim_height/2.0f - contentHeight/2.0f;
        self.titleLbl.lim_top = self.btn.lim_bottom + titleLblTopSpace;
        self.titleLbl.lim_centerX_parent = self;
        self.btn.lim_centerX_parent = self;
    }else {
        self.btn.lim_size = CGSizeMake(iconItemWidth, iconItemHeight);
        self.titleLbl.hidden = YES;
        self.btn.lim_centerY_parent = self;
        self.btn.lim_centerX_parent = self;
        self.titleLbl.lim_top = self.btn.lim_bottom;
        self.titleLbl.lim_centerX_parent = self;
    }
    
    if(self.splitView.superview) {
        self.splitView.lim_left = 0.0f;
        self.splitView.lim_height = self.lim_height - 20.0f;
        self.splitView.lim_centerY_parent = self;
    }
    if(self.selected) {
        self.btn.layer.borderWidth = 2.0f;
        self.btn.layer.cornerRadius = self.btn.lim_height/2.0f;
        self.btn.layer.borderColor = [UIColor colorWithRed:200.0f/255.0f green:200.0f/255.0f blue:200.0f/255.0f alpha:1.0f].CGColor;
    }else {
        self.btn.layer.borderWidth = 0.0f;
        self.btn.layer.cornerRadius = 0.0f;
    }
}

- (UIView *)splitView {
    if(!_splitView) {
        _splitView = [[UIView alloc] init];
        _splitView.lim_width = 1.0f;
        if([WKApp shared].config.style == WKSystemStyleDark) {
            _splitView.backgroundColor = [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f];
        }else {
            _splitView.backgroundColor = [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0f];
        }
        
    }
    return _splitView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        [_titleLbl setFont:[[WKApp shared].config appFontOfSize:12.0f]];
    }
    return _titleLbl;
}

@end

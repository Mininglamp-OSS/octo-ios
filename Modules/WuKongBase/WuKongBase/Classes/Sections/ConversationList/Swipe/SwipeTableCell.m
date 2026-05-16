//
//  SwipeTableCell.m
//  WuKongBase
//
//  Created by tt on 2021/8/10.
//

#import "SwipeTableCell.h"

#define CELL_WIDTH self.bounds.size.width
#define CELL_HEIGHT self.bounds.size.height


@interface SwipeTableCell ()<UIGestureRecognizerDelegate,SwipeViewDelegate>

@property (nonatomic, strong) UITableView *tableView; /**< 当前cell所在的tableView*/
@property (nonatomic, strong) UIImageView *swipeImageView; /**< 显示移动后的cell上的内容*/
@property (nonatomic, strong) SwipeView *rightSwipeView; /**< 右滑展示的view*/
@property (nonatomic, strong) SwipeView *leftSwipeView; /**< 左滑展示的View*/
@property (nonatomic, strong) SwipeView *gestureAnimation;

@property (nonatomic, assign) SwipeTableCellStyle swipeStyle; /**< 滑动样式 默认右滑*/
@property (nonatomic, strong) NSArray<SwipeButton *> *leftSwipeButtons; /**< 左滑buttons*/
@property (nonatomic, strong) NSArray<SwipeButton *> *rightSwipeButtons; /**< 右滑buttons*/
@property (nonatomic, strong) NSMutableSet *perviusHiddenViewSet;/**< 已经隐藏的view*/

@property (nonatomic, assign) CGFloat swipeOffset; /**< 滑动偏移量*/
@property (nonatomic, assign) CGFloat targetOffset; /**< 最终目标偏移量*/
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture; /**< 滑动手势*/
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture; /**< 点击手势*/

@property (nonatomic, assign) CGPoint panStartPoint; /**<滑动手势开始点击的坐标*/
@property (nonatomic, assign) CGFloat panStartOffset; /**<滑动手势的偏移量*/
@property (nonatomic, assign) BOOL isShowSwipeOverlayView; /**< 保证显示、隐藏swipeImageView方法只走一次*/

@property (nonatomic, strong) CADisplayLink *dispalyLink; /**<定时器 一秒60次*/
@property (nonatomic, assign) UITableViewCellSelectionStyle previousSelectStyle;/**< 先前cell的选中样式*/

@end

@implementation SwipeTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if([super initWithStyle:style reuseIdentifier:reuseIdentifier])
    {
        [self initDatas];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if([super initWithCoder:aDecoder])
    {
        [self initDatas];
    }
    return self;
}

- (void)awakeFromNib
{
    [self initDatas];
}

/**
 *  初始化数据
 */
- (void)initDatas
{
    self.swipeStyle = SwipeTableCellStyleRightToLeft; //默认右滑
    self.transformMode = SwipeViewTransfromModeDefault;
    self.swipeOffset = 0.0;
    self.targetOffset = 0.0;
    self.swipeThreshold = 0.5;
    self.isAllowMultipleSwipe = NO;
    self.isShowSwipeOverlayView = NO;
    self.hideSwipeViewWhenScrollCell = YES;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGestureRecognizer:)];
    self.panGesture.delegate = self;
    [self addGestureRecognizer:self.panGesture];
}

- (void)refreshButtonsWithTitle:(NSString *)title
{
    if(self.rightSwipeView)
    {
        [self.rightSwipeView removeFromSuperview];
        self.rightSwipeView = nil;
    }
    if(self.leftSwipeView)
    {
        [self.leftSwipeView removeFromSuperview];
        self.leftSwipeView = nil;
    }
    self.rightSwipeButtons = @[];
    self.leftSwipeButtons = @[];
    
    
    self.isRefreshButton = !self.isRefreshButton;
}

#pragma mark -- 处理滑动手势
/**
 *  处理滑动手势 上左x<0、y<0  下右x>0、y>0
 */
- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)pan
{
    CGPoint currentPanPoint = [pan translationInView:self];
    
    if(pan.state == UIGestureRecognizerStateBegan)
    {
        self.panStartPoint = currentPanPoint;
        self.panStartOffset = self.swipeOffset;
       
        [self createSwipeOverlayViewIfNeed];
        //不允许多个cell同时能滑动，则移除上一个cell的滑动手势
        if(!_isAllowMultipleSwipe)
        {
            for(SwipeTableCell * cell in self.tableView.visibleCells)
            {
                if(cell != self && [cell respondsToSelector:@selector(cancelPanGesture)]) [cell cancelPanGesture];
            }
        }
    }
    else if(pan.state == UIGestureRecognizerStateChanged)
    {
        CGFloat offset = self.panStartOffset + currentPanPoint.x - self.panStartPoint.x;
        //重新swipeOffset的setter方法，监测滑动偏移量
        self.swipeOffset = [self filterSwipeOffset:offset];
    }
    else if(pan.state == UIGestureRecognizerStateEnded)
    {
        CGFloat velocity = [self.panGesture velocityInView:self].x;
        CGFloat inertiaThreshold = 100; //每秒走过多少像素
        
        if(velocity > inertiaThreshold) //快速左滑
        {
            self.targetOffset = self.swipeOffset < 0 ? 0 : (self.leftSwipeView ? self.leftSwipeView.frame.size.width : self.targetOffset);
        }
        else if(velocity < -inertiaThreshold) //快速右滑
        {
            self.targetOffset = self.swipeOffset > 0 ? 0 : (self.rightSwipeView ? -self.rightSwipeView.frame.size.width : self.targetOffset);
        }
        
        self.targetOffset = [self filterSwipeOffset:self.targetOffset];
        //NSLog(@"targetOffset:%f", self.targetOffset);
        [self gestureAnimationWithOffset:self.targetOffset animationView:self.targetOffset <= 0 ? self.rightSwipeView : self.leftSwipeView];
    }
}

/**
 *  创建用于显示滑动过后cell内容的SwipeImageView, 并在其上添加滑动按钮
 */
- (void)createSwipeOverlayViewIfNeed
{
    [self getSwipeTableViewCellStyle];
    [self getSwipeButtons];
    
    if(!self.swipeOverlayView)
    {
        _swipeOverlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CELL_WIDTH, CELL_HEIGHT)];
        _swipeOverlayView.backgroundColor = [UIColor clearColor];
        _swipeOverlayView.hidden = YES;
        
        _swipeImageView = [[UIImageView alloc] initWithFrame:self.swipeOverlayView.bounds];
        _swipeImageView.userInteractionEnabled = YES;
        
        [_swipeOverlayView addSubview:_swipeImageView];
        [self addSubview:self.swipeOverlayView];
    }

    if(self.rightSwipeButtons.count && !self.rightSwipeView)
    {
        
        _rightSwipeView = [[SwipeView alloc] initWithButtons:self.rightSwipeButtons fromRight:YES cellHeght:CELL_HEIGHT];
        _rightSwipeView.delegate = self;
        //改变rightSwipeView的frame 使其显示在swipeImageView的最右端
        _rightSwipeView.frame = CGRectMake(self.swipeImageView.bounds.size.width, 0, _rightSwipeView.frame.size.width, CELL_HEIGHT);
        [self.swipeOverlayView addSubview:_rightSwipeView];
    }
    if(self.leftSwipeButtons.count && !self.leftSwipeView)
    {
        if (_leftSwipeView) {
            [_leftSwipeView  removeFromSuperview];
            _leftSwipeView = nil;
        }
        _leftSwipeView = [[SwipeView alloc] initWithButtons:self.leftSwipeButtons fromRight:NO cellHeght:CELL_HEIGHT];
        
        //改变leftSwipeView的frame 使其显示在swipeImageView的最左端
        _leftSwipeView.frame = CGRectMake(-_leftSwipeView.frame.size.width, 0, _leftSwipeView.frame.size.width, CELL_HEIGHT);
        [self.swipeOverlayView addSubview:_leftSwipeView];
    }
}

/**
 * 判断滑动是否合法 并返回滑动距离
 */
- (CGFloat)filterSwipeOffset:(CGFloat)offset
{
    UIView *swipeView = offset > 0 ? self.leftSwipeView : self.rightSwipeView;
    if(!swipeView)
    {
        return 0.0;
    }
    else if(self.swipeStyle == SwipeTableCellStyleLeftToRight && offset < 0)
    {
        return 0.0;
    }
    else if(self.swipeStyle == SwipeTableCellStyleRightToLeft && offset > 0)
    {
        return 0.0;
    }
    return offset;
}

/**
 *  当滑动下一个cell时 取消上一个cell的滑动手势
 */
- (void)cancelPanGesture
{
    self.panGesture.enabled = NO;
    self.panGesture.enabled = YES;
    //将上一个cell恢复原状
    if(self.swipeOffset){
        [self hiddenSwipeAnimationAtCell:YES];
    }
}

#pragma mark -- 处理点击手势

- (void)handleTapGesture:(UITapGestureRecognizer *)tapGesture
{
    BOOL hidden = YES;
    if([self.swipeDelegate respondsToSelector:@selector(tableView:hiddenSwipeViewWhenTapCellAtIndexpath:)])
    {
        //判断点击cell是否隐藏swipeView
        hidden = [self.swipeDelegate tableView:self.tableView hiddenSwipeViewWhenTapCellAtIndexpath:[self.tableView indexPathForCell:self]];
    }
    if(hidden)
    {
        [self hiddenSwipeAnimationAtCell:YES];
    }
}

#pragma mark -- 处理手势动画效果

- (void)hiddenSwipeAnimationAtCell:(BOOL)isAnimation
{
    
    SwipeView *aView = self.swipeOffset < 0 ? self.rightSwipeView : self.leftSwipeView;
    [self gestureAnimationWithOffset:0 animationView:aView];
    
}

- (void)gestureAnimationWithOffset:(CGFloat)offset animationView:(SwipeView *)animationView
{
    self.gestureAnimation = animationView;
    if(self.dispalyLink){
        [self.dispalyLink invalidate];
        self.dispalyLink = nil;
    }
    
    if(offset !=0 ){
        [self createSwipeOverlayViewIfNeed];
    }
    
    if(!self.gestureAnimation){
        self.swipeOffset = offset;
        return;
    }
    
    self.gestureAnimation.from = self.swipeOffset;
    self.gestureAnimation.to = offset;
    self.gestureAnimation.start = 0;
    self.dispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleAnimation:)];
    [self.dispalyLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

/**
 *  定时器处理动画
 */
- (void)handleAnimation:(CADisplayLink *)link
{
    if (!self.gestureAnimation.start) {
        self.gestureAnimation.start = link.timestamp;
    }
    
    CFTimeInterval elapsed = link.timestamp - self.gestureAnimation.start;
    //滑动超过SwipeView的一半 自动显示或隐藏全部内容
    self.swipeOffset = [self.gestureAnimation value:elapsed duration:self.gestureAnimation.duration from:self.gestureAnimation.from to:self.gestureAnimation.to];
    
    if(elapsed >= self.gestureAnimation.duration)
    {
        [link invalidate];
        self.dispalyLink = nil;
    }
}

#pragma mark -- UIGestureRecognizerDelegates

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    
    if(gestureRecognizer == self.panGesture)
    {
        if(self.editing)  return NO; //tableView在编辑状态
        
        if(self.targetOffset != 0.0) return YES; //已经在滑动状态
        
        if (_rightSwipeView) {
            [_rightSwipeView  removeFromSuperview];
            _rightSwipeView = nil;
        }
        //使UITableView可以滚动 解决滑动tableView和滑动cell冲突额问题
        CGPoint panPoint = [self.panGesture translationInView:self];
        if(fabs(panPoint.x) < fabs(panPoint.y))
        {
            for(UITableViewCell *cell in self.tableView.visibleCells) //滑动cell时，自动隐藏swipeView
            {
                if ([cell isKindOfClass:[SwipeTableCell class]]) {
                    SwipeTableCell *swipeCell = (SwipeTableCell *)cell;
                    if(swipeCell.hideSwipeViewWhenScrollCell && !swipeCell.swipeOverlayView.hidden){
                        [swipeCell hiddenSwipeAnimationAtCell:YES];
                    }
                }
            }
            return NO;
        }
    }
    else if(gestureRecognizer == self.tapGesture)
    {
        //解决和didSelect冲突问题
        CGPoint tapPoint = [self.tapGesture locationInView:self];
        //NSLog(@"%@,%@", NSStringFromCGRect(self.swipeOverlayView.frame), NSStringFromCGPoint(tapPoint));
        return CGRectContainsPoint(self.swipeImageView.frame, tapPoint);
    }
    return YES;
}

#pragma mark -- 获取滑动按钮、滑动按钮的样式
/**
 *  获取滑动button的样式
 */
- (void)getSwipeTableViewCellStyle
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:self];
    if([self.swipeDelegate respondsToSelector:@selector(tableView: styleOfSwipeButtonForRowAtIndexPath:)])
    {
        self.swipeStyle = [self.swipeDelegate tableView:self.tableView styleOfSwipeButtonForRowAtIndexPath:indexPath];
    }
}

/**
 *  获取滑动button
 */
- (void)getSwipeButtons
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:self];
    if(self.swipeStyle == SwipeTableCellStyleRightToLeft)
    {
        if([self.swipeDelegate respondsToSelector:@selector(tableView: rightSwipeButtonsAtIndexPath:)])
        {
            self.rightSwipeButtons = [[self.swipeDelegate tableView:self.tableView rightSwipeButtonsAtIndexPath:indexPath] mutableCopy];
        }
    }
    else if(self.swipeStyle == SwipeTableCellStyleLeftToRight)
    {
        if([self.swipeDelegate respondsToSelector:@selector(tableView : leftSwipeButtonsAtIndexPath:)])
        {
            self.leftSwipeButtons = [self.swipeDelegate tableView:self.tableView leftSwipeButtonsAtIndexPath:indexPath];
        }
    }
    else if(self.swipeStyle == SwipeTableCellStyleBoth)
    {
        if([self.swipeDelegate respondsToSelector:@selector(tableView: rightSwipeButtonsAtIndexPath:)])
        {
            self.rightSwipeButtons = [self.swipeDelegate tableView:self.tableView rightSwipeButtonsAtIndexPath:indexPath];
        }
        
        if([self.swipeDelegate respondsToSelector:@selector(tableView : leftSwipeButtonsAtIndexPath:)])
        {
            self.leftSwipeButtons = [self.swipeDelegate tableView:self.tableView leftSwipeButtonsAtIndexPath:indexPath];
        }
    }
}

- (void)getSwipeViewTransformMode
{
    if([self.swipeDelegate respondsToSelector:@selector(tableView:swipeViewTransformModeAtIndexPath:)])
    {
        self.transformMode = [self.swipeDelegate tableView:self.tableView swipeViewTransformModeAtIndexPath:[self.tableView indexPathForCell:self]];
    }
}

#pragma mark -- 私有方法

/**
 *  截取平移过后的cell上的内容 以图片的形式显示出来
 */
- (UIImage *)fecthTranslatedCellInfo:(UIView *)cell
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
    [cell.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

/**< 删除所有子视图*/
- (void)removeAllSubViewsAtView:(UIView *)view
{
    while (view.subviews.count) {
       [[view.subviews lastObject] removeFromSuperview];
    }
}

#pragma mark -- 显示、隐藏cell上的内容
/**
 * 显示self.swipeImageView
 */
- (void)showSwipeOverlayViewIfNeed
{
    if(self.isShowSwipeOverlayView) return;
    self.isShowSwipeOverlayView = YES;
    
    //去除cell的选中状态，并保存
    self.selected = NO;
    self.previousSelectStyle = self.selectionStyle;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    //显示swipeOverlayView,并将移动后cell上的内容裁剪到swipeImageView上
    self.swipeImageView.image = [self fecthTranslatedCellInfo:self];
    self.swipeOverlayView.hidden = NO;
    
    //隐藏cell上的内容
    [self hiddenAccesoryViewAndContentOfCellIfNeed:YES];
    //添加点击手势
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    self.tapGesture.delegate = self;
    [self.swipeImageView addGestureRecognizer:self.tapGesture];
}

/**
 *  隐藏self.swipeImageView
 */
- (void)hiddenSwipeOverlayViewIfNeed
{
    if(!self.isShowSwipeOverlayView) return;
    self.isShowSwipeOverlayView = NO;
    
    //隐藏swipeImageView
    self.swipeOverlayView.hidden = YES;
    self.swipeImageView.image = nil;
    
    //若cell是选中状态 则滑动手势结束后还原cell的选中状态
    self.selectionStyle = self.previousSelectStyle;
    NSArray *selectCells = self.tableView.indexPathsForSelectedRows;
    if([selectCells containsObject:[self.tableView indexPathForCell:self]])
    {
        self.selected = NO;
        self.selected = YES;
    }
    
    //将cell上的内容还原
    [self hiddenAccesoryViewAndContentOfCellIfNeed:NO];
    //移除点击手势
    if(self.tapGesture){
        [self.swipeImageView removeGestureRecognizer:self.tapGesture];
        self.tapGesture = nil;
    }
}

/**
 *  是否隐藏accesoryView和cell上的内容,从而使得滑动cell时不会看见原有cell上的内容
 */
- (void)hiddenAccesoryViewAndContentOfCellIfNeed:(BOOL)hidden
{
    //若只设置self.accessoryType 则不走这个判断语句
    if(self.accessoryView){
        self.accessoryView.hidden = hidden;
    }
    
    //设置了self.accessoryType 其实是个UIButton
    for(UIView *subView in self.contentView.superview.subviews)
    {
        if(subView != self.contentView && ([subView isKindOfClass:[UIButton class]] || [NSStringFromClass(subView.class) rangeOfString:@"Disclosure"].location != NSNotFound))
        {
            subView.hidden = hidden;
        }
    }
    
    for(UIView *subView in self.contentView.subviews)
    {
        //若是cell上的subView则隐藏
        if(hidden && !subView.hidden)
        {
            subView.hidden = YES;
            [self.perviusHiddenViewSet addObject:subView];
        }
        //还原cell时，将隐藏的cell上的内容显示出来
        else if(!hidden && [self.perviusHiddenViewSet containsObject:subView])
        {
            subView.hidden = NO;
        }
    }
    if(!hidden){
        [self.perviusHiddenViewSet removeAllObjects];
    }
}

#pragma mark -- getter或setter

/**重写tableView的getter方法 获取cell所在的tableView*/
- (UITableView *)tableView
{
    if(_tableView){
        return _tableView;
    }
    //获取当前cell所在的父tableView
    UIView *view = self.superview;
    while (view != nil)
    {
        if([view isKindOfClass:[UITableView class]])
        {
            _tableView = (UITableView *)view;
        }
        view = view.superview;
    }
    return _tableView;
}

/** 重写swipeOffset的setter方法 监测滑动手势*/
- (void)setSwipeOffset:(CGFloat)swipeOffset
{
    CGFloat sign = swipeOffset > 0 ? 1 : -1;
    SwipeView *currentSwipeView = swipeOffset < 0 ? self.rightSwipeView : self.leftSwipeView;
    
    _swipeOffset = swipeOffset;
    CGFloat offset = fabs(_swipeOffset);
    
    if(!currentSwipeView || offset == 0){
        [self hiddenSwipeOverlayViewIfNeed];
        self.targetOffset = 0.0;
        return;
    }
    else{
        [self showSwipeOverlayViewIfNeed];
        self.targetOffset = offset > currentSwipeView.bounds.size.width*self.swipeThreshold ? currentSwipeView.bounds.size.width*sign : 0;
    }
    //NSLog(@"self.swipeOffset:%f", self.swipeOffset);
    //平移swipeImageView，显示滑动后cell的内容
    self.swipeImageView.transform = CGAffineTransformMakeTranslation(self.swipeOffset, 0);
    
    SwipeView *viewArray[2] = {self.rightSwipeView, self.leftSwipeView};
     for (int i = 0; i< 2; i++)
    {
        SwipeView *swipeView = viewArray[i];
        if(!swipeView) continue;
        
        //平移显示按钮
        CGFloat translation = MIN(offset, currentSwipeView.bounds.size.width)*sign;
        swipeView.transform = CGAffineTransformMakeTranslation(translation, 0);
        if(currentSwipeView != swipeView) continue;
        
        [self getSwipeViewTransformMode];
        currentSwipeView.mode = self.transformMode;
        CGFloat t = MIN(1.0f, offset/currentSwipeView.bounds.size.width);
        //swipeView的弹出、隐藏动画效果
        [currentSwipeView swipeViewAnimationFromRight:self.swipeOffset<0 ? YES : NO effect:t cellHeight:CELL_HEIGHT];
    }
}

#pragma mark ---swipeView delegate

- (void) hideSwipeView {
    [self cancelPanGesture];
}

- (void)setEnableSwipe:(BOOL)enableSwipe {
    if (enableSwipe == false) {
        [self removeGestureRecognizer:self.panGesture];
    }
}

#pragma mark -- 懒加载

- (NSArray<SwipeButton *> *)leftSwipeButtons
{
    if(!_leftSwipeButtons)
    {
        _leftSwipeButtons = [NSArray array];
    }
    return _leftSwipeButtons;
}

- (NSArray<SwipeButton *> *)rightSwipeButtons
{
    if(!_rightSwipeButtons)
    {
        _rightSwipeButtons = [NSArray array];
    }
    return _rightSwipeButtons;
}

- (NSMutableSet *)perviusHiddenViewSet
{
    if(!_perviusHiddenViewSet)
    {
        _perviusHiddenViewSet = [NSMutableSet set];
    }
    return _perviusHiddenViewSet;
}

@end

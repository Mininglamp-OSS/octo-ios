//
//  WKPopMenuView.m
//  WuKongBase
//
//  Created by tt on 2019/12/31.
//


#import "WKPopMenuView.h"
#import "WKResource.h"
#import "WKApp.h"
#import "UIView+WK.h"
#ifndef SCREEN_WIDTH
#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#endif

static CGFloat const kCellHeight = 44;

@interface PopMenuTableViewCell : UITableViewCell
@property (nonatomic, strong) UIImageView *leftImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@end

@interface WKPopMenuView ()<UITableViewDelegate,UITableViewDataSource,UIGestureRecognizerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *tableData;
@property (nonatomic, assign) CGPoint trianglePoint;
@property (nonatomic, weak) UIWindow *hostWindow;
@property (nonatomic, copy) void(^action)(NSInteger index);
@end

@implementation WKPopMenuView

- (instancetype)initWithItems:(NSArray <NSDictionary *>*)array
                        width:(CGFloat)width
             triangleLocation:(CGPoint)point
                       window:(UIWindow *)window
                       action:(void(^)(NSInteger index))action
{
    if (array.count == 0) return nil;
    if (self = [super init]) {
        // 用触发按钮所在 window 的实际 bounds 而不是 [UIScreen mainScreen].bounds——后者是
        // 竖屏原生宽度,不随界面方向刷新,iPad 横屏下遮罩和下面的菜单锚点都会按错误的窄宽度算,
        // 跟已经移到真实横屏右边缘的触发按钮脱节。调用方只传一次 window(通常是按钮自己的
        // .window),这里和 show 里都直接用它,不再各自独立查一遍 keyWindow。
        UIWindow *hostWindow = window ?: [UIApplication sharedApplication].keyWindow;
        self.hostWindow = hostWindow;
        self.frame = hostWindow ? hostWindow.bounds : [UIScreen mainScreen].bounds;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
        self.alpha = 0;
        _tableData = [array copy];
        _trianglePoint = point;
        self.action = action;


        // 添加手势
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap)];
        tap.delegate = self;
        [self addGestureRecognizer:tap];

        // 木桶效应：菜单宽度由最长 title 决定。原 width 参数当下限用，避免中文短文案下菜单缩太窄。
        // cell 布局: leftIcon 15pt left + 22pt 宽 + 10pt spacing → title 起点 47pt; 右留 12pt
        UIFont *titleFont = [[WKApp shared].config appFontOfSize:16.0f];
        CGFloat maxTextWidth = 0;
        for (NSDictionary *item in array) {
            NSString *title = item[@"title"] ?: @"";
            CGSize sz = [title sizeWithAttributes:@{NSFontAttributeName: titleFont}];
            maxTextWidth = MAX(maxTextWidth, sz.width);
        }
        const CGFloat titleStart = 47;
        const CGFloat titleRightMargin = 12;
        CGFloat bucketWidth = ceil(maxTextWidth + titleStart + titleRightMargin);
        CGFloat finalWidth = MAX(width, bucketWidth);
        // 用遮罩自身宽度(= 实际 window 宽度,见 self.frame 赋值)代替不旋转的
        // SCREEN_WIDTH,否则 iPad 横屏下菜单会锚在竖屏窄宽度上远离按钮。
        CGFloat winW = self.bounds.size.width;
        finalWidth = MIN(finalWidth, winW * 0.8);    // 极端长翻译时让 label 自己截断, 不出屏

        // 菜单位置以传入的 triangleLocation(point.x) 为锚——三角尖点在按钮中心,
        // 菜单右边缘距三角尖点 25pt(让三角底座 ±10pt 完全落在菜单顶边内部,右侧留 15pt
        // 呼吸),两侧各留至少 5pt 边距;iPad 横屏/分屏下用真实 window 宽度兜底,
        // 不再锚死在竖屏 SCREEN_WIDTH 上。
        CGFloat menuRightX = MIN(point.x + 25, winW - 5);
        // 三角尖点也要收进菜单的水平范围内,否则触发按钮太贴边时三角会画到菜单外面去。
        _trianglePoint.x = MIN(MAX(point.x, menuRightX - finalWidth + 10), menuRightX - 10);
        CGFloat menuX = MAX(menuRightX - finalWidth, 5);

        // 创建tableView
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(menuX, point.y + 10, finalWidth, kCellHeight * array.count) style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.layer.masksToBounds = YES;
        _tableView.layer.cornerRadius = 5;
        _tableView.scrollEnabled = NO;
        _tableView.rowHeight = kCellHeight;
        [_tableView registerClass:[PopMenuTableViewCell class] forCellReuseIdentifier:@"PopMenuTableViewCell"];
        [self addSubview:_tableView];

    }
    return self;
}

+ (void)showWithItems:(NSArray <NSDictionary *>*)array
                width:(CGFloat)width
     triangleLocation:(CGPoint)point
               window:(UIWindow *)window
               action:(void(^)(NSInteger index))action
{
    WKPopMenuView *view = [[WKPopMenuView alloc] initWithItems:array width:width triangleLocation:point window:window action:action];
    [view show];
}

- (void)tap {
    [self hide];
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:NSClassFromString(@"UITableViewCellContentView")]) {
        return NO;
    }
    return YES;
}

#pragma mark - show or hide
- (void)show {
    [(self.hostWindow ?: [UIApplication sharedApplication].keyWindow) addSubview:self];
    // anchorPoint = (1,0): position.x 即菜单右边缘;y 即菜单顶边。
    // 用 menu 自己 frame 的右边缘而不是 SCREEN_WIDTH,确保旋转后菜单仍紧贴三角尖点。
    _tableView.layer.position = CGPointMake(CGRectGetMaxX(_tableView.frame), _trianglePoint.y + 10);
    // 向右下transform
    _tableView.layer.anchorPoint = CGPointMake(1, 0);
    _tableView.transform = CGAffineTransformMakeScale(0.0001, 0.0001);
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 1;
        self->_tableView.transform = CGAffineTransformMakeScale(1.0, 1.0);
    }];
}

- (void)hide {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
        self->_tableView.transform = CGAffineTransformMakeScale(0.0001, 0.0001);
    } completion:^(BOOL finished) {
        [self->_tableView removeFromSuperview];
        [self removeFromSuperview];
        if (self.hideHandle) {
            self.hideHandle();
        }
    }];
}

#pragma mark - Draw triangle
- (void)drawRect:(CGRect)rect {
    // 设置背景色
    [[UIColor whiteColor] set];
    //拿到当前视图准备好的画板
    CGContextRef context = UIGraphicsGetCurrentContext();
    //利用path进行绘制三角形
    CGContextBeginPath(context);
    CGPoint point = _trianglePoint;
    // 设置起点
    CGContextMoveToPoint(context, point.x, point.y);
    // 画线
    CGContextAddLineToPoint(context, point.x - 10, point.y + 10);
    CGContextAddLineToPoint(context, point.x + 10, point.y + 10);
    CGContextClosePath(context);
    // 设置填充色
    [[WKApp shared].config.cellBackgroundColor setFill];
    // 设置边框颜色
    [[WKApp shared].config.cellBackgroundColor setStroke];
    // 绘制路径
    CGContextDrawPath(context, kCGPathFillStroke);
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tableData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PopMenuTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PopMenuTableViewCell" forIndexPath:indexPath];
    NSDictionary *dic = _tableData[indexPath.row];
    cell.leftImageView.image = dic[@"image"];
    cell.titleLabel.text = dic[@"title"];
    cell.titleLabel.textColor =  [UIColor colorWithRed:49.0f/255.0f green:49.0f/255.0f blue:49.0f/255.0f alpha:1.0f];
    [cell.titleLabel sizeToFit];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.layoutMargins = UIEdgeInsetsZero;
    cell.separatorInset = UIEdgeInsetsZero;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self hide];
    if (_action) {
        _action(indexPath.row);
    }
}
@end






@implementation PopMenuTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _leftImageView = [[UIImageView alloc] initWithFrame:CGRectMake(15, (kCellHeight - 22) / 2, 22, 22)];
        [self.contentView addSubview:_leftImageView];
        
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(_leftImageView.frame) + 10, _leftImageView.frame.origin.y+4.0f, 0, 0)];
        _titleLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
        [self.contentView addSubview:_titleLabel];
        
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.leftImageView.lim_centerY_parent = self.contentView;
    self.titleLabel.lim_centerY_parent = self.contentView;
    
    _titleLabel.textColor = [WKApp shared].config.defaultTextColor;
    
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    
    if (highlighted) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.1];
    }else {
        self.backgroundColor =[WKApp shared].config.cellBackgroundColor;
    }
}

@end

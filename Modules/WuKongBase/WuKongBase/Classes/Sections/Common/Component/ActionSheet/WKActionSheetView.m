
#import "WKActionSheetView.h"
#import "WuKongBase.h"

static CGFloat BtnHeight = 50.0;//每个按钮的高度
static CGFloat CancleMargin = 6.0;//取消按钮上面的间隔
#define ActionSheetColor(r, g, b) [UIColor colorWithRed:(r/255.0) green:(g/255.0) blue:(b/255.0) alpha:1.0]
#define ActionSheetBGColor ActionSheetColor(237,240,242) //背景色
#define ActionSheetSeparatorColor ActionSheetColor(226, 226, 226) //分割线颜色
#define ActionSheetNormalImage [self imageWithColor:ActionSheetColor(255,255,255)] //普通下的图片
#define ActionSheetHighImage [self imageWithColor:ActionSheetColor(242,242,242)] //高粱的图片
#define ActionSheetBlueNormalImage [self imageWithColor:ActionSheetColor(100,175,247)] //普通下的图片

#define ScreenWidth [UIScreen mainScreen].bounds.size.width
#define ScreenHeight [UIScreen mainScreen].bounds.size.height

#define  ActionSheetIPhoneX (ScreenWidth == 375.f && ScreenHeight == 812.f ? YES : NO)

#define  ActionSheetTabbarSafeBottomMargin   (ActionSheetIPhoneX ? 34.f : 0.f)

@interface WKActionSheetView ()

@property (nonatomic, strong) UIView *sheetView;
@property (nonatomic, copy) NSMutableArray *items;

@end

@implementation WKActionSheetView

- (instancetype)initWithCancleTitle:(NSString *)cancleTitle otherTitleArray:(NSArray *)otherTitleArray{
    self = [super init];
       if (self) {
           //黑色遮盖
           self.frame = [UIScreen mainScreen].bounds;
           self.backgroundColor = [UIColor blackColor];
           UIWindow *window = [[UIApplication sharedApplication] keyWindow];
           [window addSubview:self];
           self.alpha = 0.0;
           UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(coverClick)];
           [self addGestureRecognizer:tap];
           
           // sheet
           _sheetView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, 0)];
           _sheetView.backgroundColor = ActionSheetColor(236,239,240);
           [window addSubview:_sheetView];
           _sheetView.hidden = YES;
           
           
           int tag = 0;
           _items = [NSMutableArray array];
           //首先添加取消按钮
           WKActionSheetItem *cancleItem = [WKActionSheetItem itemWithTitle:LLang(@"取消") index:0];
           [_items addObject:cancleItem];
           
           tag ++;
           
           for (NSString *otherTitle in otherTitleArray) {
               WKActionSheetItem *item = [WKActionSheetItem itemWithTitle:otherTitle index:tag];
                [_items addObject:item];
                tag ++;
           }
           CGRect sheetViewF = _sheetView.frame;
           sheetViewF.size.height = BtnHeight * _items.count + CancleMargin;
           _sheetView.frame = sheetViewF;
           //开始添加按钮
           [self setupBtnWithTitles:@""];
       }
       return self;
}

- (instancetype)initWithCancleTitle:(NSString *)cancleTitle otherTitles:(NSString *)otherTitles, ...
{
    self = [super init];
    if (self) {
        //黑色遮盖
        self.frame = [UIScreen mainScreen].bounds;
        self.backgroundColor = [UIColor blackColor];
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        [window addSubview:self];
        self.alpha = 0.0;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(coverClick)];
        [self addGestureRecognizer:tap];
        
        // sheet
        _sheetView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, 0)];
        _sheetView.backgroundColor = ActionSheetColor(236,239,240);
        [window addSubview:_sheetView];
        _sheetView.hidden = YES;
        
        
        int tag = 0;
        _items = [NSMutableArray array];
        //首先添加取消按钮
        WKActionSheetItem *cancleItem = [WKActionSheetItem itemWithTitle:LLang(@"取消") index:0];
        [_items addObject:cancleItem];
        
        tag ++;
        
        NSString* curStr;
        va_list list;
        if(otherTitles)
        {
            WKActionSheetItem *item = [WKActionSheetItem itemWithTitle:otherTitles index:tag];
            [_items addObject:item];
            tag ++;
            
            va_start(list, otherTitles);
            while ((curStr = va_arg(list, NSString*))) {
                WKActionSheetItem *item = [WKActionSheetItem itemWithTitle:curStr index:tag];
                [_items addObject:item];
                tag ++;
            }
            va_end(list);
        }
        CGRect sheetViewF = _sheetView.frame;
        sheetViewF.size.height = BtnHeight * _items.count + CancleMargin;
        _sheetView.frame = sheetViewF;
        //开始添加按钮
        [self setupBtnWithTitles:@""];
    }
    return self;
    
}
- (instancetype)initWithMessageTitle:(NSString*)msgTitle  CancleTitle:(NSString *)cancleTitle otherTitles:(NSString *)otherTitles, ...
{
    self = [super init];
    if (self) {
        //黑色遮盖
        self.frame = [UIScreen mainScreen].bounds;
        self.backgroundColor = [UIColor blackColor];
        [[[UIApplication sharedApplication] keyWindow] addSubview:self];
        self.alpha = 0.0;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(coverClick)];
        [self addGestureRecognizer:tap];
        
        // sheet
        _sheetView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, 0)];
        _sheetView.backgroundColor = ActionSheetColor(236,239,240);
        [[[UIApplication sharedApplication] keyWindow] addSubview:_sheetView];
        _sheetView.hidden = YES;
        
        
        int tag = 0;
        _items = [NSMutableArray array];
        //首先添加取消按钮
        WKActionSheetItem *cancleItem = [WKActionSheetItem itemWithTitle:LLang(@"取消") index:0];
        [_items addObject:cancleItem];
        
        tag ++;
        
        NSString* curStr;
        va_list list;
        if(otherTitles)
        {
            WKActionSheetItem *item = [WKActionSheetItem itemWithTitle:otherTitles index:tag];
            [_items addObject:item];
            tag ++;
            
            va_start(list, otherTitles);
            while ((curStr = va_arg(list, NSString*))) {
                WKActionSheetItem *item = [WKActionSheetItem itemWithTitle:curStr index:tag];
                [_items addObject:item];
                tag ++;
            }
            va_end(list);
        }
        CGRect sheetViewF = _sheetView.frame;
        sheetViewF.size.height = BtnHeight * _items.count + CancleMargin+BtnHeight;
        _sheetView.frame = sheetViewF;
        //开始添加按钮
        [self setupBtnWithTitles:msgTitle];
    }
    return self;
    
}


// 创建每个选项
- (void)setupBtnWithTitles:(NSString*)msgTitle {
    NSInteger index = 1;
    if (![msgTitle isEqualToString:@""]) {
        UIView * titleView =[[UIView alloc]init];
        titleView.frame =CGRectMake(0, 0, ScreenWidth, BtnHeight);
        titleView.backgroundColor = [UIColor whiteColor];
        UILabel * label = [[UILabel alloc]initWithFrame:titleView.frame];
        label.textAlignment = NSTextAlignmentCenter;
        label.font =[UIFont systemFontOfSize:15.0f];
        label.text = msgTitle;
        label.textColor =  [UIColor colorWithRed:155.0f / 255.0                                         \
                         green:155.0 / 255.0                                          \
                          blue:155.0 / 255.0                                          \
                         alpha:1.0f];
        [self.sheetView addSubview:titleView];
        [self.sheetView addSubview:label];
        index =0;
    }
  
    for (WKActionSheetItem *item in _items) {
        UIButton *btn = nil;
        if (item.index == 0) {//取消按钮
            btn = [[UIButton alloc] initWithFrame:CGRectMake(0, _sheetView.frame.size.height - BtnHeight, ScreenWidth, BtnHeight)];
          
            
        } else {
            btn = [[UIButton alloc] initWithFrame:CGRectMake(0, BtnHeight * (item.index - index) , ScreenWidth, BtnHeight)];
            // 最上面画分割线
            UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, 0.5)];
            line.backgroundColor = ActionSheetSeparatorColor;
            
            [btn addSubview:line];
            
        }
        btn.tag = item.index;
        
        [btn setBackgroundImage:ActionSheetNormalImage forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [btn setBackgroundImage:ActionSheetHighImage forState:UIControlStateHighlighted];
        [btn setTitle:item.title forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:17.0f];
        [btn addTarget:self action:@selector(sheetBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.sheetView addSubview:btn];
    }
    
    UIView * view = [[UIView alloc]initWithFrame:CGRectMake(0, _sheetView.frame.size.height, ScreenWidth, ActionSheetTabbarSafeBottomMargin)];
    view.backgroundColor = [UIColor whiteColor] ;
    [self.sheetView addSubview:view];
}
- (void)show {
    self.sheetView.hidden = NO;
    
    CGRect sheetViewF = self.sheetView.frame;
    sheetViewF.origin.y = ScreenHeight;
    self.sheetView.frame = sheetViewF;
    
    CGRect newSheetViewF = self.sheetView.frame;
    newSheetViewF.origin.y =ScreenHeight - self.sheetView.frame.size.height-ActionSheetTabbarSafeBottomMargin;
    
    [UIView animateWithDuration:0.3 animations:^{
        
        self.sheetView.frame = newSheetViewF;
        
        self.alpha = 0.3;
    }];
}


// 显示黑色遮罩
- (void)coverClick{
    CGRect sheetViewF = self.sheetView.frame;
    sheetViewF.origin.y = ScreenHeight-ActionSheetTabbarSafeBottomMargin;
    
    [UIView animateWithDuration:0.2 animations:^{
        self.sheetView.frame = sheetViewF;
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        [self.sheetView removeFromSuperview];
    }];
}

- (void)sheetBtnClick:(UIButton *)btn{
    WKActionSheetItem *item = _items[btn.tag];
    
    if (item.index == 0) {
        [self coverClick];
        return;
    }
    if (self.clickBlock) {
        self.clickBlock(item);
    }
    
    [self coverClick];
}

//根据颜色生成图片
- (UIImage*)imageWithColor:(UIColor*)color
{
    CGRect rect=CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
}


@end

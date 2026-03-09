//
//  WKTabbar.m
//  WuKongBase
//
//  Created by tt on 2025/2/26.
//

#import "WKTabbar.h"
#import "WuKongBase/WuKongBase.h"

#define titleLabelTag 1000
#define defaultColor [UIColor colorWithRed:120.0f/255.0f green:120.0f/255.0f blue:120.0f/255.0f alpha:1.0f] // 默认颜色
#define selectedColor WKApp.shared.config.defaultTextColor // 被选中后的颜色

@implementation WKTabbarItem

-(id) initWithTitle:(NSString*)title onClick:(void(^)(void))onClick {
    self = [super init];
    if(self) {
        self.title = title;
        self.onClick = onClick;
    }
    return  self;
}

@end

@interface WKTabbar ()

@property(nonatomic,strong) NSArray<WKTabbarItem *> *items;

@property(nonatomic,strong) UIView *indicatorView; // 选中的指示标

@property(nonatomic,strong) UIScrollView *scrollView;

@property(nonatomic,assign) NSInteger selectedIndex;

@end

@implementation WKTabbar

- (id)initWithItems:(NSArray<WKTabbarItem *> *)items width:(CGFloat)width{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, width, 32.0f)];
    if (self) {
        self.items = items;
        self.backgroundColor = WKApp.shared.config.backgroundColor;
        [self addSubview:self.indicatorView];
        [self addSubview:self.scrollView];
        
        NSInteger index= 0;
        for (WKTabbarItem *item in items) {
            [self.scrollView addSubview:[self titleView:item.title index:index]];
            index++;
        }
    }
    return  self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    NSArray *subviews = self.scrollView.subviews;
    
    UIView *preView;
    for (UIView *itemView in subviews) {
        if(!preView) {
            itemView.lim_left = 0.0f;
            itemView.lim_centerY_parent = self;
        }else {
            itemView.lim_left = preView.lim_right;
            itemView.lim_centerY_parent = self;
        }
        preView = itemView;
    }
    
    if(preView) {
        self.scrollView.contentSize = CGSizeMake(preView.lim_right, self.lim_height);
    }
    
    [self setSelectedByIndex:self.selectedIndex];
}

-(void) setSelectedByIndex:(NSInteger)index {
    NSArray<UIView*> *subviews = self.scrollView.subviews;
    if(index>=subviews.count) {
        return;
    }
    
    for (UIView *subview in subviews) {
        UILabel *titleLbl =[subview viewWithTag:titleLabelTag];
        titleLbl.textColor = defaultColor;
    }
    
    UIView *selectedView = subviews[index];
    
    UILabel *titleLbl = (UILabel*)[selectedView viewWithTag:titleLabelTag];
    titleLbl.textColor = selectedColor;
    
    self.indicatorView.lim_width = titleLbl.lim_width + 10;
    self.indicatorView.lim_left = selectedView.lim_left + (selectedView.lim_width/2.0f - self.indicatorView.lim_width/2.0f);
    self.indicatorView.lim_top = self.scrollView.lim_height - self.indicatorView.lim_height;
    
    
    
}

-(UIScrollView*) scrollView {
    if(!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:self.frame];
    }
    return _scrollView;
}

// 获取标题视图
-(UIButton*) titleView:(NSString*)title index:(NSInteger)index {
    CGSize size = [self calculateWidthWithText:title font:[WKApp.shared.config defaultFont]];
    
    CGFloat leftSpace = 20.0f; // 左右边距
    CGFloat topSpace = 5.0f; // 上下边距
    
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.tag = titleLabelTag;
    titleLbl.text = title;
    titleLbl.font = WKApp.shared.config.defaultFont;
    titleLbl.textColor = defaultColor;
    [titleLbl sizeToFit];
    
    
    UIButton *view = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, leftSpace*2 + size.width, topSpace*2+ size.height)];
    view.tag = index;
    [view addTarget:self action:@selector(itemClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [view addSubview:titleLbl];
    
    titleLbl.lim_centerX_parent = view;
    titleLbl.lim_centerY_parent = view;
    
    return view;
}

-(void) itemClick:(UIButton*)btn {
    self.selectedIndex = btn.tag;
    
    [UIView animateWithDuration:0.2f animations:^{
        [self layoutSubviews];
    }];
    WKTabbarItem *item =  self.items[self.selectedIndex];
    if(item.onClick) {
        item.onClick();
    }
}

-(UIView *) indicatorView {
    if(!_indicatorView) {
        _indicatorView = [[UIView alloc] init];
        _indicatorView.backgroundColor = WKApp.shared.config.defaultTextColor;
        _indicatorView.lim_height = 2.0f;
        _indicatorView.layer.masksToBounds = YES;
        _indicatorView.layer.cornerRadius = 2.0f;
    }
    return _indicatorView;
}

- (CGSize)calculateWidthWithText:(NSString *)text font:(UIFont *)font {
    if (!text || !font) return CGSizeZero;
    
    NSDictionary *attributes = @{NSFontAttributeName: font};
    CGSize textSize = [text sizeWithAttributes:attributes];
    return textSize; //
}

@end

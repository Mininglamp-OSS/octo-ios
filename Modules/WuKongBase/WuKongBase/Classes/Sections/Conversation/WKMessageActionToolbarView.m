//
//  WKMessageActionToolbarView.m
//  WuKongBase
//
//  Created by tt on 2021/9/24.
//

#import "WKMessageActionToolbarView.h"

@interface WKMessageActionToolbarView ()

@property(nonatomic,strong) NSArray<WKMessageLongMenusItem*> *toolbarMenus;

@property(nonatomic,strong) UIScrollView *contentView;

@end

@implementation WKMessageActionToolbarView

-(instancetype) initWithToolbarMenus:(NSArray<WKMessageLongMenusItem*>*)toolbarMenus {
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 60.0f)];
    if(self) {
        self.backgroundColor = [WKApp shared].config.backgroundColor;
        self.toolbarMenus = toolbarMenus;
        self.contentView.lim_size = self.lim_size;
        [self addSubview:self.contentView];
        
        if(toolbarMenus && toolbarMenus.count>0) {
            NSInteger i = 0;
            for (WKMessageLongMenusItem *menusItem in toolbarMenus) {
                [self.contentView addSubview:[self newItemView:menusItem tag:i]];
                i++;
            }
        }
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    NSArray *subviews = self.contentView.subviews;
    
    UIView *preview;
    for (UIView *view in subviews) {
        if(preview) {
            view.lim_left = preview.lim_right;
        }
        view.lim_centerY_parent = self.contentView;
        
        preview = view;
    }
    self.contentView.contentSize = CGSizeMake(preview.lim_right, self.contentView.lim_height);
    [self.contentView flashScrollIndicators];
}


- (UIScrollView *)contentView {
    if(!_contentView) {
        _contentView = [[UIScrollView alloc] init];
    }
    return _contentView;
}

-(UIView*) newItemView:(WKMessageLongMenusItem*)menusItem tag:(NSInteger)tag{
    UIView *view = [[UIView alloc] init];
//    [view setBackgroundColor:[UIColor redColor]];
    UILabel *label = [[UILabel alloc] init];
    label.font = [[WKApp shared].config appFontOfSize:15.0f];
    label.textColor = [WKApp shared].config.defaultTextColor;
    [view addSubview:label];
    
    label.text = menusItem.title;
    [label sizeToFit];
    
    view.lim_size = CGSizeMake(label.lim_width + 30.0f, self.lim_height);
    label.lim_centerX_parent = view;
    label.lim_centerY_parent = view;
    
    view.tag = tag;
    view.userInteractionEnabled = YES;
    [view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)]];
    
    return view;
}

-(void) onTap:(UITapGestureRecognizer*)gesture {
    NSInteger index = gesture.view.tag;
    
   WKMessageLongMenusItem *item = self.toolbarMenus[index];
    if(self.onClick) {
        self.onClick(item);
    }
}

@end

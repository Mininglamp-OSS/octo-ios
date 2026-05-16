//
//  WKBarUserSearchView.m
//
//  Created by tangtao on 15/12/10.
//  Copyright © 2015年 WuKong. All rights reserved.
//

#import "WKBarUserSearchView.h"
#import "WKResource.h"


@implementation WKBarUserSearchModel

- (instancetype)initWithSid:(NSString *)sid {
    self = [super init];
    if (self) {
        self.sid = sid;
    }
    
    return self;
}

- (BOOL)isEqual:(id)object {
    if ([self.sid isEqualToString:((WKBarUserSearchModel *)object).sid]) {
        
        return YES;
    }
    
    return NO;
}

@end

@interface WKBarUserSearchView ()

@property(nonatomic, strong) NSMutableArray *items;

@property(nonatomic, strong) UIImage *searchImg;

@property(nonatomic, strong) UIScrollView *containerScollView;

@property(nonatomic,assign) BOOL searchByReturn;

@end

@implementation WKBarUserSearchView

#pragma mark public
- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame searchByReturn:false];
}

- (instancetype)initWithFrame:(CGRect)frame searchByReturn:(BOOL)searchByReturn {
    self = [super initWithFrame:frame];
    if (self) {
        self.searchByReturn = searchByReturn;
        if(searchByReturn) {
            [self.searchFd addTarget:self
                              action:@selector(textFieldDidChange:)
                    forControlEvents:UIControlEventEditingDidEndOnExit];
        }else {
            [self.searchFd addTarget:self
                              action:@selector(textFieldDidChange:)
                    forControlEvents:UIControlEventEditingChanged];
        }
       
        [self addSubview:self.containerScollView];
        [self addSubview:self.searchFd];
        
        [self refreshView];
    }
    return self;
}

//文本输入改变
- (void)textFieldDidChange:(UITextField *)textField {
    
    if (_searchDidChangeBlock) {
        
        _searchDidChangeBlock(textField.text);
    }
}

//添加模型
- (void)addModel:(WKBarUserSearchModel *)model {
    
    [self.items insertObject:model atIndex:0];
    [self refreshView];
    
    [self scrollToLeft];
}

- (void)scrollToLeft {
    
    [self.containerScollView setContentOffset:CGPointMake(0, 0) animated:YES];
}

//移除模型
- (void)removeModel:(WKBarUserSearchModel *)model {
    
    [self.items removeObject:model];
    
    [self refreshView];
    
    [self scrollToLeft];
}

- (NSArray *)selectedModels {
    
    return self.items;
}

#pragma mark private
- (NSMutableArray *)items {
    
    if (!_items) {
        
        _items = [NSMutableArray array];
    }
    
    return _items;
}

#define WKBarUserIconSpace  5.0f
#define WKBarUserIconSize  CGSizeMake(40.0f,40.0f)
#define WKBarUserSearchInputMinWidth 40
//刷新视图
- (void)refreshView {
    
    [[self.containerScollView subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    if (self.items.count == 0) {
    }
    
    [self frameContainerScollView];
    
    [self frameSearchFd];
    
    
    [self.items
     enumerateObjectsUsingBlock:^(WKBarUserSearchModel *model,
                                  NSUInteger idx, BOOL *_Nonnull stop) {
         UIImageView *iconViewImg = [self newIconImageView:model index:idx];
         iconViewImg.lim_left =
         idx * (iconViewImg.lim_width + WKBarUserIconSpace) +
         WKBarUserIconSpace;
         [self.containerScollView addSubview:iconViewImg];
     }];
}

//设置搜索文本域的frame
- (void)frameSearchFd {
    
    self.searchFd.lim_width = WKScreenWidth - self.containerScollView.lim_width;
    self.searchFd.lim_left =
    self.containerScollView.lim_right + WKBarUserIconSpace;
}

//设置滚动容器的frame
- (void)frameContainerScollView {
    
    NSInteger width = (WKBarUserIconSize.width + WKBarUserIconSpace) *
    self.items.count +
    WKBarUserIconSpace;
    
    if (WKScreenWidth - width >WKBarUserSearchInputMinWidth) {
        self.containerScollView.lim_width = width;
    }
    
    self.containerScollView.contentSize = CGSizeMake(width, self.lim_height);
}

- (UIImage *)searchImg {
    
    if (!_searchImg) {
        _searchImg = [self imageName:@"Common/Index/DefaultAvatar"];
    }
    
    return _searchImg;
}

- (UITextField *)searchFd {
    if (!_searchFd) {
        _searchFd = [[UITextField alloc]
                     initWithFrame:CGRectMake(0, 0, 0, self.lim_height)];
        _searchFd.placeholder =LLang(@"搜索");
        _searchFd.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        if(self.searchByReturn) {
            _searchFd.returnKeyType = UIReturnKeySearch;
        }
    }
    
    return _searchFd;
}

// imageView创建
- (UIImageView *)newIconImageView:(WKBarUserSearchModel *)model
                                 index:(NSInteger)index {
    
    WKImageView *imageView = [[WKImageView alloc]
                              initWithFrame:CGRectMake(
                                                       0,
                                                       (self.lim_height -WKBarUserIconSize.height) / 2,
                                                       WKBarUserIconSize.width,
                                                       WKBarUserIconSize.height)];
    imageView.layer.masksToBounds = YES;
    imageView.layer.cornerRadius = imageView.lim_height/2.0f;
    
    [imageView loadImage:[NSURL URLWithString:model.icon] placeholderImage:[WKApp shared].config.defaultAvatar];
    
    imageView.tag = index;
    imageView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGecognizer = [[UITapGestureRecognizer alloc]
                                             initWithTarget:self
                                             action:@selector(iconImageViewPressed:)];
    [imageView addGestureRecognizer:tapGecognizer];
    return imageView;
}

#pragma mark icon点击事件
- (void)iconImageViewPressed:(UIGestureRecognizer *)recognizer {
    UIView *view = [recognizer view];
    
    WKBarUserSearchModel *model = [self.items objectAtIndex:view.tag];
    _removeIconBlock(model);
    
    [self.items removeObjectAtIndex:view.tag];
    
    [self refreshView];
}

- (UIScrollView *)containerScollView {
    
    if (!_containerScollView) {
        _containerScollView = [[UIScrollView alloc]
                               initWithFrame:CGRectMake(0, 0, 0, self.lim_height)];
        _containerScollView.showsVerticalScrollIndicator = FALSE;
        _containerScollView.showsHorizontalScrollIndicator = FALSE;
    }
    
    return _containerScollView;
}
-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end

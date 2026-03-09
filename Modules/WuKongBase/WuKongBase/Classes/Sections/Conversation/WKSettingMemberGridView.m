//
//  WKSettingMemberGridView.m
//  WuKongBase
//
//  Created by tt on 2020/1/20.
//

#import "WKSettingMemberGridView.h"
#import "UIView+WK.h"
#import "WuKongBase.h"

#define gridViewHeightBottomSpace 20.0f
@interface WKSettingMemberGridView ()

@property(nonatomic,assign) CGFloat maxWidth; // 视图最大宽度

@property(nonatomic,assign) CGFloat itemWidth; // 每个item大小

@property(nonatomic,strong) NSMutableArray *items; // item集合

@property(nonatomic,assign) NSInteger numberOfLine; // 每行item的数量



@property(nonatomic,strong) UIButton *moreBtn;
@property(nonatomic,strong) UIImageView *moreIcon;

@end

@implementation WKSettingMemberGridView

+(instancetype) initWithMaxWidth:(CGFloat) maxWidth  numberOfLine:(NSInteger)number{
    return [self initWithMaxWidth:maxWidth numberOfLine:number hasMore:false];
}
+(instancetype) initWithMaxWidth:(CGFloat) maxWidth numberOfLine:(NSInteger)number hasMore:(BOOL)hasMore {
    WKSettingMemberGridView *view = [WKSettingMemberGridView new];
    view.maxWidth = maxWidth;
    view.lim_width = maxWidth;
    view.items = [NSMutableArray array];
    view.numberOfLine = number;
    view.itemWidth = maxWidth/number;
    view.hasMore = hasMore;
    return view;
}

- (UIButton *)moreBtn {
    if(!_moreBtn) {
        _moreBtn = [[UIButton alloc] init];
        [[_moreBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:15.0f]];
        [_moreBtn setTitle:LLang(@"查看更多群成员") forState:UIControlStateNormal];
        [_moreBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [_moreBtn sizeToFit];
        [_moreBtn addTarget:self action:@selector(morePressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _moreBtn;
}

-(void) morePressed {
    if(self.onMore) {
        self.onMore();
    }
}

-(void) reloadData {
    if(self.subviews) {
        for (UIView *subView in self.subviews) {
            [subView removeFromSuperview];
        }
    }
    NSInteger count = [self.delegate numberOfSettingMemberGridView:self];
    for (NSInteger i=0; i<count; i++) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(itemTap:)];
        UIView *view = [self getItemView:i];
        [view addGestureRecognizer:tap];
        view.tag = i;
        [self addSubview:view];
    }
    self.lim_height = [self viewHeight];
    
    if(self.hasMore) {
        self.moreBtn.lim_top = self.lim_height - 4.0f - self.moreBtn.lim_height;
        [self addSubview:self.moreBtn];
        
        self.moreBtn.lim_centerX_parent = self;
        
    }
}

-(void) itemTap:(UIGestureRecognizer*)gesture {
    NSInteger index = gesture.view.tag;
    if([self.delegate respondsToSelector:@selector(settingMemberGridView:didSelect:)]) {
        [self.delegate settingMemberGridView:self didSelect:index];
    }
}

// item总高度
-(CGFloat) itemTotalHeight {
    NSInteger count = [self.delegate numberOfSettingMemberGridView:self];
    CGFloat itemHeight =self.itemWidth + gridViewHeightBottomSpace;
   return itemHeight*[self getLineWithIndex:count-1];
}

- (CGFloat)viewHeight {
    CGFloat height = [self itemTotalHeight];
    if(self.hasMore) {
        return height+40.0f;
    }
    return height;
}


-(UIView*) getItemView:(NSInteger)index {
    CGFloat itemHeight =self.itemWidth + gridViewHeightBottomSpace;
    NSInteger line = [self getLineWithIndex:index];
    UIView *view = [self.delegate settingMemberGridView:self size:CGSizeMake(self.itemWidth, itemHeight) atIndex:index];
    view.lim_left = index * self.itemWidth - (line-1)*self.numberOfLine*self.itemWidth;
    view.lim_top =  (line-1) * itemHeight;
    
    return view;
}

-(NSInteger) getLineWithIndex:(NSInteger) index {
    NSInteger line = (index+1) / self.numberOfLine;
    
    if( (index+1) % self.numberOfLine > 0) {
        line = line +1;
    }
    return line;
}
@end

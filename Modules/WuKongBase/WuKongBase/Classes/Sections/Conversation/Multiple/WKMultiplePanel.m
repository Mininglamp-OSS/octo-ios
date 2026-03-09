//
//  WKMultiplePanel.m
//  WuKongBase
//
//  Created by tt on 2020/10/11.
//

#import "WKMultiplePanel.h"
#import "WKResource.h"
#import "UIView+WK.h"
#import "WKActionSheetView2.h"
#import "WuKongBase.h"
@interface WKMultiplePanel ()

@property(nonatomic,strong) UIButton *forwardBtn;

@property(nonatomic,strong) UIButton *deleteBtn; // 删除


@end

#define iconWidth 40.0f

@implementation WKMultiplePanel

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:[UIColor whiteColor]];
        [self addSubview:self.forwardBtn];
        [self addSubview:self.deleteBtn];
    }
    return self;
}

- (UIButton *)forwardBtn {
    if(!_forwardBtn) {
        _forwardBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 20.0f, iconWidth, iconWidth)];
        [_forwardBtn setImage:[self imageName:@"Conversation/Index/MultipleForward"] forState:UIControlStateNormal];
        [_forwardBtn addTarget:self action:@selector(forwardPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _forwardBtn;
}

-(UIButton*) deleteBtn {
    if(!_deleteBtn){
        _deleteBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 20.0f, iconWidth, iconWidth)];
        [_deleteBtn setImage:[self imageName:@"Conversation/Index/MultipleDelete"] forState:UIControlStateNormal];
        [_deleteBtn addTarget:self action:@selector(deletePressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _deleteBtn;
}

-(void) deletePressed {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *sheetView = [WKActionSheetView2 initWithTip:nil cancel:nil];
    [sheetView addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"删除") onClick:^{
        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(multiplePanel:action:)]) {
            [weakSelf.delegate multiplePanel:weakSelf action:WKMultipActionDelete];
        }
    }]];
    [sheetView show];
}

-(void) forwardPressed {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *sheetView = [WKActionSheetView2 initWithTip:nil cancel:nil];
    [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"逐条转发") onClick:^{
        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(multiplePanel:action:)]) {
            [weakSelf.delegate multiplePanel:weakSelf action:WKMultipActionForward];
        }
    }]];
    [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"合并转发") onClick:^{
        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(multiplePanel:action:)]) {
            [weakSelf.delegate multiplePanel:weakSelf action:WKMultipActionMergeForward];
        }
    }]];
    [sheetView show];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat space = (self.lim_width - iconWidth*2)/3.0f;
    
    self.forwardBtn.lim_left = space;
    
    self.deleteBtn.lim_left = self.forwardBtn.lim_right + space;
    
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end

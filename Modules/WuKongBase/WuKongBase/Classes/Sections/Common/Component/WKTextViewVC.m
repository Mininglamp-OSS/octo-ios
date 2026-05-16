//
//  WKTextViewVC.m
//  WuKongBase
//
//  Created by tt on 2022/10/13.
//

#import "WKTextViewVC.h"
#define WKFinishTitle LLang(@"完成")
#import "NSString+WK.h"
#import "UITextView+WKPlaceholder.h"
@interface WKTextViewVC ()<UITableViewDataSource,UITableViewDelegate,UITextViewDelegate>
@property(nonatomic,strong)  UITableView *tableView;
@property(nonatomic,strong) UIView *headerView;

@property(nonatomic,strong) UITextView *textView;

@property(nonatomic,strong) UILabel *limitLbl;

@property(nonatomic,strong) UILabel *tipLbl;



@end

@implementation WKTextViewVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.editable = true;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
  
    [self.view addSubview:self.tableView];
    if(self.editable) {
        [self setRightBarItem:WKFinishTitle withDisable:true];
    }
    
    
    [self setLimitText:self.defaultValue.length];
    
    self.textView.editable = self.editable;
    
    
    self.tipLbl.text = self.tip;
    [self.tipLbl sizeToFit];
    
    self.tipLbl.lim_top = self.textView.lim_height + self.limitLbl.lim_height + 50.0f;
    self.tipLbl.lim_centerX_parent = self.view;
    
}


- (UITableView *)tableView{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:[self visibleRect] style:UITableViewStyleGrouped];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        UIEdgeInsets separatorInset = _tableView.separatorInset;
        separatorInset.right          = 0;
        _tableView.separatorInset = separatorInset;
        _tableView.backgroundColor=[UIColor clearColor];
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.sectionHeaderHeight = 0.0f;
        _tableView.sectionFooterHeight = 0.0f;
        
        [self.headerView addSubview:self.textView];
        [self.headerView addSubview:self.limitLbl];
        [self.headerView addSubview:self.tipLbl];
        
        _tableView.tableHeaderView = self.headerView;
        _tableView.tableFooterView = [[UIView alloc] init];
        
        
    }
    return _tableView;
}

- (void)setPlaceholder:(NSString *)placeholder {
    self.textView.placeholder = placeholder;
}

- (void)setEditable:(BOOL)editable {
    _editable = editable;
    self.textView.editable = editable;

}



- (UIView *)headerView {
    if(!_headerView) {
        CGFloat limitHeight = 18.0f;
        CGFloat tipHeight = 18.0f;
        _headerView = [[UIView alloc] init];
        _headerView.lim_height = self.textView.lim_height + limitHeight + tipHeight + 20.0f;
        _headerView.lim_width = self.view.lim_width;
        [_headerView setBackgroundColor:[UIColor clearColor]];
    }
    return _headerView;
}

- (UITextView *)textView {
    if(!_textView) {
        _textView = [[UITextView alloc] initWithFrame:CGRectMake(0.0f, 0, WKScreenWidth, 250)];
        [_textView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        _textView.delegate = self;
        _textView.returnKeyType = UIReturnKeyDone;
        _textView.font = [WKApp.shared.config appFontOfSize:16.0f];
    }
    return _textView;
}

- (UILabel *)limitLbl {
    if(!_limitLbl) {
        _limitLbl = [[UILabel alloc] init];
        _limitLbl.font = [WKApp.shared.config appFontOfSize:14.0f];
        _limitLbl.textColor = WKApp.shared.config.tipColor;
    }
    return _limitLbl;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.font = [WKApp.shared.config appFontOfSize:14.0f];
        _tipLbl.textColor = WKApp.shared.config.tipColor;
    }
    return _tipLbl;
}

-(void) setLimitText:(NSInteger)limit {
    self.limitLbl.text = [NSString stringWithFormat:@"%ld/%ld",(long)limit,self.maxLength];
    [self.limitLbl sizeToFit];
    
    self.limitLbl.lim_top = self.textView.lim_height + 20.0f;
    self.limitLbl.lim_left = self.view.lim_width - self.limitLbl.lim_width - 15.0f;
    
    self.limitLbl.hidden = !self.editable;
}

- (void)setDefaultValue:(NSString *)defaultValue {
    _defaultValue = defaultValue;
    self.textView.text = defaultValue;
}

 - (BOOL)textFieldShouldReturn:(UITextField *)textField {
     if(self.onFinish) {
         self.onFinish(textField.text);
     }
     return YES;
}



- (void) setRightBarItem:(NSString *)title
             withDisable:(BOOL)disable {
    
    self.navigationItem.rightBarButtonItem = nil;
    if(disable) {
        self.rightView =
        [self barButtonItemWithTitle:title
                          titleColor:[[WKApp shared].config.navBarButtonColor colorWithAlphaComponent:0.5f] action:nil];
    }else {
        self.rightView =
        [self barButtonItemWithTitle:title
                          titleColor:[WKApp shared].config.navBarButtonColor
                              action:@selector(finishedPressed)];
    }
    
    
}

-(void) finishedPressed {
    if(self.onFinish) {
        self.onFinish(self.textView.text);
    }
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if(type == WKViewConfigChangeTypeStyle) {
        [self.textView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    }
    
}

//带标题的按钮样式
- (UIButton *)barButtonItemWithTitle:(NSString *)title
                                 titleColor:(UIColor *)titleColor
                                     action:(SEL)selector {
    UIButton *barBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.0f)];
       [barBtn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
       [barBtn setTitle:title forState:UIControlStateNormal];
       [barBtn setTitleColor:titleColor forState:UIControlStateNormal];
       [barBtn sizeToFit];
       return barBtn;
}

#pragma mark -- UITextViewDelegate
- (void)textViewDidChange:(UITextView *)textView {
    
    NSString *toBeString = textView.text;
    UITextRange *selectedRange = [textView markedTextRange];
    //获取高亮部分
    UITextPosition *position = [textView positionFromPosition:selectedRange.start offset:0];
    // 没有高亮选择的字，则对已输入的文字进行字数统计和限制
    if (!position) {
        if(self.maxLength>0) {
            NSString *realText = [toBeString limitedStringForMaxBytesLength:self.maxLength*2];
            if(![realText isEqualToString:textView.text]) {
                textView.text = realText;
            }
        }
    }
    
    NSString *defaultValue = self.defaultValue?:@"";
    if(![[textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:defaultValue]) {
        [self setRightBarItem:WKFinishTitle withDisable:false];
    }else {
        [self setRightBarItem:WKFinishTitle withDisable:true];
    }
    
    [self setLimitText:textView.text.length];
}


#pragma mark - UITableViewDelegate,UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark - UITextFieldDelegate



@end

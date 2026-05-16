//
//  WKInputVC.m
//  WuKongBase
//
//  Created by tt on 2020/1/27.
//

#import "WKInputVC.h"
#import "UIView+WK.h"
#import "WKConstant.h"
#import  "UIBarButtonItem+WK.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "NSString+WK.h"
#define WKFinishTitle LLang(@"完成")
@interface WKInputVC ()<UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate>

@property(nonatomic,strong)  UITableView *tableView;
@property(nonatomic,strong) UIView *headerView;

@property(nonatomic,strong) UITextField *textField;

@property(nonatomic,strong) UILabel *placeholderLbl;
@end

@implementation WKInputVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.tableView];
    [self.headerView addSubview:self.placeholderLbl];
    [self setRightBarItem:WKFinishTitle withDisable:true];
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
        
        [self.headerView addSubview:self.textField];
        
        _tableView.tableHeaderView = self.headerView;
        _tableView.tableFooterView = [[UIView alloc] init];
        
        
    }
    return _tableView;
}

- (void)setPlaceholder:(NSString *)placeholder {
    self.placeholderLbl.text = placeholder;
    [self.placeholderLbl sizeToFit];
}

- (UILabel *)placeholderLbl {
    if(!_placeholderLbl) {
        _placeholderLbl = [[UILabel alloc] init];
        _placeholderLbl.textColor = [UIColor grayColor];
        _placeholderLbl.lim_width = WKScreenWidth - 20.0f;
        _placeholderLbl.lim_top = self.textField.lim_bottom + 10.0f;
        _placeholderLbl.numberOfLines = 0;
        _placeholderLbl.lineBreakMode = NSLineBreakByCharWrapping;
        _placeholderLbl.lim_left = 10.0f;
        [_placeholderLbl setFont:[UIFont systemFontOfSize:15.0f]];
    }
    return _placeholderLbl;
}

- (UIView *)headerView {
    if(!_headerView) {
        _headerView = [[UIView alloc] init];
        _headerView.lim_height = 100.0f;
        _headerView.lim_width = self.view.lim_width;
        [_headerView setBackgroundColor:[UIColor clearColor]];
    }
    return _headerView;
}

- (UITextField *)textField {
    if(!_textField) {
        _textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 50.0f)];
        [_textField setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        _textField.delegate = self;
        _textField.returnKeyType = UIReturnKeyDone;
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        UIView *leftView = [[UIView alloc] init];
        leftView.lim_width = 10.0f;
        _textField.leftViewMode = UITextFieldViewModeAlways;
        _textField.leftView = leftView;
        [_textField addTarget:self action:@selector(textValueChanged:) forControlEvents:UIControlEventEditingChanged];
    
    }
    return _textField;
}

- (void)setDefaultValue:(NSString *)defaultValue {
    _defaultValue = defaultValue;
    self.textField.text = defaultValue;
}

 - (BOOL)textFieldShouldReturn:(UITextField *)textField {
     if(self.onFinish) {
         self.onFinish(textField.text);
     }
     return YES;
}

-(void) textValueChanged:(UITextField*)textField {
    
    NSString *toBeString = textField.text;
    UITextRange *selectedRange = [textField markedTextRange];
    //获取高亮部分
    UITextPosition *position = [textField positionFromPosition:selectedRange.start offset:0];
    // 没有高亮选择的字，则对已输入的文字进行字数统计和限制
    if (!position) {
        if(self.maxLength>0) {
            NSString *realText = [toBeString limitedStringForMaxBytesLength:self.maxLength*2];
            if(![realText isEqualToString:textField.text]) {
                textField.text = realText;
            }
        }
    }
    
    NSString *defaultValue = self.defaultValue?:@"";
    if(![textField.text isEqualToString:defaultValue]) {
        [self setRightBarItem:WKFinishTitle withDisable:false];
    }else {
        [self setRightBarItem:WKFinishTitle withDisable:true];
    }
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
        self.onFinish(self.textField.text);
    }
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if(type == WKViewConfigChangeTypeStyle) {
        [self.textField setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
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

#pragma mark - UITableViewDelegate,UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark - UITextFieldDelegate

@end

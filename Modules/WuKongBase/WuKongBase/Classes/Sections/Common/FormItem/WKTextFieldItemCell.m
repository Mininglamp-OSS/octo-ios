//
//  WKTextFielItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/10/30.
//

#define labelWidth 60.0f

#import "WKTextFieldItemCell.h"

@implementation WKTextFieldItemModel

- (NSString *)placeholder {
    if(!_placeholder) {
        return @"请输入";
    }
    return _placeholder;
}

- (Class)cell {
    return WKTextFieldItemCell.class;
}

- (NSNumber*)keyboardType {
    if(!_keyboardType) {
        return @(UIKeyboardTypeDefault);
    }
    return _keyboardType;
}

@end

@interface WKTextFieldItemCell ()<UITextFieldDelegate>

@property(nonatomic,strong) UILabel *label;
@property(nonatomic,strong) UITextField *inputTextFd;
@property(nonatomic,strong) WKTextFieldItemModel *model;
@end

@implementation WKTextFieldItemCell

- (void)setupUI {
    [super setupUI];
    [self.contentView addSubview:self.label];
    [self.contentView addSubview:self.inputTextFd];
    [self.inputTextFd addTarget:self action:@selector(onValueChange:) forControlEvents:UIControlEventEditingChanged];
}

-(void) onValueChange:(UITextField*)textFd {
    if(self.model.onChange) {
        self.model.onChange(textFd.text);
    }
}

- (void)refresh:(WKTextFieldItemModel *)model {
    [super refresh:model];
    self.model = model;
    
    self.label.text = model.label;
    
    self.inputTextFd.placeholder = model.placeholder;
    self.inputTextFd.secureTextEntry = model.password;
    self.inputTextFd.keyboardType = model.keyboardType.integerValue;
    self.inputTextFd.delegate = self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    BOOL hasLabel = false;
    if(self.model.label && ![self.model.label isEqualToString:@""]) {
        self.label.text = self.model.label;
        self.label.lim_width = labelWidth;
        self.label.lim_height = self.lim_height;
        self.label.lim_left = 15.0f;
        hasLabel = true;
    }
    self.label.hidden = !hasLabel;
    
    self.inputTextFd.lim_height = self.contentView.lim_height;
    if(hasLabel) {
        self.inputTextFd.lim_left = self.label.lim_right;
        self.inputTextFd.lim_width = self.contentView.lim_width - self.label.lim_width - self.label.lim_left;
    }else {
        self.inputTextFd.lim_left = 15.0f;
        self.inputTextFd.lim_width = self.contentView.lim_width - self.inputTextFd.lim_left*2;
    }
   
    
}

- (UITextField *)inputTextFd {
    if(!_inputTextFd) {
        _inputTextFd = [[UITextField alloc] init];
    }
    return _inputTextFd;
}

- (UILabel *)label {
    if(!_label) {
        _label = [[UILabel alloc] init];
        _label.lineBreakMode = NSLineBreakByTruncatingTail;
        _label.textAlignment = NSTextAlignmentLeft;
    }
    return _label;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    if(!self.model.maxLen) {
        return YES;
    }
    NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    NSInteger length = [self textLength:newString];//转换过的长度
    if (length > self.model.maxLen.integerValue){
        return NO;
    }
    return YES;
}
-(NSUInteger)textLength: (NSString *) text{
    NSUInteger asciiLength = 0;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar uc = [text characterAtIndex: i];
        //设置汉字和字母的比例  如何限制4个字符或12个字母 就是1:3  如果限制是6个汉字或12个字符 就是 1:2  一次类推
        asciiLength += isascii(uc) ? 1 : 3;
    }
    NSUInteger unicodeLength = asciiLength;
    return unicodeLength;
}
@end

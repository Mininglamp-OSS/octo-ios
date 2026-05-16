//
//  WKEndToEndEncryptHitCell.m
//  WuKongBase
//
//  Created by tt on 2021/9/10.
//

#import "WKEndToEndEncryptHitCell.h"

#define hitfontSize 15.0f

#define hitText LLang(@"此对话中的消息使用端对端加密。点击了解更多。")

#define hitEdgeInsets  UIEdgeInsetsMake(10.0f, 10.0f, 10.0f, 10.0f)

#define hitBottomSpace 20.0f

@interface WKEndToEndEncryptHitCell ()

@property(nonatomic,strong) UILabel *tipLbl;

@property(nonatomic,strong) UIView *tipBoxView;

@property(nonatomic,strong) WKMessageModel *messageModel;

@end

@implementation WKEndToEndEncryptHitCell

+ (CGSize)sizeForMessage:(WKMessageModel *)model {
   
   CGSize size = [self getTextSize:hitText maxWidth:[WKApp shared].config.systemMessageContentMaxWidth fontSize:hitfontSize];
    return CGSizeMake(size.width + hitEdgeInsets.left + hitEdgeInsets.right, size.height+hitEdgeInsets.top + hitEdgeInsets.bottom + hitBottomSpace);
}

- (void)initUI {
    [super initUI];
    [self.contentView addSubview:self.tipBoxView];
    [self.tipBoxView addSubview:self.tipLbl];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    
    self.messageModel = model;
   
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if(!self.messageModel) {
        return;
    }
    CGSize messageSize = [[self class] sizeForMessage:self.messageModel];
    
    self.tipBoxView.lim_size = CGSizeMake(messageSize.width, messageSize.height - hitBottomSpace);
    
    self.tipBoxView.lim_centerX_parent = self.contentView;
    
    self.tipLbl.lim_size = self.tipBoxView.lim_size;
    
}


- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.font = [[WKApp shared].config appFontOfSize:hitfontSize];
        _tipLbl.text = hitText;
        _tipLbl.numberOfLines = 0;
        _tipLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _tipLbl.textAlignment = NSTextAlignmentCenter;
        _tipLbl.textColor = [UIColor redColor];
    }
    return _tipLbl;
}

- (UIView *)tipBoxView {
    if(!_tipBoxView) {
        _tipBoxView = [[UIView alloc] init];
        _tipBoxView.layer.masksToBounds = YES;
        _tipBoxView.layer.cornerRadius = 8.0f;
        
        _tipBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    }
    return _tipBoxView;
}

+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth fontSize:(CGFloat)fontSize{
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = NSTextAlignmentCenter;
    NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:fontSize], NSParagraphStyleAttributeName:style}];
    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    return size;
}

@end

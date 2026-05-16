//
//  WKMessageBaseCell.m
//  WuKongBase
//
//  Created by tt on 2019/12/28.
//

#import "WKMessageBaseCell.h"

@implementation WKMessageBaseCell

+ (CGSize)sizeForMessage:(WKMessageModel *)model {
    return CGSizeMake(0, 0);
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
   if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
       self.selectionStyle = UITableViewCellSelectionStyleNone;
       [self initUI];
       
   }
    return self;
}

-(void) initUI {
    [self setBackgroundColor:[UIColor clearColor]];
    self.contentView.userInteractionEnabled = YES;
    
    [self.contentView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onContentTap)]];
}

-(void) onContentTap {
    [self.conversationContext endEditing];
}

- (void)refresh:(WKMessageModel *)model {
    self.messageModel = model;
}

-(void) onWillDisplay {
    
}

- (void)onEndDisplay {
    
}

@end

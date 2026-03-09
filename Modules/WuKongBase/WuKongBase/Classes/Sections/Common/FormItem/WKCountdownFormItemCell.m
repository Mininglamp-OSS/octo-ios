//
//  WKCountdownFormItemCell.m
//  WuKongBase
//
//  Created by tt on 2022/11/21.
//

#import "WKCountdownFormItemCell.h"
#import "WuKongBase.h"
@implementation WKCountdownFormItemModel

- (Class)cell {
    return WKCountdownFormItemCell.class;
}

@end

@interface WKCountdownFormItemCell ()

@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) WKCountdownFormItemModel *countdownFormItemModel;

@end

@implementation WKCountdownFormItemCell

- (void)setupUI {
    [super setupUI];
    
    
}

- (void)prepareForReuse {
    [super prepareForReuse];
    if(self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
}

- (void)refresh:(WKCountdownFormItemModel *)model {
    [super refresh:model];
    self.countdownFormItemModel = model;
    [self updateCountdown];
    __weak typeof(self) weakSelf = self;
    if(self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    self.timer =  [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf updateCountdown];
     }];
    

}

-(void) updateCountdown {
    if(!self.countdownFormItemModel) {
        return;
    }
    NSString *secondStr = [WKTimeTool formatCountdownTime:self.countdownFormItemModel.second];
    if([secondStr isEqualToString:@""]) {
        self.valueLbl.text = self.countdownFormItemModel.value;
    }else {
        self.valueLbl.text = [NSString stringWithFormat:@"%@（%@）",self.countdownFormItemModel.value,secondStr];
    }
}


- (void)dealloc {
    NSLog(@"WKCountdownFormItemCell dealloc");
    [self.timer invalidate];
    self.timer = nil;
}

@end

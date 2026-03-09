//
//  WKConversationPositionBarView.m
//  WuKongBase
//
//  Created by tt on 2022/4/19.
//

#import "WKConversationPositionBarView.h"
#import "WKConversationPosition.h"
#import "WuKongBase.h"
#import "WKConversationInputPanel.h"
#import "WKBadgeView.h"

#define barSpace 10.0f

#define bottomBarViewTag 999

@interface WKConversationPositionBarView ()

@property(nonatomic,strong) NSArray<WKReminder*>*reminders;

@property(nonatomic,strong) NSMutableDictionary<NSString*,NSMutableArray<WKReminder*>*> *remindersDict;

@property(nonatomic,strong) NSMutableSet<NSNumber*> *types;

@property(nonatomic,strong) UIView *barBox;

@property(nonatomic,assign) BOOL showScrollBottom;

@end

@implementation WKConversationPositionBarView

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.frame = CGRectMake(0.0f, 0.0f, WKPositionBarWidth, WKPositionBarHeight);
        [self addSubview:self.barBox];
    }
    return self;
}

-(void) updateReminders:(NSArray<WKReminder*>*)reminderList {
    
    NSMutableArray<WKReminder*> *reminders = [NSMutableArray array];
    if(reminderList && reminderList.count>0) {
        for (WKReminder *reminder in reminderList) {
            if(reminder.publisher && ![reminder.publisher isEqualToString:WKApp.shared.loginInfo.uid])
            [reminders addObject:reminder];
        }
    }
    
    [self.types removeAllObjects];
    [self.remindersDict removeAllObjects];
    if(self.barBox.subviews && self.barBox.subviews.count>0) {
        for (UIView *subView in self.barBox.subviews) {
            if(subView.tag != bottomBarViewTag) {
                [subView removeFromSuperview];
            }
        }
    }
    for (WKReminder *reminder in reminders) {
        if(!reminder.isLocate || reminder.done) {
            continue;
        }
        NSString *key = [NSString stringWithFormat:@"%lu",(unsigned long)reminder.type];
        [self.types addObject:@(reminder.type)];
        NSMutableArray *reminders = self.remindersDict[key];
        if(!reminders) {
            reminders = [NSMutableArray array];
        }
        [reminders addObject:reminder];
        self.remindersDict[key] = reminders;
    }
    
    __weak typeof(self) weakSelf = self;
    
    for (NSNumber *type in self.types) {
        NSString *key = [type stringValue];
        NSArray<WKReminder*> *typeReminders =  self.remindersDict[key];
        WKPositionBar *bar = [[WKPositionBar alloc] initWithType:(WKConversationPositionType)type.integerValue];
        NSArray<WKConversationPosition*> *positions = [self toPositions:typeReminders];
        positions = [positions sortedArrayUsingComparator:^NSComparisonResult(WKConversationPosition*  _Nonnull obj1, WKConversationPosition * _Nonnull obj2) {
            if(obj1.orderSeq > obj2.orderSeq) {
                return NSOrderedDescending;
            }
            if(obj1.orderSeq == obj2.orderSeq) {
                return NSOrderedSame;
            }
            return NSOrderedAscending;
        }];
        bar.positions =positions;
        
        [bar setOnClick:^ {
            if(!positions ||positions.count == 0) {
                return;
            }
            if(weakSelf.onScrollToPosition) {
                WKConversationPosition *lastPosition = positions.lastObject;
                WKConversationPosition *firstPosition = positions.firstObject;
                if(firstPosition.orderSeq > weakSelf.maxVisiableOrderSeq ) {
                    weakSelf.onScrollToPosition(firstPosition,UITableViewScrollPositionBottom);
                }else if(weakSelf.minVisiableOrderSeq > lastPosition.orderSeq) {
                    weakSelf.onScrollToPosition(lastPosition,UITableViewScrollPositionTop);
                }else {
                    weakSelf.onScrollToPosition(firstPosition,UITableViewScrollPositionBottom);
                }
            }
        }];
        [self.barBox addSubview:bar];
    }
    
    UIView *scrollToBottomBar = [self.barBox viewWithTag:bottomBarViewTag];
    if(scrollToBottomBar) {
        [scrollToBottomBar removeFromSuperview];
        [self.barBox addSubview:scrollToBottomBar];
    }

    
//    self.backgroundColor = [UIColor redColor];
    
    [self layoutSubviews];
    
}

-(void) showScrollBottom:(BOOL)showScrollBottom animateComplete:(void(^__nullable)(void))animateComplete{
    bool change = self.showScrollBottom != showScrollBottom;
    self.showScrollBottom = showScrollBottom;
    
    if(!change) {
        [self layoutSubviews];
        return;
    }
    
    UIView *scrollToBottomBar = [self.barBox viewWithTag:bottomBarViewTag];
    if(showScrollBottom) {
        if(scrollToBottomBar) {
            [scrollToBottomBar removeFromSuperview];
        }
        WKPositionBar *bar = [[WKPositionBar alloc] initWithType:WKConversationPositionTypeScrollToBottom];
        bar.tag = bottomBarViewTag;
        __weak typeof(self) weakSelf = self;
        [bar setOnClick:^{
            if(weakSelf.onScrollToBottom) {
                weakSelf.onScrollToBottom();
            }
        }];
        [self.barBox addSubview:bar];
        [self layoutSubviews];
        bar.transform = CGAffineTransformMakeScale(0.5f, 0.5f);
        bar.alpha = 0.0f;
        [UIView animateWithDuration:SessionInputAnimateDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            bar.transform = CGAffineTransformIdentity;
            bar.alpha = 1.0f;
        } completion:^(BOOL finished) {
            [self layoutSubviews];
            if(animateComplete) {
                animateComplete();
            }
        }];
    }else {
        [self layoutSubviews];
        scrollToBottomBar.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
        scrollToBottomBar.alpha = 1.0f;
        [UIView animateWithDuration:SessionInputAnimateDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            scrollToBottomBar.transform = CGAffineTransformMakeScale(0.5f, 0.5f);
            scrollToBottomBar.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [scrollToBottomBar removeFromSuperview];
            [self layoutSubviews];
            if(animateComplete) {
                animateComplete();
            }
        }];
    }
}

-(void) updateScrollToBottomBarBadge:(NSInteger)value {
    WKPositionBar *scrollToBottomBar = (WKPositionBar*)[self.barBox viewWithTag:bottomBarViewTag];
    if(!scrollToBottomBar) {
        return;
    }
    [scrollToBottomBar updateBadge:value];
}


-(NSArray<WKConversationPosition*>*) toPositions:(NSArray<WKReminder*>*)reminders {
    NSMutableArray *positions = [NSMutableArray array];
    for (WKReminder *reminder in reminders) {
        [positions addObject:[WKConversationPosition orderSeq:[[WKSDK shared].chatManager getOrderSeq:reminder.messageSeq] offset:0 type:(WKConversationPositionType)reminder.type]];
    }
    return positions;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    CGFloat space = barSpace;
    UIView *preBar;
   
    for (NSInteger i=0; i<self.barBox.subviews.count; i++) {
        UIView *bar = self.barBox.subviews[i];
        if(preBar) {
            bar.lim_top =  preBar.lim_bottom + space;
        }else {
            bar.lim_top = 0.0f;
        }
        preBar = bar;
    }
    if(self.barBox.subviews.count>0) {
        self.hidden = NO;
        CGFloat totalHeight = self.barBox.subviews.count * WKPositionBarHeight + (self.barBox.subviews.count -1)*barSpace;
        self.barBox.frame =  CGRectMake(0.0f, 0.0f, WKPositionBarWidth, totalHeight);
        self.lim_size = self.barBox.lim_size;
    }else {
        self.hidden = YES;
    }
}

- (UIView *)barBox {
    if(!_barBox) {
        _barBox = [[UIView alloc] init];
    }
    return _barBox;
}


- (NSMutableDictionary<NSString *,NSMutableArray<WKReminder *> *> *)remindersDict {
    if(!_remindersDict) {
        _remindersDict = [NSMutableDictionary dictionary];
    }
    return _remindersDict;
}

- (NSMutableSet<NSNumber *> *)types {
    if(!_types) {
        _types = [[NSMutableSet alloc] init];
    }
    return _types;
}

@end

@interface WKPositionBar ()

@property(nonatomic,assign) WKConversationPositionType type;
@property(nonatomic,strong) UIImageView *iconImgView;

@property(nonatomic,strong) UIView *boxView;

@property(nonatomic,strong) WKBadgeView *badgeView;



@end

@implementation WKPositionBar

- (instancetype)initWithType:(WKConversationPositionType)type
{
    self = [super init];
    if (self) {
        self.type = type;
        self.frame = CGRectMake(0.0f, 0.0f, WKPositionBarWidth, WKPositionBarHeight);
        [self addSubview:self.boxView];
        self.boxView.lim_size = CGSizeMake(self.lim_width - 10.0f, self.lim_height - 10.0f);
        
        UIColor *color = [UIColor colorWithRed:220.0f/255.0f green:220.0f/255.0f blue:220.0f/255.0f alpha:1.0f];
        if([WKApp shared].config.style == WKSystemStyleDark) {
            color = [UIColor colorWithRed:112.0f/255.0f green:112.0f/255.0f blue:112.0f/255.0f alpha:112.0f/255.0f];
        }
        self.boxView.tintColor =color;
        self.boxView.layer.masksToBounds = YES;
        
        self.boxView.layer.borderColor = color.CGColor;
        self.boxView.layer.borderWidth = 0.5f;
        [self.boxView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
//        self.backgroundColor = [UIColor greenColor];
        
        self.boxView.layer.cornerRadius = self.boxView.lim_height/2.0f;
        
        UIImage *icon;
        if(type == WKConversationPositionTypeScrollToBottom) {
            icon = [self imageName:@"Conversation/Index/MessageDown"];
        }else if(type == WKConversationPositionTypeMention) {
            icon = [self imageName:@"Conversation/Reminder/Mention"];
        }else if(type == WKConversationPositionTypeApplyJoinGroup) {
            icon = [self imageName:@"Conversation/Reminder/MemberInvite"];
        }
        if(icon) {
            self.iconImgView.image = icon;
        }
        [self.boxView addSubview:self.iconImgView];
        
        [self addSubview:self.badgeView];
        
        self.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

-(void) onTap {
    if(self.onClick) {
        self.onClick();
    }
}

- (void)setPositions:(NSArray<WKConversationPosition *> *)positions {
    _positions = positions;
    if(positions && positions.count>0) {
        self.badgeView.hidden = NO;
        self.badgeView.badgeValue = [NSString stringWithFormat:@"%ld",positions.count];
    }else {
        self.badgeView.hidden = YES;
    }
}

-(void) updateBadge:(NSInteger)badge {
    if(badge>0) {
        self.badgeView.hidden = NO;
        self.badgeView.badgeValue = [NSString stringWithFormat:@"%ld",badge];
    }else{
        self.badgeView.hidden = YES;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
   
    
    self.boxView.lim_top = self.lim_height - self.boxView.lim_height;
    self.boxView.lim_centerX_parent = self;
    
    self.iconImgView.lim_centerX_parent = self.boxView;
    self.iconImgView.lim_centerY_parent = self.boxView;
    
    self.badgeView.lim_centerX_parent = self;
    self.badgeView.lim_top = -2.0f;
    
}

- (UIImageView *)iconImgView {
    if(!_iconImgView) {
        _iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
    }
    return _iconImgView;
}

- (UIView *)boxView {
    if(!_boxView) {
        _boxView = [[UIView alloc] init];
    }
    return _boxView;
}

- (WKBadgeView *)badgeView {
    if(!_badgeView) {
        _badgeView = [WKBadgeView viewWithBadgeTip:@""];
        _badgeView.hidden = YES;
    }
    return _badgeView;
}



-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end

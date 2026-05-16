// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSpacePopupView.m
//  WuKongBase
//
//  Created by Claude on 2026/03/11.
//

#import "WKSpacePopupView.h"
#import "WKSpaceModel.h"
#import "WKApp.h"
#import "WuKongBase.h"

@interface WKSpaceListCell : UITableViewCell

@property(nonatomic,strong) UILabel *avatarLabel;
@property(nonatomic,strong) UILabel *nameLabel;
@property(nonatomic,strong) UILabel *checkLabel;
@property(nonatomic,strong) UIButton *linkButton;

@end

@implementation WKSpaceListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        // 头像标签
        _avatarLabel = [[UILabel alloc] init];
        _avatarLabel.textAlignment = NSTextAlignmentCenter;
        _avatarLabel.font = [UIFont boldSystemFontOfSize:14];
        _avatarLabel.textColor = [UIColor whiteColor];
        _avatarLabel.backgroundColor = [UIColor colorWithRed:102/255.0 green:126/255.0 blue:234/255.0 alpha:1.0];
        _avatarLabel.layer.cornerRadius = 16;
        _avatarLabel.layer.masksToBounds = YES;
        [self.contentView addSubview:_avatarLabel];

        // 名称标签
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:15];
        _nameLabel.textColor = [WKApp shared].config.defaultTextColor;
        [self.contentView addSubview:_nameLabel];

        // 选中标记
        _checkLabel = [[UILabel alloc] init];
        _checkLabel.text = @"✓";
        _checkLabel.font = [UIFont boldSystemFontOfSize:13];
        _checkLabel.textColor = [WKApp shared].config.themeColor;
        _checkLabel.textAlignment = NSTextAlignmentCenter;
        _checkLabel.hidden = YES;
        [self.contentView addSubview:_checkLabel];

        // 链接按钮
        _linkButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_linkButton setImage:[self createLinkIcon] forState:UIControlStateNormal];
        [self.contentView addSubview:_linkButton];

        // 使用 autoresizing 和手动布局
        _avatarLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _checkLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _linkButton.translatesAutoresizingMaskIntoConstraints = NO;

        [NSLayoutConstraint activateConstraints:@[
            [_avatarLabel.leftAnchor constraintEqualToAnchor:self.contentView.leftAnchor constant:8],
            [_avatarLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarLabel.widthAnchor constraintEqualToConstant:32],
            [_avatarLabel.heightAnchor constraintEqualToConstant:32],

            [_nameLabel.leftAnchor constraintEqualToAnchor:_avatarLabel.rightAnchor constant:12],
            [_nameLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_nameLabel.rightAnchor constraintEqualToAnchor:_checkLabel.leftAnchor constant:-8],

            [_checkLabel.rightAnchor constraintEqualToAnchor:_linkButton.leftAnchor constant:-8],
            [_checkLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_checkLabel.widthAnchor constraintEqualToConstant:18],
            [_checkLabel.heightAnchor constraintEqualToConstant:18],

            [_linkButton.rightAnchor constraintEqualToAnchor:self.contentView.rightAnchor constant:-8],
            [_linkButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_linkButton.widthAnchor constraintEqualToConstant:24],
            [_linkButton.heightAnchor constraintEqualToConstant:24]
        ]];
    }
    return self;
}

- (UIImage *)createLinkIcon {
    // 使用文本渲染🔗符号作为图标
    CGSize size = CGSizeMake(24, 24);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);

    NSString *linkEmoji = @"🔗";
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:16],
        NSForegroundColorAttributeName: [UIColor colorWithRed:103/255.0 green:106/255.0 blue:111/255.0 alpha:1.0]
    };

    CGSize textSize = [linkEmoji sizeWithAttributes:attributes];
    CGPoint textPoint = CGPointMake((size.width - textSize.width) / 2, (size.height - textSize.height) / 2);
    [linkEmoji drawAtPoint:textPoint withAttributes:attributes];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end

@interface WKSpacePopupView ()<UITableViewDelegate, UITableViewDataSource>

@property(nonatomic,strong) UIView *containerView;
@property(nonatomic,strong) UIView *backgroundView;
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) UIView *footerView;
@property(nonatomic,strong) NSArray<WKSpaceEntity *> *spaces;
@property(nonatomic,strong) NSLayoutConstraint *tableViewHeightConstraint;

@end

@implementation WKSpacePopupView

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        NSLog(@"🔧 WKSpacePopupView 初始化");
        // 初始化空数组，防止nil访问
        self.spaces = @[];
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // 背景遮罩
    _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
    _backgroundView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    [_backgroundView addGestureRecognizer:tapGesture];
    [self addSubview:_backgroundView];

    // 容器视图
    _containerView = [[UIView alloc] init];
    _containerView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    _containerView.layer.cornerRadius = 8;
    _containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    _containerView.layer.shadowOpacity = 0.2;
    _containerView.layer.shadowOffset = CGSizeMake(0, 2);
    _containerView.layer.shadowRadius = 8;
    [self addSubview:_containerView];

    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Space";
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textColor = [WKApp shared].config.defaultTextColor;
    [_containerView addSubview:titleLabel];

    // 表格视图
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 48;
    _tableView.scrollEnabled = NO;
    _tableView.showsVerticalScrollIndicator = YES;
    _tableView.bounces = NO;
    [_tableView registerClass:[WKSpaceListCell class] forCellReuseIdentifier:@"SpaceCell"];
    [_containerView addSubview:_tableView];

    // 分割线
    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = [WKApp shared].config.lineColor;
    [_containerView addSubview:divider];

    // 底部操作区
    _footerView = [[UIView alloc] init];
    [_containerView addSubview:_footerView];

    [self createFooterButtons];

    // 布局 - 使用 AutoLayout，添加内边距
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    _footerView.translatesAutoresizingMaskIntoConstraints = NO;

    // 保存tableView高度约束以便动态更新
    self.tableViewHeightConstraint = [_tableView.heightAnchor constraintEqualToConstant:0];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:16],
        [titleLabel.leftAnchor constraintEqualToAnchor:_containerView.leftAnchor constant:16],

        [_tableView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [_tableView.leftAnchor constraintEqualToAnchor:_containerView.leftAnchor constant:12],
        [_tableView.rightAnchor constraintEqualToAnchor:_containerView.rightAnchor constant:-12],
        self.tableViewHeightConstraint,

        [divider.topAnchor constraintEqualToAnchor:_tableView.bottomAnchor constant:12],
        [divider.leftAnchor constraintEqualToAnchor:_containerView.leftAnchor constant:12],
        [divider.rightAnchor constraintEqualToAnchor:_containerView.rightAnchor constant:-12],
        [divider.heightAnchor constraintEqualToConstant:0.5],

        [_footerView.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:8],
        [_footerView.leftAnchor constraintEqualToAnchor:_containerView.leftAnchor],
        [_footerView.rightAnchor constraintEqualToAnchor:_containerView.rightAnchor],
        [_footerView.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor constant:-8]
    ]];
}

- (void)createFooterButtons {
    NSArray *items = @[
        @{@"title": LLang(@"加入Space"), @"action": @"joinSpace", @"icon": @"🔍"},
        @{@"title": LLang(@"显示全部"), @"action": @"showAll", @"icon": @""}
    ];

    UIView *lastView = nil;
    for (int i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];

        // 创建带图标的标题
        NSString *icon = item[@"icon"];
        NSString *title = item[@"title"];
        NSString *fullTitle = icon.length > 0 ? [NSString stringWithFormat:@"%@  %@", icon, title] : title;

        [button setTitle:fullTitle forState:UIControlStateNormal];
        [button setTitleColor:i == 2 ? [UIColor grayColor] : [WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:i == 2 ? 14 : 15];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 0);  // 减少左边距从36到16
        button.tag = i;
        [button addTarget:self action:@selector(footerButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_footerView addSubview:button];

        button.translatesAutoresizingMaskIntoConstraints = NO;

        NSMutableArray *constraints = [NSMutableArray arrayWithArray:@[
            [button.leftAnchor constraintEqualToAnchor:_footerView.leftAnchor],
            [button.rightAnchor constraintEqualToAnchor:_footerView.rightAnchor],
            [button.heightAnchor constraintEqualToConstant:44]
        ]];

        if (lastView) {
            [constraints addObject:[button.topAnchor constraintEqualToAnchor:lastView.bottomAnchor]];
        } else {
            [constraints addObject:[button.topAnchor constraintEqualToAnchor:_footerView.topAnchor]];
        }

        if (i == items.count - 1) {
            [constraints addObject:[button.bottomAnchor constraintEqualToAnchor:_footerView.bottomAnchor constant:-8]];
        }

        [NSLayoutConstraint activateConstraints:constraints];

        lastView = button;
    }
}

- (void)footerButtonTapped:(UIButton *)sender {
    [self dismiss];

    switch (sender.tag) {
        case 0: // 加入空间
            [self showJoinSpaceDialog];
            break;
        case 1: // 显示全部
            [self loadSpaces];
            break;
    }
}

- (void)showFromView:(UIView *)anchorView {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self];

    // 加载 Space 列表
    [self loadSpaces];

    // 计算容器位置
    CGRect anchorFrame = [anchorView convertRect:anchorView.bounds toView:window];
    CGFloat containerWidth = 320;
    CGFloat containerX = anchorFrame.origin.x + 15;
    CGFloat containerY = anchorFrame.origin.y + anchorFrame.size.height + 20;

    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_containerView.topAnchor constraintEqualToAnchor:self.topAnchor constant:containerY],
        [_containerView.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:containerX],
        [_containerView.widthAnchor constraintEqualToConstant:containerWidth]
    ]];

    // 动画显示
    self.alpha = 0;
    _containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 1;
        self.containerView.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismiss {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
        self.containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (self.onDismiss) {
            self.onDismiss();
        }
    }];
}

- (void)loadSpaces {
    NSLog(@"📡 开始加载Space列表");
    // 清除缓存，强制从服务器获取最新数据
    [[WKSpaceModel shared] invalidateCache];
    __weak typeof(self) weakSelf = self;
    [[WKSpaceModel shared] getMySpaces].then(^(NSArray *spaces){
        NSLog(@"✅ Space列表加载成功，数量: %lu", (unsigned long)spaces.count);
        // 确保在主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.spaces = spaces ?: @[];  // 防止nil

            // 更新tableView高度：每行48，最多显示6行，超出可滚动
            NSInteger maxVisibleRows = 6;
            CGFloat height = MIN(weakSelf.spaces.count, maxVisibleRows) * 48;
            NSLog(@"📐 更新tableView高度: %.0f (共%lu个Space)", height, (unsigned long)weakSelf.spaces.count);
            weakSelf.tableView.scrollEnabled = (NSInteger)weakSelf.spaces.count > maxVisibleRows;
            weakSelf.tableViewHeightConstraint.constant = height;

            [weakSelf.tableView reloadData];
            [weakSelf layoutIfNeeded];  // 立即更新布局
        });
    }).catch(^(NSError *error){
        NSLog(@"❌ Space列表加载失败: %@", error);
        // 加载失败，显示错误提示
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) {
                window = [[UIApplication sharedApplication].windows firstObject];
            }
            if (window) {
                [window showMsg:LLang(@"加载失败")];
            }
        });
    });
}

- (void)showJoinSpaceDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"加入Space") message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = LLang(@"请输入邀请码");
    }];

    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"加入") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *inviteCode = alert.textFields[0].text;

        if (!inviteCode || inviteCode.length == 0) {
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) {
                window = [[UIApplication sharedApplication].windows firstObject];
            }
            [window showMsg:LLang(@"请输入邀请码")];
            return;
        }

        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        [window showHUD:LLang(@"加入中...")];
        [[WKSpaceModel shared] joinSpace:inviteCode].then(^(id result){
            [window hideHud];
            [window showHUDWithHide:LLang(@"加入成功")];

            // 从 API 返回中提取新空间 ID
            NSString *joinedSpaceId = nil;
            if ([result isKindOfClass:[NSDictionary class]]) {
                joinedSpaceId = result[@"space_id"];
            }

            // 刷新空间列表，自动切换到新加入的空间
            [[WKSpaceModel shared] invalidateCache];
            [[WKSpaceModel shared] getMySpaces].then(^(NSArray<WKSpaceEntity *> *spaces) {
                weakSelf.spaces = spaces ?: @[];
                [weakSelf.tableView reloadData];

                // 用 API 返回的 space_id 精确匹配新空间
                WKSpaceEntity *newSpace = nil;
                if (joinedSpaceId) {
                    for (WKSpaceEntity *space in spaces) {
                        if ([space.space_id isEqualToString:joinedSpaceId]) {
                            newSpace = space;
                            break;
                        }
                    }
                }
                // 兜底：找不到则用不等于当前空间的最后一个
                if (!newSpace) {
                    for (NSInteger i = spaces.count - 1; i >= 0; i--) {
                        if (![spaces[i].space_id isEqualToString:weakSelf.currentSpaceId]) {
                            newSpace = spaces[i];
                            break;
                        }
                    }
                }

                if (newSpace) {
                    [weakSelf dismiss];
                    if (weakSelf.onSpaceSelected) {
                        weakSelf.onSpaceSelected(newSpace);
                    }
                }
            });
        }).catch(^(NSError *error){
            [window hideHud];
            [window showHUDWithHide:error.localizedDescription];
        });
    }]];

    UIViewController *topVC = [self topViewController];
    [topVC presentViewController:alert animated:YES completion:nil];
}

- (UIViewController *)topViewController {
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.spaces.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKSpaceListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SpaceCell" forIndexPath:indexPath];

    // 边界检查
    if (indexPath.row >= self.spaces.count) {
        NSLog(@"⚠️ indexPath.row (%ld) 超出spaces数组范围 (%lu)", (long)indexPath.row, (unsigned long)self.spaces.count);
        return cell;
    }

    WKSpaceEntity *space = self.spaces[indexPath.row];
    if (!space) {
        NSLog(@"⚠️ space对象为nil at index %ld", (long)indexPath.row);
        return cell;
    }

    // 设置头像首字母
    NSString *initial = space.name.length > 0 ? [[space.name substringToIndex:1] uppercaseString] : @"S";
    cell.avatarLabel.text = initial;

    // 设置名称
    cell.nameLabel.text = space.name ?: @"";

    // 设置选中状态
    BOOL isSelected = [space.space_id isEqualToString:self.currentSpaceId];
    cell.checkLabel.hidden = !isSelected;

    // 链接按钮点击事件
    __weak typeof(self) weakSelf = self;
    [cell.linkButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [cell.linkButton addTarget:self action:@selector(linkButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    cell.linkButton.tag = indexPath.row;

    return cell;
}

- (void)linkButtonTapped:(UIButton *)sender {
    // 边界检查
    if (sender.tag >= self.spaces.count) {
        NSLog(@"⚠️ linkButton tag (%ld) 超出spaces数组范围 (%lu)", (long)sender.tag, (unsigned long)self.spaces.count);
        return;
    }

    WKSpaceEntity *space = self.spaces[sender.tag];
    if (!space) {
        NSLog(@"⚠️ space对象为nil at tag %ld", (long)sender.tag);
        return;
    }

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) {
        window = [[UIApplication sharedApplication].windows firstObject];
    }

    [window showHUD:LLang(@"获取中...")];
    // 与 Web 端一致：通过 GET /space/{id} 获取空间详情中已有的 invite_code
    NSString *path = [NSString stringWithFormat:@"space/%@", space.space_id];
    [[WKAPIClient sharedClient] GET:path parameters:nil].then(^(NSDictionary *detail){
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *win = [UIApplication sharedApplication].keyWindow;
            if (!win) {
                win = [[UIApplication sharedApplication].windows firstObject];
            }
            [win hideHud];

            NSString *inviteCode = detail[@"invite_code"];
            if (inviteCode && inviteCode.length > 0) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = inviteCode;
                [win showMsg:LLang(@"邀请码已复制")];
            } else {
                [win showMsg:LLang(@"该空间暂无邀请码")];
            }
        });
    }).catch(^(NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *win = [UIApplication sharedApplication].keyWindow;
            if (!win) {
                win = [[UIApplication sharedApplication].windows firstObject];
            }
            [win hideHud];
            [win showMsg:error.localizedDescription ?: LLang(@"获取邀请码失败")];
        });
    });
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"📍 选中Space at index: %ld", (long)indexPath.row);

    // 边界检查
    if (indexPath.row >= self.spaces.count) {
        NSLog(@"⚠️ didSelect indexPath.row (%ld) 超出spaces数组范围 (%lu)", (long)indexPath.row, (unsigned long)self.spaces.count);
        return;
    }

    WKSpaceEntity *space = self.spaces[indexPath.row];
    if (!space) {
        NSLog(@"⚠️ 选中的space对象为nil at index %ld", (long)indexPath.row);
        return;
    }

    [self dismiss];

    if (self.onSpaceSelected) {
        self.onSpaceSelected(space);
    }
}

@end

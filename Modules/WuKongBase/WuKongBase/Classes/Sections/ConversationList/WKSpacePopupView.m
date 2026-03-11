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
            [_avatarLabel.leftAnchor constraintEqualToAnchor:self.contentView.leftAnchor constant:4],
            [_avatarLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarLabel.widthAnchor constraintEqualToConstant:32],
            [_avatarLabel.heightAnchor constraintEqualToConstant:32],

            [_nameLabel.leftAnchor constraintEqualToAnchor:_avatarLabel.rightAnchor constant:10],
            [_nameLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_nameLabel.rightAnchor constraintEqualToAnchor:_checkLabel.leftAnchor constant:-6],

            [_checkLabel.rightAnchor constraintEqualToAnchor:_linkButton.leftAnchor constant:-6],
            [_checkLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_checkLabel.widthAnchor constraintEqualToConstant:18],
            [_checkLabel.heightAnchor constraintEqualToConstant:18],

            [_linkButton.rightAnchor constraintEqualToAnchor:self.contentView.rightAnchor constant:-4],
            [_linkButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_linkButton.widthAnchor constraintEqualToConstant:24],
            [_linkButton.heightAnchor constraintEqualToConstant:24]
        ]];
    }
    return self;
}

- (UIImage *)createLinkIcon {
    CGSize size = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    // 绘制链接图标 (简化版)
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(7, 13)];
    [path addLineToPoint:CGPointMake(7, 17)];
    [path addLineToPoint:CGPointMake(13, 17)];

    [path moveToPoint:CGPointMake(13, 7)];
    [path addLineToPoint:CGPointMake(13, 3)];
    [path addLineToPoint:CGPointMake(7, 3)];

    [[UIColor colorWithRed:103/255.0 green:106/255.0 blue:111/255.0 alpha:1.0] setStroke];
    path.lineWidth = 2;
    [path stroke];

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

@end

@implementation WKSpacePopupView

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
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
    titleLabel.text = LLang(@"空间");
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

    // 布局 - 使用 AutoLayout
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    _footerView.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:12],
        [titleLabel.leftAnchor constraintEqualToAnchor:_containerView.leftAnchor constant:12],

        [_tableView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [_tableView.leftAnchor constraintEqualToAnchor:_containerView.leftAnchor],
        [_tableView.rightAnchor constraintEqualToAnchor:_containerView.rightAnchor],
        [_tableView.heightAnchor constraintLessThanOrEqualToConstant:300],

        [divider.topAnchor constraintEqualToAnchor:_tableView.bottomAnchor constant:8],
        [divider.leftAnchor constraintEqualToAnchor:_containerView.leftAnchor],
        [divider.rightAnchor constraintEqualToAnchor:_containerView.rightAnchor],
        [divider.heightAnchor constraintEqualToConstant:0.5],

        [_footerView.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:8],
        [_footerView.leftAnchor constraintEqualToAnchor:_containerView.leftAnchor],
        [_footerView.rightAnchor constraintEqualToAnchor:_containerView.rightAnchor],
        [_footerView.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor]
    ]];
}

- (void)createFooterButtons {
    NSArray *items = @[
        @{@"title": LLang(@"创建空间"), @"action": @"createSpace"},
        @{@"title": LLang(@"加入空间"), @"action": @"joinSpace"},
        @{@"title": LLang(@"显示全部"), @"action": @"showAll"}
    ];

    UIView *lastView = nil;
    for (int i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:item[@"title"] forState:UIControlStateNormal];
        [button setTitleColor:i == 2 ? [UIColor grayColor] : [WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:i == 2 ? 14 : 15];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 36, 0, 0);
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
        case 0: // 创建空间
            [self showCreateSpaceDialog];
            break;
        case 1: // 加入空间
            [self showJoinSpaceDialog];
            break;
        case 2: // 显示全部
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
    }];
}

- (void)loadSpaces {
    __weak typeof(self) weakSelf = self;
    [[WKSpaceModel shared] getMySpaces].then(^(NSArray *spaces){
        weakSelf.spaces = spaces;
        [weakSelf.tableView reloadData];
    }).catch(^(NSError *error){
        // 加载失败，显示错误提示
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        [window showToast:LLang(@"加载失败")];
    });
}

- (void)showCreateSpaceDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"创建空间") message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = LLang(@"空间名称");
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = LLang(@"描述（可选）");
    }];

    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"创建") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = alert.textFields[0].text;
        NSString *desc = alert.textFields[1].text;

        if (!name || name.length == 0) {
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) {
                window = [[UIApplication sharedApplication].windows firstObject];
            }
            [window showToast:LLang(@"请输入空间名称")];
            return;
        }

        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        [window showHUD:LLang(@"创建中...")];
        [[WKSpaceModel shared] createSpaceWithName:name description:desc].then(^(WKSpaceEntity *space){
            [window hideHud];
            [window showToast:LLang(@"创建成功")];
            [weakSelf loadSpaces];
        }).catch(^(NSError *error){
            [window hideHud];
            [window showToast:error.localizedDescription];
        });
    }]];

    UIViewController *topVC = [self topViewController];
    [topVC presentViewController:alert animated:YES completion:nil];
}

- (void)showJoinSpaceDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"加入空间") message:nil preferredStyle:UIAlertControllerStyleAlert];

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
            [window showToast:LLang(@"请输入邀请码")];
            return;
        }

        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        [window showHUD:LLang(@"加入中...")];
        [[WKSpaceModel shared] joinSpace:inviteCode].then(^(id result){
            [window hideHud];
            [window showToast:LLang(@"加入成功")];
            [weakSelf loadSpaces];
        }).catch(^(NSError *error){
            [window hideHud];
            [window showToast:error.localizedDescription];
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

    WKSpaceEntity *space = self.spaces[indexPath.row];

    // 设置头像首字母
    NSString *initial = space.name.length > 0 ? [[space.name substringToIndex:1] uppercaseString] : @"S";
    cell.avatarLabel.text = initial;

    // 设置名称
    cell.nameLabel.text = space.name;

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
    WKSpaceEntity *space = self.spaces[sender.tag];

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) {
        window = [[UIApplication sharedApplication].windows firstObject];
    }

    [window showHUD:LLang(@"获取中...")];
    __weak typeof(self) weakSelf = self;
    [[WKSpaceModel shared] createInvite:space.space_id].then(^(NSString *inviteCode){
        [window hideHud];

        // 复制到剪贴板
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = inviteCode;

        [window showToast:LLang(@"邀请码已复制")];
    }).catch(^(NSError *error){
        [window hideHud];
        [window showToast:error.localizedDescription];
    });
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    WKSpaceEntity *space = self.spaces[indexPath.row];

    [self dismiss];

    if (self.onSpaceSelected) {
        self.onSpaceSelected(space);
    }
}

@end

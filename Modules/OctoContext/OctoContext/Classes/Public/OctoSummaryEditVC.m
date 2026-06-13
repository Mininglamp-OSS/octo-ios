//
//  OctoSummaryEditVC.m
//  OctoContext
//

#import "OctoSummaryEditVC.h"
#import "OctoSummaryAPI.h"

@interface OctoSummaryEditVC ()
@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, copy) NSString *initialContent;
@property(nonatomic, assign) CGFloat keyboardHeight;     // 当前键盘高度,影响 textView 底缘
@end

@implementation OctoSummaryEditVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationBar.title = LLang(@"编辑总结");

    // 不再放自定义 ✕。WKBaseVC.viewDidLoad 检测到 viewControllers.count >= 2 会自动
    // setShowBackButton:YES, 走系统返回箭头 + WKNavigationManager pop, 与发起总结
    // 页面体验一致。
    // 但要拦截"未保存修改时按返回二次确认"的场景: WKNavigationBar.onBack 是这个钩子。
    __weak typeof(self) weakSelf = self;
    self.navigationBar.onBack = ^{
        [weakSelf onClose];
    };

    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [saveBtn setTitle:LLang(@"保存") forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    // 字色与底色反向配对, 浅 / 深两态都正确出对比 (见 CreateVC 同模式注释)
    [saveBtn setTitleColor:[UIColor systemBackgroundColor] forState:UIControlStateNormal];
    saveBtn.backgroundColor = [UIColor labelColor];
    saveBtn.contentEdgeInsets = UIEdgeInsetsMake(5, 16, 5, 16);
    [saveBtn addTarget:self action:@selector(onSave) forControlEvents:UIControlEventTouchUpInside];
    // sizeToFit 算出按英文/中文的实际所需宽度, 切语言后 "Save"(更长) / "保存" 都不被
    // 硬编 60pt 截成 …。高度仍锚到 32pt 让圆角对得齐。
    [saveBtn sizeToFit];
    CGRect bf = saveBtn.frame; bf.size.height = 32;
    saveBtn.frame = bf;
    saveBtn.layer.cornerRadius = 16;
    self.navigationBar.rightView = saveBtn;

    self.textView = [UITextView new];
    self.textView.font = [UIFont systemFontOfSize:14];
    self.textView.text = self.detail.result.content ?: @"";
    self.initialContent = self.textView.text;
    self.textView.textColor = [UIColor labelColor];
    [self.view addSubview:self.textView];

    // 键盘弹出时把 textView 高度向上缩 keyboardHeight, 避免最后几行被键盘挡住。
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = CGRectGetMaxY(self.navigationBar.frame);
    // 减去键盘占用的高度,让光标处的内容始终可见
    self.textView.frame = CGRectMake(8, top + 8,
                                     self.view.bounds.size.width - 16,
                                     self.view.bounds.size.height - top - 16 - self.keyboardHeight);
}

#pragma mark - Keyboard

- (void)onKeyboardWillShow:(NSNotification *)note {
    CGRect endFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // 转到 view 坐标系再求与 view 的交集 —— 同时兼容浮动键盘 / iPad 分屏的边界。
    CGRect kbInView = [self.view convertRect:endFrame fromView:nil];
    CGRect intersect = CGRectIntersection(self.view.bounds, kbInView);
    CGFloat kbH = CGRectIsNull(intersect) ? 0 : intersect.size.height;
    if (fabs(kbH - self.keyboardHeight) < 0.5) return;
    self.keyboardHeight = kbH;
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = (UIViewAnimationCurve)[note.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptions)(curve << 16) animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)onKeyboardWillHide:(NSNotification *)note {
    if (self.keyboardHeight == 0) return;
    self.keyboardHeight = 0;
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = (UIViewAnimationCurve)[note.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptions)(curve << 16) animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:nil];
}

#pragma mark - Actions

- (void)onClose {
    if (![self.textView.text isEqualToString:self.initialContent]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"放弃修改?")
                                                                       message:LLang(@"未保存的修改将丢失")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"继续编辑") style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"放弃") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [[WKNavigationManager shared] popViewControllerAnimated:YES];
}

- (void)onSave {
    int64_t baseResultId = self.detail.resultId.longLongValue;
    __weak typeof(self) weakSelf = self;
    [[OctoSummaryAPI shared] editSummary:self.detail.taskId
                                  content:self.textView.text ?: @""
                             baseResultId:baseResultId
                                 callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSInteger st = [error.userInfo[@"_httpStatus"] integerValue];
            if (st == 409) {
                [weakSelf.view showMsg:LLang(@"内容已被他人更新,请返回刷新")];
            } else {
                [weakSelf.view showMsg:error.localizedDescription ?: LLang(@"保存失败")];
            }
            return;
        }
        if (weakSelf.onSaved) weakSelf.onSaved();
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }];
}

@end

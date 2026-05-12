//
//  WKRocketLaunchEffect.m
//  WuKongBase
//
//  火箭用 CAShapeLayer + CAGradientLayer + CAEmitterLayer 原生绘制。
//  结构参考 CodePen chingy/OJMLodv：鼻锥 / 机身 / 舷窗 / Octo 文字 / 红条带 / 尾翼 / 喷口 / 火焰 / 烟雾。
//
//  动画时间轴（总 ~4.2s，蓄势压缩到 0.75s，节奏紧凑）：
//    0.0~0.3s  入场（spring scale 0→1）+ 火焰点燃
//    0.3~1.0s  引擎蓄势（机身震动 + 烟雾涌出 + 火焰待机）—— 0.75s
//    1.0~2.4s  加速发射（power4 曲线飞出屏幕 + 尾迹颜色灰→白渐变）
//    2.4~3.0s  拖尾星星粒子消散
//    4.9s      effectView 清理

#import "WKRocketLaunchEffect.h"
#import "WKMessageEffectView.h"
#import <WuKongBase/WuKongBase-Swift.h>

#pragma mark - 尾迹追踪器（私有）

/// 挂在 effectView 上的烟雾 emitter，通过 CADisplayLink 每帧读火箭 presentationLayer 位置，
/// 更新 emitterPosition 到火箭当前喷口处 → 粒子在各自 spawn 点生成后就停在那，
/// 随着火箭上升,在它身后留下一串自然的尾迹烟。
@interface WKRocketTrailTracker : NSObject
- (instancetype)initWithEmitter:(CAEmitterLayer *)emitter
                     rocketView:(UIView *)rocket
                       hostView:(UIView *)host
            nozzleLocalInRocket:(CGPoint)nozzle;
- (void)start;
- (void)stopEmitting;
@end

@implementation WKRocketTrailTracker {
    CAEmitterLayer *_emitter;
    __weak UIView *_rocket;
    __weak UIView *_host;
    CGPoint _nozzleLocal;
    CADisplayLink *_link;
}

- (instancetype)initWithEmitter:(CAEmitterLayer *)emitter
                     rocketView:(UIView *)rocket
                       hostView:(UIView *)host
            nozzleLocalInRocket:(CGPoint)nozzle {
    if ((self = [super init])) {
        _emitter = emitter;
        _rocket = rocket;
        _host = host;
        _nozzleLocal = nozzle;
    }
    return self;
}

- (void)start {
    if (_link) return;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self tick]; // 立即对齐一次
}

- (void)tick {
    UIView *rocket = _rocket;
    UIView *host = _host;
    if (!rocket || !host) { [self stopEmitting]; return; }
    CALayer *pres = rocket.layer.presentationLayer ?: rocket.layer;
    CGPoint nozzleInHost = [pres convertPoint:_nozzleLocal toLayer:host.layer];
    _emitter.emitterPosition = nozzleInHost;
}

- (void)stopEmitting {
    [_link invalidate];
    _link = nil;
    // 停产新粒子；已有粒子按 lifetime 自然淡出。emitter layer 随 effectView 一起被移除。
    _emitter.birthRate = 0;
    for (CAEmitterCell *c in _emitter.emitterCells) { c.birthRate = 0; }
}

- (void)dealloc {
    [_link invalidate];
}

@end

@implementation WKRocketLaunchEffect

#pragma mark - 常量

static const CGFloat kRocketWidth  = 64.0;
static const CGFloat kRocketHeight = 138.0;

// 霓虹全息风配色（参照表情包火箭图）：
//   机身：青蓝 → 银白 → 紫粉 三色水平渐变（全息感）
//   鼻锥：青蓝 → 紫 渐变 + 亮白顶端
//   舷窗：深紫外框 + 蓝色玻璃 + 白色高光
//   尾翼：紫色主体 + 橙黄描边（卡通感）
//   喷口：橙色
//   文字："Octo" 用深紫（与机身紫粉调性呼应）
static UIColor *kBodyCyanColor(void)     { return [UIColor colorWithRed:0x5C/255.0 green:0xD0/255.0 blue:0xFA/255.0 alpha:1.0]; } // 亮青 #5CD0FA
static UIColor *kBodySilverColor(void)   { return [UIColor colorWithRed:0xEE/255.0 green:0xF4/255.0 blue:0xFA/255.0 alpha:1.0]; } // 银白 #EEF4FA
static UIColor *kBodyMidColor(void)      { return [UIColor colorWithRed:0xD3/255.0 green:0xDD/255.0 blue:0xEB/255.0 alpha:1.0]; } // 中银 #D3DDEB
static UIColor *kBodyPurpleColor(void)   { return [UIColor colorWithRed:0xBE/255.0 green:0x8A/255.0 blue:0xE8/255.0 alpha:1.0]; } // 紫粉 #BE8AE8
static UIColor *kAccentPurpleColor(void) { return [UIColor colorWithRed:0x8A/255.0 green:0x5C/255.0 blue:0xD6/255.0 alpha:1.0]; } // 深紫 #8A5CD6
static UIColor *kAccentCyanColor(void)   { return [UIColor colorWithRed:0x49/255.0 green:0xBF/255.0 blue:0xEB/255.0 alpha:1.0]; } // 深青 #49BFEB
static UIColor *kOrangeAccentColor(void) { return [UIColor colorWithRed:0xFF/255.0 green:0x9A/255.0 blue:0x3B/255.0 alpha:1.0]; } // 橙黄 #FF9A3B
static UIColor *kWindowBlueColor(void)   { return [UIColor colorWithRed:0x4A/255.0 green:0xA5/255.0 blue:0xFF/255.0 alpha:1.0]; } // 舷窗亮蓝 #4AA5FF
static UIColor *kWindowDeepColor(void)   { return [UIColor colorWithRed:0x1E/255.0 green:0x5F/255.0 blue:0xC4/255.0 alpha:1.0]; } // 舷窗深蓝 #1E5FC4
static UIColor *kTextColor(void)         { return [UIColor colorWithRed:0x5B/255.0 green:0x3E/255.0 blue:0x8E/255.0 alpha:1.0]; } // 深紫 #5B3E8E
static UIColor *kNozzleColor(void)       { return [UIColor colorWithRed:0xE8/255.0 green:0x74/255.0 blue:0x29/255.0 alpha:1.0]; } // 暖橙 #E87429
// 鼻锥红色系（红帽子 — 有层次的暖红）
static UIColor *kNoseRedBrightColor(void){ return [UIColor colorWithRed:0xFF/255.0 green:0x7A/255.0 blue:0x6C/255.0 alpha:1.0]; } // 亮红橙 #FF7A6C
static UIColor *kNoseRedColor(void)      { return [UIColor colorWithRed:0xE7/255.0 green:0x4C/255.0 blue:0x3C/255.0 alpha:1.0]; } // 经典红 #E74C3C
static UIColor *kNoseRedDarkColor(void)  { return [UIColor colorWithRed:0xA8/255.0 green:0x32/255.0 blue:0x34/255.0 alpha:1.0]; } // 深红 #A83234
static UIColor *kNoseSeamColor(void)     { return [UIColor colorWithRed:0x75/255.0 green:0x24/255.0 blue:0x2F/255.0 alpha:1.0]; } // 暗红接缝 #75242F
static UIColor *kRivetColor(void)        { return [UIColor colorWithRed:0x7D/255.0 green:0x8B/255.0 blue:0xA3/255.0 alpha:1.0]; } // 铆钉深灰蓝 #7D8BA3

#pragma mark - 主入口

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    [self playInView:effectView sourceRect:sourceRect avatarImage:nil memberAvatars:nil];
}

+ (void)playInView:(WKMessageEffectView *)effectView
        sourceRect:(CGRect)sourceRect
       avatarImage:(nullable UIImage *)avatarImage {
    [self playInView:effectView sourceRect:sourceRect avatarImage:avatarImage memberAvatars:nil];
}

+ (void)playInView:(WKMessageEffectView *)effectView
        sourceRect:(CGRect)sourceRect
       avatarImage:(nullable UIImage *)avatarImage
     memberAvatars:(nullable NSArray<UIImage *> *)memberAvatars {
    if (!effectView) return;

    CGFloat viewW = effectView.bounds.size.width;
    CGFloat viewH = effectView.bounds.size.height;

    // **群聊模式检测**:非空 memberAvatars → 能量汇聚动画 + launch 延迟 1.5s 给汇聚 + 闪光 + 揭晓留时间
    //   私聊模式也需要延迟:头像弧形入场在 0.30s 启动、duration 1.20s → 1.50s 才完全就位,
    //   launch 不能早于这个时间点,否则头像还没进舷窗火箭就飞了。0.7s → 发射 @ 1.7s,留 0.2s 缓冲。
    BOOL isGroupMode = (memberAvatars.count > 0);
    NSTimeInterval launchDelay = isGroupMode ? 1.5 : (avatarImage ? 0.7 : 0.0);

    // 发射起点：固定在屏幕底部（不再随消息气泡位置变化）
    //   —— 让火箭发射有"固定舞台"仪式感：不管你戳的是第几条消息，火箭都从底部起飞。
    //   底部留 ~180pt 给输入栏 + 安全区 + 一点留白，保证鼻锥不被输入栏挡住。
    CGFloat bottomInset = 0;
    if (@available(iOS 11.0, *)) { bottomInset = effectView.safeAreaInsets.bottom; }
    CGPoint origin = CGPointMake(viewW * 0.5, viewH - bottomInset - 180.0);
    (void)sourceRect;  // 参数保留以维持签名兼容，不再用于定位

    // 火箭容器视图（包含机身 bodyContainer + 喷射火焰）
    //   群聊模式即使 avatarImage=nil 也走"透明舷窗"(挖孔 + 半透玻璃),让下方汇入的成员头像可见
    UIView *rocketView = [self buildRocketViewWithSize:CGSizeMake(kRocketWidth, kRocketHeight)
                                           avatarImage:avatarImage
                                     transparentWindow:(avatarImage != nil || isGroupMode)];
    rocketView.center = origin;
    rocketView.transform = CGAffineTransformMakeScale(0.001, 0.001);
    [effectView addSubview:rocketView];

    // 机身子容器（shake 只作用于此，避免传递给火焰导致"歪"）
    UIView *bodyContainer = [rocketView viewWithTag:1001];

    // 水滴形火焰（实体 CAShapeLayer）：尖端朝下，始终贴在火箭尾部垂直向下
    // 通过 scale.x / scale.y 的阶段动画实现蓄势→发射的形态变化：
    //   - 蓄势：X 放大 Y 压缩 → 宽胖短（待机火球）
    //   - 发射：X 收窄 Y 最长 → 窄长喷射
    CALayer *coreFlame = [self coreFlameLayer];
    coreFlame.position = CGPointMake(kRocketWidth / 2.0, kRocketHeight);
    coreFlame.opacity = 0;
    [rocketView.layer addSublayer:coreFlame];

    // 烟雾云（**不跟随火箭**）：覆盖屏幕全宽，强化视觉冲击
    // 烟雾云覆盖整个屏幕 → 烟雾有充足空间向上翻卷、向四周扩散
    // SKScene 的湍流场/涡流场作用范围 = 云框尺寸；全屏尺寸让烟雾可以飘得足够远
    CGFloat cloudW = viewW;
    CGFloat cloudH = viewH;
    CGRect cloudFrame = CGRectMake(0, 0, cloudW, cloudH);
    WKRocketSmokeCloud *smokeCloud = [[WKRocketSmokeCloud alloc] initWithFrame:cloudFrame];
    [effectView insertSubview:smokeCloud belowSubview:rocketView];

    CGPoint nozzleInCloud = [effectView convertPoint:CGPointMake(origin.x, origin.y + kRocketHeight / 2.0 - 4.0)
                                              toView:smokeCloud];
    [smokeCloud startEmittingAtNozzlePoint:nozzleInCloud spread:kRocketWidth * 0.45];

    // 尾迹烟雾：挂在 effectView 上（不跟随火箭），通过 CADisplayLink 追踪火箭喷口
    // → 火箭上升时每帧把 emitterPosition 更新到当前喷口，粒子留在各自 spawn 点
    // → 自然形成一缕跟随火箭上升的尾迹烟。初始 birthRate=0，launch block 里才开。
    CAEmitterLayer *trailEmitter = [self buildRocketTrailEmitterWithHostBounds:effectView.bounds];
    [effectView.layer insertSublayer:trailEmitter below:rocketView.layer];
    // 喷口相对 rocketView.origin 的偏移（rocketView 是 bounds.origin=0，center=origin）
    CGPoint nozzleLocal = CGPointMake(kRocketWidth / 2.0, kRocketHeight - 4.0);
    WKRocketTrailTracker *trailTracker =
        [[WKRocketTrailTracker alloc] initWithEmitter:trailEmitter
                                           rocketView:rocketView
                                             hostView:effectView
                                  nozzleLocalInRocket:nozzleLocal];

    // 机身包裹烟雾：**前后+双侧 Point emitter**
    //   - 后层(bodyWrapBack):full 密度、机身中部(被机身挡住,做背景)
    //   - 前层双份(bodyWrapFrontL/R):light 密度、左右两侧从机身**中上部**向下流
    //     → 视觉是"水汽从机身两侧滑落",而不是中间一股

    // --- 后层：正常密度，位置在机身中偏下 ---
    CGPoint backEmitterPos = CGPointMake(origin.x, origin.y + kRocketHeight * 0.10);
    CAEmitterLayer *bodyWrapBack = [self buildBodyWrapEmitterWithHostBounds:effectView.bounds light:NO];
    bodyWrapBack.emitterPosition = backEmitterPos;
    [effectView.layer insertSublayer:bodyWrapBack below:rocketView.layer];

    // --- 前层双侧：左右各一个 emitter 从机身两侧中上部向下流水汽 ---
    //   位置提高(原 0.37 → 0.22 → 本地 y ≈ 100,seam 附近),左右偏移 ±0.35*机身宽
    CGFloat bodyHeightFrac = 0.22;
    CGFloat sideOffset     = kRocketWidth * 0.35;   // 左右偏 ±22pt
    CGPoint leftFrontPos   = CGPointMake(origin.x - sideOffset, origin.y + kRocketHeight * bodyHeightFrac);
    CGPoint rightFrontPos  = CGPointMake(origin.x + sideOffset, origin.y + kRocketHeight * bodyHeightFrac);

    UIView *bodyWrapView = [[UIView alloc] initWithFrame:effectView.bounds];
    bodyWrapView.backgroundColor = [UIColor clearColor];
    bodyWrapView.userInteractionEnabled = NO;
    bodyWrapView.clipsToBounds = NO;
    bodyWrapView.tag = 2001;
    CAEmitterLayer *bodyWrapFrontL = [self buildBodyWrapEmitterWithHostBounds:bodyWrapView.bounds light:YES];
    bodyWrapFrontL.emitterPosition = leftFrontPos;
    [bodyWrapView.layer addSublayer:bodyWrapFrontL];
    CAEmitterLayer *bodyWrapFrontR = [self buildBodyWrapEmitterWithHostBounds:bodyWrapView.bounds light:YES];
    bodyWrapFrontR.emitterPosition = rightFrontPos;
    [bodyWrapView.layer addSublayer:bodyWrapFrontR];
    [effectView addSubview:bodyWrapView];
    // 保留 bodyWrapFront 名称供下游代码引用(用左侧代表,右侧会在同处理)
    CAEmitterLayer *bodyWrapFront = bodyWrapFrontL;  // placeholder,真实控制都同步应用两份

    NSLog(@"[RocketLaunch] bodyWrap 挂载 | back.pos=%@ (full) left=%@ right=%@ (light, dual sides)",
          NSStringFromCGPoint(backEmitterPos),
          NSStringFromCGPoint(leftFrontPos),
          NSStringFromCGPoint(rightFrontPos));

    // === 尾部蒸汽(prep 阶段引擎待机漏出的少量水蒸气) ===
    //   位置：火箭喷口上方(origin.y + 0.44*kRocketHeight ≈ 喷口附近内部)
    //   z 层：挂独立 UIView 在 rocketView 之后 addSubview → 粒子画在机身前面
    //   时机：prep 0.25s 开 birthRate=40，launch 1.0s 关；粒子短寿命 0.7s 自然淡完，
    //        正好对上 blast 爆炸喷薄 → 视觉效果 "被火焰吹散"
    UIView *tailVaporView = [[UIView alloc] initWithFrame:effectView.bounds];
    tailVaporView.backgroundColor = [UIColor clearColor];
    tailVaporView.userInteractionEnabled = NO;
    tailVaporView.clipsToBounds = NO;
    tailVaporView.tag = 2002;
    CAEmitterLayer *tailVapor = [self buildTailVaporEmitterWithHostBounds:tailVaporView.bounds];
    CGPoint tailVaporPos = CGPointMake(origin.x, origin.y + kRocketHeight * 0.44);
    tailVapor.emitterPosition = tailVaporPos;
    [tailVaporView.layer addSublayer:tailVapor];
    [effectView addSubview:tailVaporView];

    NSLog(@"[RocketLaunch] tailVapor 挂载 | emitterPosition=%@ | tailVaporView.idx=%lu (rocket 之上应 idx > rocket.idx)",
          NSStringFromCGPoint(tailVaporPos),
          (unsigned long)[effectView.subviews indexOfObject:tailVaporView]);

    // === 头像进入火箭的入场动画 ===
    //   1v1 模式(memberAvatars=nil): 单个头像从侧面弧形飞入舷窗
    //   群聊模式(memberAvatars 非空): N 个成员头像从四面八方汇聚到舷窗 → 闪光 → 群头像淡入
    //   ⚠️ groupAvatar 允许为 nil(群头像缓存 MISS),此时仍跑汇聚动画,只是最后舷窗空着不揭晓
    if (isGroupMode) {
        UIView *avatarBodyContainer = [rocketView viewWithTag:1001];
        CGFloat bodyTop = kRocketHeight * 0.26;
        CGFloat windowRadius = kRocketWidth * 0.22;
        CGPoint windowLocal = CGPointMake(kRocketWidth / 2.0, bodyTop + windowRadius + 4.0);
        CGFloat avatarDiameter = (windowRadius - 1.0) * 2;

        // **群头像 layer**:挂 bodyContainer 最底层,初始 opacity=0
        //   汇聚动画完成 + 闪光后通过 CABasicAnimation 淡入
        //   avatarImage=nil 时跳过(缓存 MISS → 舷窗留空,但仍跑汇聚)
        CALayer *groupAvatarLayer = nil;
        if (avatarImage) {
            groupAvatarLayer = [CALayer layer];
            groupAvatarLayer.contents = (__bridge id)avatarImage.CGImage;
            groupAvatarLayer.contentsGravity = kCAGravityResizeAspectFill;
            groupAvatarLayer.bounds = CGRectMake(0, 0, avatarDiameter, avatarDiameter);
            groupAvatarLayer.cornerRadius = avatarDiameter / 2.0;
            groupAvatarLayer.masksToBounds = YES;
            // 有些群头像本身带透明像素,透过舷窗能看到后面聊天页背景 → 加白色底色铺底,
            // 透明区域会被白色填满,视觉上像"白底印花"。masksToBounds+cornerRadius 保证圆形裁切。
            groupAvatarLayer.backgroundColor = [UIColor whiteColor].CGColor;
            groupAvatarLayer.position = windowLocal;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            groupAvatarLayer.opacity = 0.0;
            [avatarBodyContainer.layer insertSublayer:groupAvatarLayer atIndex:0];
            [CATransaction commit];
        }

        // 舷窗世界坐标(所有汇聚头像都以此为终点)
        CGPoint windowWorld = CGPointMake(origin.x, origin.y - kRocketHeight/2.0 + windowLocal.y);

        // === 能量汇聚参数(连续流设计) ===
        //   1. 起点:**屏幕外**随机边(上/左/右或对角),margin 60pt
        //   2. 初始 alpha=0.3 → 飞到半程 alpha=1.0(能量变强) → 最后 20% 缩小+淡出(被吸入)
        //   3. 连续流 ~1.0s 内 14 颗,视觉"源源不断"
        //   4. 成员不足时循环复用 memberAvatars(2-3 人群也能撑满流)
        NSInteger totalSpawns    = 14;          // 14 颗流过
        NSTimeInterval baseDelay = 0.35;        // 等 rocket 入场 spring 完成
        NSTimeInterval stagger   = 0.080;       // 每 80ms 一颗 → 1.0s 流完
        NSTimeInterval perDur    = 0.75;        // 每颗飞 0.75s
        CGFloat memberSize       = 36.0;        // 初始尺寸 36pt
        CGFloat edgeMargin       = 60.0;        // 起点在屏幕外 60pt

        // === 机身能量蓄积膨胀 ===
        //   能量源源不断汇入 → 机身逐步鼓胀(1.00 → 1.08),期间配两次轻微"呼吸"波动;
        //   发射瞬间(launch = 1.0 + launchDelay)回弹到 1.0 → "能量释放 → 起飞"的自然因果感。
        //   只缩放 bodyContainer(不含 coreFlame 喷口火焰),避免火焰跟着放大。
        //   keypath: transform.scale,与 engine-shake 用的 transform.translation.x 不冲突。
        {
            NSTimeInterval swellDur = (1.0 + launchDelay) - baseDelay;  // 0.35 → launch
            CAKeyframeAnimation *swell = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            swell.values = @[@1.00, @1.012, @1.025, @1.018, @1.040, @1.058, @1.070, @1.080, @1.00];
            swell.keyTimes = @[@0.00, @0.12, @0.24, @0.32, @0.48, @0.64, @0.78, @0.88, @1.00];
            swell.duration = swellDur;
            swell.beginTime = CACurrentMediaTime() + baseDelay;
            swell.fillMode = kCAFillModeBoth;
            swell.removedOnCompletion = YES;
            swell.timingFunctions = @[
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :0.2 :1.0],  // 最后一段:快速回弹
            ];
            [avatarBodyContainer.layer addAnimation:swell forKey:@"body-energy-swell"];
        }

        for (NSInteger i = 0; i < totalSpawns; i++) {
            UIImage *memberImg = memberAvatars[i % memberAvatars.count];

            // **随机选屏幕外起点**:4 种 — 左、右、上、对角(上左/上右任一)
            NSInteger edgeChoice = arc4random_uniform(5);
            CGPoint spawn;
            switch (edgeChoice) {
                case 0:  // 上边随机 x
                    spawn = CGPointMake(arc4random_uniform((u_int32_t)MAX(1, viewW)),
                                        -edgeMargin);
                    break;
                case 1:  // 左边随机 y (上半部)
                    spawn = CGPointMake(-edgeMargin,
                                        arc4random_uniform((u_int32_t)MAX(1, viewH * 0.55)));
                    break;
                case 2:  // 右边随机 y (上半部)
                    spawn = CGPointMake(viewW + edgeMargin,
                                        arc4random_uniform((u_int32_t)MAX(1, viewH * 0.55)));
                    break;
                case 3:  // 左上角外
                    spawn = CGPointMake(-edgeMargin - arc4random_uniform(40),
                                        -edgeMargin - arc4random_uniform(40));
                    break;
                default: // 右上角外
                    spawn = CGPointMake(viewW + edgeMargin + arc4random_uniform(40),
                                        -edgeMargin - arc4random_uniform(40));
                    break;
            }

            UIImageView *memberView = [[UIImageView alloc] initWithImage:memberImg];
            memberView.contentMode = UIViewContentModeScaleAspectFill;
            memberView.bounds = CGRectMake(0, 0, memberSize, memberSize);
            memberView.center = spawn;
            memberView.layer.cornerRadius = memberSize / 2.0;
            memberView.layer.masksToBounds = YES;
            memberView.layer.borderWidth = 1.5;
            memberView.layer.borderColor = [kAccentPurpleColor() colorWithAlphaComponent:0.85].CGColor;
            memberView.alpha = 0.20;   // **起始非常透明**(离火箭最远,几乎看不清)
            // 在 rocketView 之下插入 → 路径经过机身时会被遮挡,但屏幕外->接近舷窗途中大部分是可见的
            [effectView insertSubview:memberView belowSubview:rocketView];

            NSTimeInterval myDelay = baseDelay + i * stagger;

            // **距离动态透明度**:alpha 随"距离火箭"变化 —— 远=透、近=实、吸入=消失
            //   Phase 1 (0~25%): 最远段,alpha 从 0.20 → 0.45
            //   Phase 2 (25~55%): 中程,alpha → 0.80
            //   Phase 3 (55~85%): 靠近火箭,alpha → 1.00(完全不透明,"能量凝实")
            //   Phase 4 (85~100%): 被吸入 → 缩小 + alpha → 0
            //   position 在每个 phase 沿 spawn→windowWorld 线性插值到对应进度点,
            //   整条路径在 cubic 插值下丝滑(不是分段折线)
            CGFloat dx = windowWorld.x - spawn.x, dy = windowWorld.y - spawn.y;
            CGPoint q1 = CGPointMake(spawn.x + dx * 0.25, spawn.y + dy * 0.25);
            CGPoint q2 = CGPointMake(spawn.x + dx * 0.55, spawn.y + dy * 0.55);
            CGPoint q3 = CGPointMake(spawn.x + dx * 0.85, spawn.y + dy * 0.85);
            [UIView animateKeyframesWithDuration:perDur
                                           delay:myDelay
                                         options:UIViewKeyframeAnimationOptionCalculationModeCubic
                                      animations:^{
                [UIView addKeyframeWithRelativeStartTime:0.00 relativeDuration:0.25 animations:^{
                    memberView.alpha = 0.45;       // 远 → 略显清
                    memberView.center = q1;
                }];
                [UIView addKeyframeWithRelativeStartTime:0.25 relativeDuration:0.30 animations:^{
                    memberView.alpha = 0.80;       // 中程 → 大部分显现
                    memberView.center = q2;
                }];
                [UIView addKeyframeWithRelativeStartTime:0.55 relativeDuration:0.30 animations:^{
                    memberView.alpha = 1.00;       // 靠近 → 完全不透明,"能量凝实"
                    memberView.center = q3;
                }];
                [UIView addKeyframeWithRelativeStartTime:0.85 relativeDuration:0.15 animations:^{
                    memberView.alpha = 0;          // 吸入 → 消失(但**保持舷窗大小**,不是缩成零点)
                    memberView.center = windowWorld;
                    // 到舷窗后尺寸与舷窗一致(avatarDiameter),看起来像"叠进去"而不是"缩没"
                    memberView.bounds = CGRectMake(0, 0, avatarDiameter, avatarDiameter);
                    memberView.layer.cornerRadius = avatarDiameter / 2.0;
                    memberView.layer.borderWidth = 0.5;
                }];
            } completion:^(BOOL finished) {
                [memberView removeFromSuperview];
            }];
        }

        // 汇聚尾声 → 闪光 → 群头像(avatarImage)揭晓
        NSTimeInterval lastSpawn    = baseDelay + (totalSpawns - 1) * stagger;  // ≈ 1.80s
        NSTimeInterval lastAbsorbed = lastSpawn + perDur;                        // ≈ 2.65s
        NSTimeInterval flashAt      = lastAbsorbed - 0.20;                       // 最后几颗还在被吸的同时就开始闪光
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(flashAt * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CGFloat flashSize = avatarDiameter * 1.6;
            UIView *flash = [[UIView alloc] initWithFrame:CGRectMake(0, 0, flashSize, flashSize)];
            flash.center = windowWorld;
            flash.backgroundColor = [UIColor whiteColor];
            flash.layer.cornerRadius = flashSize / 2.0;
            flash.alpha = 0.95;
            [effectView insertSubview:flash belowSubview:rocketView];  // flash 在 rocket 下,机身挡一部分,只在舷窗洞里可见
            [UIView animateWithDuration:0.40 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                flash.transform = CGAffineTransformMakeScale(2.5, 2.5);
                flash.alpha = 0;
            } completion:^(BOOL f) {
                [flash removeFromSuperview];
            }];

            // 群头像(avatarImage)在舷窗淡入 —— groupAvatarLayer 为 nil 时(缓存 MISS)跳过揭晓,闪光依旧播
            if (groupAvatarLayer) {
                CABasicAnimation *reveal = [CABasicAnimation animationWithKeyPath:@"opacity"];
                reveal.fromValue = @0.0;
                reveal.toValue   = @1.0;
                reveal.duration  = 0.32;
                reveal.beginTime = CACurrentMediaTime() + 0.15;
                reveal.fillMode  = kCAFillModeForwards;
                reveal.removedOnCompletion = NO;
                [groupAvatarLayer addAnimation:reveal forKey:@"groupReveal"];
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                groupAvatarLayer.opacity = 1.0;
                [CATransaction commit];
            }

            NSLog(@"[GroupConverge] ⚡️ 闪光%@ @ t=%.2fs (lastAbsorbed=%.2fs)",
                  groupAvatarLayer ? @" + 群头像揭晓" : @"(无群头像,舷窗留空)",
                  flashAt, lastAbsorbed);
        });

        NSLog(@"[GroupConverge] 🌟 启动 | memberAvatars=%lu totalSpawns=%ld lastAbsorbed=%.2fs flashAt=%.2fs launchAt=%.2fs",
              (unsigned long)memberAvatars.count, (long)totalSpawns, lastAbsorbed, flashAt, 1.0 + launchDelay);
    }

    // === 1v1 模式:头像进入火箭的入场动画(弧形) ===
    //   设计目标:消除之前的"弹 2 次"—— 原因是直线路径穿过 body 不透明区(x=0~18)时 avatar 被遮,
    //     到舷窗洞(x=18~45)又重现,造成"消失-重现"两次 pop。
    //   弧形路径:从侧面起飞 → 弧形**绕过鼻锥上方** → 从正上方**垂直降入**舷窗洞,
    //     全程不经过 body 的不透明区域,最终直接从舷窗上方进入 → 无"弹 2 次"。
    //   由于 avatar 挂 bodyContainer.layer,发射时跟随 rocket 升空自动实现,无需 handoff。
    if (!isGroupMode && avatarImage) {
        UIView *avatarBodyContainer = [rocketView viewWithTag:1001];
        CGFloat bodyTop = kRocketHeight * 0.26;
        CGFloat windowRadius = kRocketWidth * 0.22;
        CGPoint windowLocal = CGPointMake(kRocketWidth / 2.0, bodyTop + windowRadius + 4.0);
        CGFloat avatarDiameter = (windowRadius - 1.0) * 2;

        CALayer *avatarLayer = [CALayer layer];
        avatarLayer.contents = (__bridge id)avatarImage.CGImage;
        avatarLayer.contentsGravity = kCAGravityResizeAspectFill;
        avatarLayer.bounds = CGRectMake(0, 0, avatarDiameter, avatarDiameter);
        avatarLayer.cornerRadius = avatarDiameter / 2.0;
        avatarLayer.masksToBounds = YES;
        // 白色底色,防止透明像素透出聊天页背景
        avatarLayer.backgroundColor = [UIColor whiteColor].CGColor;
        // **关键:整套属性初始化包在 disableActions 事务里**,防止 CALayer 对 position/hidden/bounds
        // 等可动画属性自动加隐式 CABasicAnimation(那些隐式动画就是"直线闪入"的罪魁)
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        avatarLayer.hidden = YES;   // spring 阶段(0~0.3s)隐藏,避免 rocket scale 0.001→1.0 把它从中心拖到 off-screen

        BOOL fromLeft = (arc4random_uniform(2) == 0);
        CGFloat startLocalX = fromLeft ? -250.0 : (kRocketWidth + 250.0);
        avatarLayer.position = CGPointMake(startLocalX, windowLocal.y);
        [avatarBodyContainer.layer insertSublayer:avatarLayer atIndex:0];
        [CATransaction commit];

        // 等 rocket 入场 spring 完成(0.3s)后启动弧形动画
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // **二次贝塞尔弧形路径**(先构建好,再原子提交)
            UIBezierPath *path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(startLocalX, windowLocal.y)];
            [path addQuadCurveToPoint:windowLocal
                         controlPoint:CGPointMake(kRocketWidth / 2.0, -70.0)];

            CAKeyframeAnimation *moveAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
            moveAnim.path = path.CGPath;
            moveAnim.duration = 1.20;
            moveAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            moveAnim.calculationMode = kCAAnimationCubicPaced;
            moveAnim.fillMode = kCAFillModeBoth;
            moveAnim.removedOnCompletion = NO;

            // **关键修复:把 model 终态 + addAnimation + unhide 塞进同一事务原子提交**
            //   否则两个事务之间有一帧窗口,layer 已可见但动画未接管,会在 windowLocal 闪一下
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            avatarLayer.position = windowLocal;         // model 终态
            [avatarLayer addAnimation:moveAnim forKey:@"avatarArcIn"];  // 动画接管渲染
            avatarLayer.hidden = NO;                     // 同一事务内 unhide,下一帧起动画已就位,不会闪
            [CATransaction commit];

            NSLog(@"[AvatarFly] 🚀 弧形路径 fromLeft=%d start(%g,%g) ctrl(%g,%g) end(%g,%g) duration=1.2s(easeOut)",
                  fromLeft, startLocalX, windowLocal.y, kRocketWidth/2.0, -70.0, windowLocal.x, windowLocal.y);
        });

        NSLog(@"[AvatarFly] 🚀 setup | fromLeft=%d diameter=%g windowLocal=%@",
              fromLeft, avatarDiameter, NSStringFromCGPoint(windowLocal));
    }

    // 舷窗扫光动画 —— idle 状态 shimmer 全 clear,扫光触发时**同时动画 colors 加白锚点**
    // + locations 平移,做完后再 colors 回 clear → 屏幕上只在扫光期间短暂看到一道光
    //
    // **时机:avatar 必须已进入舷窗(~1.5s)之后才能扫光**,否则 user 看到的是"头像还没来,玻璃先闪"很违和
    CALayer *shimmerLayer = [self findLayerWithName:@"window-shimmer" inLayer:rocketView.layer];
    if (shimmerLayer) {
        NSArray *clearColors = @[
            (id)[UIColor clearColor].CGColor,
            (id)[UIColor clearColor].CGColor,
            (id)[UIColor clearColor].CGColor,
            (id)[UIColor clearColor].CGColor,
            (id)[UIColor clearColor].CGColor,
        ];
        NSArray *litColors = @[
            (id)[UIColor clearColor].CGColor,
            (id)[UIColor clearColor].CGColor,
            (id)[[UIColor whiteColor] colorWithAlphaComponent:0.75].CGColor,
            (id)[UIColor clearColor].CGColor,
            (id)[UIColor clearColor].CGColor,
        ];

        void (^doSweep)(NSTimeInterval, NSString *) = ^(NSTimeInterval delay, NSString *key) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                CAGradientLayer *shimmerGrad = (CAGradientLayer *)shimmerLayer;
                shimmerGrad.colors = litColors;
                CABasicAnimation *loc = [CABasicAnimation animationWithKeyPath:@"locations"];
                loc.fromValue = @[@(-0.3), @(-0.2), @(-0.1), @(0.0), @(0.1)];
                loc.toValue   = @[@(0.9), @(1.0), @(1.1), @(1.2), @(1.3)];
                loc.duration = 0.55;
                loc.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                loc.fillMode = kCAFillModeBoth;
                [shimmerLayer addAnimation:loc forKey:key];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    shimmerGrad.colors = clearColors;
                });
            });
        };
        // 只保留 **avatar 进入后** 的那次扫光(约 1.6s,头像刚停在舷窗中心),做为"宇航员已就位"的反光提示
        doSweep(1.6 + launchDelay, @"glass-shimmer-after-avatar");
    }

    // === 动画编排（两阶段：蓄势 → 发射。蓄势 0.75s 节奏紧凑） ===
    // 0.0 ~ 0.3s   入场 spring
    // 0.25 ~ 1.0s  蓄势（机身震动、烟雾涌出、火焰待机）—— 0.75s
    // 1.0 ~ 2.4s   发射（加速飞出 + 尾迹颜色由灰→白渐变）
    // 2.0s          播撒星星（rocket 2.4s 出屏）
    // 3.3s          烟雾停止
    // 4.9s          清理

    // 阶段 1：入场（0.0~0.3s）
    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        rocketView.transform = CGAffineTransformIdentity;
    } completion:nil];

    // 阶段 2：引擎蓄势（0.25 ~ 1.0s）火焰待机 + 大量白烟涌出 + 机身持续震动 0.75s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        coreFlame.opacity = 1.0;
        [self setCoreFlameScaleX:coreFlame toValue:1.35 duration:0.25];
        [self startFlickerOnLayer:coreFlame baseScale:0.65];

        // 蓄势烟雾：快速爬升到 1.9（与起飞爆发同强度 → 同颜色 w≈0.83 浅灰）
        //   - 0.55s 内拉满 → prep 中段起所有新粒子都是 blast 同色
        //   - prep 头 0.55s 内的早期白粒子 lifetime 最多 2.0s，launch (1.0s) 前不会完全消散
        //     但 blast 冲击场会把它们吹散 → 视觉上仍然统一
        [smokeCloud animateIntensityTo:1.9 duration:0.55];

        // 开启机身包裹雾 + 尾部蒸汽：用 **emitter.birthRate = 1.0** 打开 layer-level gate
        //   cell.birthRate 已在 build 时预设目标值,这里只翻 gate 开关,最可靠
        bodyWrapBack.beginTime   = CACurrentMediaTime();
        bodyWrapFrontL.beginTime = CACurrentMediaTime();
        bodyWrapFrontR.beginTime = CACurrentMediaTime();
        bodyWrapBack.birthRate   = 1.0;
        bodyWrapFrontL.birthRate = 1.0;
        bodyWrapFrontR.birthRate = 1.0;

        tailVapor.beginTime = CACurrentMediaTime();
        tailVapor.birthRate = 1.0;       // ← gate ON（关键!之前漏了这行导致 tailVapor 一颗粒子都不发）
        NSLog(@"[TailVapor] 🔵 prep 0.25s emitter.birthRate=1.0 gate OPEN | emitterPos=%@ cell.birthRate(preset)=%g",
              NSStringFromCGPoint(tailVapor.emitterPosition),
              ((CAEmitterCell *)tailVapor.emitterCells.firstObject).birthRate);
        NSLog(@"[BodyWrap] 🟢 prep 0.25s back+front emitter.birthRate=1.0 gate OPEN | bothCell.birthRate(preset)=%g",
              ((CAEmitterCell *)bodyWrapBack.emitterCells.firstObject).birthRate);

        // 诊断：确认 wrapView 在 rocketView 之上，back emitter 还在 rocket 之下
        NSArray *subviews = effectView.subviews;
        NSUInteger rocketIdx = [subviews indexOfObject:rocketView];
        UIView *wrapView = [effectView viewWithTag:2001];
        NSUInteger wrapIdx = wrapView ? [subviews indexOfObject:wrapView] : NSNotFound;
        NSInteger backIdxInSublayers = -1;
        NSInteger rocketIdxInSublayers = -1;
        NSArray *subs = effectView.layer.sublayers;
        for (NSInteger i = 0; i < (NSInteger)subs.count; i++) {
            if (subs[i] == bodyWrapBack) backIdxInSublayers = i;
            if (subs[i] == rocketView.layer) rocketIdxInSublayers = i;
        }
        NSLog(@"[RocketLaunch] prep 0.25s | wrapView.idx=%lu rocket.idx=%lu frontOnTop=%@ | sublayers: back.idx=%ld rocket.idx=%ld backBelowRocket=%@ | both cells opened birthRate=80",
              (unsigned long)wrapIdx, (unsigned long)rocketIdx,
              (wrapIdx != NSNotFound && wrapIdx > rocketIdx) ? @"YES" : @"NO",
              (long)backIdxInSublayers, (long)rocketIdxInSublayers,
              (backIdxInSublayers >= 0 && rocketIdxInSublayers >= 0 && backIdxInSublayers < rocketIdxInSublayers) ? @"YES" : @"NO");

        // 0.5s 后复查：emitter 是否还在层级中、cell birthRate 是否保持，帮助定位"粒子不发射"的根因
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CAEmitterCell *backCell = bodyWrapBack.emitterCells.firstObject;
            CAEmitterCell *frontCell = bodyWrapFront.emitterCells.firstObject;
            NSLog(@"[RocketLaunch] prep+0.5s 复查 | back.superlayer=%@ back.cell.birthRate=%g front.superlayer=%@ front.cell.birthRate=%g | back.hidden=%d front.hidden=%d | back.opacity=%g front.opacity=%g",
                  bodyWrapBack.superlayer ? @"STILL_MOUNTED" : @"NIL!!",
                  backCell ? backCell.birthRate : -1,
                  bodyWrapFront.superlayer ? @"STILL_MOUNTED" : @"NIL!!",
                  frontCell ? frontCell.birthRate : -1,
                  bodyWrapBack.hidden, bodyWrapFront.hidden,
                  bodyWrapBack.opacity, bodyWrapFront.opacity);
        });

        [self applyEngineShakeToView:bodyContainer duration:0.75 + launchDelay];

        UIImpactFeedbackGenerator *light = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [light prepare];
        [light impactOccurred];
    });

    // 阶段 3：直接加速发射（1.0 ~ 2.4s）从原地直接飞出屏幕顶部
    __block CGPoint liftStart = origin;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1.0 + launchDelay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CAMediaTimingFunction *power4 = [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :1.0 :0.25];
        [CATransaction begin];
        [CATransaction setAnimationTimingFunction:power4];
        [UIView animateWithDuration:1.4
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            rocketView.center = CGPointMake(origin.x, -(kRocketHeight * 3) - 200);
        } completion:^(BOOL finished) {
            rocketView.hidden = YES;
            // 火箭出屏 → 停产尾迹新粒子（已有粒子按 lifetime 自然淡出）
            [trailTracker stopEmitting];
        }];
        [CATransaction commit];

        // 启动尾迹：用 emitter.birthRate 层级 gate 打开（cell 的 100/55 已在 build 时预设）
        trailEmitter.birthRate = 1.0;      // ← gate ON
        [trailTracker start];

        // === 尾迹颜色 5 关键帧：从"比 SK 浅"的灰白 → 纯白 ===
        // 设计原则：
        //   1. 起始色必须明显亮于 SK 地面烟(w=0.82)：用 rgb(0.88~0.96) 自然浅灰→近白
        //   2. **改用 cell.color 直改 + emitter.emitterCells 重赋值** 强制 refresh —
        //      上一版用 setValue:forKeyPath: 根本没改到 cell.color 的 model 值(日志显示 t=2.0s
        //      时 cell 还是初始 0.88)，原因是 CAEmitterCell 属性被 emitter 缓存，需要
        //      重新 assign emitterCells 才会让 emitter pick up。
        //   3. 每个关键帧打日志，并同时读回 cell.color 做自我验证
        UIColor *c1 = [UIColor colorWithRed:0.88 green:0.88 blue:0.90 alpha:0.68]; // t=0.00 起点：自然浅灰
        UIColor *c2 = [UIColor colorWithRed:0.90 green:0.91 blue:0.92 alpha:0.72]; // t=0.35
        UIColor *c3 = [UIColor colorWithRed:0.92 green:0.93 blue:0.94 alpha:0.75]; // t=0.70
        UIColor *c4 = [UIColor colorWithRed:0.94 green:0.94 blue:0.95 alpha:0.78]; // t=1.05
        UIColor *c5 = [UIColor colorWithRed:0.96 green:0.96 blue:0.97 alpha:0.80]; // t=1.40 终点：近白(不过度纯白)

        NSLog(@"[Trail] 🎨 t=0.00s 起点 core=rgba(0.88,0.88,0.90,0.68) —— 自然浅灰，不过白");

        // 内联宏：直改 cell.color + 重赋值 emitterCells 强制 refresh
        void (^updateTrailColors)(UIColor *) = ^(UIColor *c) {
            NSArray<CAEmitterCell *> *cells = trailEmitter.emitterCells;
            CAEmitterCell *haloC = cells.firstObject;
            CAEmitterCell *coreC = cells.count >= 2 ? cells[1] : cells.firstObject;
            coreC.color = c.CGColor;
            CGFloat haloAlpha = MIN(0.55, CGColorGetAlpha(c.CGColor) - 0.20);
            haloC.color = [c colorWithAlphaComponent:MAX(0.35, haloAlpha)].CGColor;
            trailEmitter.emitterCells = cells;   // ← 关键：强制 refresh
        };

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            updateTrailColors(c2);
            CAEmitterCell *coreC = trailEmitter.emitterCells.count >= 2 ? trailEmitter.emitterCells[1] : trailEmitter.emitterCells.firstObject;
            NSLog(@"[Trail] 🎨 t=0.35s → c2 | 验证读回 cell.color=%@", coreC.color);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.70 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            updateTrailColors(c3);
            CAEmitterCell *coreC = trailEmitter.emitterCells.count >= 2 ? trailEmitter.emitterCells[1] : trailEmitter.emitterCells.firstObject;
            NSLog(@"[Trail] 🎨 t=0.70s → c3 | 验证读回 cell.color=%@", coreC.color);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            updateTrailColors(c4);
            CAEmitterCell *coreC = trailEmitter.emitterCells.count >= 2 ? trailEmitter.emitterCells[1] : trailEmitter.emitterCells.firstObject;
            NSLog(@"[Trail] 🎨 t=1.05s → c4 | 验证读回 cell.color=%@", coreC.color);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.40 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            updateTrailColors(c5);
            CAEmitterCell *coreC = trailEmitter.emitterCells.count >= 2 ? trailEmitter.emitterCells[1] : trailEmitter.emitterCells.firstObject;
            NSLog(@"[Trail] 🎨 t=1.40s 终点 → c5 | 验证读回 cell.color=%@", coreC.color);
        });

        // 停止机身包裹雾 + 尾部蒸汽：layer-level gate OFF,已有粒子按 lifetime 自然淡出
        bodyWrapBack.birthRate   = 0.0;
        bodyWrapFrontL.birthRate = 0.0;
        bodyWrapFrontR.birthRate = 0.0;
        tailVapor.birthRate     = 0.0;
        NSLog(@"[BodyWrap+TailVapor] 🔴 launch 1.0s emitter.birthRate=0 gate CLOSED");

        NSLog(@"[RocketLaunch] launch 1.0s | trail opened (halo=55 core=100) + 5-keyframe color, bodyWrap+tailVapor birthRate→0, trailTracker.started=YES");

        // 🔍 launch+1.0s (= t=2.0s) 诊断：打印每一类粒子源的当前 cell.color + birthRate，
        //   帮助定位"升空 1s 后尾迹中出现的黑色烟雾"到底来自哪个 emitter
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CAEmitterCell *trailCore  = trailEmitter.emitterCells.count >= 2 ? trailEmitter.emitterCells[1] : trailEmitter.emitterCells.firstObject;
            CAEmitterCell *trailHalo  = trailEmitter.emitterCells.firstObject;
            CAEmitterCell *wrapBack   = bodyWrapBack.emitterCells.firstObject;
            CAEmitterCell *wrapFront  = bodyWrapFront.emitterCells.firstObject;
            CAEmitterCell *vapor      = tailVapor.emitterCells.firstObject;
            NSLog(@"[PostLaunch+1s 🔍] 粒子源状态排查:\n"
                  @"  trail.core:  color=%@ birthRate=%g\n"
                  @"  trail.halo:  color=%@ birthRate=%g\n"
                  @"  bodyWrap.back:  color=%@ birthRate=%g\n"
                  @"  bodyWrap.front: color=%@ birthRate=%g\n"
                  @"  tailVapor:   color=%@ birthRate=%g\n"
                  @"  → 任何颜色明显偏暗(w < 0.8)或 birthRate 非预期即为可疑源",
                  trailCore.color, trailCore.birthRate,
                  trailHalo.color, trailHalo.birthRate,
                  wrapBack.color,  wrapBack.birthRate,
                  wrapFront.color, wrapFront.birthRate,
                  vapor.color,     vapor.birthRate);
        });

        // 火焰：X 最窄 0.75，Y 最长 1.75（一束狭长喷射）
        [self setCoreFlameScaleX:coreFlame toValue:0.75 duration:0.35];
        [coreFlame removeAnimationForKey:@"flame-flicker"];
        [self startFlickerOnLayer:coreFlame baseScale:1.75];

        // 烟雾：发射推力冲击 → intensity 升到 1.9 (烟量最大且最浓)
        [smokeCloud animateIntensityTo:1.9 duration:0.5];

        // 火焰炙烤粒子（红色染色）：
        //   1. 先切换到"起飞形态"：粒子拉长、顺左右喷射方向 → 橙色烟条
        //   2. 0.45s 内 heatLevel 从 1.0 → 0，新红粒子在 1.45s 停产
        //   3. 已生成粒子按 lifetime 0.4~0.55s 自然淡出 → **2.0s 画面中完全无红色**
        [smokeCloud configureHeatForLaunch];
        [smokeCloud fadeHeatLevelTo:0 duration:0.45];

        // 爆发冲击：径向推力场把蓄势阶段累积的白烟"吹散"翻滚 → 真实感
        CGPoint nozzleWorld = CGPointMake(origin.x, origin.y + kRocketHeight / 2.0 - 4.0);
        CGPoint nozzleInCloudLocal = [effectView convertPoint:nozzleWorld toView:smokeCloud];
        // 延长 blast 横推时长(原 0.9 → 1.8s)：横向线性重力场和 turbo 湍流会持续推动新生粒子
        // 向左右两侧散开，防止"火箭走后粒子继续从喷口点冒出堆成球"
        [smokeCloud applyBlastAtNozzlePoint:nozzleInCloudLocal duration:1.8];

        UIImpactFeedbackGenerator *medium = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [medium prepare];
        [medium impactOccurred];
    });

    // 烟雾衰减链
    //   1.9 (峰值 @launch) → 1.3 (@+0.7s) → 0.55 (@+1.2s) → 0.10 (@+1.7s) → stopEmitting (@+2.3s)
    // 火箭于 launch+1.4s 飞出屏幕，尾段在其后 ~2s 内完全淡出
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1.7 + launchDelay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [smokeCloud animateIntensityTo:1.30 duration:0.5];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((2.2 + launchDelay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [smokeCloud animateIntensityTo:0.55 duration:0.5];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((2.7 + launchDelay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [smokeCloud animateIntensityTo:0.10 duration:0.5];
    });

    // 阶段 4：发射路径上留下 4 颗星星
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((2.0 + launchDelay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGPoint liftEndCenter = CGPointMake(liftStart.x, liftStart.y - 80.0);
        [self scatterSparkleStarsAlongPathFrom:liftStart to:liftEndCenter inView:effectView];
    });

    // 阶段 5：烟雾停止生成（intensity 已降到 0.10）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((3.3 + launchDelay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [smokeCloud stopEmitting];
    });

    // 阶段 6：清理(群聊 launchDelay 0.75s 叠加上去,保证延后的发射尾段也能被清理)
    [effectView scheduleRemovalAfterDelay:4.9 + launchDelay];
}

#pragma mark - 火箭视图组装

+ (UIView *)buildRocketViewWithSize:(CGSize)size avatarImage:(nullable UIImage *)avatarImage {
    return [self buildRocketViewWithSize:size avatarImage:avatarImage transparentWindow:(avatarImage != nil)];
}

+ (UIView *)buildRocketViewWithSize:(CGSize)size
                        avatarImage:(nullable UIImage *)avatarImage
                  transparentWindow:(BOOL)transparentWindow {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    container.userInteractionEnabled = NO;
    container.backgroundColor = [UIColor clearColor];

    // 机身子容器（所有机身 layer 加到这里）。shake 只应用到这个子视图，
    // 不会传递给火焰粒子，避免火焰看起来"歪"。
    UIView *bodyContainer = [[UIView alloc] initWithFrame:container.bounds];
    bodyContainer.tag = 1001;
    bodyContainer.userInteractionEnabled = NO;
    bodyContainer.backgroundColor = [UIColor clearColor];
    [container addSubview:bodyContainer];

    // 部件几何（相对 bodyContainer 坐标，原点 top-left）
    CGFloat W = size.width;
    CGFloat H = size.height;
    CGFloat noseH   = H * 0.26;                     // 鼻锥高度（按比例随火箭尺寸变化）
    CGFloat nozzleH = 7.0;
    CGFloat bodyTop = noseH;
    CGFloat bodyBottom = H - nozzleH;
    CGRect bodyRect = CGRectMake(0, bodyTop, W, bodyBottom - bodyTop);

    // 1. 机身（白→浅灰水平渐变模拟光照）
    //    transparentWindow=YES 时给机身加**舷窗位置的圆孔 mask** → 底层的 avatarLayer / 汇入头像能真正透过舷窗显露
    //    (光玻璃透明是不够的,因为 body 本身是不透明的银色渐变,遮住了后面的 avatar)
    CGFloat windowRadius = kRocketWidth * 0.22;
    CGPoint windowCenter = CGPointMake(kRocketWidth / 2.0, bodyTop + windowRadius + 4.0);
    CGRect windowCutoutRect = transparentWindow
        ? CGRectMake(windowCenter.x - windowRadius + 1.0, windowCenter.y - windowRadius + 1.0,
                     (windowRadius - 1.0) * 2, (windowRadius - 1.0) * 2)
        : CGRectZero;
    CALayer *body = [self bodyLayerInRect:bodyRect windowCutout:windowCutoutRect];
    [bodyContainer.layer addSublayer:body];

    // 2. 鼻锥（红→深红垂直渐变）
    CALayer *nose = [self noseConeLayerInRect:CGRectMake(0, 0, W, noseH)];
    [bodyContainer.layer addSublayer:nose];

    // 3. 舷窗（机身上部）— 舷窗内嵌发送者头像，像是发送者坐在火箭里
    //    transparentWindow=YES 时 glass fill 透明, body 已在 step 1 挖了圆孔,avatar / 汇入头像透过孔直接可见
    CALayer *windowLayer = [self windowLayerAtCenter:windowCenter radius:windowRadius
                                         avatarImage:avatarImage transparent:transparentWindow];
    [bodyContainer.layer addSublayer:windowLayer];

    // 4. "OCTO" 品牌铭牌（舷窗下方，11pt Heavy 主题紫色渐变）
    CGPoint octoCenter = CGPointMake(W / 2.0, windowCenter.y + windowRadius + 15.0);
    CALayer *octo = [self brandLabelAt:octoCenter
                                  text:@"OCTO"
                              fontSize:11.0
                              topColor:[UIColor colorWithRed:0.54 green:0.36 blue:0.84 alpha:1.0]   // #8A5CD6 = kAccentPurple
                           bottomColor:[UIColor colorWithRed:0.22 green:0.14 blue:0.53 alpha:1.0]]; // #382488 深靛
    [bodyContainer.layer addSublayer:octo];

    // 5. 机身分段线（机身中下部一道细接缝）—— 接缝位置整体上调 6pt，留出更大的下段放 2718
    //    模拟机身分段构造：上半段和下半段的接缝处有一条深色细线 + 两个小铆钉
    CGFloat seamY = bodyBottom - 32.0;
    CAShapeLayer *seamLine = [CAShapeLayer layer];
    UIBezierPath *seamPath = [UIBezierPath bezierPath];
    [seamPath moveToPoint:CGPointMake(4.0, seamY)];
    [seamPath addLineToPoint:CGPointMake(W - 4.0, seamY)];
    seamLine.path = seamPath.CGPath;
    seamLine.strokeColor = [kAccentPurpleColor() colorWithAlphaComponent:0.38].CGColor;
    seamLine.lineWidth = 0.7;
    [bodyContainer.layer addSublayer:seamLine];

    // 接缝处左右两颗小铆钉（加固感）
    for (NSInteger i = 0; i < 2; i++) {
        CGFloat rx = (i == 0) ? W * 0.16 : W * 0.84;
        CAShapeLayer *rivet = [CAShapeLayer layer];
        rivet.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(rx - 1.1, seamY - 1.1, 2.2, 2.2)].CGPath;
        rivet.fillColor = [kRivetColor() colorWithAlphaComponent:0.7].CGColor;
        [bodyContainer.layer addSublayer:rivet];
    }

    // 6. "2718" 股票代码铭牌（接缝下方，10pt Heavy 主题紫色渐变 —— 同 OCTO 同色系但字号小一档）
    CGPoint tickerCenter = CGPointMake(W / 2.0, seamY + 13.0);
    CALayer *ticker = [self brandLabelAt:tickerCenter
                                    text:@"2718"
                                fontSize:10.0
                                topColor:[UIColor colorWithRed:0.54 green:0.36 blue:0.84 alpha:1.0]   // #8A5CD6 = kAccentPurple
                             bottomColor:[UIColor colorWithRed:0.22 green:0.14 blue:0.53 alpha:1.0]]; // #382488 深靛
    [bodyContainer.layer addSublayer:ticker];

    // 6. 左右尾翼（从机身底部向外斜下，顶边嵌入机身内侧平滑衔接）
    CAShapeLayer *finL = [self finLayerLeft:YES bodyRect:bodyRect];
    [bodyContainer.layer addSublayer:finL];
    CAShapeLayer *finR = [self finLayerLeft:NO bodyRect:bodyRect];
    [bodyContainer.layer addSublayer:finR];

    // 7. 喷口（倒梯形）
    CGRect nozzleRect = CGRectMake(0, bodyBottom, W, nozzleH);
    CAShapeLayer *nozzle = [self nozzleLayerInRect:nozzleRect];
    [bodyContainer.layer addSublayer:nozzle];

    // 8. 中尾翼（机身底部中央，倒三角形指向喷口方向 → 呼应参考图第三片尾翼）
    //    放在喷口之上避免视觉冲突（中翼覆盖喷口中段）
    CALayer *centerFin = [self centerFinLayerInBodyRect:bodyRect nozzleRect:nozzleRect];
    [bodyContainer.layer addSublayer:centerFin];

    return container;
}

#pragma mark - 机身 (Body)

+ (CALayer *)bodyLayerInRect:(CGRect)rect windowCutout:(CGRect)windowCutoutRect {
    // 机身外形：圆角胶囊形
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:
                          CGRectMake(rect.origin.x + 1, rect.origin.y, rect.size.width - 2, rect.size.height)
                          cornerRadius:rect.size.width * 0.18];

    // 霓虹全息水平渐变：青蓝 → 银白 → 中银 → 紫粉
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = rect;
    gradient.colors = @[
        (id)kBodyCyanColor().CGColor,    // 0.0  左侧亮青
        (id)kBodySilverColor().CGColor,  // 0.35 银白高光
        (id)kBodyMidColor().CGColor,     // 0.65 中银过渡
        (id)kBodyPurpleColor().CGColor,  // 1.0  右侧紫粉
    ];
    gradient.locations = @[@(0.0), @(0.35), @(0.65), @(1.0)];
    gradient.startPoint = CGPointMake(0.0, 0.5);
    gradient.endPoint = CGPointMake(1.0, 0.5);

    // 用形状做 mask
    CAShapeLayer *mask = [CAShapeLayer layer];
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:
                              CGRectMake(1, 0, rect.size.width - 2, rect.size.height)
                              cornerRadius:rect.size.width * 0.18];
    mask.path = maskPath.CGPath;
    gradient.mask = mask;

    // 在外层包一个 wrapper，叠加橙色描边（卡通勾边感）
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, rect.origin.x * 2 + rect.size.width, rect.origin.y + rect.size.height);
    [wrapper addSublayer:gradient];

    // === 光泽质感增强（多层叠加）===

    // 光泽 1：顶部弧形高光（机身顶部一道弧 → 模拟曲面的反射光带）
    CAGradientLayer *topGloss = [CAGradientLayer layer];
    topGloss.frame = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height * 0.35);
    topGloss.colors = @[
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor,
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor,
        (id)[UIColor clearColor].CGColor,
    ];
    topGloss.locations = @[@(0.0), @(0.6), @(1.0)];
    topGloss.startPoint = CGPointMake(0.5, 0.0);
    topGloss.endPoint = CGPointMake(0.5, 1.0);
    // mask 到机身轮廓（避免溢出圆角外）
    CAShapeLayer *topGlossMask = [CAShapeLayer layer];
    UIBezierPath *topGlossMaskPath = [UIBezierPath bezierPathWithRoundedRect:
                                      CGRectMake(1, 0, rect.size.width - 2, topGloss.frame.size.height)
                                      cornerRadius:rect.size.width * 0.18];
    topGlossMask.path = topGlossMaskPath.CGPath;
    topGloss.mask = topGlossMask;
    [wrapper addSublayer:topGloss];

    // 光泽 2：底部阴影渐变（下部微暗 → 3D 圆柱立体感）
    CAGradientLayer *bottomShade = [CAGradientLayer layer];
    CGFloat shadeH = rect.size.height * 0.30;
    bottomShade.frame = CGRectMake(rect.origin.x, rect.origin.y + rect.size.height - shadeH,
                                   rect.size.width, shadeH);
    bottomShade.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[[UIColor blackColor] colorWithAlphaComponent:0.10].CGColor,
        (id)[[UIColor blackColor] colorWithAlphaComponent:0.20].CGColor,
    ];
    bottomShade.locations = @[@(0.0), @(0.6), @(1.0)];
    bottomShade.startPoint = CGPointMake(0.5, 0.0);
    bottomShade.endPoint = CGPointMake(0.5, 1.0);
    CAShapeLayer *bottomShadeMask = [CAShapeLayer layer];
    UIBezierPath *bottomShadeMaskPath = [UIBezierPath bezierPathWithRoundedRect:
                                         CGRectMake(1, 0, rect.size.width - 2, shadeH)
                                         cornerRadius:rect.size.width * 0.18];
    bottomShadeMask.path = bottomShadeMaskPath.CGPath;
    bottomShade.mask = bottomShadeMask;
    [wrapper addSublayer:bottomShade];

    // 橙色卡通描边
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = path.CGPath;
    stroke.fillColor = [UIColor clearColor].CGColor;
    stroke.strokeColor = [kOrangeAccentColor() colorWithAlphaComponent:0.75].CGColor;
    stroke.lineWidth = 0.8;
    [wrapper addSublayer:stroke];

    // 光泽 3：主竖向高光（左 22% 位置，明显白光 → 金属圆柱反光核心）
    CAShapeLayer *verticalShine = [CAShapeLayer layer];
    UIBezierPath *vsPath = [UIBezierPath bezierPath];
    CGFloat vsX = rect.origin.x + rect.size.width * 0.22;
    [vsPath moveToPoint:CGPointMake(vsX, rect.origin.y + 6)];
    [vsPath addLineToPoint:CGPointMake(vsX, rect.origin.y + rect.size.height - 10)];
    verticalShine.path = vsPath.CGPath;
    verticalShine.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.55].CGColor;
    verticalShine.lineWidth = 2.5;
    verticalShine.lineCap = kCALineCapRound;
    [wrapper addSublayer:verticalShine];

    // 光泽 4：次级竖向反光（左 33% 位置，更淡更细 → 多层反光层次）
    CAShapeLayer *secondShine = [CAShapeLayer layer];
    UIBezierPath *ssPath = [UIBezierPath bezierPath];
    CGFloat ssX = rect.origin.x + rect.size.width * 0.35;
    [ssPath moveToPoint:CGPointMake(ssX, rect.origin.y + 10)];
    [ssPath addLineToPoint:CGPointMake(ssX, rect.origin.y + rect.size.height - 14)];
    secondShine.path = ssPath.CGPath;
    secondShine.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.22].CGColor;
    secondShine.lineWidth = 1.0;
    secondShine.lineCap = kCALineCapRound;
    [wrapper addSublayer:secondShine];

    // 光泽 5：右侧暗边反光（紫色侧的边缘阴影 → 圆柱背光感）
    CAShapeLayer *darkEdge = [CAShapeLayer layer];
    UIBezierPath *dePath = [UIBezierPath bezierPath];
    CGFloat deX = rect.origin.x + rect.size.width * 0.88;
    [dePath moveToPoint:CGPointMake(deX, rect.origin.y + 8)];
    [dePath addLineToPoint:CGPointMake(deX, rect.origin.y + rect.size.height - 12)];
    darkEdge.path = dePath.CGPath;
    darkEdge.strokeColor = [[UIColor blackColor] colorWithAlphaComponent:0.14].CGColor;
    darkEdge.lineWidth = 1.5;
    darkEdge.lineCap = kCALineCapRound;
    [wrapper addSublayer:darkEdge];

    // 机身两列铆钉（左右对称各 3 颗，小深色圆点 → 机体拼装感）
    CGFloat rivetLeftX = rect.origin.x + rect.size.width * 0.14;
    CGFloat rivetRightX = rect.origin.x + rect.size.width * 0.86;
    CGFloat rivetTopY = rect.origin.y + rect.size.height * 0.32;
    CGFloat rivetStep = rect.size.height * 0.18;
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat y = rivetTopY + i * rivetStep;
        for (NSInteger side = 0; side < 2; side++) {
            CGFloat x = (side == 0) ? rivetLeftX : rivetRightX;
            CAShapeLayer *rivet = [CAShapeLayer layer];
            rivet.path = [UIBezierPath bezierPathWithOvalInRect:
                          CGRectMake(x - 1.0, y - 1.0, 2.0, 2.0)].CGPath;
            rivet.fillColor = [kRivetColor() colorWithAlphaComponent:0.55].CGColor;
            [wrapper addSublayer:rivet];
        }
    }

    // 舷窗圆孔 mask(仅在 windowCutoutRect 非空时启用)
    //   机身 wrapper 上挖一个圆形"洞",让底层的 avatarLayer 透过舷窗可见。
    //   用 even-odd fill rule:外层矩形 + 内层圆 = 矩形减去圆 = 机身有洞。
    if (!CGRectIsEmpty(windowCutoutRect)) {
        CAShapeLayer *holeMask = [CAShapeLayer layer];
        UIBezierPath *outer = [UIBezierPath bezierPathWithRect:wrapper.bounds];
        UIBezierPath *hole  = [UIBezierPath bezierPathWithOvalInRect:windowCutoutRect];
        [outer appendPath:hole];
        holeMask.path = outer.CGPath;
        holeMask.fillRule = kCAFillRuleEvenOdd;
        wrapper.mask = holeMask;
    }

    return wrapper;
}

#pragma mark - 鼻锥 (Nose Cone)

+ (CALayer *)noseConeLayerInRect:(CGRect)rect {
    CGFloat W = rect.size.width;
    CGFloat H = rect.size.height;

    // 鼻锥轮廓：上尖下宽圆润尖顶
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(rect.origin.x + 1, rect.origin.y + H)];
    [path addQuadCurveToPoint:CGPointMake(rect.origin.x + W / 2.0, rect.origin.y + 1)
                 controlPoint:CGPointMake(rect.origin.x + W * 0.12, rect.origin.y + H * 0.25)];
    [path addQuadCurveToPoint:CGPointMake(rect.origin.x + W - 1, rect.origin.y + H)
                 controlPoint:CGPointMake(rect.origin.x + W * 0.88, rect.origin.y + H * 0.25)];
    [path closePath];

    // 红色渐变：左亮红 → 中橙红高光 → 右深红（立体感）
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = rect;
    gradient.colors = @[
        (id)kNoseRedBrightColor().CGColor,  // 0.05 亮红橙
        (id)kNoseRedColor().CGColor,        // 0.45 经典红
        (id)kNoseRedDarkColor().CGColor,    // 0.95 深红
    ];
    gradient.locations = @[@(0.05), @(0.45), @(0.95)];
    gradient.startPoint = CGPointMake(0.0, 0.2);
    gradient.endPoint = CGPointMake(1.0, 0.8);  // 斜向（左上亮，右下暗）

    CAShapeLayer *mask = [CAShapeLayer layer];
    CGAffineTransform t = CGAffineTransformMakeTranslation(-rect.origin.x, -rect.origin.y);
    mask.path = CGPathCreateCopyByTransformingPath(path.CGPath, &t);
    gradient.mask = mask;

    // 外层 wrapper
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, rect.origin.x * 2 + W, rect.origin.y + H);
    [wrapper addSublayer:gradient];

    // 细节 1：顶部白色高光（长弧，强调顶端反光）
    CAShapeLayer *topShine = [CAShapeLayer layer];
    UIBezierPath *tsPath = [UIBezierPath bezierPath];
    [tsPath moveToPoint:CGPointMake(rect.origin.x + W * 0.38, rect.origin.y + H * 0.35)];
    [tsPath addQuadCurveToPoint:CGPointMake(rect.origin.x + W * 0.50, rect.origin.y + 2)
                   controlPoint:CGPointMake(rect.origin.x + W * 0.40, rect.origin.y + H * 0.12)];
    topShine.path = tsPath.CGPath;
    topShine.fillColor = [UIColor clearColor].CGColor;
    topShine.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.82].CGColor;
    topShine.lineWidth = 1.6;
    topShine.lineCap = kCALineCapRound;
    [wrapper addSublayer:topShine];

    // 细节 2：侧边小高光（右侧一道小白线，金属反光）
    CAShapeLayer *sideShine = [CAShapeLayer layer];
    UIBezierPath *ssPath = [UIBezierPath bezierPath];
    [ssPath moveToPoint:CGPointMake(rect.origin.x + W * 0.66, rect.origin.y + H * 0.55)];
    [ssPath addLineToPoint:CGPointMake(rect.origin.x + W * 0.68, rect.origin.y + H * 0.78)];
    sideShine.path = ssPath.CGPath;
    sideShine.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35].CGColor;
    sideShine.lineWidth = 1.0;
    sideShine.lineCap = kCALineCapRound;
    [wrapper addSublayer:sideShine];

    // 细节 3：底部分界线（锥盖接缝 → 机身和鼻锥的"衔接环"）
    CAShapeLayer *seam = [CAShapeLayer layer];
    UIBezierPath *seamPath = [UIBezierPath bezierPath];
    [seamPath moveToPoint:CGPointMake(rect.origin.x + 3, rect.origin.y + H - 1.5)];
    [seamPath addLineToPoint:CGPointMake(rect.origin.x + W - 3, rect.origin.y + H - 1.5)];
    seam.path = seamPath.CGPath;
    seam.strokeColor = kNoseSeamColor().CGColor;
    seam.lineWidth = 1.8;
    seam.lineCap = kCALineCapRound;
    [wrapper addSublayer:seam];

    // 细节 4：接缝铆钉（左右两个小圆点）
    CGFloat rivetY = rect.origin.y + H - 1.5;
    for (NSInteger i = 0; i < 2; i++) {
        CGFloat rivetX = rect.origin.x + (i == 0 ? W * 0.22 : W * 0.78);
        CAShapeLayer *rivet = [CAShapeLayer layer];
        rivet.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(rivetX - 1.2, rivetY - 1.2, 2.4, 2.4)].CGPath;
        rivet.fillColor = [[UIColor blackColor] colorWithAlphaComponent:0.5].CGColor;
        [wrapper addSublayer:rivet];
    }

    // 细节 5：鼻锥外描边（深红勾边 → 卡通质感）
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = path.CGPath;
    stroke.fillColor = [UIColor clearColor].CGColor;
    stroke.strokeColor = [kNoseRedDarkColor() colorWithAlphaComponent:0.9].CGColor;
    stroke.lineWidth = 1.0;
    [wrapper addSublayer:stroke];

    return wrapper;
}

#pragma mark - 舷窗 (Window)

/// 舷窗层级（由外向内）：
///   外层：紫色描边的蓝色玻璃圆
///   头像层（如有）：圆形裁剪的发送者头像，alpha 0.78（玻璃后透出的感觉）
///   玻璃覆膜：蓝色半透明覆盖（玻璃质感）
///   高光：左上角白色小圆（玻璃反光）
+ (CALayer *)windowLayerAtCenter:(CGPoint)center radius:(CGFloat)r avatarImage:(nullable UIImage *)avatarImage {
    return [self windowLayerAtCenter:center radius:r avatarImage:avatarImage transparent:(avatarImage != nil)];
}

+ (CALayer *)windowLayerAtCenter:(CGPoint)center
                          radius:(CGFloat)r
                     avatarImage:(nullable UIImage *)avatarImage
                     transparent:(BOOL)transparent {
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(center.x - r - 2, center.y - r - 2, (r + 2) * 2, (r + 2) * 2);

    // 舷窗玻璃:
    //   - transparent=YES (有头像 / 群聊汇入模式): fill = **半透明玻璃蓝**(alpha 0.28),
    //     保留玻璃色调但能透过去看到 body hole 内的 avatar / 汇入头像
    //     → 视觉效果: 最底 body(挖洞) → avatar 透过洞可见 → 半透蓝玻璃给 avatar 染上玻璃蓝
    //     → 真正的"玻璃后面的人"立体错觉
    //   - transparent=NO: fill = 不透明深蓝(普通舷窗观感)
    CAShapeLayer *glass = [CAShapeLayer layer];
    glass.path = [UIBezierPath bezierPathWithOvalInRect:
                  CGRectMake(2, 2, r * 2, r * 2)].CGPath;
    glass.fillColor = transparent
        ? [kWindowBlueColor() colorWithAlphaComponent:0.28].CGColor
        : kWindowBlueColor().CGColor;
    glass.strokeColor = kAccentPurpleColor().CGColor;
    glass.lineWidth = 2.5;
    [wrapper addSublayer:glass];

    if (!transparent) {
        // 不透明舷窗才加深蓝内圈
        CAShapeLayer *inner = [CAShapeLayer layer];
        inner.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(5, 5, (r - 1.5) * 2, (r - 1.5) * 2)].CGPath;
        inner.fillColor = kWindowDeepColor().CGColor;
        [wrapper addSublayer:inner];
    }
    // transparent=YES: **不绘制任何 fill/内圈/头像 layer** → 头像由 playInView 挂到 bodyContainer.layer
    // 最底层,穿过透明舷窗自然可见,不需要内置 avatar + handoff

    // 玻璃光泽扫过动画（蓄势阶段触发,模拟光线划过玻璃表面）
    //   idle 状态:**所有 colors 都 clear**,locations 不触发白色 → 舷窗纯透明,无一丝白色
    //   扫光动画:playInView 里触发时,会同时动画 colors(加白锚点) + locations(平移位置),
    //   才短暂显现"一道光闪过"的视觉
    CAShapeLayer *shimmerMask = [CAShapeLayer layer];
    shimmerMask.path = [UIBezierPath bezierPathWithOvalInRect:
                        CGRectMake(2, 2, r * 2, r * 2)].CGPath;

    CAGradientLayer *shimmer = [CAGradientLayer layer];
    shimmer.frame = wrapper.bounds;
    shimmer.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor clearColor].CGColor,     // 原为 white 0.85,改 clear → idle 无任何白色
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor clearColor].CGColor,
    ];
    shimmer.locations = @[@(-0.3), @(-0.2), @(-0.1), @(0.0), @(0.1)];
    shimmer.startPoint = CGPointMake(0.05, 0.05);
    shimmer.endPoint = CGPointMake(0.95, 0.95);
    shimmer.mask = shimmerMask;
    shimmer.name = @"window-shimmer";
    [wrapper addSublayer:shimmer];

    // ⚠️ 扫光动画不在这里挂 —— 本方法在 rocketView 还未加入 view 层级时调用，
    // 此时 layer 尚无本地时间坐标系，CACurrentMediaTime() + delay 会与 layer attach
    // 后的本地时间错位，导致 sweep1（短延迟）可能直接被跳过。
    // 真正的挂载在 playInView: 里 addSubview 之后用 dispatch_after 触发。

    // 左上角白色静态高光（玻璃反光） — 仅无头像时显示
    // 有头像时这个点会遮住头像左上角区域，且 shimmer 扫光已足够表现玻璃质感
    if (!avatarImage) {
        CAShapeLayer *shine = [CAShapeLayer layer];
        CGFloat sr = r * 0.30;
        shine.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(r * 0.30, r * 0.30, sr * 2, sr * 2)].CGPath;
        shine.fillColor = [[UIColor whiteColor] colorWithAlphaComponent:0.75].CGColor;
        [wrapper addSublayer:shine];
    }

    // 舷窗外圈 4 颗小螺丝（斜向位置 + 轻微随机偏移 → 自然不呆板）
    // 舷窗几何中心 = (r+2, r+2)（wrapper 坐标系），螺丝分布在 r+0.5 半径圆上
    CGFloat screwRadius = 1.1;
    CGFloat ringR = r + 0.5;
    CGFloat cx = r + 2.0;
    CGFloat cy = r + 2.0;
    // 四个斜方向 + 每个方向略微不对称偏移（打破完美对称）
    CGFloat angles[4] = {
        -3.0 * M_PI_4 + 0.08,   // 左上（略偏上）
        -M_PI_4 - 0.10,         // 右上（略偏右）
        3.0 * M_PI_4 - 0.06,    // 左下（略偏下）
        M_PI_4 + 0.12           // 右下（略偏下）
    };
    for (NSInteger i = 0; i < 4; i++) {
        CGFloat sx = cx + ringR * cos(angles[i]);
        CGFloat sy = cy + ringR * sin(angles[i]);
        CAShapeLayer *screw = [CAShapeLayer layer];
        screw.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(sx - screwRadius, sy - screwRadius,
                                 screwRadius * 2, screwRadius * 2)].CGPath;
        screw.fillColor = [kAccentPurpleColor() colorWithAlphaComponent:0.9].CGColor;
        screw.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7].CGColor;
        screw.lineWidth = 0.4;
        [wrapper addSublayer:screw];
    }

    return wrapper;
}

/// 兼容旧调用（无头像 → 普通舷窗外观）
+ (CALayer *)windowLayerAtCenter:(CGPoint)center radius:(CGFloat)r {
    return [self windowLayerAtCenter:center radius:r avatarImage:nil];
}

#pragma mark - 2718 品牌铭牌（金属质感，接缝下方）

#pragma mark - 机身铭牌（OCTO / 2718，无 shine，颜色参数化）

/// 通用铭牌渲染：**两层**（阴影 + 垂直渐变文字）。**去掉 shine 高光**，更干净自然。
///   - topColor / bottomColor：每个铭牌自己传，OCTO 和 2718 可以有不同色调
///   - fontSize：每个铭牌自己传，OCTO/2718 可以大小不同
///   - 同款阴影（下偏 0.8pt 的半透黑）保持一致的"机身刻字"深度感
+ (CALayer *)brandLabelAt:(CGPoint)center
                     text:(NSString *)text
                 fontSize:(CGFloat)fontSize
                 topColor:(UIColor *)topColor
              bottomColor:(UIColor *)bottomColor {
    UIFont *font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightHeavy];
    CGSize size = CGSizeMake(48, fontSize + 4);
    CGRect frame = CGRectMake(center.x - size.width / 2.0, center.y - size.height / 2.0,
                              size.width, size.height);

    CALayer *container = [CALayer layer];
    container.frame = frame;
    container.contentsScale = [UIScreen mainScreen].scale;

    NSNumber *kern = @(0.8);

    // --- 1. 底层阴影（半透黑，下偏 0.8pt 做深度） ---
    CATextLayer *shadow = [CATextLayer layer];
    shadow.contentsScale = [UIScreen mainScreen].scale;
    shadow.alignmentMode = kCAAlignmentCenter;
    shadow.font = (__bridge CFTypeRef)(font.fontName);
    shadow.fontSize = fontSize;
    UIColor *shadowColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.35];
    shadow.foregroundColor = shadowColor.CGColor;
    shadow.string = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: shadowColor,
        NSKernAttributeName: kern,
    }];
    shadow.frame = CGRectMake(0, 0.8, size.width, size.height);
    [container addSublayer:shadow];

    // --- 2. 主层：垂直渐变 + 文字 mask（topColor 到 bottomColor） ---
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 0, size.width, size.height);
    gradient.colors = @[ (id)topColor.CGColor, (id)bottomColor.CGColor ];
    gradient.locations = @[@(0.0), @(1.0)];
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);

    CATextLayer *maskText = [CATextLayer layer];
    maskText.contentsScale = [UIScreen mainScreen].scale;
    maskText.alignmentMode = kCAAlignmentCenter;
    maskText.font = (__bridge CFTypeRef)(font.fontName);
    maskText.fontSize = fontSize;
    maskText.foregroundColor = [UIColor whiteColor].CGColor;
    maskText.string = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSKernAttributeName: kern,
    }];
    maskText.frame = gradient.bounds;
    gradient.mask = maskText;
    [container addSublayer:gradient];

    // 不再加 shine 高光层 —— 机身已有多彩渐变，再加反光就显得过度装饰

    return container;
}

#pragma mark - 尾翼 (Fins)

/// 左右尾翼：月牙形（狼牙状）— 外沿大弧突出，内沿微凹贴合机身，上下端收尖。
/// 渐变填色 + 外沿白色高光弧 → 3D 月牙感，不是简笔画。
+ (CALayer *)finLayerLeft:(BOOL)isLeft bodyRect:(CGRect)bodyRect {
    CGFloat bodyBottom = bodyRect.origin.y + bodyRect.size.height;
    CGFloat finH = 32.0;                                // 尾翼总高度（上下端收尖距离）
    CGFloat finW = bodyRect.size.width * 0.48;          // 外沿外扩量
    CGFloat topYTuck = 8.0;                             // 顶端嵌入机身深度

    UIBezierPath *p = [UIBezierPath bezierPath];
    if (isLeft) {
        // 左翼月牙：顶端贴机身上 → 外弧下凸 → 底端贴机身下 → 内弧回上（微凹）
        CGFloat topX    = bodyRect.origin.x + 5.0;              // 顶端贴机身
        CGFloat topY    = bodyBottom - finH + topYTuck;
        CGFloat bottomX = bodyRect.origin.x + 2.0;              // 底端贴机身
        CGFloat bottomY = bodyBottom - 1.0;
        CGFloat outerTipX = bodyRect.origin.x - finW + 3.0;     // 翼尖最外侧
        CGFloat outerTipY = bodyBottom - 2.0;

        [p moveToPoint:CGPointMake(topX, topY)];
        // 外弧 1：顶端 → 翼尖（大弧，明显向外下凸）
        [p addQuadCurveToPoint:CGPointMake(outerTipX, outerTipY)
                  controlPoint:CGPointMake(topX - finW * 0.95, topY + finH * 0.35)];
        // 外弧 2：翼尖 → 底端（圆润收回到机身）
        [p addQuadCurveToPoint:CGPointMake(bottomX, bottomY)
                  controlPoint:CGPointMake(outerTipX + finW * 0.25, bottomY + 2.0)];
        // 内弧：底端 → 顶端（贴机身一侧，微凹向机身内）
        [p addQuadCurveToPoint:CGPointMake(topX, topY)
                  controlPoint:CGPointMake(topX + 3.0, (topY + bottomY) / 2.0 + 2.0)];
    } else {
        CGFloat topX    = bodyRect.origin.x + bodyRect.size.width - 5.0;
        CGFloat topY    = bodyBottom - finH + topYTuck;
        CGFloat bottomX = bodyRect.origin.x + bodyRect.size.width - 2.0;
        CGFloat bottomY = bodyBottom - 1.0;
        CGFloat outerTipX = bodyRect.origin.x + bodyRect.size.width + finW - 3.0;
        CGFloat outerTipY = bodyBottom - 2.0;

        [p moveToPoint:CGPointMake(topX, topY)];
        [p addQuadCurveToPoint:CGPointMake(outerTipX, outerTipY)
                  controlPoint:CGPointMake(topX + finW * 0.95, topY + finH * 0.35)];
        [p addQuadCurveToPoint:CGPointMake(bottomX, bottomY)
                  controlPoint:CGPointMake(outerTipX - finW * 0.25, bottomY + 2.0)];
        [p addQuadCurveToPoint:CGPointMake(topX, topY)
                  controlPoint:CGPointMake(topX - 3.0, (topY + bottomY) / 2.0 + 2.0)];
    }

    // 用渐变 mask 填色：顶端亮紫 → 底端深紫（月牙内侧明暗过渡，立体感）
    CGRect finBounds = CGPathGetBoundingBox(p.CGPath);
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = finBounds;
    gradient.colors = @[
        (id)kBodyPurpleColor().CGColor,    // 顶：紫粉（亮）
        (id)kAccentPurpleColor().CGColor,  // 中：深紫
        (id)kNoseRedDarkColor().CGColor,   // 底：暗红（火焰照亮）
    ];
    gradient.locations = @[@(0.0), @(0.55), @(1.0)];
    // 左翼亮面朝右上（机身方向），右翼亮面朝左上（镜像）
    gradient.startPoint = isLeft ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    gradient.endPoint   = isLeft ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);

    CAShapeLayer *mask = [CAShapeLayer layer];
    CGAffineTransform t = CGAffineTransformMakeTranslation(-finBounds.origin.x, -finBounds.origin.y);
    mask.path = CGPathCreateCopyByTransformingPath(p.CGPath, &t);
    gradient.mask = mask;

    // Wrapper 叠加所有装饰层
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, finBounds.origin.x + finBounds.size.width,
                               finBounds.origin.y + finBounds.size.height);
    [wrapper addSublayer:gradient];

    // 细节 1：外沿橙色勾边（卡通感 + 参照图片橙色描边）
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = p.CGPath;
    stroke.fillColor = [UIColor clearColor].CGColor;
    stroke.strokeColor = kOrangeAccentColor().CGColor;
    stroke.lineWidth = 1.1;
    stroke.lineJoin = kCALineJoinRound;
    [wrapper addSublayer:stroke];

    // 细节 2：沿外沿的高光弧（月牙顶部亮线 → 3D 弧面感）
    CAShapeLayer *highlight = [CAShapeLayer layer];
    UIBezierPath *hlPath = [UIBezierPath bezierPath];
    if (isLeft) {
        CGFloat hlTopX = bodyRect.origin.x + 3.0;
        CGFloat hlTopY = bodyBottom - finH + topYTuck + 2.0;
        CGFloat hlTipX = bodyRect.origin.x - finW * 0.85;
        CGFloat hlTipY = bodyBottom - 4.0;
        [hlPath moveToPoint:CGPointMake(hlTopX, hlTopY)];
        [hlPath addQuadCurveToPoint:CGPointMake(hlTipX, hlTipY)
                       controlPoint:CGPointMake(hlTopX - finW * 0.8, hlTopY + finH * 0.25)];
    } else {
        CGFloat hlTopX = bodyRect.origin.x + bodyRect.size.width - 3.0;
        CGFloat hlTopY = bodyBottom - finH + topYTuck + 2.0;
        CGFloat hlTipX = bodyRect.origin.x + bodyRect.size.width + finW * 0.85;
        CGFloat hlTipY = bodyBottom - 4.0;
        [hlPath moveToPoint:CGPointMake(hlTopX, hlTopY)];
        [hlPath addQuadCurveToPoint:CGPointMake(hlTipX, hlTipY)
                       controlPoint:CGPointMake(hlTopX + finW * 0.8, hlTopY + finH * 0.25)];
    }
    highlight.path = hlPath.CGPath;
    highlight.fillColor = [UIColor clearColor].CGColor;
    highlight.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor;
    highlight.lineWidth = 1.2;
    highlight.lineCap = kCALineCapRound;
    [wrapper addSublayer:highlight];

    // 用 CAShapeLayer 包装返回（兼容原签名）
    CAShapeLayer *holder = [CAShapeLayer layer];
    [holder addSublayer:wrapper];
    return holder;
}

/// 中尾翼：机身底部中央的小三角形稳定翼（呼应图片里的第三个尾翼）
+ (CAShapeLayer *)centerFinLayerInBodyRect:(CGRect)bodyRect nozzleRect:(CGRect)nozzleRect {
    CGFloat bodyBottom = bodyRect.origin.y + bodyRect.size.height;
    CGFloat centerX = bodyRect.origin.x + bodyRect.size.width / 2.0;
    CGFloat finWidth = bodyRect.size.width * 0.28;   // 比左右翼窄
    CGFloat finHeight = 20.0;                         // 向下延伸（延伸到喷口范围）
    CGFloat topY = bodyBottom - 8.0;                  // 顶部略嵌入机身内
    CGFloat tipY = nozzleRect.origin.y + nozzleRect.size.height - 2.0; // 尖端到喷口底部

    UIBezierPath *p = [UIBezierPath bezierPath];
    // 倒三角：机身底部两侧 → 尖端向下
    [p moveToPoint:CGPointMake(centerX - finWidth / 2.0, topY)];
    [p addQuadCurveToPoint:CGPointMake(centerX, tipY)
              controlPoint:CGPointMake(centerX - finWidth * 0.25, topY + finHeight * 0.6)];
    [p addQuadCurveToPoint:CGPointMake(centerX + finWidth / 2.0, topY)
              controlPoint:CGPointMake(centerX + finWidth * 0.25, topY + finHeight * 0.6)];
    // 顶缘圆润（贴机身底部弧度）
    [p addQuadCurveToPoint:CGPointMake(centerX - finWidth / 2.0, topY)
              controlPoint:CGPointMake(centerX, topY - 1.0)];
    [p closePath];

    // 用 gradient mask 做青→紫的垂直渐变（呼应图里的中翼颜色）
    CAGradientLayer *gradient = [CAGradientLayer layer];
    CGRect finBounds = CGPathGetBoundingBox(p.CGPath);
    gradient.frame = finBounds;
    gradient.colors = @[
        (id)kAccentCyanColor().CGColor,   // 顶：青
        (id)kAccentPurpleColor().CGColor, // 底：紫
    ];
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);

    CAShapeLayer *mask = [CAShapeLayer layer];
    CGAffineTransform t = CGAffineTransformMakeTranslation(-finBounds.origin.x, -finBounds.origin.y);
    mask.path = CGPathCreateCopyByTransformingPath(p.CGPath, &t);
    gradient.mask = mask;

    // 外层 wrapper：在 gradient 之上加橙色描边（卡通勾边）
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, finBounds.origin.x + finBounds.size.width,
                               finBounds.origin.y + finBounds.size.height);
    [wrapper addSublayer:gradient];

    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = p.CGPath;
    stroke.fillColor = [UIColor clearColor].CGColor;
    stroke.strokeColor = kOrangeAccentColor().CGColor;
    stroke.lineWidth = 1.0;
    stroke.lineJoin = kCALineJoinRound;
    [wrapper addSublayer:stroke];

    // 包一层 CAShapeLayer 便于统一返回（虽然内容是 wrapper 的 sublayer）
    CAShapeLayer *holder = [CAShapeLayer layer];
    [holder addSublayer:wrapper];
    return holder;
}

#pragma mark - 喷口 (Nozzle)

+ (CAShapeLayer *)nozzleLayerInRect:(CGRect)rect {
    CGFloat W = rect.size.width;
    CGFloat H = rect.size.height;
    CGFloat topInset    = W * (1 - 0.55) / 2.0;
    CGFloat bottomInset = W * (1 - 0.70) / 2.0;

    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(rect.origin.x + topInset, rect.origin.y)];
    [p addLineToPoint:CGPointMake(rect.origin.x + W - topInset, rect.origin.y)];
    [p addLineToPoint:CGPointMake(rect.origin.x + W - bottomInset, rect.origin.y + H)];
    [p addLineToPoint:CGPointMake(rect.origin.x + bottomInset, rect.origin.y + H)];
    [p closePath];

    CAShapeLayer *nozzle = [CAShapeLayer layer];
    nozzle.path = p.CGPath;
    nozzle.fillColor = kNozzleColor().CGColor;
    nozzle.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.35].CGColor;
    nozzle.lineWidth = 0.6;

    // 细节 1：顶部接缝线（喷口和机身的金属接合处）
    CAShapeLayer *topSeam = [CAShapeLayer layer];
    UIBezierPath *tsPath = [UIBezierPath bezierPath];
    [tsPath moveToPoint:CGPointMake(rect.origin.x + topInset + 1, rect.origin.y + 0.8)];
    [tsPath addLineToPoint:CGPointMake(rect.origin.x + W - topInset - 1, rect.origin.y + 0.8)];
    topSeam.path = tsPath.CGPath;
    topSeam.strokeColor = [[UIColor blackColor] colorWithAlphaComponent:0.5].CGColor;
    topSeam.lineWidth = 1.0;
    [nozzle addSublayer:topSeam];

    // 细节 2：喷口内暗环（模拟喷口内部烧黑）— 底部接近尾焰处的深色带
    CAShapeLayer *innerDark = [CAShapeLayer layer];
    UIBezierPath *idPath = [UIBezierPath bezierPath];
    [idPath moveToPoint:CGPointMake(rect.origin.x + bottomInset + 1, rect.origin.y + H - 1)];
    [idPath addLineToPoint:CGPointMake(rect.origin.x + W - bottomInset - 1, rect.origin.y + H - 1)];
    innerDark.path = idPath.CGPath;
    innerDark.strokeColor = [[UIColor blackColor] colorWithAlphaComponent:0.55].CGColor;
    innerDark.lineWidth = 1.4;
    [nozzle addSublayer:innerDark];

    return nozzle;
}

#pragma mark - 水滴形火焰（实体 CAShapeLayer，始终垂直向下）

/// 细长水滴形：尖端朝下，橙→黄→白热三层色。anchorPoint 在顶部中心
/// → scale.y 拉伸时从喷口向下延伸（上端不动，下端变长/短）。
+ (CALayer *)coreFlameLayer {
    CGFloat W = kRocketWidth * 0.36;   // 基础宽度（阶段过渡用 scale.x 调整）
    CGFloat H = kRocketWidth * 1.10;   // 基础长度（阶段过渡用 scale.y 调整）

    // 外层：橙色水滴
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0, 0)];
    [path addQuadCurveToPoint:CGPointMake(W * 0.5, H)
                 controlPoint:CGPointMake(W * 0.08, H * 0.6)];
    [path addQuadCurveToPoint:CGPointMake(W, 0)
                 controlPoint:CGPointMake(W * 0.92, H * 0.6)];
    [path closePath];

    CAShapeLayer *shape = [CAShapeLayer layer];
    shape.path = path.CGPath;
    shape.fillColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.15 alpha:1.0].CGColor;  // 外层橙
    shape.bounds = CGRectMake(0, 0, W, H);
    shape.anchorPoint = CGPointMake(0.5, 0.0); // 顶部中点 = 锚点

    // 中层：黄色内焰
    CGFloat innerW = W * 0.55;
    CGFloat innerH = H * 0.80;
    UIBezierPath *innerPath = [UIBezierPath bezierPath];
    CGFloat ox = (W - innerW) / 2.0;
    CGFloat oy = H * 0.04;
    [innerPath moveToPoint:CGPointMake(ox, oy)];
    [innerPath addQuadCurveToPoint:CGPointMake(ox + innerW / 2.0, oy + innerH)
                      controlPoint:CGPointMake(ox + innerW * 0.08, oy + innerH * 0.6)];
    [innerPath addQuadCurveToPoint:CGPointMake(ox + innerW, oy)
                      controlPoint:CGPointMake(ox + innerW * 0.92, oy + innerH * 0.6)];
    [innerPath closePath];

    CAShapeLayer *inner = [CAShapeLayer layer];
    inner.path = innerPath.CGPath;
    inner.fillColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.25 alpha:0.98].CGColor;  // 黄
    [shape addSublayer:inner];

    // 最内：白热高光
    CGFloat hotW = innerW * 0.55;
    CGFloat hotH = innerH * 0.45;
    CAShapeLayer *hot = [CAShapeLayer layer];
    hot.path = [UIBezierPath bezierPathWithRoundedRect:
                CGRectMake((W - hotW) / 2.0, H * 0.05, hotW, hotH)
                cornerRadius:hotW * 0.5].CGPath;
    hot.fillColor = [[UIColor colorWithWhite:1.0 alpha:0.85] CGColor];
    [shape addSublayer:hot];

    // 外光晕：紫蓝色 halo（呼应图片里火焰外的蓝紫拖尾）
    shape.shadowColor = [UIColor colorWithRed:0.55 green:0.45 blue:1.0 alpha:1.0].CGColor;
    shape.shadowOffset = CGSizeMake(0, 3);
    shape.shadowRadius = 9.0;
    shape.shadowOpacity = 0.85;

    return shape;
}

/// Y 方向 flicker 跳动（火焰闪烁）。values 围绕 base 波动 → 可动态调整基础长度。
+ (void)startFlickerOnLayer:(CALayer *)layer baseScale:(CGFloat)base {
    CAKeyframeAnimation *flicker = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale.y"];
    flicker.values = @[@(base * 1.0), @(base * 1.15), @(base * 0.92), @(base * 1.10), @(base * 0.96), @(base * 1.07), @(base * 1.0)];
    flicker.keyTimes = @[@0.0, @0.18, @0.32, @0.52, @0.68, @0.84, @1.0];
    flicker.duration = 0.22;
    flicker.repeatCount = HUGE_VALF;
    [layer addAnimation:flicker forKey:@"flame-flicker"];
}

/// X 方向宽度过渡（阶段切换时平滑改变横向宽度 — 不与 flicker.scale.y 冲突）。
+ (void)setCoreFlameScaleX:(CALayer *)layer toValue:(CGFloat)value duration:(NSTimeInterval)duration {
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.scale.x"];
    anim.fromValue = [layer.presentationLayer valueForKeyPath:@"transform.scale.x"] ?: @(1.0);
    anim.toValue = @(value);
    anim.duration = duration;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.fillMode = kCAFillModeForwards;
    anim.removedOnCompletion = NO;
    [layer addAnimation:anim forKey:@"flame-scale-x"];
}

#pragma mark - 拖尾星星纹理

+ (UIImage *)starParticleImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 22;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        // 四角星形：两条对角线 + 十字
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.95 blue:0.6 alpha:1.0].CGColor);
        CGContextSetLineWidth(ctx, 2.0);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGFloat c = size / 2.0;
        CGFloat r = size / 2.0 - 1.0;
        CGContextMoveToPoint(ctx, c - r, c);
        CGContextAddLineToPoint(ctx, c + r, c);
        CGContextMoveToPoint(ctx, c, c - r);
        CGContextAddLineToPoint(ctx, c, c + r);
        CGContextStrokePath(ctx);
        // 中心亮点
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(c - 2, c - 2, 4, 4));

        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

#pragma mark - 工具动画

+ (void)applyEngineShakeToView:(UIView *)view duration:(NSTimeInterval)duration {
    // 频率固定 8Hz（每个周期 0.125s 内跑完 7 个关键帧），repeatCount 按 duration 缩放。
    // → 不管 duration 是 0.75s 还是 2.75s，看起来都是"持续快速抖动"，不会变成慢摇晃。
    NSTimeInterval cycle = 0.125;
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[@(-2), @(2), @(-1.5), @(1.5), @(-1), @(1), @(0)];
    shake.duration = cycle;
    shake.repeatCount = MAX(1, (float)(duration / cycle));
    shake.additive = YES;
    [view.layer addAnimation:shake forKey:@"engine-shake"];
}

#pragma mark - 尾迹烟雾

/// 柔边白色烟团纹理（径向渐变）—— 小尺寸版本，专门给尾迹 emitter 用。
+ (UIImage *)trailPuffParticleImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 64;
        UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
        fmt.opaque = NO;
        UIGraphicsImageRenderer *renderer =
            [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:fmt];
        img = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            CGContextRef cg = ctx.CGContext;
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            NSArray *colors = @[
                (id)[UIColor colorWithWhite:1.0 alpha:0.82].CGColor,
                (id)[UIColor colorWithWhite:1.0 alpha:0.45].CGColor,
                (id)[UIColor colorWithWhite:1.0 alpha:0.10].CGColor,
                (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            ];
            CGFloat locs[] = {0.0, 0.35, 0.72, 1.0};
            CGGradientRef g = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)colors, locs);
            CGContextDrawRadialGradient(cg, g,
                                        CGPointMake(size/2.0, size/2.0), 0,
                                        CGPointMake(size/2.0, size/2.0), size/2.0, 0);
            CGGradientRelease(g);
            CGColorSpaceRelease(cs);
        }];
    });
    return img;
}

/// 构造尾迹 emitter layer：**两支粒子**叠加 → 浓密可见的升空尾迹。
///   - coreWake（定向向下 + 快）：细长的"喷出物"，直接接在喷口下方形成一条烟柱
///   - haloPuff（全向慢）：大而柔和的包裹雾，飘散形成"烟气环绕"的体积感
/// 两支粒子 birthRate 初始 0，发射瞬间由外部打开。
+ (CAEmitterLayer *)buildRocketTrailEmitterWithHostBounds:(CGRect)hostBounds {
    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.frame = hostBounds;
    emitter.emitterShape = kCAEmitterLayerPoint;
    emitter.emitterMode = kCAEmitterLayerPoints;
    emitter.renderMode = kCAEmitterLayerBackToFront;
    emitter.emitterSize = CGSizeZero;

    // —— 核心尾迹（定向喷射） —— 构成直接在火箭后方的一条"白烟柱"
    CAEmitterCell *core = [CAEmitterCell emitterCell];
    core.name = @"core";
    core.contents = (id)[self trailPuffParticleImage].CGImage;
    core.birthRate = 100;               // ← 预设目标值，由 emitter.birthRate 层级 gate 控制开关
    core.lifetime = 1.5;
    core.lifetimeRange = 0.4;
    core.scale = 0.38;
    core.scaleRange = 0.10;
    core.scaleSpeed = 0.45;
    core.alphaRange = 0.08;
    core.alphaSpeed = -0.55;
    core.velocity = 22;
    core.velocityRange = 8;
    core.emissionLongitude = M_PI_2;
    core.emissionRange = M_PI / 6.0;
    core.yAcceleration = 14;
    core.color = [UIColor colorWithRed:0.88 green:0.88 blue:0.90 alpha:0.68].CGColor;

    // —— 环绕雾（全向慢） —— 给体积感
    CAEmitterCell *halo = [CAEmitterCell emitterCell];
    halo.name = @"halo";
    halo.contents = (id)[self trailPuffParticleImage].CGImage;
    halo.birthRate = 55;                // ← 预设目标值
    halo.lifetime = 1.0;
    halo.lifetimeRange = 0.3;
    halo.scale = 0.60;
    halo.scaleRange = 0.20;
    halo.scaleSpeed = 0.65;
    halo.alphaRange = 0.08;
    halo.alphaSpeed = -0.85;
    halo.velocity = 10;
    halo.velocityRange = 6;
    halo.emissionLongitude = 0;
    halo.emissionRange = (CGFloat)M_PI * 2.0;
    halo.yAcceleration = 4;
    halo.color = [UIColor colorWithRed:0.88 green:0.88 blue:0.90 alpha:0.42].CGColor;

    emitter.emitterCells = @[halo, core];
    emitter.birthRate = 0.0;            // ← layer-level gate，由 launch block 打开
    return emitter;
}

/// 构造"机身包裹雾"emitter：**Point 形状 + Points 模式**（已证能发射，和 trail 同套路），
/// 从火箭机身中心向四周放射状散发粒子。
///
/// 设计要点：
///   - 单个 Point emitter 从一点向全向（2π）散射，粒子自然分布在机身周围
///   - 在 playInView 里建 **两份**：一份挂 rocketView 前（bodyWrapView 上），
///     另一份挂 rocketView 后（effectView 直接 sublayer）→ 真正的前后包裹
///   - 不再用 Rectangle shape —— Apple 的 CAEmitterLayer 对 Rectangle + Volume/Surface
///     组合实测一颗粒子都不发，放弃。
/// 构造"机身包裹雾"emitter。
///   @param light YES: 前层(模拟冷凝水汽顺机身滑落) —— 小颗粒、向下流动 + 重力加速
///                    位置应设置在机身下部(2718 下方),粒子向下扩散,不覆盖上方文字
///                NO : 后层(被机身挡住的背景雾) —— 全向环绕,保持体积感
+ (CAEmitterLayer *)buildBodyWrapEmitterWithHostBounds:(CGRect)hostBounds light:(BOOL)light {
    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.frame = hostBounds;
    emitter.emitterShape = kCAEmitterLayerPoint;
    emitter.emitterMode = kCAEmitterLayerPoints;
    emitter.renderMode = kCAEmitterLayerBackToFront;
    emitter.emitterSize = CGSizeZero;

    CAEmitterCell *cell = [CAEmitterCell emitterCell];
    cell.contents = (id)[self trailPuffParticleImage].CGImage;
    cell.birthRate = light ? 12 : 80;             // 前层 7→12,粒子稍多
    cell.lifetime = light ? 1.4 : 1.0;
    cell.lifetimeRange = 0.3;
    cell.scale = light ? 0.10 : 0.75;             // 前层 0.06→0.10,粒子 ~6.4pt(稍大,看得清)
    cell.scaleRange = 0.03;
    cell.scaleSpeed = light ? 0.05 : 0.40;        // 稍膨胀,末期 ~10pt
    cell.alphaRange = 0.08;
    cell.alphaSpeed = light ? -0.40 : -0.85;      // 前层慢淡出(1s 内可见)，下落全程都能看到
    cell.velocity = light ? 30 : 20;              // **前层速度 30 pt/s**，足够"飞过"视野而不堆积
    cell.velocityRange = light ? 10 : 12;
    if (light) {
        // 流下来：向下窄锥 ±30°，**重力加速 22** → 越往下越快，像真实水滴
        cell.emissionLongitude = M_PI_2;
        cell.emissionRange = (CGFloat)(M_PI / 3.0);   // 60° 窄锥，清晰"下落带"而不是圆团
        cell.yAcceleration = 22;
    } else {
        cell.emissionLongitude = 0;
        cell.emissionRange = (CGFloat)M_PI * 2.0;
        cell.yAcceleration = 0;
    }
    cell.spin = 0.2;
    cell.spinRange = 0.8;
    // **前层 alpha 0.50** → 半透明,能看到机身轮廓但粒子明显可见
    CGFloat alpha = light ? 0.50 : 0.72;
    cell.color = [UIColor colorWithRed:0.96 green:0.96 blue:0.97 alpha:alpha].CGColor;

    emitter.emitterCells = @[cell];
    emitter.birthRate = 0.0;
    return emitter;
}

/// 构造**尾部蒸汽 emitter**：prep 阶段在喷口前方轻轻飘的水蒸气细节。
///   - Point shape 向上扇形喷射(±30°)，粒子从喷口位置慢慢向上飘
///   - 短寿命 0.7s → launch 时关闭 birthRate 后，老粒子 0.7s 内淡完
///   - 正好和 blast 大烟喷薄接力 → 视觉上像"被火焰吹散"
///   - z 层放到 rocketView 之上(挂在独立 UIView 里用 addSubview)，粒子"在前面"
+ (CAEmitterLayer *)buildTailVaporEmitterWithHostBounds:(CGRect)hostBounds {
    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.frame = hostBounds;
    emitter.emitterShape = kCAEmitterLayerPoint;
    emitter.emitterMode = kCAEmitterLayerPoints;
    emitter.renderMode = kCAEmitterLayerBackToFront;
    emitter.emitterSize = CGSizeZero;
    emitter.birthRate = 1.0;

    CAEmitterCell *cell = [CAEmitterCell emitterCell];
    cell.name = @"tailVapor";
    cell.contents = (id)[self trailPuffParticleImage].CGImage;
    cell.birthRate = 12;                // **大幅减少:70→12** 同时活 8~10 颗,不再堆成球
    cell.lifetime = 0.7;
    cell.lifetimeRange = 0.2;
    cell.scale = 0.10;                  // **粒子 6.4pt**(原 32pt,砍掉 80%),喷口附近小水珠
    cell.scaleRange = 0.03;
    cell.scaleSpeed = 0.15;             // 末期膨胀到 ~10pt
    cell.alphaRange = 0.08;
    cell.alphaSpeed = -0.95;
    cell.velocity = 10;
    cell.velocityRange = 5;
    cell.emissionLongitude = -M_PI_2;
    cell.emissionRange = M_PI / 3.0;
    cell.yAcceleration = -3;
    cell.spin = 0.2;
    cell.spinRange = 0.8;
    cell.color = [UIColor colorWithRed:0.96 green:0.96 blue:0.97 alpha:0.45].CGColor; // 0.82→0.45 半透

    emitter.emitterCells = @[cell];
    emitter.birthRate = 0.0;            // ← **layer-level gate** 初始关闭，最可靠的开关方式
    return emitter;
}



#pragma mark - 拖尾星星粒子

+ (void)scatterSparkleStarsAlongPathFrom:(CGPoint)start to:(CGPoint)midEnd inView:(UIView *)host {
    // 沿升空方向向上平均分布 4 颗星星（从 midEnd 开始继续向上）
    UIImage *starImg = [self starParticleImage];
    CGFloat pathLength = 140.0;
    NSInteger count = 4;

    for (NSInteger i = 0; i < count; i++) {
        CGFloat t = (CGFloat)(i + 1) / (CGFloat)count;
        CGFloat x = midEnd.x + ((CGFloat)arc4random_uniform(40) - 20);
        CGFloat y = midEnd.y - pathLength * t;

        UIImageView *star = [[UIImageView alloc] initWithImage:starImg];
        star.center = CGPointMake(x, y);
        star.alpha = 0;
        star.transform = CGAffineTransformMakeScale(0.3, 0.3);
        [host addSubview:star];

        NSTimeInterval delay = i * 0.08;
        [UIView animateWithDuration:0.2 delay:delay options:UIViewAnimationOptionCurveEaseOut animations:^{
            star.alpha = 1.0;
            star.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.4 delay:0.1 options:UIViewAnimationOptionCurveEaseIn animations:^{
                star.alpha = 0;
                star.transform = CGAffineTransformMakeScale(0.1, 0.1);
            } completion:^(BOOL f) {
                [star removeFromSuperview];
            }];
        }];
    }
}

#pragma mark - Helpers

+ (nullable CALayer *)findLayerWithName:(NSString *)name inLayer:(CALayer *)root {
    if (!name || !root) return nil;
    if ([root.name isEqualToString:name]) return root;
    for (CALayer *sub in root.sublayers) {
        CALayer *found = [self findLayerWithName:name inLayer:sub];
        if (found) return found;
    }
    return nil;
}

@end

# SpaceGate 工作空间引导功能实现说明

## 修改概述

实现了新用户注册/登录后的工作空间引导功能，强制要求用户加入团队或创建新的工作空间。

## 一、添加flag参数（iOS传2）

### 修改文件：
1. **WKLoginVM.m**
   - `login:password:` - 用户名登录添加 flag:@(2)
   - `emailLogin:password:` - 邮箱登录添加 flag:@(2)

2. **WKRegisterVM.m**
   - `registerByPhone:phone:code:inviteCode:password:` - 手机注册添加 flag:@(2)
   - `emailRegister:code:name:password:inviteCode:` - 邮箱注册添加 flag:@(2)

### flag参数说明：
- 0: app（移动端旧版）
- 1: pc/web（Web端和PC客户端）
- 2: Android（安卓移动端）
- 3: iOS（iOS移动端）

## 二、创建Space相关ViewModel

### 新增文件：
**WKSpaceGateVM.h/m** - Space工作空间管理ViewModel

### 主要功能：
1. `getMySpaces` - 获取用户的工作空间列表
2. `createSpace:description:` - 创建新工作空间
3. `joinSpace:` - 通过邀请码加入工作空间
4. `createInvite:` - 创建邀请码

### API接口：
- GET `space/my` - 获取我的空间列表
- POST `space/create` - 创建空间（参数：name, description）
- POST `space/join` - 加入空间（参数：invite_code）
- POST `space/{space_id}/invite` - 创建邀请码

## 三、创建SpaceGate引导页面

### 新增文件：
**WKSpaceGateVC.h/m** - 工作空间引导页面ViewController

### 页面功能：
1. **自动检查空间**
   - 检查缓存的currentSpaceId
   - 检查服务器上是否有工作空间
   - 有空间：自动进入主应用
   - 无空间：显示引导页

2. **加入团队功能**
   - 点击"输入邀请码加入团队"按钮
   - 显示邀请码输入框
   - 输入邀请码后调用API加入空间
   - 成功后重新检查空间并进入主应用

3. **创建新团队功能**
   - 点击"创建新团队"按钮
   - 弹出Alert对话框输入：
     - Space名称（必填）
     - Space描述（可选）
   - 调用API创建空间
   - 成功后重新检查空间并进入主应用

### UI设计：
- 紫色渐变背景（#667eea → #764ba2）
- 白色卡片容器（圆角16px，阴影效果）
- 欢迎emoji：👋
- 标题："欢迎使用 DMWork！"
- 副标题："加入团队或创建新的工作空间"
- 两个主按钮：
  - "📩 输入邀请码加入团队"（主题色）
  - "✨ 创建新团队"（次要样式）

## 四、修改注册流程

### 修改文件：
**WKRegisterVC.m**

### 修改内容：
```objc
// 新用户注册成功后，强制显示SpaceGate引导页面
[self.viewModel emailRegister:account code:@"" name:nickname password:password inviteCode:inviteCode].then(^(WKLoginResp*resp){
    [weakSelf.view hideHud];
    // 保存登录信息
    [WKLoginVM handleLoginData:resp isSave:YES];

    // 显示SpaceGate引导页面
    WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
    [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
})
```

## 五、修改登录流程

### 修改文件：
**WKLoginVC.m**

### 新增方法：
`checkSpaceBeforeEnter` - 登录成功后检查空间

### 检查逻辑：
1. 检查本地缓存的currentSpaceId
   - 有缓存：直接进入主应用
   - 无缓存：继续下一步

2. 调用API获取用户的工作空间列表
   - 有空间：保存第一个空间ID到缓存，进入主应用
   - 无空间：显示SpaceGate引导页面
   - 出错：显示SpaceGate引导页面

## 六、用户流程

### 新用户注册流程：
1. 用户填写注册信息
2. 注册成功
3. **自动跳转到SpaceGate引导页**
4. 用户选择：
   - 输入邀请码加入团队，或
   - 创建新的工作空间
5. 完成后进入主应用

### 已有用户登录流程：
1. 用户输入账号密码
2. 登录成功
3. **检查是否有工作空间**
   - 有：直接进入主应用
   - 无：跳转到SpaceGate引导页
4. （如无空间）选择加入或创建
5. 完成后进入主应用

## 七、数据存储

### NSUserDefaults缓存：
- Key: `currentSpaceId`
- Value: 当前选中的工作空间ID
- 用途：避免每次登录都调用API检查空间

## 八、参考实现

参考了Web端的SpaceGate实现：
- `/Users/wanglitao/Documents/dmwork-web/apps/web/src/Components/SpaceGate/index.tsx`
- `/Users/wanglitao/Documents/dmwork-web/packages/dmworkbase/src/Service/SpaceService.tsx`

## 九、测试建议

1. **新用户注册测试**
   - 注册成功后是否显示SpaceGate页面
   - 加入团队功能是否正常
   - 创建新团队功能是否正常

2. **已有用户登录测试**
   - 有空间的用户登录是否直接进入
   - 无空间的用户登录是否显示SpaceGate页面

3. **异常情况测试**
   - 网络错误时的处理
   - 邀请码无效时的提示
   - 空间已满时的提示

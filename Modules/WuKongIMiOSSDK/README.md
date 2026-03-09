# WuKongIMiOSSDK

## 说明

本项目是[悟空IM](https://github.com/WuKongIM/WuKongIM)端的iOS SDK。

## 运行

进入到项目Example目录内，执行 `pod install`，然后打开 `Example/WuKongIMSDK.xcworkspace` 运行即可。



## 效果

![](./docs/screen11.png)
![](./docs/screen22.png)
![](./docs/screen33.png)


## 编译SDK


构建模拟器文件

xcodebuild BITCODE_GENERATION_MODE=bitcode OTHER_CFLAGS="-fembed-bitcode" -project '_Pods.xcodeproj' -target 'WuKongIMSDK' -sdk iphonesimulator


// 生成真机文件

xcodebuild BITCODE_GENERATION_MODE=bitcode OTHER_CFLAGS="-fembed-bitcode" -project '_Pods.xcodeproj' -target 'WuKongIMSDK' -sdk iphoneos

// 合并模拟器和真机

lipo -create ./Example/build/Release-iphonesimulator/WuKongIMSDK/WuKongIMSDK.framework/WuKongIMSDK  ./Example/build/Release-iphoneos/WuKongIMSDK/WuKongIMSDK.framework/WuKongIMSDK  -output WuKongIMSDKLib
# WuKongIMiOSSDK


xcodebuild BITCODE_GENERATION_MODE=bitcode OTHER_CFLAGS="-fembed-bitcode" -project '_Pods.xcodeproj' -target 'WuKongIMSDK' -sdk iphonesimulator


xcodebuild BITCODE_GENERATION_MODE=bitcode OTHER_CFLAGS="-fembed-bitcode" -project '_Pods.xcodeproj' -target 'WuKongIMSDK' -sdk iphoneos

lipo -create ./Example/build/Release-iphonesimulator/WuKongIMSDK/WuKongIMSDK.framework/WuKongIMSDK  ./Example/build/Release-iphoneos/WuKongIMSDK/WuKongIMSDK.framework/WuKongIMSDK  -output WuKongIMSDKLib
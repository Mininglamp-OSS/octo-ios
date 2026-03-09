//
//  WKMediaMessageContentProto.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/13.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
NS_ASSUME_NONNULL_BEGIN

@protocol WKMediaProto <NSObject>

/**
 消息
 */
@property (nonatomic, weak) WKMessage *message; //TODO: 这里要注意不能声明为strong 如果声明为strong message和media互相引用 就释放不掉了导致内存爆炸。

/**
 媒体内容的本地路径（当remoteUrl为空时此属性必须有值）
 */
@property (nonatomic, copy) NSString *localPath;

/**
 媒体内容上传服务器后的网络地址（上传成功后SDK会为该属性赋值）
 */
@property (nonatomic, copy) NSString *remoteUrl;


/**
 源文件扩展
 */
@property(nullable,nonatomic,copy) NSString *extension;

/**
 副本路径
 */
@property(nullable,nonatomic,copy) NSString *thumbPath;


/**
 副本的扩展名
 */
@property(nullable,nonatomic,copy) NSString *thumbExtension;

/**
 保存数据到本地路径
 多媒体上传前会调用此方法，请在此方法里将NSData数据保存到localPath对应的位置。
 如果继承WKMediaMessageContent必须调用 [super writeDataToLocalPath]
 */
-(void) writeDataToLocalPath;


// 从本地扩展数据里获取值
-(nullable id) getExtra:(NSString*)key;

// 设置值到本地扩展字段内
-(void) setExtra:(id)value key:(NSString*)key;

@end

NS_ASSUME_NONNULL_END

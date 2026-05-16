//
//  WKConst.h
//  Pods
//
//  Created by tt on 2019/11/25.
//



// 正文类型
typedef enum : NSUInteger {
    WK_TEXT = 1, // 文本消息
    WK_IMAGE = 2, // 图片消息
    WK_GIF = 3, // gif表情
    WK_VOICE = 4, // 语音消息
    
    WK_SIGNAL_ERROR = 98, // signal解密失败
    WK_CMD = 99, // 命令消息
    WK_UNKNOWN = 0, // 未知消息
} WKContentType;



// 消息状态
typedef enum : NSUInteger {
    WK_MESSAGE_WAITSEND, // 等待发送
    WK_MESSAGE_SUCCESS, // 发送成功
    WK_MESSAGE_ONLYSAVE, // 仅仅保存消息（不做重发处理）
    WK_MESSAGE_UPLOADING, // 上传中
    WK_MESSAGE_FAIL, // 发送失败
} WKMessageStatus;


typedef enum : uint8_t {
    NONE,
    WK_CONNECT = 1, // 客户端请求连接到服务器(c2s)
    WK_CONNACK =2, //  服务端收到连接请求后确认的报文(s2c)
    WK_SEND = 3, // 发送消息(c2s)
    WK_SENDACK = 4,  // 收到消息确认的报文(s2c)
    WK_RECV = 5,   //收取消息(s2c)
    WK_RECVACK = 6, // 收取消息确认(c2s)
    WK_PING = 7, //ping请求
    WK_PONG = 8, // 对ping请求的相应
    WK_DISCONNECT = 9 // 断开连接
} WKPacketType;


typedef enum : uint8_t {
    WK_REASON_UNKNOWN = 0, // 未知
    WK_REASON_SUCCESS = 1, // 认证成功
    WK_REASON_AUTHFAIL = 2, // 认证失败（一般是token不正确）
    WK_REASON_IN_BLACKLIST = 4, // 在黑名单内
    WK_REASON_KICK = 12, // 被踢
    WK_REASON_NOT_IN_WHITELIST = 13, // 没在好友白明单内（说明不是好友）
    
} WKReason;

// 频道类型
typedef enum : uint8_t {
    WK_PERSON = 1, // 个人
    WK_GROUP = 2, // 群组
    WK_COMMUNITY = 4, // 社区
    WK_COMMUNITY_TOPIC = 5, // 社区话题
    WK_COMMUNITY_INFO = 6, // 信息频道
} WKChannelType;

// 协议类型
typedef enum : NSUInteger {
    WK_PROTO_WK,
} WKProto;


// 设备类型
typedef enum : NSInteger {
    WKDeviceFlagEnumUnknown = -1, // 未知
    WKDeviceFlagEnumAPP = 0, // APP
    WKDeviceFlagEnumWeb = 1, // Web
    WKDeviceFlagEnumPC = 2 // PC
} WKDeviceFlagEnum;


typedef enum : NSUInteger {
    WKPullModeDown,
    WKPullModeUp,
} WKPullMode;


// cmd sign签名错误
#define WKCMDSignError @"cmdSignError"

// 排序序号因子
#define WKOrderSeqFactor 1000

// 默认协议版本
#define WKDefaultProtoVersion 0x4;

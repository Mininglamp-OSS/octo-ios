// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMOSContentConvertManager.m
//  WuKongIMSDK
//
//  Created by tt on 2020/6/5.
//

#import "WKMOSContentConvertManager.h"
#import "WKConst.h"
#import <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#import "WKSDK.h"
@implementation WKMOSContentConvertManager

static WKMOSContentConvertManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKMOSContentConvertManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(NSDictionary*) convertContentToMOS:(NSDictionary *)contentDic message:(WKMessage*)message{
    if(!contentDic[@"type"]) {
        return contentDic;
    }
     NSMutableDictionary *newContentDic = [NSMutableDictionary dictionaryWithDictionary:contentDic];
    if(newContentDic[@"from_uid"]) {
        newContentDic[@"from_cust_id"] = newContentDic[@"from_uid"];
        [newContentDic removeObjectForKey:@"from_uid"];
    }
    if(newContentDic[@"from_name"]) {
        newContentDic[@"from_cust_name"] = newContentDic[@"from_cust_name"];
        [newContentDic removeObjectForKey:@"from_cust_name"];
    }
    // 转换正文属性
    [self convertContentPropToMOS:newContentDic];
    
    // 转换正文类型
    [self convertContentTypeToMOS:newContentDic];
    
    return newContentDic;
}


// 将MOS协议的content转换为LM协议的content
-(NSDictionary*) convertContentToLM:(NSDictionary *)contentDic message:(WKMessage*)message{
    if(!contentDic[@"type"]) {
        return contentDic;
    }
    
    NSMutableDictionary *newContentDic = [NSMutableDictionary dictionaryWithDictionary:contentDic];
    if(newContentDic[@"from_cust_id"]) {
        newContentDic[@"from_uid"] = newContentDic[@"from_cust_id"];
        [newContentDic removeObjectForKey:@"from_cust_id"];
    }
    if(newContentDic[@"from_cust_name"]) {
        newContentDic[@"from_name"] = newContentDic[@"from_cust_name"];
        [newContentDic removeObjectForKey:@"from_cust_name"];
    }
    if([contentDic[@"type"] integerValue] == 33) { // 领取红包的消息，这个消息比较特殊要特殊处理
        if(newContentDic[@"content_param"]) {
            newContentDic[@"redpacket_no"] = newContentDic[@"content_param"][0][@"redpacketNo"];
        }
        
    }
   
    // 转换带参数的content
    [self convertContentParamToLM:newContentDic];
    
    // 转换正文属性
    [self convertContentPropToLM:newContentDic];
    
    // 转换正文类型
    [self convertContentTypeToLM:newContentDic];

    if([newContentDic[@"type"] integerValue] == WK_CMD) {
        message.header.noPersist = YES; // cmd消息都不存
    }
    return newContentDic;
}


// 转换正文属性
-(void) convertContentPropToLM:(NSMutableDictionary *)contentDic {
    NSInteger type = [contentDic[@"type"] integerValue];
    switch (type) {
        case 1:{
            NSString *contentJsonStr = contentDic[@"contentJson"];
            if(contentJsonStr && ![contentJsonStr isEqualToString:@""]) {
                NSDictionary *dic = [NSJSONSerialization
                    JSONObjectWithData:[contentJsonStr dataUsingEncoding:NSUTF8StringEncoding]
                               options:0
                                 error:nil];
                if(dic) {
                    NSMutableDictionary *replyDic = [NSMutableDictionary dictionary];
                    replyDic[@"message_id"] = dic[@"quoteMsgNo"];
                    replyDic[@"from_uid"] = dic[@"quoteUserId"];
                    replyDic[@"from_name"] = @"";
                    replyDic[@"payload"] = @{@"type":@(1),@"content":dic[@"quoteText"]?:@""};
                    contentDic[@"reply"] = replyDic;
                }
            }
        }
            break;
        case 2:
            contentDic[@"url"] =  contentDic[@"path"];
            [contentDic removeObjectForKey:@"path"];
            [contentDic removeObjectForKey:@"content"];
            break;
        case 4:
            contentDic[@"url"] =  contentDic[@"path"];
            contentDic[@"timeTrad"] =  contentDic[@"second"];
            [contentDic removeObjectForKey:@"second"];
            [contentDic removeObjectForKey:@"path"];
            break;
        case 5:
            contentDic[@"cover"] =  contentDic[@"cover_path"];
            contentDic[@"url"] =  contentDic[@"video_path"];
            contentDic[@"height"] =  @([contentDic[@"cover_height"] integerValue]);
            contentDic[@"width"] =  @([contentDic[@"cover_width"] integerValue]);
            break;
        case 6: // 文件
            contentDic[@"url"] =  contentDic[@"path"];
            break;
        case 7: // 消息撤回
            contentDic[@"cmd"] =  @"messageRevoke";
            contentDic[@"param"] = @{@"client_msg_no":contentDic[@"msgno"]?:@""};
            break;
        case 17: // 位置
            if(!contentDic[@"title"] || [contentDic[@"title"] isEqualToString:@""] ) {
                contentDic[@"title"] =  contentDic[@"content"];
            }
            if(!contentDic[@"address"] || [contentDic[@"address"] isEqualToString:@""] ) {
               contentDic[@"address"] =  contentDic[@"content"];
            }
            
            contentDic[@"lng"] =  contentDic[@"longitude"];
            contentDic[@"lat"] =  contentDic[@"latitude"];
            [contentDic removeObjectForKey:@"content"];
            [contentDic removeObjectForKey:@"longitude"];
            [contentDic removeObjectForKey:@"latitude"];
            break;
        case 31: // 名片
            contentDic[@"uid"] =  contentDic[@"cust_id"];
            contentDic[@"name"] =  contentDic[@"nick_name"];
            contentDic[@"vercode"] = contentDic[@"verification_code"]?:@"";
            [contentDic removeObjectForKey:@"cust_id"];
            [contentDic removeObjectForKey:@"nick_name"];
            break;
        case 32: // 红包
            contentDic[@"redpacket_no"] = contentDic[@"packetsid"];
            contentDic[@"blessing"] = contentDic[@"content"];
            break;
        case 26: // 添加群聊的时候发过来的消息（非添加群成员消息）
            contentDic[@"cmd"] =  @"groupAvatarUpdate";
            contentDic[@"param"] = @{@"group_no":contentDic[@"chat_id"]?:@""};
            break;
        case 18: //  修改群内昵称
            if(contentDic[@"group_no"] && ![contentDic[@"group_no"] isEqualToString:@""]) {
                contentDic[@"cmd"] =  @"memberUpdate";
                contentDic[@"param"] = @{@"group_no":[self openIdToCustId:contentDic[@"group_no"]?:@""]};
            }else { // 好友昵称修改
                if(contentDic[@"remarked_id"] && ![contentDic[@"remarked_id"] isEqualToString:@""]) {
                    contentDic[@"cmd"] = @"channelUpdate";
                    contentDic[@"param"] = @{@"channel_id":[self openIdToCustId:contentDic[@"remarked_id"]],@"channel_type":@(WK_PERSON)};
                }
            }
            
            break;
        case 51:
            contentDic[@"cmd"] =  @"memberUpdate";
            contentDic[@"param"] = @{@"group_no":contentDic[@"session_id"]?:@""};
            break;
        case 14: // 用户头像更新
            contentDic[@"cmd"] =  @"userAvatarUpdate";
            contentDic[@"param"] = @{@"uid":contentDic[@"cust_id"]?:@""};
            break;
        case 8: //好友邀请
            contentDic[@"cmd"] =  @"friendRequest";
            contentDic[@"param"] = @{
                @"apply_uid":contentDic[@"from_uid"]?:@"",
                @"apply_name":contentDic[@"from_name"]?:@"",
                @"remark":contentDic[@"content"]?:@"",
                @"token":contentDic[@"pre_relation_no"]?:@"",
            };
            break;
        case 10: //好友接受邀请
            contentDic[@"cmd"] =  @"friendAccept";
            contentDic[@"param"] = @{
                @"from_uid":contentDic[@"from_uid"]?:@"",
            };
            break;
        case 11: // 合并转发
            
            break;
        case 30: //被好友删除😭
            contentDic[@"cmd"] =  @"friendDeleted";
            contentDic[@"param"] = @{
                @"uid":contentDic[@"from_uid"]?:@"",
            };
            break;
        case 34: //被好友拉嘿😭
        case 35: //被拉出黑明单😊
            contentDic[@"cmd"] =  @"unknown";
            break;
        case 40: { // 好友发布了朋友圈
            contentDic[@"cmd"] = @"momentMsg";
            contentDic[@"param"] = @{
                @"action": @"publish",
                @"uid": contentDic[@"from_uid"]?:@"",
                
            };
        }
            break;
        case 41:  { // 朋友圈消息
            NSString *contentStr = contentDic[@"content"];
            NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[contentStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
            if(dictionary) {
                NSString *action = dictionary[@"comment_or_like"];
                contentDic[@"cmd"] = @"momentMsg";
                contentDic[@"param"] = @{
                    @"action": action?:@"",
                    @"action_at": dictionary[@"time"],
                    @"uid": contentDic[@"from_uid"]?:@"",
                    @"name": contentDic[@"from_name"]?:@"",
                    @"moment_no": dictionary[@"topic_id"],
                    @"content": dictionary[@"moment_content"],
                    @"comment": dictionary[@"content"],
                    
                };
            }
        }
            break;
        case 4006: { // 扫码收款通知
            if(contentDic[@"qrcode_type"]) {
                NSInteger qrcodeType = [contentDic[@"qrcode_type"] integerValue];
                if(qrcodeType == 1) { // 付款码
                    contentDic[@"cmd"] = @"payMoneySuccess";
                    contentDic[@"param"] = @{
                        @"amount": contentDic[@"amount"],
                        @"uid": contentDic[@"from_uid"]?:@"",
                    };
                }else{ // 收款码
                    contentDic[@"cmd"] = @"receiveMoneySuccess";
                    contentDic[@"param"] = @{
                        @"amount": contentDic[@"amount"],
                        @"uid": contentDic[@"from_uid"]?:@"",
                    };
                }
            }
           
        }
        case 10004: {
                NSArray *params = contentDic[@"extra"];
                if(params.count>0) {
                    contentDic[@"from_name"] =   params[0][@"name"];
                    contentDic[@"from_uid"] =   params[0][@"uid"];
                }
            }
            break;
        case 11002:
            contentDic[@"invite_no"] = [contentDic[@"id"] stringValue];
            break;
        case 9996: // 收到通话
        case 9998: // 接受通话
            contentDic[@"cmd"] = @"videoCall";
            contentDic[@"param"] = @{@"extra":contentDic[@"extra"]?:@{},@"type":@(type)};
            [contentDic removeObjectForKey:@"extra"];
            break;
        case 9995:
        case 9997:
        case 9999:
            if(!contentDic[@"content"] || [contentDic[@"content"] isEqualToString:@""]) {
                contentDic[@"content"] = [self getVideoCallContentDesc:contentDic];
                contentDic[@"second"] = [self getVideoCallTime:contentDic];
            }
            break;
        default:
            break;
    }
}


-(NSNumber*) getVideoCallTime:(NSDictionary*)contentDic {
    NSNumber *time; // 通话时长
    if([contentDic[@"extra"] isKindOfClass:[NSArray class]]) {
        NSArray *extraArray = (NSArray*)contentDic[@"extra"];
        if(extraArray.count>0) {
            NSDictionary *data = extraArray[0];
            time = data[@"time"];
        }
    }
    return time?:@(0);
}

- (NSString *) getVideoCallContentDesc:(NSDictionary*)contentDic {
    
    NSString *content;
    if([contentDic[@"extra"] isKindOfClass:[NSArray class]]) {
        NSArray *extraArray = (NSArray*)contentDic[@"extra"];
        if(extraArray.count>0) {
            NSDictionary *data = extraArray[0];
            content = data[@"content"];
        }
    }
    NSInteger contentType = [contentDic[@"type"] integerValue];
    if(!content  ||  [content isEqualToString:@""]) {
        switch (contentType) {
            case 9995:
                content =  @"未接通";
                break;
            case 9996:
                content =  @"已接通";
                break;
            case 9997:
                content =  @"已拒绝";
                break;
            case 9999:
                content =  @"已挂断";
                break;
            default:
                content =  @"未知通话消息";
                break;
        }
    }
    return content;
}
// 转换正文属性
-(void) convertContentPropToMOS:(NSMutableDictionary *)contentDic {
    NSInteger type = [contentDic[@"type"] integerValue];
    switch (type) {
        case WK_TEXT: {
           NSDictionary *replyDict = contentDic[@"reply"];
            if(replyDict && replyDict[@"payload"] && [replyDict[@"payload"][@"type"] integerValue]==1) {
                NSMutableDictionary *contentJSONDict = [NSMutableDictionary dictionary];
                contentJSONDict[@"quoteMsgType"] = @(1);
                
                NSDictionary *mentionDic = contentDic[@"mention"];
                if(mentionDic) {
                    contentJSONDict[@"isAtPerson"] = mentionDic[@"uids"];
                }
                contentJSONDict[@"quoteMsgNo"] = replyDict[@"message_id"];
                contentJSONDict[@"quoteUserId"] = replyDict[@"from_uid"];
                contentJSONDict[@"quoteText"] = replyDict[@"payload"][@"content"];
                
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:contentJSONDict options:0 error:nil];
                NSString *contentJSONStr =
                    [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                
                contentDic[@"contentJson"] = contentJSONStr;
            }
            [contentDic removeObjectForKey:@"reply"];
        }
            break;
        case WK_IMAGE:
            contentDic[@"content"] =  contentDic[@"url"];
            contentDic[@"path"] =  contentDic[@"url"];
            [contentDic removeObjectForKey:@"url"];
            break;
        case WK_VOICE:
            contentDic[@"path"] =  contentDic[@"url"];
            contentDic[@"second"] =  contentDic[@"timeTrad"];
            [contentDic removeObjectForKey:@"url"];
            [contentDic removeObjectForKey:@"timeTrad"];
            break;
        case 5: // 小视频
            contentDic[@"cover_path"] =  contentDic[@"cover"];
            contentDic[@"video_path"] =  contentDic[@"url"];
            contentDic[@"cover_height"] =  @([contentDic[@"height"] integerValue]);
            contentDic[@"cover_width"] =   @([contentDic[@"width"] integerValue]);
            break;
        case 6: // 位置
            contentDic[@"content"] =  contentDic[@"title"];
            contentDic[@"longitude"] =  contentDic[@"lng"];
            contentDic[@"latitude"] =  contentDic[@"lat"];
            break;
        case 7: // 名片
            contentDic[@"cust_id"] =  contentDic[@"uid"];
            contentDic[@"nick_name"] =  contentDic[@"name"];
            contentDic[@"verification_code"] = contentDic[@"vercode"];
            [contentDic removeObjectForKey:@"uid"];
            [contentDic removeObjectForKey:@"name"];
            break;
        case 8: // 文件
            contentDic[@"path"] =  contentDic[@"url"];
            break;
        case 9: // 红包
            contentDic[@"packetsid"] = contentDic[@"redpacket_no"];
            contentDic[@"content"] = contentDic[@"blessing"];
            [contentDic removeObjectForKey:@"redpacket_no"];
            [contentDic removeObjectForKey:@"blessing"];
            break;
        case 1014: // 截屏通知
            contentDic[@"content_param"] = @[@{@"nickname":contentDic[@"from_name"]?:@"",@"custid":[WKSDK shared].options.connectInfo.uid?:@""}];
            contentDic[@"content"] = @"{0}在聊天中截屏了";
            
            break;
        default:
            break;
    }
}

// 转换正文类型
-(void) convertContentTypeToLM:(NSMutableDictionary *)contentDic {
    NSInteger type = [contentDic[@"type"] integerValue];
    contentDic[@"type"] = @([self convertTypeToLM:type]);
}

// 转换正文类型
-(void) convertContentTypeToMOS:(NSMutableDictionary *)contentDic {
    NSInteger type = [contentDic[@"type"] integerValue];
    contentDic[@"type"] = @([self convertTypeToMOS:type]);
}

-(NSInteger) convertTypeToMOS:(NSInteger)lmContentType {
    switch (lmContentType) {
        case 7: // 名片
            return 31;
        case 6: // 位置
            return 17;
        case 8: // 文件
            return 6;
        case 9: // 红包
            return 32;
        case 11: // 合并转发
            return 10010;
        case 1014: // 截屏通知
            return 10004;
        default:
            break;
    }
    return lmContentType;
}

-(NSInteger) convertTypeToLM:(NSInteger)mosContentType {
    switch (mosContentType) {
        case 6: // 文件
            return 8;
        case 19: // 添加群成员
            return 1002;
        case 20: // 移除群成员
            return 1003;
        case 21: // 修改群名称
        case 22: // 修改群公告
        case 11001: // 群聊邀请确认
        case 23: // 群禁言
            return 1005; // 群更新
        case 29: // 转账消息
            return 10;
        case 31: // 名片
            return 7;
        case 32: // 红包
            return 9;
        case 17: // 位置
            return 6;
        case 25: // 群禁止加好友
            return 1013;
        case 26: // 添加群聊的时候发过来的消息（非添加群成员消息）
        case 18: // 修改群内昵称
        case 14: // 修改用户头像
        case 8: // 好友邀请
        case 7: // 消息撤回
        case 10: // 接受好友申请
        case 30: // 被好友删除
        case 34: // 被拉入黑明单😭
        case 35: // 被拉出黑明单😊
        case 40: // 好友发布了朋友圈
        case 41: // 朋友圈点赞或评论
        case 51: // 设置为管理员
        case 9996: // 发起音频通话
        case 9998: // 接受音频通话
        case 4006: // 扫码收款通知
            return WK_CMD;
        case 506: // 拒绝加入群聊
            return 1010;
        case 10004: // 截屏通知
            return 1014;
        case 11002:
            return 1009;
        case 4001: // 交易系统消息
            return 1012;
        case 11003: // 群主转让
            return 1008;
        case 33: // 红包领取tip(某某领取了你的红包)
            return 1011;
        case 10010: // 合并转发
            return 11;
        default:
            break;
    }
    return mosContentType;
}
// 转换带参数的content
-(void) convertContentParamToLM:(NSMutableDictionary *)contentDic {
    if(!contentDic[@"content_param"]) {
        return;
    }
    NSArray *contentParamDictArray = contentDic[@"content_param"];
    if(contentParamDictArray) {
        NSMutableArray *newParams = [NSMutableArray array];
        for (NSDictionary *contentParam  in contentParamDictArray) {
            NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:contentParam];
            if(contentParam[@"custid"] && contentParam[@"nickname"]) {
                newDict[@"uid"] = contentParam[@"custid"];
                newDict[@"name"] = contentParam[@"nickname"];
            }
            [newParams addObject:newDict];
        }
        contentDic[@"extra"] = newParams;
        [contentDic removeObjectForKey:@"content_param"];
    }
}

// openId转换成custid
- (NSString *)openIdToCustId:(NSString *)openId {
  return [self DESDecrypt:openId WithKey:@""];
}

- (NSString*)DESDecrypt:(NSString*)plainText
                         WithKey:(NSString*)key
{
    if (!plainText) {
        return nil;
    }
    if (!key || [key isEqualToString:@""]) {
        key = @"klohjmz_";
    }

    plainText = [plainText stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    plainText = [plainText stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    NSData* textData = [[NSData alloc] initWithBase64EncodedString:plainText options:0];

    char keyPtr[kCCKeySizeDES + 1];
    //    char keyPtr[kCCKeySizeAES256 + 1];
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];

    NSUInteger dataLength = [textData length];
    size_t bufferSize = dataLength + kCCBlockSizeDES;
    //    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void* buffer = malloc(bufferSize);

    NSData* keydata = [key dataUsingEncoding:NSUTF8StringEncoding];
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(
        kCCDecrypt, kCCAlgorithmDES, kCCOptionPKCS7Padding, keyPtr,
        kCCBlockSizeDES, [keydata bytes], [textData bytes], dataLength,
        buffer, bufferSize, &numBytesDecrypted);

    if (cryptStatus == kCCSuccess) {
        NSData* data = [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
        Byte* testByte = (Byte*)[data bytes];
        NSString* str;
        for (int i = 0; i < [data length]; i++) {
            if (i == 0) {
                str = [NSString stringWithFormat:@"%hhu", testByte[i]];

            } else {
                str = [NSString stringWithFormat:@"%@%hhu", str, testByte[i]];
            }
        }
        return str;
    }

    free(buffer);
    return nil;
}

@end

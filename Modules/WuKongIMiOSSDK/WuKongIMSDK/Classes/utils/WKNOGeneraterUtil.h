//
//  WKNOGeneraterUtil.h
//  WuKongIMSDK
//
//  Created by tt on 2020/6/1.
//

#import <Foundation/Foundation.h>

/**
 *  为一段data创建唯一的64位数据签名
 *
 *  @param[in]  psrc  src data
 *  @param[in]  slen  data的长度
 *  @return 操作结果
 * - 1   成功
 * - -1  失败
 *  @note 异常情况：
 * - if slen<0，有可能出现程序异常；
 * - if slen==0，sign = 0:0；
 */
uint64_t get_sign64 (const char* psrc, int slen);

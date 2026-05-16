// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRTCIceServer.h
//  WuKongBase
//
//  Created by tt on 2023/12/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKRTCIceServer : NSObject

@property(nonatomic,strong) NSArray<NSString*> *urlStrings;
@property(nonatomic,copy) NSString *username;
@property(nonatomic,copy) NSString *credential;

- (instancetype)initWithURLStrings:(NSArray<NSString *> *)urlStrings
                          username:(nullable NSString *)username
                        credential:(nullable NSString *)credential;

- (instancetype)initWithURLStrings:(NSArray<NSString *> *)urlStrings;

@end

NS_ASSUME_NONNULL_END

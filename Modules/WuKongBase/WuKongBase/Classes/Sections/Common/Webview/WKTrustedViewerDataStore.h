// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import <WebKit/WebKit.h>

@interface WKTrustedViewerDataStore : NSObject

+ (WKWebsiteDataStore *)storeForUID:(NSString *)uid token:(NSString *)token apiBaseURL:(NSString *)apiBaseURL;
+ (void)retireStoreIfCurrent:(WKWebsiteDataStore *)store;

@end

// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const WKTrustedViewerSessionDidChangeNotification;
FOUNDATION_EXPORT BOOL WKIsSameViewerOriginURL(NSURL * _Nullable URL, NSURL * _Nullable referenceURL);
FOUNDATION_EXPORT BOOL WKIsTrustedViewerURL(NSURL * _Nullable URL,
                                             NSString * _Nullable apiBaseURL);
FOUNDATION_EXPORT NSURL * _Nullable WKTrustedViewerHandoffURL(NSURL * _Nullable URL,
                                                               NSString * _Nullable apiBaseURL);
FOUNDATION_EXPORT NSString * _Nullable WKTrustedViewerIdentityScript(NSURL * _Nullable URL,
                                                                      NSString *token,
                                                                      NSString *uid,
                                                                      NSString *name,
                                                                      NSString * _Nullable spaceId);

NS_ASSUME_NONNULL_END

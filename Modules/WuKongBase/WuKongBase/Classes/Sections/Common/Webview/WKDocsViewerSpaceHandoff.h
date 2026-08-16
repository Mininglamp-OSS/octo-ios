// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Returns YES only for same-origin, standalone Docs viewer/presentation URLs.
FOUNDATION_EXPORT BOOL WKIsTrustedDocsViewerURL(NSURL * _Nullable URL,
                                                NSString * _Nullable apiBaseURL);

/// Builds the document-start script that snapshots the native viewer Space.
/// A nil or empty value removes the key so pooled web content cannot reuse stale state.
FOUNDATION_EXPORT NSString *WKDocsViewerSpaceJavaScript(NSString * _Nullable currentSpaceId,
                                                        NSString *apiBaseURL);

NS_ASSUME_NONNULL_END

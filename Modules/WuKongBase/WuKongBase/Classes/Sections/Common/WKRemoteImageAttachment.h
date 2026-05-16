// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRemoteImageAttachment.h
//  WuKongRichTextEditor
//
//  Created by tt on 2022/7/28.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKRemoteImageAttachment : NSTextAttachment

@property(nonatomic,assign) CGSize displaySize;
@property(nonatomic,copy) NSString *url;

-(instancetype) initWithURL:(NSString*)url displaySize:(CGSize)displaySize;

-(void) startDownload:(void(^)(UIImage *img))complete;

@end

NS_ASSUME_NONNULL_END

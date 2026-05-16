// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSearchMediaCell.h
//  WuKongBase
//
//  Created by tt on 2025/2/27.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSearchMediaItem : NSObject


@property(nonatomic,copy) NSString *url; // 资源地址
@property(nonatomic,copy) NSString *type; // 资源类型 image,video
@property(nonatomic,strong) NSDictionary *extra;

@end

@interface WKSearchMediaModel : WKFormItemModel
@property(nonatomic,assign) NSInteger numOfRow; // 每行数量
@property(nonatomic,strong) NSArray<WKSearchMediaItem*> *items;


@end

@interface WKSearchMediaCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END

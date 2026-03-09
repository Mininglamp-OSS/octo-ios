//
//  ActionSheetItem.h
//  qiyunxin
//
//  Created by Mac on 2017/12/9.
//  Copyright © 2017年 aiti. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WKActionSheetItem : NSObject
//点击title
@property (nonatomic,copy) NSString *title;
//点击的index
@property (nonatomic,assign) NSInteger index;

+ (WKActionSheetItem *)itemWithTitle:(NSString *)title index:(NSInteger)index;
@end

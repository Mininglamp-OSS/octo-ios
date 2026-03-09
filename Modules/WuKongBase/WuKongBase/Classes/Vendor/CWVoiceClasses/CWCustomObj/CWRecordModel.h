//
//  CWRecordModel.h
//  QQVoiceDemo
//
//  Created by 陈旺 on 2017/10/7.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CWSington.h"

@interface CWRecordModel : NSObject

@property (nonatomic,copy) NSString *path;

@property (nonatomic,strong) NSArray *levels; // 振幅数组

@property (nonatomic,assign) NSInteger duration;

// 单例
singtonInterface;


@end

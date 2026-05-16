//
//  WKChineseSort.m
//
//  Created by Baymax on 16/2/11.
//  Copyright (c) 2016年 Baymax. All rights reserved.
//  version: 0.2.4

#import <Foundation/Foundation.h>
/**
    排序参数设置类
 */
@interface WKChineseSortSetting : NSObject
+(WKChineseSortSetting*)share;
/**
    排序的时间主要花在 中文转拼音上 sortMode 选择转换的方法 default is 2
    sortMode = 1 使用原生CFStringTransform 方法转换，比较耗时
    sortMode = 2 使用汉字码表对应的首字母码表 通过编码顺序查找 比较快
                 码表来源于网络 不保证准确性（除了多音字没发现有错误），可以码表配合polyphoneMapping手动修改想要的映射
 */
@property (nonatomic,assign) NSInteger sortMode;
/**
    是否打印所用时间。 default is YES
 */
@property (nonatomic,assign) BOOL logEable;

/**
 是否要求排序是稳定的排序，即相同的拼音首字母的元素的顺序排完序后不变，开启会多消耗时间， default is false
 */
@property (nonatomic,assign) BOOL needStable;
/**
    特殊字符最后单独分组所用的 分组名称。 default is @“#”
 */
@property (strong, nonatomic) NSString *  specialCharSectionTitle;
/**
 特殊字符所在 位置 YES = 开头，NO = 结尾, defalut is @"YES"
 */
@property (nonatomic,assign) BOOL specialCharPositionIsFront;
/**
    剔除 特定字符开头的对象，不出现在最终结果集中，不要与 specialCharSectionTitle 冲突。 default is ""
    eg: 过滤所有数字开的对象  ignoreModelWithPrefix = @"0123456789"
 */
@property (strong, nonatomic) NSString * ignoreModelWithPrefix;
/**
    常用错误多音字 手动映射
    已经识别了：
        重庆=CQ，厦门=XM，长=C，
    如遇到默认选择错误的可以手动映射，使用格式{"匹配的文字":"对应的首字母(大写)"}
    eg:.polyphoneMapping = @{"长安":"CA","厦门":"XM"}
    如有发现常用的多音字 也可以在issue里提出来 定期更新
 */
@property (strong, nonatomic) NSMutableDictionary * polyphoneMapping;
@end


/**
    排序主体类
 */
@interface WKChineseSort : NSObject

/**
 根据汉字返回汉字的拼音

 @param word 转换的汉字
 @return 返回对应的拼音
 */
+(NSString *)transformChinese:(NSString *)word;

/**
  获取汉子首字母
 */
+ (NSString *)getFirstLetter:(NSString *)chinese;

/**
 异步获取拼音分组排序 (分组)

 @param objectArray 需要排序的数据源 可以是自定义模型数组，字符串数组，字典数组
 @param key 如果是字符串数组key传nil, 否则传入需要排序的字符串属性，或是字符串字段
 @param finish 异步回调block isSuccess为no, 打开打印功能查看原因
 */

+(void)sortAndGroup:(NSArray*)objectArray key:(NSString *)key finish:(void (^)(bool isSuccess, NSMutableArray *unGroupedArr, NSMutableArray *sectionTitleArr, NSMutableArray<NSMutableArray*>* sortedObjArr))finish;

@end

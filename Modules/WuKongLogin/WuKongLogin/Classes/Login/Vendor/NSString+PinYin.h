//
//  NSString+PinYin.h
//  TableViewIndexTest
//
//  Created by Shadow on 14-3-5.
//  Copyright (c) 2014年 Shadow. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (PinYin)

/*
 *获取汉字拼音的首字母, 返回的字母是大写形式, 例如: @"俺妹", 返回 @"A".
 *如果字符串开头不是汉字, 而是字母, 则直接返回该字母, 例如: @"b彩票", 返回 @"B".
 *如果字符串开头不是汉字和字母, 则直接返回 @"#", 例如: @"&哈哈", 返回 @"#".
 *字符串开头有特殊字符(空格,换行)不影响判定, 例如@"       a啦啦啦", 返回 @"A".
 */
- (NSString *)getFirstLetter;

@end

@interface NSArray (PinYin)

/*
 *将一个字符串数组按照拼音首字母规则进行重组排序, 返回重组后的数组.
 *格式和规则为:

  [
      @{
           @"firstLetter": @"A",
           @"content": @[@"啊", @"阿狸"]
       }
      ,
      @{
           @"firstLetter": @"B",
           @"content": @[@"部落", @"帮派"]
       }
      ,
      ...
  ]

 *只会出现有对应元素的字母字典, 例如: 如果没有对应 @"C"的字符串出现,
 则数组内也不会出现 @"C"的字典.
 *数组内字典的顺序按照26个字母的顺序排序
 *@"#"对应的字典永远出现在数组最后一位
 */
- (NSArray *)arrayWithPinYinFirstLetterFormat;

@end

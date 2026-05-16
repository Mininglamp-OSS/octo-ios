//
//  WKJsonUtil.m
//  WuKongBase
//
//  Created by tt on 2020/7/27.
//

#import "WKJsonUtil.h"

@implementation WKJsonUtil

+ (NSString *)toJson:(id)obj {
    NSData *jsonData;
    if ([obj isKindOfClass:[NSData class]]) {
        jsonData = (NSData *)obj;
    } else {
        jsonData = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    }

  NSString *json =
      [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

  return json;
}

+ (NSDictionary *)toDic:(NSString *)jsonStr {
  if (!jsonStr || [jsonStr isEqualToString:@""]) {
    return nil;
  }
  NSDictionary *dic = [NSJSONSerialization
      JSONObjectWithData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding]
                 options:NSJSONReadingAllowFragments
                   error:nil];

  return dic;
}

+(NSArray*) toArray:(NSString*)jsonStr {
    if (!jsonStr || [jsonStr isEqualToString:@""]) {
      return nil;
    }
    id array = [NSJSONSerialization
        JSONObjectWithData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding]
                   options:NSJSONReadingAllowFragments
                     error:nil];

    return array;
}

@end

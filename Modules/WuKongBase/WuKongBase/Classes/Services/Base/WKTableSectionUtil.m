//
//  WKTableSectionUtil.m
//  WuKongBase
//
//  Created by tt on 2020/3/1.
//

#import "WKTableSectionUtil.h"
#import "WKFormSection.h"
@implementation WKTableSectionUtil


+(NSArray<WKFormSection*>*) toSections:(NSArray<NSDictionary*>*) sectionArray {
   // NSDictionary *test = @[@{@"height":@(20.0f),@"items":@[@{@"class":@"WKLabelIemModel",@"label":@"群名称",@"value":@"测试"}]}];
    if(!sectionArray || sectionArray.count<=0) {
        return nil;
    }
    NSMutableArray<WKFormSection*> *sections = [NSMutableArray array];
    for (NSDictionary *sectionDict in sectionArray) {
        WKFormSection *section = [WKFormSection new];
        if(sectionDict[@"height"]) {
            section.height = [sectionDict[@"height"] floatValue];
        }
        if(sectionDict[@"remark"]) {
            section.remark = sectionDict[@"remark"];
        }
        if(sectionDict[@"title"]) {
            section.title = sectionDict[@"title"];
        }
        if(sectionDict[@"headView"]) {
            section.headView = sectionDict[@"headView"];
        }
        if(sectionDict[@"items"]) {
            NSMutableArray *items = [NSMutableArray array];
            for (NSDictionary *itemDict in sectionDict[@"items"]) {
               Class formModelClass =  itemDict[@"class"];
                if(itemDict[@"hidden"] && [itemDict[@"hidden"] boolValue]) { // 如果隐藏，则不添加
                    continue;
                }
                id object = [formModelClass new];
                for (NSString *key in itemDict.allKeys) {
                    if([key isEqualToString:@"class"] || [key isEqualToString:@"hidden"]) {
                        continue;
                    }
                    if(itemDict[key]!=[NSNull null]) {
                        [object setValue:itemDict[key] forKey:key];
                    }
                }
                [items addObject:object];
            }
            section.items = items;
        }
        [sections addObject:section];
    }
  
    return sections;
}

@end

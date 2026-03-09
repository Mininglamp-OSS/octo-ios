//
//  WKLanguageVM.m
//  WuKongBase
//
//  Created by tt on 2020/12/25.
//

#import "WKLanguageVM.h"
#import "WKLabelItemSelectCell.h"


@implementation WKLanguageVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    NSString *langue = [WKApp shared].config.langue;
    __weak typeof(self) weakSelf = self;
    return @[
        @{
            @"height":@(0.0f),
            @"items":@[
                    @{
                        @"class":WKLabelItemSelectModel.class,
                        @"label":@"简体中文",
                        @"selected":@([langue isEqualToString:@"zh-Hans"]),
                        @"onClick":^{
                            [WKApp shared].config.langue = @"zh-Hans";
                            [weakSelf reloadData];
                        }
                    },
                    @{
                        @"class":WKLabelItemSelectModel.class,
                        @"label":@"English",
                        @"selected":@([langue isEqualToString:@"en"]),
                        @"onClick":^{
                            [WKApp shared].config.langue = @"en";
                            [weakSelf reloadData];
                        }
                    }
            ],
        }
    ];
}

@end

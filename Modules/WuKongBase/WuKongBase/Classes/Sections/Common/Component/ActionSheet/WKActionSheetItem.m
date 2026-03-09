
#import "WKActionSheetItem.h"

@implementation WKActionSheetItem

+ (WKActionSheetItem *)itemWithTitle:(NSString *)title index:(NSInteger)index{
    
    WKActionSheetItem *sheetItem = [[WKActionSheetItem alloc] initWithTitle:title index:index];
    return sheetItem;
}

- (instancetype)initWithTitle:(NSString *)title index:(NSInteger)index {
    self = [super init];
    if(self) {
        _title = title;
        _index = index;
    }
    return self;
}


@end

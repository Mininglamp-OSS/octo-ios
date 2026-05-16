//
//  WKBaseTableVM.m
//  WuKongBase
//
//  Created by tt on 2020/6/21.
//

#import "WKBaseTableVM.h"
#import "WKTableSectionUtil.h"
@implementation WKBaseTableVM

-(NSArray<WKFormSection*>*) tableSections {
    return [WKTableSectionUtil toSections:[self tableSectionMaps]];
}

-(NSArray<NSDictionary*>*) tableSectionMaps {
    return @[];
}

-(void) requestData:(void(^)(NSError * error))complete {
    complete(nil);
}

-(void) pullup:(void(^)(BOOL hasMore))complete {
    complete(false);
}

- (void)reloadData {
    if(self.delegateR && [self.delegateR respondsToSelector:@selector(baseTableReloadData:)]) {
        [self.delegateR baseTableReloadData:self];
    }
}
- (void)reloadRemoteData {
    if(self.delegateR && [self.delegateR respondsToSelector:@selector(baseTableReloadRemoteData:)]) {
        [self.delegateR baseTableReloadRemoteData:self];
    }
}

-(void) resetPullupState {
    if(self.delegateR && [self.delegateR respondsToSelector:@selector(baseTableResetPullupState:)]) {
        [self.delegateR baseTableResetPullupState:self];
    }
}

@end

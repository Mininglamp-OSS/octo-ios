//
//  WKSecurityTipManager.m
//  WuKongBase
//
//  Created by tt on 2022/3/22.
//

#import "WKSecurityTipManager.h"
#import "WKApp.h"
#import "WKAPIClient.h"
#import "WKJsonUtil.h"

@interface WKSecurityTipManager ()

@property(nonatomic,strong) NSArray<NSString*> *sensitiveWords;
@property(nonatomic,copy) NSString *tip;

@end

@implementation WKSecurityTipManager


+ (instancetype)shared{
    static WKSecurityTipManager *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[WKSecurityTipManager alloc] init];
    });
    
    return _shared;
}

-(void) sync {
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] GET:@"message/sync/sensitivewords" parameters:nil].then(^(NSDictionary *resultDict){
        if(resultDict) {
            weakSelf.sensitiveWords =   resultDict[@"list"];
            weakSelf.tip = resultDict[@"tips"];
            [weakSelf saveSecurityTipData:resultDict];
        }
       
    }).catch(^(NSError *error){
        NSLog(@"同步敏感词失败！->%@",error);
    });
}

-(void) syncIfNeed {
    NSDictionary *resultDict = [self getSecurityTipData];
    if(resultDict) {
        self.sensitiveWords =   resultDict[@"list"];
        self.tip = resultDict[@"tips"];
    }else {
        [self sync];
    }
}

-(void) saveSecurityTipData:(NSDictionary*)dataDict {
    if(dataDict) {
        NSString *tipJSON = [WKJsonUtil toJson:dataDict];
         [[NSUserDefaults standardUserDefaults] setObject:tipJSON forKey:@"lim_security_tip_data"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

-(NSDictionary*) getSecurityTipData {
   NSString *dataStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"lim_security_tip_data"];
    if(dataStr && ![dataStr isEqualToString:@""]) {
       return [WKJsonUtil toDic:dataStr];
    }
    return  nil;
}

-(BOOL) match:(NSString*)text {
    if(self.sensitiveWords && self.sensitiveWords.count>0) {
        for (NSString *sensitiveWord in self.sensitiveWords) {
            if([text containsString:sensitiveWord]) {
                return  true;
            }
        }
    }
    return false;
}


@end

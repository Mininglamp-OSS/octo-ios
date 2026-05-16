// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//

#import <Foundation/Foundation.h>

#define WKInputAtStartChar  @"@"
#define WKInputAtEndChar    @"\u2004"

@interface WKInputMentionItem : NSObject

@property (nonatomic,copy) NSString *name;

@property (nonatomic,copy) NSString *uid;

@property (nonatomic,assign) NSRange range;

@end

@interface WKInputMentionCache : NSObject

@property (nonatomic,strong) NSMutableArray<WKInputMentionItem*> *items;

- (NSArray *)allMentionUid:(NSString *)sendText;

- (void)clean;

-(NSInteger) itemCount;

- (void)addMentionItem:(WKInputMentionItem *)item;

- (WKInputMentionItem *)item:(NSString *)name;

- (WKInputMentionItem *)removeName:(NSString *)name;

@end

// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import "WKTrustedViewerDataStore.h"
#import "WKTrustedViewerHandoff.h"

@interface WKTrustedViewerDataStore ()
@property(nonatomic, strong) WKWebsiteDataStore *store;
@property(nonatomic, copy) NSString *uid;
@property(nonatomic, copy) NSString *token;
@property(nonatomic, copy) NSString *apiBaseURL;
@end

@implementation WKTrustedViewerDataStore

+ (instancetype)shared {
    static WKTrustedViewerDataStore *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionDidChange:)
                                                     name:WKTrustedViewerSessionDidChangeNotification object:nil];
    }
    return self;
}

+ (WKWebsiteDataStore *)storeForUID:(NSString *)uid token:(NSString *)token apiBaseURL:(NSString *)apiBaseURL {
    WKTrustedViewerDataStore *manager = [self shared];
    @synchronized(manager) {
        if (manager.store && (![manager.uid isEqualToString:uid]
            || ![manager.token isEqualToString:token]
            || ![manager.apiBaseURL isEqualToString:apiBaseURL])) {
            [manager retireCurrentStore];
        }
        if (!manager.store) {
            manager.store = [WKWebsiteDataStore nonPersistentDataStore];
            manager.uid = uid;
            manager.token = token;
            manager.apiBaseURL = apiBaseURL;
        }
        return manager.store;
    }
}

+ (void)retireStoreIfCurrent:(WKWebsiteDataStore *)store {
    WKTrustedViewerDataStore *manager = [self shared];
    @synchronized(manager) {
        if (manager.store == store) [manager retireCurrentStore];
    }
}

- (void)sessionDidChange:(NSNotification *)notification {
    @synchronized(self) {
        [self retireCurrentStore];
    }
}

- (void)retireCurrentStore {
    WKWebsiteDataStore *oldStore = self.store;
    if (!oldStore) return;
    self.store = nil;
    self.uid = nil;
    self.token = nil;
    self.apiBaseURL = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [oldStore removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
                    modifiedSince:[NSDate distantPast] completionHandler:^{}];
    });
}

@end

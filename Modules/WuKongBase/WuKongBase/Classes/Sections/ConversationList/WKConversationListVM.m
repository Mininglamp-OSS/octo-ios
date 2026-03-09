//
//  WKConversationListVM.m
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import "WKConversationListVM.h"
#import "WuKongBase.h"
#import "WKProhibitwordsService.h"
@interface WKConversationListVM ()
@property(nonatomic,strong) NSMutableArray<WKConversationWrapModel*> *conversationWrapModels;
@property(nonatomic,strong) NSRecursiveLock *conversationsLock;

@end

@implementation WKConversationListVM


static WKConversationListVM *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKConversationListVM *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        
    });
    return _instance;
}

-(instancetype) init {
    self = [super init];
    if(self) {
        self.conversationsLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (void)reset {
    [self.conversationWrapModels removeAllObjects];
}

-(void) loadConversationList:(void(^)(void)) finished {
    NSMutableArray<WKConversationWrapModel*> *conversationWrapModels = [[NSMutableArray alloc] init];
    NSArray<WKConversation*> *conversations = [[[WKSDK shared] conversationManager] getConversationList];
    if(conversations) {
        for (WKConversation *conversation in conversations) {
            WKConversationWrapModel *wrapModel = [[WKConversationWrapModel alloc] initWithConversation:conversation];
            if(conversation.parentChannel) {
                
                WKConversationWrapModel *parentConversationWrapModel = [self addOrCreateParentConversation:conversation.parentChannel newConversationWrapModel:wrapModel conversationWrapModels:conversationWrapModels];
                
                if(parentConversationWrapModel) {
                    [self handleProhibitwords:parentConversationWrapModel];
                    [conversationWrapModels addObject:parentConversationWrapModel];
                }
            }else {
                [self handleProhibitwords:wrapModel];
                [conversationWrapModels addObject:wrapModel];
            }
            
        }
    }
    
    self.conversationWrapModels = conversationWrapModels;
    [self sortConversationList];
    if(finished) {
        finished();
    }
}

-(void) handleProhibitwords:(WKConversationWrapModel*)model {
    if(!model.lastMessage) {
        return;
    }
    if(model.lastMessage.contentType != WK_TEXT) {
        return;
    }
    if( model.lastMessage.remoteExtra.isEdit) {
        if(model.lastMessage.remoteExtra.isEdit) {
            WKTextContent *content = (WKTextContent*)model.lastMessage.remoteExtra.contentEdit;
            content.content =[WKProhibitwordsService.shared filter:content.content]; // 违禁词过滤
            return;
        }
        WKTextContent *content = (WKTextContent*)model.lastMessage.content;
        content.content = [WKProhibitwordsService.shared filter:content.content]; // 违禁词过滤
    }
}

-(WKConversationWrapModel*) addOrCreateParentConversation:(WKChannel*) parentChannel newConversationWrapModel:(WKConversationWrapModel*)wrapModel conversationWrapModels:(NSArray<WKConversationWrapModel*>*)conversationWrapModels {
    WKConversationWrapModel *parentConversation = [self getConversationWrap:parentChannel conversations:conversationWrapModels];
    if(parentConversation) {
        [self handleProhibitwords:wrapModel];
        [parentConversation addOrUpdateChildren:wrapModel];
    }else{
        WKConversation *newParentConversation = [[WKConversation alloc] init];
        newParentConversation.channel = wrapModel.parentChannel;
        WKConversationWrapModel *parentConversationWrap = [[WKConversationWrapModel alloc] initWithConversation:newParentConversation];
        [self handleProhibitwords:wrapModel];
        [parentConversationWrap addOrUpdateChildren:wrapModel];
        return parentConversationWrap;
    }
    return nil;
}

-(WKConversationWrapModel*) getConversationWrap:(WKChannel*)channel conversations:(NSArray<WKConversationWrapModel*>*)conversations{
    for (WKConversationWrapModel *conversation in conversations) {
        if([conversation.channel isEqual:channel]) {
            return conversation;
        }
    }
    return nil;
}

// 获取真实显示的最近会话对象
-(WKConversationWrapModel*) getRealShowConversationWrap:(WKConversationWrapModel*) wrapModel {
    if(!wrapModel.parentChannel) {
        return wrapModel;
    }
    for (WKConversationWrapModel *conversation in self.conversationWrapModels) {
        if([conversation.channel isEqual:wrapModel.parentChannel]) {
            [self handleProhibitwords:wrapModel];
            [conversation addOrUpdateChildren:wrapModel];
            return conversation;
        }
    }
    WKConversation *parentConversation = [[WKConversation alloc] init];
    parentConversation.channel = wrapModel.parentChannel;
    WKConversationWrapModel *parentConversationWrap = [[WKConversationWrapModel alloc] initWithConversation:parentConversation];
    [self handleProhibitwords:wrapModel];
    [parentConversationWrap addOrUpdateChildren:wrapModel];
    return parentConversationWrap;
}

-(void) sortConversationList {
    [self.conversationWrapModels sortUsingComparator:^NSComparisonResult(WKConversationWrapModel   *obj1, WKConversationWrapModel   *obj2) {
        
        if(obj1.stick && !obj2.stick) {
            return NSOrderedAscending;
        }
        if(obj2.stick && !obj1.stick) {
            return NSOrderedDescending;
        }
        if(obj1.lastMsgTimestamp < obj2.lastMsgTimestamp) {
            return NSOrderedDescending;
        }else if(obj1.lastMsgTimestamp == obj2.lastMsgTimestamp) {
            return NSOrderedSame;
        }
        return NSOrderedAscending;
    }];
}

-(NSArray<WKConversationWrapModel*> *) conversationList {
    // [_conversationsLock lock];
    NSArray<WKConversationWrapModel*> *data =  self.conversationWrapModels;
    // [_conversationsLock unlock];
    return data;
}

-(NSInteger) conversationCount {
     // [_conversationsLock lock];
    NSInteger count = [self.conversationWrapModels count];
    // [_conversationsLock unlock];
    return count;
}
-(NSInteger) indexAtChannel:(WKChannel*)channel {
     // [_conversationsLock lock];
    if( self.conversationWrapModels) {
        for (int i=0; i< self.conversationWrapModels.count; i++) {
            WKConversationWrapModel *conversation = self.conversationWrapModels[i];
            if([conversation.channel isEqual:channel]) {
                 // [_conversationsLock unlock];
                return i;
            }
        }
    }
    // [_conversationsLock unlock];
    return -1;
    
}

-(WKConversationWrapModel*) modelAtChannel:(WKChannel*) channel {
    // [_conversationsLock lock];
    if( self.conversationWrapModels) {
        for (int i=0; i< self.conversationWrapModels.count; i++) {
            WKConversationWrapModel *conversation = self.conversationWrapModels[i];
            if([conversation.channel isEqual:channel]) {
                // [_conversationsLock unlock];
                return conversation;
            }
        }
    }
    // [_conversationsLock unlock];
    return nil;
}

-(WKConversationWrapModel*) modelAtIndex:(NSInteger)index {
    // [_conversationsLock lock];
    WKConversationWrapModel *conversation = self.conversationWrapModels[index];
    // [_conversationsLock unlock];
    return conversation;
}

-(void) replaceAtChannel:(WKConversationWrapModel*)model atChannel:(WKChannel*)channel  {
     NSInteger index =[self indexAtChannel:channel];
    if(index!=-1) {
         // [_conversationsLock lock];
        [self handleProhibitwords:model];
        [self.conversationWrapModels replaceObjectAtIndex:index withObject:model];
         // [_conversationsLock unlock];
    }
}
-(void) replaceObjectAtIndex:(NSInteger)index withObject:(WKConversationWrapModel*)model{
    // [self.conversationsLock lock];
    [self handleProhibitwords:model];
    [self.conversationWrapModels replaceObjectAtIndex:index withObject:model];
    // [self.conversationsLock unlock];
}

-(void) removeAtChannnel:(WKChannel*)channel {
   NSInteger index = [self indexAtChannel:channel];
    if(index!=-1) {
        // [self.conversationsLock lock];
        [self.conversationWrapModels removeObjectAtIndex:index];
        // [self.conversationsLock unlock];
    }
}

-(void) removeAtIndex:(NSInteger)index {
    // [self.conversationsLock lock];
    [self.conversationWrapModels removeObjectAtIndex:index];
    // [self.conversationsLock unlock];
}


-(void) removeAll {
    // [self.conversationsLock lock];
    [self.conversationWrapModels removeAllObjects];
    // [self.conversationsLock unlock];
}

-(void) insert:(WKConversationWrapModel*)model atIndex:(NSInteger)insert {
     // [self.conversationsLock lock];
    if(insert>self.conversationWrapModels.count) {
        WKLogWarn(@"warn: conversationWrapModels数组大小->%ld insert的大小%ld",(long)self.conversationWrapModels.count,(long)insert);
        return;
    }
    [self handleProhibitwords:model];
    [self.conversationWrapModels insertObject:model atIndex:insert];
   
    // [self.conversationsLock unlock];
}

-(NSInteger) insert:(WKConversationWrapModel*)model {
    [self  handleProhibitwords:model];
    WKConversationWrapModel *conversationWrapModel = [self getRealShowConversationWrap:model];
    NSInteger insertPlace =  [self findInsertPlace:conversationWrapModel];
    [self.conversationWrapModels insertObject:conversationWrapModel atIndex:insertPlace];
    
    return insertPlace;
}

-(NSInteger) findInsertPlace:(WKConversationWrapModel*)m {
    WKConversationWrapModel *newModel = m;
    if(newModel.parentChannel) {
       WKConversationWrapModel *parentConversationWrapModel = [self addOrCreateParentConversation:m.parentChannel newConversationWrapModel:m conversationWrapModels:self.conversationWrapModels];
        if(parentConversationWrapModel) {
            newModel = parentConversationWrapModel;
        }else {
             parentConversationWrapModel = [self getConversationWrap:m.parentChannel conversations:self.conversationWrapModels];
            if(parentConversationWrapModel) {
                newModel = parentConversationWrapModel;
            }
        }
    }
   
//    return 0;
//    __block int topMsgCount = 0;
//    for (NSInteger i=self.conversationWrapModels.count-1;i>=0;i--) {
//        WKConversationWrapModel *oldModel = self.conversationWrapModels[i];
//        if(newModel.stick) {
//            if(oldModel.stick) {
//                if(newModel.lastMsgTimestamp>=oldModel.lastMsgTimestamp) {
//                    return i;
//                }
//            }else {
//                return i;
//            }
//        }else if(!oldModel.stick && newModel.lastMsgTimestamp>=oldModel.lastMsgTimestamp) {
//            return i;
//        }
//    }
    if(!self.conversationWrapModels || self.conversationWrapModels.count == 0) {
        return 0;
    }
    if(self.conversationWrapModels.count == 1) {
        if( [self.conversationWrapModels[0].channel isEqual:newModel.channel]) {
            return 0;
        }
    }
   __block bool find = false;
    __block NSUInteger matchIndex = 0;
    __block bool beforeHasSelf = false;
    [self.conversationWrapModels enumerateObjectsUsingBlock:^(WKConversationWrapModel * _Nonnull oldModel, NSUInteger idx, BOOL * _Nonnull stop) {
        if(newModel.stick) {
            if(oldModel.stick) {
                if(newModel.lastMsgTimestamp>=oldModel.lastMsgTimestamp) {
                    find = YES;
                    matchIndex = idx;
                    *stop = YES;
                    return;
                }
            }else {
                find = YES;
                matchIndex = idx;
                *stop = YES;
            }
            return;
        }else if(!oldModel.stick && newModel.lastMsgTimestamp>oldModel.lastMsgTimestamp) {
            find = YES;
            matchIndex = idx;
            *stop = YES;
            return;
        }else if(!oldModel.stick && newModel.lastMsgTimestamp == oldModel.lastMsgTimestamp && [newModel.channel isEqual:oldModel.channel]) {
            find = YES;
            matchIndex = idx;
            *stop = YES;
            return;
        }else if([newModel.channel isEqual:oldModel.channel]) {
            beforeHasSelf = true;
        }
    }];
    if (find) {
        if(beforeHasSelf){
            return matchIndex-1;
        }
        return matchIndex;
    }else {
        return self.conversationWrapModels.count-1;
    }
}


-(WKConversationWrapModel*) conversationAtIndex:(NSInteger)index {
    if(index>=self.conversationWrapModels.count) {
        return nil;
    }
    // [_conversationsLock lock];
    WKConversationWrapModel *model =  [self.conversationWrapModels objectAtIndex:index];
    // [_conversationsLock unlock];
    return model;
}

-(void) removeConversationAtIndex:(NSInteger)index {
    // [_conversationsLock lock];
    if(index<self.conversationWrapModels.count) {
        [self.conversationWrapModels removeObjectAtIndex:index];
    }
    // [_conversationsLock unlock];
}

-(BOOL) hasConversationTop {
    if(self.conversationWrapModels) {
        for (WKConversationWrapModel *model in self.conversationWrapModels) {
            if(model.stick) {
                return true;
            }
        }
    }
    return false;
}

-(NSInteger) getAllUnreadCount {
     // [_conversationsLock lock];
    NSInteger unreadCount = 0;
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if(!model.mute) {
            unreadCount +=model.unreadCount;
        }
    }
    // [_conversationsLock unlock];
    return unreadCount;
}
@end

//
//  WKConversationPosition.m
//  WuKongBase
//
//  Created by tt on 2021/8/11.
//

#import "WKConversationPosition.h"

@implementation WKConversationPosition

+(WKConversationPosition*) orderSeq:(uint32_t)orderSeq offset:(int)offset type:(WKConversationPositionType)type{
    WKConversationPosition *position = [WKConversationPosition new];
    position.orderSeq = orderSeq;
    position.offset = offset;
    position.positionType = type;
    return position;
}

+(WKConversationPosition*) orderSeq:(uint32_t)orderSeq offset:(int)offset {
    return [self orderSeq:orderSeq offset:offset type:WKConversationPositionTypeUnreadFirst];
}

@end

@interface WKConversationPositionManager ()

@property(nonatomic,strong) NSMutableDictionary<WKChannel*,NSMutableArray<WKConversationPosition*>*> *positions;

@end

@implementation WKConversationPositionManager

static WKConversationPositionManager *_instance = nil;

+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone ];
    });
    return _instance;
}

+(instancetype) shared{
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(void) reload {
    [self.positions removeAllObjects];
}

- (NSMutableDictionary *)positions {
    if(!_positions) {
        _positions = [NSMutableDictionary dictionary];
    }
    return _positions;
}

-(void) channel:(WKChannel*)channel position:(WKConversationPosition*)position{
    if(!position) {
        return;
    }
    NSMutableArray *positions = self.positions[channel];
    if(!positions) {
        positions = [NSMutableArray array];
    }
    [positions addObject:position];
    self.positions[channel] = positions;
    
}

-(void) removePositions:(WKChannel*)channel {
    [self.positions removeObjectForKey:channel];
}

-(void) removePositions:(WKChannel*)channel type:(WKConversationPositionType)type{
    NSArray<WKConversationPosition*> *positions = [self.positions objectForKey:channel];
    NSMutableArray *newPositions = [NSMutableArray array];
    if(positions&&positions.count>0) {
        for (WKConversationPosition *position in positions) {
            if(position.positionType != type) {
                [newPositions addObject:position];
            }
        }
    }
    [self.positions setObject:newPositions forKey:channel];
}


-(NSArray<WKConversationPosition*>*) position:(WKChannel*)channel {
    
    return self.positions[channel];
}

@end

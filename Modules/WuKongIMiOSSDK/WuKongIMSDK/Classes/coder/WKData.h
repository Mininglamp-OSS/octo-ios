//
//  WKData.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKDataWrite : NSObject


/// 初始化（大端模式）
+(instancetype) initLittleEndian;

-(void) writeUint8:(uint8_t)v;

-(void) writeUint16:(uint16_t)v;

-(void) writeUint32:(uint32_t)v;

-(void) writeUint64:(uint64_t)v;


/// 写可变字符串 （前2位为字符串长度）
/// @param v <#v description#>
-(void) writeVariableString:(NSString*)v;

-(void) writeData:(NSData*) data;


-(NSData*) toData;
@end

@interface WKDataRead : NSObject

-(instancetype) initWithData:(NSData*) data;

-(instancetype) initWithData:(NSData*) data littleEndian:(BOOL)littleEndian;

-(uint8_t) readUint8;

-(uint16_t) readUint16;

-(uint32_t) readUint32;

-(uint64_t) readUint64;

-(int64_t) readint64;


/// 读取指定长度的data
/// @param len <#len description#>
-(NSData*) readData:(int)len;

-(NSString*) readString;

-(uint32_t) readLenth;
// 字节里是否包含完整的长度
-(BOOL) lengthFull;
// 长度的长度
-(int) lenthLength;
-(NSData*) remainingData;

+(void) numberHNMemcpy:(void*)dest src:(const void *)src count:(unsigned int)count;

@end

NS_ASSUME_NONNULL_END

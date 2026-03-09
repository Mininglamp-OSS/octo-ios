//
//  WKData.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import "WKData.h"
#import "WKSDK.h"
@interface WKDataWrite ()
@property(nonatomic,strong) NSMutableData *buffData;
@property(nonatomic,assign) BOOL isLittleEndian; // 是否是小端编码（默认为大端编码）
@end

@implementation WKDataWrite

+(instancetype) initLittleEndian {
    WKDataWrite *dataWrite = [[WKDataWrite alloc] init];
    dataWrite.isLittleEndian = true;
    return dataWrite;
}

-(instancetype) init {
    self = [super init];
    if(self) {
        self.buffData = [[NSMutableData alloc] init];
    }
    return self;
}

-(void) writeUint8:(uint8_t)v {
   NSData *tmpData = [NSData dataWithBytes:&v length:1];
   [self pushBufferData:tmpData];
}

-(void) writeUint16:(uint16_t)v {
    NSData *tmpData = [NSData dataWithBytes:&v length:2];
    [self pushBufferData:tmpData];
    
}

-(void) writeUint32:(uint32_t)v {
    NSData *tmpData = [NSData dataWithBytes:&v length:4];
    [self pushBufferData:tmpData];
}

-(void) writeUint64:(uint64_t)v {
    NSData *tmpData = [NSData dataWithBytes:&v length:8];
    [self pushBufferData:tmpData];
}

-(void) writeData:(NSData*) data {
    [self.buffData appendData:data];
}

-(void) writeVariableString:(NSString*)v {
    if(v && v.length>0) {
        NSData *data =[v dataUsingEncoding:NSUTF8StringEncoding];
        [self writeUint16:data.length];
        [self.buffData appendData:data];
    }else {
         [self writeUint16:0];
    }
    
}
-(void) pushBufferData:(NSData*)tmpData{
    if(self.isLittleEndian) {
        for (int i=0; i<tmpData.length; i++) {
             [self.buffData appendData:[tmpData subdataWithRange:NSMakeRange(i, 1)]];
        }
    } else {
        for (NSInteger i=tmpData.length-1; i>=0; i--) {
            [self.buffData appendData:[tmpData subdataWithRange:NSMakeRange(i, 1)]];
        }
    }
}

-(NSData*) toData {
    return self.buffData;
}

@end



@interface WKDataRead ()
@property(nonatomic,strong) NSData *buffData;
@property(nonatomic,assign) int offset;
@property(nonatomic,assign) BOOL isLittleEndian; // 是否是大端编码（默认为小端编码）
@end

@implementation WKDataRead

-(instancetype) initWithData:(NSData*) data {
    return [self initWithData:data littleEndian:false];
}
-(instancetype) initWithData:(NSData*) data littleEndian:(BOOL)littleEndian{
    self = [super init];
    if(self) {
        self.buffData =data;
        self.isLittleEndian = littleEndian;
    }
    return self;
}

-(uint8_t) readUint8 {
    uint8_t v;
     [WKDataRead numberHNMemcpy:&v src:[[self.buffData subdataWithRange:NSMakeRange(self.offset, 1)] bytes] count:1];
     self.offset+=1;
    return v;
}

-(uint16_t) readUint16 {
    uint16_t v;
     [WKDataRead numberHNMemcpy:&v src:[[self.buffData subdataWithRange:NSMakeRange(self.offset, 2)] bytes] count:2];
    self.offset+=2;
    return v;
}

-(uint32_t) readUint32 {
    uint32_t v;
     [WKDataRead numberHNMemcpy:&v src:[[self.buffData subdataWithRange:NSMakeRange(self.offset, 4)] bytes] count:4];
    self.offset+=4;
    return v;
}

-(uint64_t) readUint64 {
    uint64_t v;
    [WKDataRead numberHNMemcpy:&v src:[[self.buffData subdataWithRange:NSMakeRange(self.offset, 8)] bytes] count:8];
    self.offset+=8;
    return v;
}

-(int64_t) readint64 {
    int64_t v;
    [WKDataRead numberHNMemcpy:&v src:[[self.buffData subdataWithRange:NSMakeRange(self.offset, 8)] bytes] count:8];
    self.offset+=8;
    return v;
}

-(NSData*) readData:(int)len {
   NSData *data = [self.buffData subdataWithRange:NSMakeRange(self.offset, len)];
    self.offset+=len;
    return data;
}

-(NSString*) readString {
    uint16_t len = [self readUint16];
    if(len == 0) {
        return @"";
    }
   NSData *d = [self.buffData subdataWithRange:NSMakeRange(self.offset, len)];
    self.offset += len;
    
    return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
}


-(BOOL) lengthFull {
    uint32_t rLength = 0;
    uint32_t multiplier = 0;
    int i = self.offset;
    while (multiplier < 27) {
        if(self.buffData.length<i+1) {
            return false;
        }
        uint8_t digit;
        [WKDataRead numberHNMemcpy:&digit src:[[self.buffData subdataWithRange:NSMakeRange(i, 1)] bytes] count:1];
        rLength |= ((uint32_t)digit&127) << multiplier;
        if ((digit & 128) == 0) {
            return true;
        }
        i++;
        multiplier += 7;
    }
    return false;
}

-(uint32_t) readLenth {
    uint32_t rLength = 0;
    uint32_t multiplier = 0;
    while (multiplier < 27) {
        uint8_t digit = [self readUint8];
        rLength |= ((uint32_t)digit&127) << multiplier;
        if ((digit & 128) == 0) {
            break;
        }
        multiplier += 7;
    }
    return rLength;
}

-(int) lenthLength {
    uint32_t rLength = 0;
    uint32_t multiplier = 0;
    int i = self.offset;
    int  lengthL = 0;
    while (multiplier < 27) {
        lengthL ++;
        uint8_t digit;
        [WKDataRead numberHNMemcpy:&digit src:[[self.buffData subdataWithRange:NSMakeRange(i, 1)] bytes] count:1];
        rLength |= ((uint32_t)digit&127) << multiplier;
        if ((digit & 128) == 0) {
            break;
        }
        i++;
        multiplier += 7;
    }
    return lengthL;
}

-(NSData*) remainingData {

    return  [self.buffData subdataWithRange:NSMakeRange(self.offset, self.buffData.length-self.offset)];
}

+(void) numberHNMemcpy:(void*)dest src:(const void *)src count:(unsigned int)count {
    if(count == 8)
    {
        unsigned long long ll;
        memcpy(&ll,src,count);
        ll = bswap_64(ll);
        memcpy(dest,&ll,count);
    }
    else if(count == 4)
    {
        unsigned int i;
        memcpy(&i,src,count);
        i = htonl(i);
        memcpy(dest,&i,count);
    }
    else if(count == 2)
    {
        unsigned short s;
        memcpy(&s,src,count);
        s = htons(s);
        memcpy(dest,&s,count);
    }
    else
    {
        memcpy(dest,src,count);
    }
}

unsigned long long bswap_64(unsigned long long inval)
{
    unsigned long long outval = 0;
    int i=0;
    for(i=0;i<8; i++)
        outval=(outval<<8)+ ((inval >> (i *8))&255);
    return   outval;
}
@end

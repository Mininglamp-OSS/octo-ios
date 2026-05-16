//
//  WKAudioWaveformView.m
//  WuKongBase
//
//  Created by tt on 2021/7/29.
//

#import "WKAudioWaveformView.h"
#import "WKApp.h"
@interface WKAudioWaveformView ()

@property(nonatomic,strong) NSMutableArray<CAShapeLayer*> *itemArray;
@property(nonatomic,strong) NSArray<NSNumber*> *filerSamples;
@property(nonatomic,strong) NSMutableArray *levelArray;
@property(nonatomic,strong) UIColor *tintColorInner;


@property(nonatomic,strong) NSData *waveformInner;

@end

@implementation WKAudioWaveformView


- (void)setWaveform:(NSData *)waveform {
    
    if(_waveformInner && _waveformInner == waveform) {
        return;
    }
    _waveformInner = waveform;
    if(!waveform) {
        return;
    }
   
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self clear];
    if(self.waveform) {
        [self setupItems];
        [self updateItems];
    }
   
}

- (NSData *)waveform {
    return _waveformInner;
}


-(void) clear {
    if(self.itemArray) {
        for (CALayer *layer in self.itemArray) {
            [layer removeFromSuperlayer];
        }
    }
    [self.itemArray removeAllObjects];
    [self.levelArray removeAllObjects];
}

-(CGFloat) barWidth {
    return 2.0f;
}

-(CGFloat) barDensity {
    return 1.5f;
}

- (void)setTintColor:(UIColor *)tintColor {
    _tintColorInner = tintColor;
    for (CAShapeLayer *layer in self.itemArray) {
        layer.fillColor = tintColor.CGColor;
    }
}

- (UIColor *)tintColor {
    return _tintColorInner;
}




-(NSInteger) waveformMaxNum {
    return self.frame.size.width/([self barWidth]+1);
}


- (NSArray *)cutAudioData {
    NSMutableArray *filteredSamplesMA = [[NSMutableArray alloc]init];
    
    Byte waveformBytes[self.waveform.length];
    [self.waveform getBytes:&waveformBytes length:self.waveform.length];
    NSUInteger sampleCount = self.waveform.length;
    
    NSInteger waveformMaxNum = [self waveformMaxNum]; // 波纹数量
    
    uint8_t maxSample = 0;
    

    if(sampleCount<waveformMaxNum) { // 需要扩大
        CGFloat rate = (CGFloat)(waveformMaxNum-sampleCount)/(CGFloat)sampleCount;
        CGFloat expandValue = 0.0f;
        for (NSInteger i=0; i<sampleCount; i++) {
            expandValue += rate;
            uint8_t value  = waveformBytes[i];
            [filteredSamplesMA addObject:@(value)];
            while (expandValue>=1) {
                [filteredSamplesMA addObject:@(value)];
                expandValue = expandValue - 1;
            }
        }
        while (filteredSamplesMA.count<waveformMaxNum) {
            uint8_t value  = waveformBytes[sampleCount - 1];
            [filteredSamplesMA addObject:@(value)];
        }
    }else if(sampleCount>waveformMaxNum) { // 需要缩小
        CGFloat rate =  1-(((CGFloat)(sampleCount- waveformMaxNum)/(CGFloat)sampleCount));
        CGFloat expandValue = rate;
//
        for (NSInteger i=0; i<sampleCount; i++) {
            expandValue += rate;
            uint8_t value  = waveformBytes[i];
            if(expandValue>=1) {
                [filteredSamplesMA addObject:@(value)];
                expandValue = expandValue - 1;
            }
        }
    }else { // 等于
        for (NSInteger i=0; i<sampleCount; i++) {
            uint8_t value  = waveformBytes[i];
            [filteredSamplesMA addObject:@(value)];
        }
    }
    
    for (NSNumber *value in filteredSamplesMA) {
        if (value.intValue > maxSample) {
            maxSample = value.intValue;
        }
    }
    //计算比例因子
    CGFloat scaleFactor = (self.frame.size.height)/maxSample;
    //对所有数据进行“缩放”
    for (NSUInteger i = 0; i < filteredSamplesMA.count; i++) {
        filteredSamplesMA[i] = @([filteredSamplesMA[i] integerValue] * scaleFactor);
    }
    
    return filteredSamplesMA;
}
//比较大小的方法，返回最大值
- (uint8_t)maxValueInArray:(uint8_t[])values ofSize:(NSUInteger)size {
    uint8_t maxvalue = 0;
    for (int i = 0; i < size; i++) {
        
        if (abs(values[i] > maxvalue)) {
            
            maxvalue = values[i];
        }
    }
    return maxvalue;
}

-(void) setupItems {
    self.filerSamples = [self cutAudioData];//得到绘制数据
    
    // 计算音轨数组的平均值
    double avg = 0;
    int sum = 0;
    for (int i = 0; i < self.filerSamples.count; i++) {
        sum += [self.filerSamples[i] intValue];
    }
    avg = sum/self.filerSamples.count;
    
    for(int i = 0 ; i < self.filerSamples.count ; i++){
        // 计算每组数据与平均值的差值
        int Xi = [self.filerSamples[i] intValue];
        CGFloat scale = (Xi - avg)/avg;     // 绘制线条的缩放比
        int baseH = 0;      // 长度基数,   线条长度范围: baseH + 10 ~ baseH + 100
        
        if (scale <= -0.4) {
            [self.levelArray addObject:@(baseH + 10)];
        }else if (scale > -0.4 && scale <= -0.3) {
            [self.levelArray addObject:@(baseH + 20)];
        }else if (scale > -0.3 && scale <= -0.2) {
            [self.levelArray addObject:@(baseH + 30)];
        }else if (scale > -0.2 && scale <= -0.1) {
            [self.levelArray addObject:@(baseH + 40)];
        }else if (scale > -0.1 && scale <= 0) {
            [self.levelArray addObject:@(baseH + 50)];
        }else if (scale > 0 && scale <= 0.1) {
            [self.levelArray addObject:@(baseH + 60)];
        } else if (scale > 0.1 && scale <= 0.2) {
            [self.levelArray addObject:@(baseH + 70)];
        } else if (scale > 0.2 && scale <= 0.3) {
            [self.levelArray addObject:@(baseH + 80)];
        } else if (scale > 0.3 && scale <= 0.4) {
            [self.levelArray addObject:@(baseH + 90)];
        } else if (scale > 0.4) {
            [self.levelArray addObject:@(baseH + 100)];
        }
        
        
        CAShapeLayer *itemline = [CAShapeLayer layer];
        itemline.lineCap       = kCALineCapButt;
        itemline.lineJoin      = kCALineJoinRound;
        [itemline setLineWidth:self.frame.size.width*0.4/(self.filerSamples.count)];
        itemline.fillColor = self.tintColor.CGColor;
        [self.layer addSublayer:itemline];
        [self.itemArray addObject:itemline];
    }


}

- (void)updateItems
{
    UIGraphicsBeginImageContext(self.frame.size);
    
    for(int i=0; i < (self.itemArray.count); i++) {
        
        CAShapeLayer *itemLine = [self.itemArray objectAtIndex:i];
        CGFloat barWidth = [self barWidth];
        itemLine.frame = CGRectMake(barWidth*(float)i*[self barDensity], 0.0f, barWidth, self.frame.size.height);
        CGFloat barHeight = self.filerSamples[i].floatValue;
        
        UIBezierPath *itemLinePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, self.frame.size.height - barHeight, 2.0f, barHeight) cornerRadius:1.0f];
//        y += x;
//        CGPoint point = CGPointMake(y, self.frame.size.height/2+([[self.filerSamples[i] objectAtIndex:i]intValue]+1)*z/2);
//        [itemLinePath moveToPoint:point];
//        CGPoint toPoint = CGPointMake(y, self.frame.size.height/2-([[self.levelArray objectAtIndex:i]intValue]+1)*z/2);
//        [itemLinePath addLineToPoint:toPoint];
        
       
        itemLine.path = [itemLinePath CGPath];
        
    }
    UIGraphicsEndImageContext();
}

- (NSMutableArray *)itemArray {
    if(!_itemArray) {
        _itemArray = [NSMutableArray array];
    }
    return _itemArray;
}

- (NSMutableArray *)levelArray {
    if(!_levelArray) {
        _levelArray = [NSMutableArray array];
    }
    return _levelArray;
}

@end

//
//  WKRNNoise.m
//  WuKongBase
//
//  Created by tt on 2023/2/13.
//

#import "WKRNNoise.h"
#import "rnnoise.h"

#define FRAME_SIZE 480

@implementation WKRNNoise

static WKRNNoise *_instance;
+ (WKRNNoise *)shared {
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(NSError*) rnnoiseProcess:(NSString*)srcFilepath saveFilePath:(NSString*)saveFilePath {
   int result = lim_rnnoiseConvert([srcFilepath cStringUsingEncoding:NSUTF8StringEncoding], [saveFilePath cStringUsingEncoding:NSUTF8StringEncoding]);
    
    if(result != 0) {
        return [NSError errorWithDomain:@"noise fail" code:0 userInfo:nil];
    }
    return  nil;
}

int lim_rnnoiseConvert(const char* noiseFileName, const char* nonoiseFileName) {
    int i;
    int first = 1;
    float x[FRAME_SIZE];
    FILE *f1, *fout;
    DenoiseState *st;
    st = rnnoise_create(NULL);
    
    f1 = fopen(noiseFileName, "rb");
    fout = fopen(nonoiseFileName, "wb");
    if(!f1) {
        return -1;
    }
    while (1) {
        short tmp[FRAME_SIZE];
        fread(tmp, sizeof(short), FRAME_SIZE, f1);
        if (feof(f1)) break;
        for (i=0;i<FRAME_SIZE;i++) x[i] = tmp[i];
        rnnoise_process_frame(st, x, x);
        for (i=0;i<FRAME_SIZE;i++) tmp[i] = x[i];
        if (!first) fwrite(tmp, sizeof(short), FRAME_SIZE, fout);
        first = 0;
      }
      rnnoise_destroy(st);
      fclose(f1);
      fclose(fout);
    return 0;
}



@end

//
//  WidthBandWavToAmr.m
//  SpeakIn
//
//  Created by 势必可赢 on 16/8/18.
//  Copyright © 2016年 势必可赢. All rights reserved.
//

#include "WidthBandWavToAmr.h"


void usage(const char* name) {
    fprintf(stderr, "%s [-r bitrate] [-d] in.wav out.amr\n", name);
}

int findMode(const char* str) {
    struct {
        int mode;
        int rate;
    }
    modes[] = {
        { 0,  6600 },
        { 1,  8850 },
        { 2, 12650 },
        { 3, 14250 },
        { 4, 15850 },
        { 5, 18250 },
        { 6, 19850 },
        { 7, 23050 },
        { 8, 23850 }
    };
    int rate = atoi(str);
    int closest = -1;
    int closestdiff = 0;
    unsigned int i;
    for (i = 0; i < sizeof(modes)/sizeof(modes[0]); i++) {
        if (modes[i].rate == rate)
            return modes[i].mode;
        if (closest < 0 || closestdiff > abs(modes[i].rate - rate)) {
            closest = i;
            closestdiff = abs(modes[i].rate - rate);
        }
    }
    fprintf(stderr, "Using bitrate %d\n", modes[closest].rate);
    return modes[closest].mode;
}


int EncodeWidthBandWAVEFileToAMRFile(const char* infile, const char* outfile)
{
    int mode = 8;  //使用23850最高比特率
    int dtx = 0;   //不开启dtx
    //    const char *infile, *outfile;
    FILE* out;
    void *wav, *amr;
    int format, sampleRate, channels, bitsPerSample;
    int inputSize;
    uint8_t* inputBuf;
    
    
    wav = wav_read_open(infile);
    if (!wav) {
        fprintf(stderr, "Unable to open wav file %s\n", infile);
        return 0;
    }
    if (!wav_get_header(wav, &format, &channels, &sampleRate, &bitsPerSample, NULL)) {
        fprintf(stderr, "Bad wav file %s\n", infile);
        return 0;
    }
    if (format != 1) {
        fprintf(stderr, "Unsupported WAV format %d\n", format);
        return 0;
    }
    if (bitsPerSample != 16) {
        fprintf(stderr, "Unsupported WAV sample depth %d\n", bitsPerSample);
        return 0;
    }
    if (channels != 1)
        fprintf(stderr, "Warning, only compressing one audio channel\n");
    if (sampleRate != 16000)
        fprintf(stderr, "Warning, AMR-WB uses 16000 Hz sample rate (WAV file has %d Hz)\n", sampleRate);
    inputSize = channels*2*320;
    inputBuf = (uint8_t*) malloc(inputSize);
    
    amr = E_IF_init();
    out = fopen(outfile, "wb");
    if (!out) {
        perror(outfile);
        return 0;
    }
    
    fwrite("#!AMR-WB\n", 1, 9, out); //写文件头
    while (1) {
        int read, i, n;
        short buf[320];
        uint8_t outbuf[500];
        
        read = wav_read_data(wav, inputBuf, inputSize);
        read /= channels;
        read /= 2;
        if (read < 320)
            break;
        for (i = 0; i < 320; i++) {
            const uint8_t* in = &inputBuf[2*channels*i];
            buf[i] = in[0] | (in[1] << 8);
        }
        n = E_IF_encode(amr, mode, buf, outbuf, dtx);
        fwrite(outbuf, 1, n, out);
    }
    free(inputBuf);
    fclose(out);
    E_IF_exit(amr);
    wav_read_close(wav);
    return 1;
}



const int sizes[] = { 17, 23, 32, 36, 40, 46, 50, 58, 60, 5, -1, -1, -1, -1, -1, 0 };

int DecodeWidthBandAMRFileToWAVEFile(const char* inputFile, const char* outputFile)
{
    FILE* in;
    char header[9];
    int n;
    void *wav, *amr;
    //    if (argc < 3) {
    //        fprintf(stderr, "%s in.amr out.wav\n", argv[0]);
    //        return 1;
    //   }
    
    in = fopen(inputFile, "rb");
    if (!in) {
        perror(inputFile);
        return 0;
    }
    n = fread(header, 1, 9, in);
    if (n != 9 || memcmp(header, "#!AMR-WB\n", 9)) {
        fprintf(stderr, "Bad header\n");
        return 0;
    }
    
    wav = wav_write_open(outputFile, 16000, 16, 1);
    if (!wav) {
        fprintf(stderr, "Unable to open %s\n", outputFile);
        return 0;
    }
    amr = D_IF_init();
    while (1) {
        uint8_t buffer[500], littleendian[640], *ptr;
        int size, i;
        int16_t outbuffer[320];
        /* Read the mode byte */
        n = fread(buffer, 1, 1, in);
        if (n <= 0)
            break;
        /* Find the packet size */
        size = sizes[(buffer[0] >> 3) & 0x0f];
        if (size < 0)
            break;
        n = fread(buffer + 1, 1, size, in);
        if (n != size)
            break;
        
        /* Decode the packet */
        D_IF_decode(amr, buffer, outbuffer, 0);
        
        /* Convert to little endian and write to wav */
        ptr = littleendian;
        for (i = 0; i < 320; i++) {
            *ptr++ = (outbuffer[i] >> 0) & 0xff;
            *ptr++ = (outbuffer[i] >> 8) & 0xff;
        }
        wav_write_data(wav, littleendian, 640);
    }
    fclose(in);
    D_IF_exit(amr);
    wav_write_close(wav);
    return 1;
}


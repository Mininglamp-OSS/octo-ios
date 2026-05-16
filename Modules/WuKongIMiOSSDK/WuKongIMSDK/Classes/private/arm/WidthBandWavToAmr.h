//
//  WidthBandWavToAmr.h
//  SpeakIn
//
//  Created by 势必可赢 on 16/8/18.
//  Copyright © 2016年 势必可赢. All rights reserved.
// 16K采样率编码和解码

#ifndef WidthBandWavToAmr_h
#define WidthBandWavToAmr_h

#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include "dec_if.h"
#include "enc_if.h"
#include "wavwriter.h"
#include "wavreader.h"

/**
 *  编码
 *
 *  @param infile  wav文件路径
 *  @param outfile amr文件路径
 *
 *  @return
 */
int EncodeWidthBandWAVEFileToAMRFile(const char* infile, const char* outfile);


/**
 *  解码
 *
 *  @param inputFile  amr文件路径
 *  @param outputFile wav文件路径
 *
 *  @return 
 */
int DecodeWidthBandAMRFileToWAVEFile(const char* inputFile, const char* outputFile);


#endif /* WidthBandWavToAmr_h */

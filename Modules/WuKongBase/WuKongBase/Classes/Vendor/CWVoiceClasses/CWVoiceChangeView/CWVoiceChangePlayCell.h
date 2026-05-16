//
//  CWVoiceChangePlayCell.h
//  QQVoiceDemo
//
//  Created by chavez on 2017/10/11.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CWVoiceChangePlayCell : UIView

@property (nonatomic,copy) NSString *voicePath;
@property (nonatomic,strong) NSIndexPath *indexPath;
@property (nonatomic,copy) NSString *imageName;
@property (nonatomic,copy) NSString *title;
@property (nonatomic,copy) void (^playRecordBlock)(CWVoiceChangePlayCell *cell);
@property (nonatomic,copy) void (^endPlayBlock)(CWVoiceChangePlayCell *cell);

- (void)playingRecord;

- (void)updateLevels;

- (void)endPlay;

@end

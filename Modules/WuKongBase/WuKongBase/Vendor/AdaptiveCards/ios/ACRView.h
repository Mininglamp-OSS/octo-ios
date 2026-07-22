//
//  ACRView.h
//  ACRView
//
//  Copyright © 2021 Microsoft. All rights reserved.
//

#import "ACOAdaptiveCard.h"
#import "ACOHostConfig.h"
#import "ACORenderContext.h"
#import "ACOWarning.h"
#import "ACRActionDelegate.h"
#import "ACRColumnView.h"
#import "ACRIMedia.h"
#import "ACICitationPresenter.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ACRView : ACRColumnView

@property (weak) id<ACRActionDelegate> acrActionDelegate;
@property (weak) id<ACRMediaDelegate> mediaDelegate;
@property NSArray<ACOWarning *> *warnings;
@property (readonly) ACORenderContext *context;
@property (readwrite)ACRTheme theme;
@property (readonly) ACOHostConfig *hostConfig;
@property (nonatomic, assign) BOOL isRenderingInsideBottomSheet;
@property (nonatomic, readonly) id<ACICitationPresenter> citationPresenter;

- (instancetype)init:(ACOAdaptiveCard *)card hostconfig:(ACOHostConfig *)config widthConstraint:(float)width theme:(ACRTheme)theme;

- (instancetype)init:(ACOAdaptiveCard *)card
          hostconfig:(ACOHostConfig *)config
     widthConstraint:(float)width
            delegate:(id<ACRActionDelegate>)acrActionDelegate
               theme:(ACRTheme)theme;

- (NSMutableDictionary *)getImageMap;

- (UIImageView *)getImageView:(NSString *)key;

- (void)setImageView:(NSString *)key view:(UIView *)view;

- (dispatch_queue_t)getSerialQueue;

- (NSMutableDictionary *)getTextMap;

- (ACOAdaptiveCard *)card;

- (UIView *)render;

- (void)setWidthForElememt:(unsigned int)key width:(float)width;

- (float)widthForElement:(unsigned int)key;

- (void)waitForAsyncTasksToFinish;

- (BOOL)hasKVOObserverForImageView:(UIImageView *)imageView;

@end

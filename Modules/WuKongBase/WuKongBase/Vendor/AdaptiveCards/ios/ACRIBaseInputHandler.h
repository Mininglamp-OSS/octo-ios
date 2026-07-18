//
//  ACRIBaseInputHandler
//  ACRIBaseInputHandler.h
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRErrors.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol ACRInputChangeDelegate <NSObject>

-(void)inputValueChanged;

@end

typedef void (^CompletionHandler)(void);

@protocol ACRIBaseInputHandler

@property BOOL isRequired;
@property BOOL hasValidationProperties;
@property BOOL hasVisibilityChanged;
@property NSString *_Nonnull id;

- (BOOL)validate:(NSError *_Nullable *_Nullable)error;
- (void)setFocus:(BOOL)shouldBecomeFirstResponder view:(UIView *_Nullable)view;
- (void)getInput:(NSMutableDictionary *_Nonnull)dictionary;
- (void)addObserverWithCompletion:(CompletionHandler _Nonnull)completion;
- (void)resetInput;

@optional
// should be removed in future as addObserverWithCompletion will be used. Not rmeoving right now because it will break Teams changes using this method.
- (void)addObserverForValueChange:(id<ACRInputChangeDelegate>_Nonnull)delegate;
@end

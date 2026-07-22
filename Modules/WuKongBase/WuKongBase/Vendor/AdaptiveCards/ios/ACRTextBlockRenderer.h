//
//  ACRTextBlockRenderer
//  ACRTextBlockRenderer.h
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRBaseCardElementRenderer.h"
#import "ACRCitationBuilderDelegate.h"

@interface ACRTextBlockRenderer : ACRBaseCardElementRenderer <ACRCitationBuilderDelegate>

+ (ACRTextBlockRenderer *)getInstance;

@end

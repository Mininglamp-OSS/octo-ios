//
//  ACRRichTextBlockRenderer
//  ACRRichTextBlockRenderer.h
//
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "ACRBaseCardElementRenderer.h"
#import "ACRCitationBuilderDelegate.h"

@interface ACRRichTextBlockRenderer : ACRBaseCardElementRenderer <ACRCitationBuilderDelegate>

+ (ACRRichTextBlockRenderer *)getInstance;

@end

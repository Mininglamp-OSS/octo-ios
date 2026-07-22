//
//  ACOCitation.mm
//  AdaptiveCards
//
//  Created by Harika P on 30/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACOCitation.h"

@implementation ACOCitation

- (instancetype)initWithDisplayText:(NSString *)displayText
                     referenceIndex:(NSNumber *)referenceIndex
                              theme:(ACRTheme)theme
{
    self = [super init];
    if (self)
    {
        self.displayText = displayText;
        NSInteger referenceId = [referenceIndex integerValue] - 1;
        self.referenceIndex = @(referenceId);
        self.theme = theme;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
                             theme:(ACRTheme)theme
{
    NSString *displayText = dictionary[@"title"] ?: @"";
    return [self initWithDisplayText:displayText referenceIndex:@(1) theme:theme];
}

@end

//
//  ACRIImageResolver.h
//  AdaptiveCards
//
//  Created by Harika P on 10/11/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACREnums.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ACRIImageResolver <NSObject>

- (UIImage *) getImage:(ACIcon) iconName withTheme:(ACRTheme) theme;

@end

NS_ASSUME_NONNULL_END

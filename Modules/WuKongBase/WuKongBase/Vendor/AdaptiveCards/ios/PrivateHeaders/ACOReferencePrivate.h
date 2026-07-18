//
//  ACOReferencePrivate.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 30/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACOReference.h"
#ifdef __cplusplus
#import "SharedAdaptiveCard.h"
#endif

using namespace AdaptiveCards;

@interface ACOReference ()

#ifdef __cplusplus
- (instancetype)initWithReference:(const std::shared_ptr<References> &)reference;
- (std::shared_ptr<References>)reference;
#endif

@end
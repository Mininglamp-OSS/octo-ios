//
//  ACOReference.mm
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 30/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACOReference.h"
#import "ACOReferencePrivate.h"
#import "ACOAdaptiveCard.h"
#import "ACOAdaptiveCardPrivate.h"
#import "SharedAdaptiveCard.h"
#import "ACRIImageResolver.h"
#import "ACRRegistration.h"

using namespace AdaptiveCards;

@implementation ACOReference {
    std::shared_ptr<References> _reference;
}

typedef NS_ENUM(NSInteger, ACRCitationIcon) {
    ACRAdobeIllustrator = 0,
    ACRAdobePhotoshop,
    ACRAdobeInDesign,
    ACRAdobeFlash,
    ACRMsWord,
    ACRMsExcel,
    ACRMsPowerPoint,
    ACRMsOneNote,
    ACRMsSharePoint,
    ACRMsVisio,
    ACRMsLoop,
    ACRMsWhiteboard,
    ACRCode,
    ACRGif,
    ACRCitationImage,
    ACRPdf,
    ACRSketch,
    ACRSound,
    ACRText,
    ACRVideo,
    ACRZip
};


- (instancetype)initWithReference:(const std::shared_ptr<References> &)reference {
    self = [super init];
    if (self && reference) {
        _reference = reference;
    }
    return self;
}

- (ACOReferenceType)type {
    if (!_reference) {
        return ACOReferenceTypeDocument;
    }
    
    ReferenceType cppType = _reference->GetType();
    switch (cppType) {
        case ReferenceType::AdaptiveCard:
            return ACOReferenceTypeAdaptiveCard;
        case ReferenceType::Document:
        default:
            return ACOReferenceTypeDocument;
    }
}

- (NSString *)abstract {
    if (!_reference) {
        return @"";
    }
    return [NSString stringWithUTF8String:_reference->GetAbstract().c_str()];
}

- (NSString *)title {
    if (!_reference) {
        return @"";
    }
    return [NSString stringWithUTF8String:_reference->GetTitle().c_str()];
}

- (NSString *)url {
    if (!_reference) {
        return @"";
    }
    return [NSString stringWithUTF8String:_reference->GetUrl().c_str()];
}

- (UIImage *)iconForTheme:(ACRTheme)theme
{
    NSObject<ACRIImageResolver> *imageResolver = [[ACRRegistration getInstance] getImageResolver];
    if (!_reference) {
        return nil;
    }
    ACRCitationIcon citationIcon = ACRCitationIcon(_reference->GetIcon());
    ACIcon acIcon = ACIcon(citationIcon);
    return [imageResolver getImage:acIcon withTheme:theme];
}

- (NSArray<NSString *> *)keywords {
    if (!_reference) {
        return @[];
    }
    
    NSMutableArray<NSString *> *keywordArray = [NSMutableArray array];
    std::vector<std::string> cppKeywords = _reference->GetKeywords();
    
    for (const auto& keyword : cppKeywords) {
        [keywordArray addObject:[NSString stringWithUTF8String:keyword.c_str()]];
    }
    
    return [keywordArray copy];
}

- (ACOAdaptiveCard *)content {
    if (!_reference) {
        return nil;
    }
    
    auto content = _reference->GetContent();
    if (!content) {
        return nil;
    }
    
    ACOAdaptiveCard *acoCard = [[ACOAdaptiveCard alloc] init];
    [acoCard setCard:content];
    return acoCard;
}

- (std::shared_ptr<References>)reference {
    return _reference;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        NSString *typeString = dictionary[@"type"];
        ReferenceType cppType = [typeString isEqualToString:@"AdaptiveCardReference"]
            ? ReferenceType::AdaptiveCard
            : ReferenceType::Document;

        NSString *title    = dictionary[@"title"]    ?: @"";
        NSString *abstract = dictionary[@"abstract"] ?: @"";
        NSString *url      = dictionary[@"url"]      ?: @"";
        NSString *iconString = dictionary[@"icon"]   ?: @"image";

        std::vector<std::string> cppKeywords;
        for (NSString *kw in (NSArray<NSString *> *)(dictionary[@"keywords"] ?: @[])) {
            cppKeywords.push_back(std::string([kw UTF8String]));
        }

        _reference = std::make_shared<References>(
            cppType,
            std::string([abstract UTF8String]),
            std::string([title UTF8String]),
            std::string([url UTF8String]),
            cppKeywords
        );
        
        // Set the icon from the dictionary
        try {
            ReferenceIcon cppIcon = ReferenceIconFromString([iconString UTF8String]);
            _reference->SetIcon(cppIcon);
        } catch (const std::out_of_range&) {
            // Use default icon if string doesn't match any enum value
            _reference->SetIcon(ReferenceIcon::Image);
        }
    }
    return self;
}

@end

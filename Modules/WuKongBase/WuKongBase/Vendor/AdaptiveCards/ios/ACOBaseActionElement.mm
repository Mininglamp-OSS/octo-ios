//
//  ACOBaseActionElement
//  ACOBaseActionElement.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//
#import "ACOBaseActionElement.h"
#import "ACRRegistrationPrivate.h"
#import "BaseActionElement.h"
#import "ExecuteAction.h"
#import "OpenUrlAction.h"
#import "SubmitAction.h"
#import "UnknownAction.h"
#import "UtiliOS.h"
#import <Foundation/Foundation.h>

using namespace AdaptiveCards;

@implementation ACOBaseActionElement {
    std::shared_ptr<BaseActionElement> _elem;
    NSString *_tooltip;
    NSString *_inlineTooltip;
}

- (instancetype)init
{
    return [self initWithBaseActionElement:nil];
}

- (instancetype)initWithBaseActionElement:(std::shared_ptr<BaseActionElement> const &)element
{
    self = [super init];
    if (self) {
        [self setElem:element];
    }
    self.isActionFromSplitButtonBottomSheet = NO;
    return self;
}

+ (instancetype)getACOActionElementFromAdaptiveElement:(std::shared_ptr<BaseActionElement> const &)element
{
    ACOBaseActionElement *actionElement = nil;

    if (!element) {
        return nil;
    }

    AdaptiveCards::ActionType type = element->GetElementType();
    if (element->GetElementType() == AdaptiveCards::ActionType::UnknownAction) {
        std::shared_ptr<UnknownAction> unknownAction = std::dynamic_pointer_cast<UnknownAction>(element);
        // we get back a deserialized action object by calling a custom parser registered via host
        actionElement = deserializeUnknownActionToCustomAction(unknownAction);
    } else {
        actionElement = [[ACOBaseActionElement alloc] initWithBaseActionElement:element];
    }

    if (type == ActionType::OpenUrl) {
        actionElement.accessibilityTraits |= UIAccessibilityTraitLink;
    } else if (type == ActionType::UnknownAction) {
        actionElement.accessibilityTraits |= actionElement.accessibilityTraits;
    } else {
        actionElement.accessibilityTraits |= UIAccessibilityTraitButton;
    }
    return actionElement;
}

- (std::shared_ptr<BaseActionElement>)element
{
    return _elem;
}

- (void)setElem:(std::shared_ptr<BaseActionElement> const &)element
{
    if (element) {
        _type = (ACRActionType)element->GetElementType();
        _sentiment = [NSString stringWithCString:element->GetStyle().c_str() encoding:NSUTF8StringEncoding];
    }
    _elem = element;
}

- (NSData *)additionalProperty
{
    if (_elem) {
        Json::Value blob = _elem->GetAdditionalProperties();
        if (blob.empty()) {
            return nil;
        }
        return JsonToNSData(blob);
    }
    return nil;
}

- (NSString *)title
{
    if (_elem) {
        return [NSString stringWithCString:_elem->GetTitle().c_str() encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (NSString *)elementId
{
    if (_elem) {
        return [NSString stringWithCString:_elem->GetId().c_str() encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (NSString *)url
{
    if (_elem && _type == ACROpenUrl) {
        std::shared_ptr<OpenUrlAction> openUrlAction = std::dynamic_pointer_cast<OpenUrlAction>(_elem);
        return [NSString stringWithCString:openUrlAction->GetUrl().c_str() encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (NSString *)data
{
    if (_elem) {
        std::string data;
        if (_type == ACRSubmit) {
            std::shared_ptr<SubmitAction> submitAction = std::dynamic_pointer_cast<SubmitAction>(_elem);
            data = decodeUnicodeEscapes(submitAction->GetDataJson());
        }

        if (_type == ACRExecute) {
            std::shared_ptr<ExecuteAction> executeAction = std::dynamic_pointer_cast<ExecuteAction>(_elem);
            data = executeAction->GetDataJson();
        }

        if (!data.empty()) {
            return [NSString stringWithCString:data.c_str() encoding:NSUTF8StringEncoding];
        }
    }
    return nil;
}

// Decodes \uXXXX (and surrogate-pair \uXXXX\uXXXX) escape sequences,
// replacing them with the actual UTF-8 encoded characters.
std::string decodeUnicodeEscapes(const std::string &jsonString) {
    if (jsonString.empty()) {
        return jsonString;
    }

    std::string result;
    result.reserve(jsonString.size());

    size_t i = 0;
    while (i < jsonString.size()) {
        // Need at least 6 chars for \uXXXX
        if (jsonString[i] == '\\' && i + 5 < jsonString.size() && jsonString[i + 1] == 'u') {
            const std::string hexStr = jsonString.substr(i + 2, 4);
            bool validHex = true;
            for (char c : hexStr) {
                if (!isxdigit((unsigned char)c)) { validHex = false; break; }
            }
            if (validHex) {
                unsigned int codePoint = (unsigned int)std::stoul(hexStr, nullptr, 16);

                // High surrogate (U+D800–U+DBFF): look for a following low surrogate.
                if (codePoint >= 0xD800 && codePoint <= 0xDBFF && i + 11 < jsonString.size() &&
                    jsonString[i + 6] == '\\' && jsonString[i + 7] == 'u') {
                    const std::string lowHex = jsonString.substr(i + 8, 4);
                    bool validLow = true;
                    for (char c : lowHex) {
                        if (!isxdigit((unsigned char)c)) { validLow = false; break; }
                    }
                    if (validLow) {
                        unsigned int low = (unsigned int)std::stoul(lowHex, nullptr, 16);
                        if (low >= 0xDC00 && low <= 0xDFFF) {
                            // UTF-16 surrogate-pair formula (Unicode §3.9 D91):
                            //   0x10000  — base of supplementary planes
                            //   0xD800   — first high-surrogate; subtracted to isolate 10-bit high payload
                            //   << 10    — shift high payload into bits 10–19 of the 20-bit offset
                            //   0xDC00   — first low-surrogate; subtracted to isolate 10-bit low payload
                            uint32_t cp = 0x10000 + ((codePoint - 0xD800) << 10) + (low - 0xDC00);
                            result += (char)(0xF0 | (cp >> 18));
                            result += (char)(0x80 | ((cp >> 12) & 0x3F));
                            result += (char)(0x80 | ((cp >> 6) & 0x3F));
                            result += (char)(0x80 | (cp & 0x3F));
                            i += 12;
                            continue;
                        }
                    }
                }

                // BMP character (U+0000–U+FFFF) — encode as UTF-8.
                if (codePoint < 0x80) {
                    result += (char)codePoint;
                } else if (codePoint < 0x800) {
                    result += (char)(0xC0 | (codePoint >> 6));
                    result += (char)(0x80 | (codePoint & 0x3F));
                } else {
                    result += (char)(0xE0 | (codePoint >> 12));
                    result += (char)(0x80 | ((codePoint >> 6) & 0x3F));
                    result += (char)(0x80 | (codePoint & 0x3F));
                }
                i += 6;
                continue;
            }
        }
        result += jsonString[i];
        i++;
    }

    return result;
}

- (NSString *)verb
{
    if (_elem && _type == ACRExecute) {
        std::shared_ptr<ExecuteAction> executeAction = std::dynamic_pointer_cast<ExecuteAction>(_elem);
        return [NSString stringWithCString:executeAction->GetVerb().c_str() encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (BOOL)isEnabled
{
    if (_elem) {
        return _elem->GetIsEnabled();
    }
    return YES;
}

- (BOOL)shouldFlipInRtl
{
    if (_elem) {
        return _elem->GetIsRtl();
    }
    return NO;
}

- (NSArray<ACOBaseActionElement *> *)menuActions
{
    NSMutableArray *menuActions = [NSMutableArray array];
    const std::vector<std::shared_ptr<AdaptiveCards::BaseActionElement>> m_menuActions = _elem->GetMenuActions();
    
    for (auto &action : m_menuActions) {
        ACOBaseActionElement *acoElem = [ACOBaseActionElement getACOActionElementFromAdaptiveElement:action];
        [menuActions addObject:acoElem];
    }
    return menuActions;
}

- (NSString *)elementIconUrl
{
    if (_elem) {
        return [NSString stringWithCString:_elem->GetIconUrl().c_str() encoding:[NSString defaultCStringEncoding]];
    }
    return nil;
}

- (BOOL)meetsRequirements:(ACOFeatureRegistration *)featureReg
{
    if (_elem) {
        const std::shared_ptr<FeatureRegistration> sharedFReg = [featureReg getSharedFeatureRegistration];
        return _elem->MeetsRequirements(*sharedFReg.get());
    }
    return false;
}

+ (NSNumber *)getKey:(ACRActionType)actionType
{
    NSNumber *key = nil;
    switch (actionType) {
        case ACRShowCard:
            key = [NSNumber numberWithInt:static_cast<int>(ActionType::ShowCard)];
            break;
        case ACRSubmit:
            key = [NSNumber numberWithInt:static_cast<int>(ActionType::Submit)];
            break;
        case ACROpenUrl:
            key = [NSNumber numberWithInt:static_cast<int>(ActionType::OpenUrl)];
            break;
        case ACRPopover:
            key = [NSNumber numberWithInt:static_cast<int>(ActionType::Popover)];
            break;
        case ACRToggleVisibility:
            key = [NSNumber numberWithInt:static_cast<int>(ActionType::ToggleVisibility)];
            break;
        case ACRExecute:
            key = [NSNumber numberWithInt:static_cast<int>(ActionType::Execute)];
            break;
        case ACROverflow:
            key = [NSNumber numberWithInt:static_cast<int>(ActionType::Overflow)];
            break;
        case ACRUnknownAction:
        default:
            key = [NSNumber numberWithInt:static_cast<int>(ActionType::UnknownAction)];
    }

    return key;
}

- (NSString *)tooltip
{
    if (_tooltip && _tooltip.length) {
        return _tooltip;
    }

    if (_elem && !_elem->GetTooltip().empty()) {
        _tooltip = [NSString stringWithCString:_elem->GetTooltip().c_str() encoding:NSUTF8StringEncoding];
        return _tooltip;
    }

    return nil;
}

- (void)setTooltip:(NSString *)tooltip
{
    if (tooltip) {
        _tooltip = [tooltip copy];
    }
}

- (NSString *)inlineTooltip
{
    if (self.tooltip) {
        if (!_inlineTooltip) {
            _inlineTooltip = [self.tooltip copy];
        }
    } else if (self.title) {
        _inlineTooltip = self.title;
    }

    return _inlineTooltip;
}

@end

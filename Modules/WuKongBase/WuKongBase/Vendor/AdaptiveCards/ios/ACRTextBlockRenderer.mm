//
//  ACRTextBlockRenderer
//  ACRTextBlockRenderer.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACOAdaptiveCardPrivate.h"
#import "ACRTextBlockRenderer.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACRContentHoldingUIView.h"
#import "ACRRegistration.h"
#import "ACRUILabel.h"
#import "ACRView.h"
#import "DateTimePreparsedToken.h"
#import "DateTimePreparser.h"
#import "HostConfig.h"
#import "MarkDownParser.h"
#import "TextBlock.h"
#import "TextInput.h"
#import "UtiliOS.h"
#import "ARCGridViewLayout.h"
#import "TSExpressionObjCBridge.h"
#import "ACRViewTextAttachment.h"
#import "ACRViewAttachingTextView.h"
#import "ACRCitationBuilder.h"

@implementation ACRTextBlockRenderer {
    ACRCitationBuilder *_citationBuilder;
}

NSString * const DYNAMIC_TEXT_PROP = @"text.dynamic";

#pragma mark - Lazy Properties

- (ACRCitationBuilder *)citationBuilder {
    if (!_citationBuilder) {
        _citationBuilder = [[ACRCitationBuilder alloc] initWithDelegate:self];
    }
    return _citationBuilder;
}

+ (ACRTextBlockRenderer *)getInstance
{
    static ACRTextBlockRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRTextBlock;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
          rootView:(ACRView *)rootView
            inputs:(NSMutableArray *)inputs
   baseCardElement:(ACOBaseCardElement *)acoElem
        hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<TextBlock> txtBlck = std::dynamic_pointer_cast<TextBlock>(elem);
    
    if (txtBlck->GetText().empty()) {
        return nil;
    }
    
    ACRViewAttachingTextView *lab = [[ACRViewAttachingTextView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    lab.backgroundColor = [UIColor clearColor];
    
    lab.style = [viewGroup style];
    NSMutableAttributedString *content = nil;
    if (rootView) {
        NSMutableDictionary *textMap = [rootView getTextMap];
        NSNumber *number = [NSNumber numberWithUnsignedLongLong:(unsigned long long)txtBlck.get()];
        NSString *key = [number stringValue];
        NSDictionary *data = nil;
        NSData *htmlData = nil;
        NSDictionary *options = nil;
        NSDictionary *descriptor = nil;
        NSString *text = nil;
        NSObject<ACRIFeatureFlagResolver> *featureFlagResolver = [[ACRRegistration getInstance] getFeatureFlagResolver];
        
        if (![textMap objectForKey:key] || rootView.context.isFirstRowAsHeaders) {
            RichTextElementProperties textProp;
            TexStylesToRichTextElementProperties(txtBlck, [acoConfig getHostConfig]->GetTextStyles().columnHeader, textProp);
            buildIntermediateResultForText(rootView, acoConfig, textProp, key);
        }
        
        data = textMap[key];
        htmlData = data[@"html"];
        options = data[@"options"];
        descriptor = data[@"descriptor"];
        text = data[@"nonhtml"];
        
        std::shared_ptr<AdaptiveCard> card = [[rootView card] card];
        BOOL isStringResourceEnabled = [featureFlagResolver boolForFlag:@"isStringResourceEnabled"] ?: NO;
        if (isStringResourceEnabled && text != nil)
        {
            std::string replacedText = AdaptiveCard::ReplaceStringResources([text UTF8String], card->GetResources(), GetDeviceLanguageLocale());
            text = [NSString stringWithUTF8String:replacedText.c_str()];
        }

        // Initializing NSMutableAttributedString for HTML rendering is very slow
        if (htmlData) {
            content = [[NSMutableAttributedString alloc] initWithData:htmlData options:options documentAttributes:nil error:nil];
            // Drop newline char
            [content deleteCharactersInRange:NSMakeRange([content length] - 1, 1)];
            
            UpdateFontWithDynamicType(content);
            
            lab.selectable = YES;
            lab.dataDetectorTypes = UIDataDetectorTypeLink | UIDataDetectorTypePhoneNumber;
            lab.userInteractionEnabled = YES;
        } else {
            // if html rendering is skipped, remove p tags from both ends (<p>, </p>)
            content = [[NSMutableAttributedString alloc] initWithString:text attributes:descriptor];
        }
        lab.selectable = YES;
        lab.userInteractionEnabled = YES;
        BOOL isCitationsEnabled = [featureFlagResolver boolForFlag:@"isCitationsEnabled"] ?: NO;
        if (isCitationsEnabled)
        {
            content = [[[self citationBuilder] buildCitationsFromNSLinkAttributesInAttributedString:content
                                                                                          rootView:rootView] mutableCopy];
        }
        
        lab.textContainer.lineFragmentPadding = 0;
        lab.textContainerInset = UIEdgeInsetsZero;
        lab.layoutManager.usesFontLeading = false;
        
        // Set paragraph style such as line break mode and alignment
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = [ACOHostConfig getTextBlockAlignment:txtBlck->GetHorizontalAlignment().value_or(HorizontalAlignment::Left) context:rootView.context];
        
        auto sharedStyle = txtBlck->GetStyle();
        auto backUpColor = sharedStyle.has_value() ? txtBlck->GetTextColor().value_or(config->GetTextStyles().heading.color) : txtBlck->GetTextColor().value_or(ForegroundColor::Default);
        auto backUpIsSubtle = sharedStyle.has_value() ? txtBlck->GetIsSubtle().value_or(config->GetTextStyles().heading.isSubtle) : txtBlck->GetIsSubtle().value_or(false);
        
        // Obtain text color to apply to the attributed string
        ACRContainerStyle style = lab.style;
        auto foregroundColor = [acoConfig getTextBlockColor:style textColor:backUpColor subtleOption:backUpIsSubtle];
        
        // Add paragraph style, text color, text weight as attributes to a NSMutableAttributedString, content.
        
        [content addAttributes:@{
            NSParagraphStyleAttributeName : paragraphStyle,
            NSForegroundColorAttributeName : foregroundColor,
        }
                         range:NSMakeRange(0, content.length)];
        
        if (!txtBlck->GetLabelFor().empty() && TextInput().getIsRequired(txtBlck->GetLabelFor()))
        {
            RichTextElementProperties redStarProperties;
            redStarProperties.SetTextColor(ForegroundColor::Attention);
            NSAttributedString *redStar = initAttributedText(acoConfig, " *", redStarProperties, [viewGroup style]);
            [content appendAttributedString:redStar];
        }
        
        lab.textContainer.lineBreakMode = NSLineBreakByTruncatingTail;
        lab.attributedText = content;
        lab.accessibilityLabel = content.string;
        // if accessibility label is the same as accessibility value, clear accessibility value
        // this prevents the same content from being repeated twice in voiceover
        if (lab.accessibilityValue != nil && [lab.accessibilityValue isEqualToString:lab.accessibilityLabel]) {
            lab.accessibilityValue = @"";
        }
        if ([content.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length == 0) {
            lab.accessibilityValue = @"";
            lab.isAccessibilityElement = NO;
        }
    }
    
    lab.translatesAutoresizingMaskIntoConstraints = NO;
    
    lab.textContainer.maximumNumberOfLines = int(txtBlck->GetMaxLines());
    if (!lab.textContainer.maximumNumberOfLines && !txtBlck->GetWrap()) {
        lab.textContainer.maximumNumberOfLines = 1;
    }
    
    if (txtBlck->GetStyle() == TextStyle::Heading || rootView.context.isFirstRowAsHeaders) {
        lab.accessibilityTraits |= UIAccessibilityTraitHeader;
    }
    
    lab.editable = NO;
    
    [lab setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    
    if (txtBlck->GetHeight() == HeightType::Auto) {
        [lab setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
    } else {
        [lab setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    }
    
    configRtl(lab, rootView.context);
    
    //  Expression evaluation for dynamic text property
    if ([TSExpressionObjCBridge isExpressionEvalEnabled])
    {
        [self handleExpressionEvaluationForTextBlock:lab rootView:rootView baseCardElement:acoElem];
    }
    
    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:lab withAreaName:areaName];
    
    return lab;
}

#pragma mark - Expression Evaluation Helper
- (void)handleExpressionEvaluationForTextBlock:(ACRViewAttachingTextView *)label
                                      rootView:(ACRView *)rootView
                               baseCardElement:(ACOBaseCardElement *)acoElem
{
    NSData *jsonData = [acoElem additionalProperty];
    NSError *jsonError = nil;
    NSDictionary *additionalProperties = nil;
    if (jsonData)
    {
        additionalProperties = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
        if (additionalProperties && [additionalProperties isKindOfClass:[NSDictionary class]])
        {
            NSString *titleDynamic = additionalProperties[DYNAMIC_TEXT_PROP];
            
            [self evaluateDynamicProperties:titleDynamic
                                      label:label];
        }
    }
}

- (void)evaluateDynamicProperties:(NSString * _Nullable)textDynamic
                            label:(ACRViewAttachingTextView *)label
{
    if (textDynamic && [textDynamic length] > 0)
    {
        [self evaluateExpression:textDynamic completion:^(id value, NSError *error)
         {
            if ([value isKindOfClass:[NSString class]] && [((NSString *)value) length] > 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [label setText:value];
                });
            }
        }];
    }
}

/// Evaluates an expression string using the Swift ObjCExpressionEvaluator bridge.
/// Calls the completion block with success/failure and result/error.
- (void)evaluateExpression:(NSString *)expression completion:(void (^)(id _Nullable result, NSError * _Nullable error))completion
{
    [TSExpressionObjCBridge evaluateExpression:expression withData:nil completion:^(NSObject * _Nullable evalResult, NSError * _Nullable evalError)
     {
        if (completion)
        {
            completion(evalResult, evalError);
        }
    }];
}

@end

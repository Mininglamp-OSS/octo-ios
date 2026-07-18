//
//  ACRRichTextBlockRenderer
//  ACRRichTextBlockRenderer.mm
//
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "ACOAdaptiveCardPrivate.h"
#import "ACRRichTextBlockRenderer.h"
#import "ACRCitationBuilder.h"
#import "ACRViewTextAttachment.h"
#import "ACOBaseActionElementPrivate.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOCitation.h"
#import "ACOHostConfigPrivate.h"
#import "ACRAggregateTarget.h"
#import "ACRContentHoldingUIView.h"
#import "ACRRegistration.h"
#import "ACRTapGestureRecognizerFactory.h"
#import "ACRUILabel.h"
#import "ACRView.h"
#import "CitationRun.h"
#import "DateTimePreparsedToken.h"
#import "DateTimePreparser.h"
#import "HostConfig.h"
#import "MarkDownParser.h"
#import "RichTextBlock.h"
#import "TextRun.h"
#import "TextInput.h"
#import "UtiliOS.h"
#import "ACRViewAttachingTextView.h"

@implementation ACRRichTextBlockRenderer {
    ACRCitationBuilder *_citationBuilder;
}

#pragma mark - Lazy Properties

- (ACRCitationBuilder *)citationBuilder {
    if (!_citationBuilder) {
        _citationBuilder = [[ACRCitationBuilder alloc] initWithDelegate:self];
    }
    return _citationBuilder;
}

+ (ACRRichTextBlockRenderer *)getInstance
{
    static ACRRichTextBlockRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRRichTextBlock;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
           rootView:(ACRView *)rootView
             inputs:(NSMutableArray *)inputs
    baseCardElement:(ACOBaseCardElement *)acoElem
         hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<RichTextBlock> rTxtBlck = std::dynamic_pointer_cast<RichTextBlock>(elem);
    
    ACRViewAttachingTextView *lab = [[ACRViewAttachingTextView alloc] initWithFrame:CGRectMake(0, 0, viewGroup.frame.size.width, 0)];

    lab.backgroundColor = [UIColor clearColor];
    lab.style = [viewGroup style];
    // Apple Bug: without setting editable to YES, VO link navigation in iOS 12 and above
    // doesn't work.
    lab.editable = YES;
    lab.delegate = lab;
    lab.textContainer.lineFragmentPadding = 0;
    lab.textContainerInset = UIEdgeInsetsZero;
    lab.layoutManager.usesFontLeading = false;

    NSMutableAttributedString *content = [[NSMutableAttributedString alloc] init];
    if (rootView) {
        NSMutableDictionary *textMap = [rootView getTextMap];
        NSObject<ACRIFeatureFlagResolver> *featureFlagResolver = [[ACRRegistration getInstance] getFeatureFlagResolver];
        BOOL hasGestureRecognizerAdded = NO;
        BOOL hasLongPressGestureRecognizerAdded = NO;
        for (const auto &inlineText : rTxtBlck->GetInlines()) {
            switch (inlineText->GetInlineType()) {
                case InlineElementType::TextRun:
                {
                    std::shared_ptr<TextRun> textRun = std::static_pointer_cast<TextRun>(inlineText);
                    if (textRun) {
                        NSNumber *number =
                            [NSNumber numberWithUnsignedLongLong:(unsigned long long)textRun.get()];
                        NSString *key = [number stringValue];
                        NSData *htmlData = nil;
                        NSDictionary *options = nil;
                        NSDictionary *descriptor = nil;
                        NSString *text = nil;

                        if (![textMap objectForKey:key]) {
                            RichTextElementProperties textProp;
                            TextRunToRichTextElementProperties(textRun, textProp);
                            buildIntermediateResultForText(rootView, acoConfig, textProp, key);
                        }

                        NSDictionary *data = textMap[key];
                        if (data) {
                            htmlData = data[@"html"];
                            options = data[@"options"];
                            descriptor = data[@"descriptor"];
                            text = data[@"nonhtml"];
                        }
                        
                        std::shared_ptr<AdaptiveCard> card = [[rootView card] card];
                        BOOL isStringResourceEnabled = [featureFlagResolver boolForFlag:@"isStringResourceEnabled"] ?: NO;
                        if (isStringResourceEnabled && text != nil)
                        {
                            std::string replacedText = AdaptiveCard::ReplaceStringResources([text UTF8String], card->GetResources(), GetDeviceLanguageLocale());
                            text = [NSString stringWithUTF8String:replacedText.c_str()];
                        }

                        NSMutableAttributedString *textRunContent = nil;
                        // Initializing NSMutableAttributedString for HTML rendering is very slow
                        if (htmlData) {
                            textRunContent = [[NSMutableAttributedString alloc] initWithData:htmlData
                                                                                     options:options
                                                                          documentAttributes:nil
                                                                                       error:nil];
                            UpdateFontWithDynamicType(textRunContent);

                            lab.selectable = YES;
                            lab.dataDetectorTypes = UIDataDetectorTypeLink | UIDataDetectorTypePhoneNumber;
                            lab.userInteractionEnabled = YES;
                        } else {
                            textRunContent = [[NSMutableAttributedString alloc] initWithString:text
                                                                                    attributes:descriptor];
                        }
                        // Set paragraph style such as line break mode and alignment
                        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
                        paragraphStyle.alignment =
                            [ACOHostConfig getTextBlockAlignment:rTxtBlck->GetHorizontalAlignment().value_or(HorizontalAlignment::Left)
                                                         context:rootView.context];

                        // Obtain text color to apply to the attributed string
                        ACRContainerStyle style = lab.style;
                        auto textColor = textRun->GetTextColor().value_or(ForegroundColor::Default);
                        auto foregroundColor = [acoConfig getTextBlockColor:style
                                                                  textColor:textColor
                                                               subtleOption:textRun->GetIsSubtle().value_or(false)];

                        // Config and add Select Action
                        std::shared_ptr<BaseActionElement> baseAction = textRun->GetSelectAction();
                        ACOBaseActionElement *acoAction = [[ACOBaseActionElement alloc] initWithBaseActionElement:baseAction];
                        if (baseAction && [acoAction isEnabled]) {
                            NSObject *target;
                            if (ACRRenderingStatus::ACROk ==
                                buildTarget([rootView getSelectActionsTargetBuilderDirector], acoAction,
                                            &target)) {
                                NSRange selectActionRange = NSMakeRange(0, textRunContent.length);

                                [textRunContent addAttribute:NSLinkAttributeName
                                                       value:target
                                                       range:selectActionRange];

                                if (!hasGestureRecognizerAdded) {
                                    [ACRTapGestureRecognizerFactory
                                        addTapGestureRecognizerToUITextView:lab
                                                                     target:(NSObject<ACRSelectActionDelegate>
                                                                                 *)target
                                                                   rootView:rootView
                                                                 hostConfig:acoConfig];
                                    hasGestureRecognizerAdded = YES;
                                }

                                if (acoAction.inlineTooltip && [acoAction.inlineTooltip length]) {
                                    [((ACRBaseTarget *)target) setTooltip:lab toolTipText:acoAction.inlineTooltip];
                                    if (!hasLongPressGestureRecognizerAdded) {
                                        UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:lab action:@selector(handleInlineAction:)];
                                        [lab addGestureRecognizer:recognizer];
                                        hasLongPressGestureRecognizerAdded = YES;
                                    }
                                }

                                foregroundColor = UIColor.linkColor;
                            }
                        }

                        // apply hightlight to textrun
                        if (textRun->GetHighlight()) {
                            UIColor *highlightColor = [acoConfig getHighlightColor:style
                                                                   foregroundColor:textRun->GetTextColor().value_or(ForegroundColor::Default)
                                                                      subtleOption:textRun->GetIsSubtle().value_or(false)];
                            #if TARGET_OS_VISION
                            // Reduce alpha component and add shadow to ensure is visible on Vision Pro
                            highlightColor = [highlightColor colorWithAlphaComponent:0.3];
                            
                            NSShadow *shadow = [[NSShadow alloc] init];
                            [shadow setShadowColor:[UIColor darkGrayColor]];
                            [shadow setShadowOffset:CGSizeMake(0, 1.0f)];
                            [textRunContent addAttribute:NSShadowAttributeName
                                                   value:shadow
                                                   range:NSMakeRange(0, textRunContent.length)];
                            #endif
                            
                            [textRunContent addAttribute:NSBackgroundColorAttributeName
                                                   value:highlightColor
                                                   range:NSMakeRange(0, textRunContent.length)];
                        }

                        if (textRun->GetStrikethrough()) {
                            [textRunContent addAttribute:NSStrikethroughStyleAttributeName
                                                   value:[NSNumber numberWithInteger:NSUnderlineStyleSingle]
                                                   range:NSMakeRange(0, textRunContent.length)];
                        }

                        if (textRun->GetUnderline()) {
                            [textRunContent addAttribute:NSUnderlineStyleAttributeName
                                                   value:[NSNumber numberWithInteger:NSUnderlineStyleSingle]
                                                   range:NSMakeRange(0, textRunContent.length)];
                        }

                        // Add paragraph style, text color, text weight as attributes to a
                        // NSMutableAttributedString, content.
                        [textRunContent addAttributes:@{
                            NSParagraphStyleAttributeName : paragraphStyle,
                            NSForegroundColorAttributeName : foregroundColor,
                        }
                                                range:NSMakeRange(0, textRunContent.length)];

                        [content appendAttributedString:textRunContent];
                    }
                    break;
                }
                case InlineElementType::CitationRun:
                {
                    BOOL isCitationsEnabled = [featureFlagResolver boolForFlag:@"isCitationsEnabled"] ?: NO;
                    if (isCitationsEnabled)
                    {
                        std::shared_ptr<CitationRun> citationRun = std::static_pointer_cast<CitationRun>(inlineText);
                        if (citationRun) {
                            NSNumber *number =
                            [NSNumber numberWithUnsignedLongLong:(unsigned long long)citationRun.get()];
                            NSString *key = [number stringValue];
                            NSString *text = nil;
                            NSDictionary *data = textMap[key];
                            if (data) {
                                text = data[@"nonhtml"];
                                NSNumber *referenceId = @(citationRun->GetReferenceIndex());
                                ACOCitation *citation = [[ACOCitation alloc] initWithDisplayText:text
                                                                                  referenceIndex:referenceId
                                                                                           theme:rootView.theme];
                                NSArray<ACOReference *> *references = [[rootView card] references];
                                NSAttributedString *citationRunContent = [[self citationBuilder] buildCitationAttachmentWithCitation:citation
                                                                                                                          references:references
                                                                                                                           presenter:rootView.citationPresenter];
                                [content appendAttributedString:citationRunContent];
                            }
                        }
                    }
                    break;
                }
                default:
                    break;
            }
        }
        
        if (!rTxtBlck->GetLabelFor().empty() && TextInput().getIsRequired(rTxtBlck->GetLabelFor()))
        {
            RichTextElementProperties redStarProperties;
            redStarProperties.SetTextColor(ForegroundColor::Attention);
            NSAttributedString *redStar = initAttributedText(acoConfig, " *", redStarProperties, [viewGroup style]);
            [content appendAttributedString:redStar];
        }
    }

    lab.textContainer.lineBreakMode = NSLineBreakByTruncatingTail;
    lab.attributedText = content;
    if ([content.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length == 0) {
        lab.accessibilityValue = @"";
        lab.isAccessibilityElement = NO;
    } else {
        lab.isAccessibilityElement = YES;
    }
    lab.area = lab.frame.size.width * lab.frame.size.height;

    lab.translatesAutoresizingMaskIntoConstraints = NO;

    HorizontalAlignment adaptiveAlignment = rTxtBlck->GetHorizontalAlignment().value_or(HorizontalAlignment::Left);

    if (adaptiveAlignment == HorizontalAlignment::Left) {
        lab.textAlignment = NSTextAlignmentLeft;
    }
    if (adaptiveAlignment == HorizontalAlignment::Right) {
        lab.textAlignment = NSTextAlignmentRight;
    }
    if (adaptiveAlignment == HorizontalAlignment::Center) {
        lab.textAlignment = NSTextAlignmentCenter;
    }

    lab.textContainer.maximumNumberOfLines = 0;

    if (rTxtBlck->GetHeight() == HeightType::Auto) {
        [lab setContentCompressionResistancePriority:UILayoutPriorityRequired
                                             forAxis:UILayoutConstraintAxisVertical];
        [lab setContentHuggingPriority:UILayoutPriorityDefaultHigh
                               forAxis:UILayoutConstraintAxisVertical];
    } else {
        [lab setContentHuggingPriority:UILayoutPriorityDefaultLow
                               forAxis:UILayoutConstraintAxisVertical];
        [lab setContentCompressionResistancePriority:UILayoutPriorityRequired
                                             forAxis:UILayoutConstraintAxisVertical];
    }

    [lab setContentCompressionResistancePriority:UILayoutPriorityRequired
                                         forAxis:UILayoutConstraintAxisHorizontal];

    [lab setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

    configRtl(lab, rootView.context);

    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:lab withAreaName:areaName];

    return lab;
}

@end

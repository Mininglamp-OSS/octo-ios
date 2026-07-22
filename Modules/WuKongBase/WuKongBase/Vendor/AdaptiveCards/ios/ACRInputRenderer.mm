//
//  ACRInputRenderer
//  ACRInputRenderer.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRInputRenderer.h"
#import "ACOBaseActionElement.h"
#import "ACOBaseActionElementPrivate.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOBundle.h"
#import "ACOHostConfigPrivate.h"
#import "ACRActionOpenURLRenderer.h"
#import "ACRAggregateTarget.h"
#import "ACRButton.h"
#import "ACRContentHoldingUIView.h"
#import "ACRInputLabelViewPrivate.h"
#import "ACRQuickReplyMultilineView.h"
#import "ACRQuickReplyView.h"
#import "ACRSeparator.h"
#import "ACRShowCardTarget.h"
#import "ACRTextField.h"
#import "ACRTextInputHandler.h"
#import "ACRTextView.h"
#import "ACRToggleVisibilityTarget.h"
#import "ACRUIImageView.h"
#import "TextInput.h"
#import "UtiliOS.h"

@implementation ACRInputRenderer

+ (ACRInputRenderer *)getInstance
{
    static ACRInputRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRTextInput;
}

+ (ACRTextField *)configTextFiled:(std::shared_ptr<TextInput> const &)inputBlock renderAction:(BOOL)renderAction rootView:(ACRView *)rootView viewGroup:(UIView<ACRIContentHoldingView> *)viewGroup
{
    ACRTextField *txtInput = nil;
    switch (inputBlock->GetTextInputStyle()) {
        case TextInputStyle::Email: {
            txtInput = [[ACRTextEmailField alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
            break;
        }
        case TextInputStyle::Tel: {
            txtInput = [[ACRTextTelelphoneField alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
#if !TARGET_OS_VISION
            CGRect frame = CGRectMake(0, 0, viewGroup.frame.size.width, 30);
            UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:frame];
            UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:txtInput action:@selector(dismissNumPad)];
            [toolBar setItems:@[ doneButton, flexSpace ] animated:NO];
            [toolBar sizeToFit];
            txtInput.inputAccessoryView = toolBar;
#endif
            break;
        }
        case TextInputStyle::Url: {
            txtInput = [[ACRTextUrlField alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
            break;
        }
        case TextInputStyle::Password: {
            txtInput = [[ACRTextField alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
            txtInput.secureTextEntry = YES;
            break;
        }
        case TextInputStyle::Text:
        default: {
            txtInput = [[ACRTextField alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
            break;
        }
    }
    txtInput.placeholder = [NSString stringWithCString:inputBlock->GetPlaceholder().c_str()
                                              encoding:NSUTF8StringEncoding];
    txtInput.text = [NSString stringWithCString:inputBlock->GetValue().c_str() encoding:NSUTF8StringEncoding];

    txtInput.allowsEditingTextAttributes = YES;
    return txtInput;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
           rootView:(ACRView *)rootView
             inputs:(NSMutableArray *)inputs
    baseCardElement:(ACOBaseCardElement *)acoElem
         hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<TextInput> inputBlck = std::dynamic_pointer_cast<TextInput>(elem);
    std::shared_ptr<BaseActionElement> action = inputBlck->GetInlineAction();
    UIView *inputview = nil;
    ACRTextField *txtInput = nil;
    ACRTextView *txtview = nil;
    ACRButton *button = nil;
    ACRQuickReplyMultilineView *multilineview = nil;
    ACRQuickReplyView *quickReplyView = nil;

    BOOL renderAction = NO;
    if (action != nullptr && [acoConfig getHostConfig]->GetSupportsInteractivity()) {
        if (action->GetElementType() == ActionType::ShowCard) {
            if ([acoConfig getHostConfig]->GetActions().showCard.actionMode != ActionMode::Inline) {
                renderAction = YES;
            }
        } else {
            renderAction = YES;
        }
    }

    ACRTextInputHandler *textInputHandler = [[ACRTextInputHandler alloc] init:acoElem];

    BOOL isMultiline = (inputBlck->GetTextInputStyle() != TextInputStyle::Password) && inputBlck->GetIsMultiline();
    if (isMultiline) {
        if (renderAction) {
            // if action is defined, load ACRQuickReplyMultilineView nib for customizable UI
            multilineview = [[ACRQuickReplyMultilineView alloc] initWithFrame:CGRectMake(0, 0, viewGroup.frame.size.width, 0)];
            txtview = multilineview.textView;
            // configure it with basecard element since init with decoder can't pass in input param
            [txtview configWithSharedModel:acoElem];
            button = multilineview.button;
            // borderColor is user defined runtime attribute
            if (txtview.borderColor) {
                txtview.layer.borderColor = txtview.borderColor.CGColor;
            }
            [NSLayoutConstraint constraintWithItem:multilineview
                                         attribute:NSLayoutAttributeWidth
                                         relatedBy:NSLayoutRelationGreaterThanOrEqual
                                            toItem:txtview
                                         attribute:NSLayoutAttributeWidth
                                        multiplier:1.0
                                          constant:0]
                .active = YES;
            inputview = multilineview;
            configRtl(multilineview.contentView, rootView.context);
            configRtl(txtview, rootView.context);
            configRtl(button, rootView.context);
            ACRInputLabelView *inputLabelView = [[ACRInputLabelView alloc] initInputLabelView:rootView acoConfig:acoConfig adaptiveInputElement:inputBlck inputView:inputview accessibilityItem:txtview viewGroup:viewGroup dataSource:nil];
            inputview = inputLabelView;
        } else {
            txtview = [[ACRTextView alloc] initWithFrame:CGRectMake(0, 0, viewGroup.frame.size.width, 0) element:acoElem];
            txtview.allowsEditingTextAttributes = YES;
            txtview.layer.borderWidth = 0.5;
            txtview.layer.borderColor = [[UIColor grayColor] CGColor];
            txtview.scrollEnabled = NO;
            txtview.keyboardType = UIKeyboardTypeDefault;
            [txtview.layer setCornerRadius:5.0f];
            inputview = [[ACRInputLabelView alloc] initInputLabelView:rootView acoConfig:acoConfig adaptiveInputElement:inputBlck inputView:txtview accessibilityItem:txtview viewGroup:viewGroup dataSource:nil];
        }
    } else {
        if (renderAction) {
            // if action is defined, load ACRQuickReplyView nib for customizable UI
            quickReplyView = [[ACRQuickReplyView alloc] initWithFrame:CGRectMake(0, 0, viewGroup.frame.size.width, 0)];
            button = quickReplyView.button;
            txtInput = [ACRInputRenderer configTextFiled:inputBlck renderAction:renderAction rootView:rootView viewGroup:viewGroup];
            [quickReplyView addTextField:txtInput];
            inputview = [[ACRInputLabelView alloc] initInputLabelView:rootView acoConfig:acoConfig adaptiveInputElement:inputBlck inputView:quickReplyView accessibilityItem:txtInput viewGroup:viewGroup dataSource:textInputHandler];
            configRtl(quickReplyView.stack, rootView.context);
            configRtl(txtInput, rootView.context);
            configRtl(button, rootView.context);
        } else {
            txtInput = [ACRInputRenderer configTextFiled:inputBlck renderAction:renderAction rootView:rootView viewGroup:viewGroup];
            inputview = [[ACRInputLabelView alloc] initInputLabelView:rootView acoConfig:acoConfig adaptiveInputElement:inputBlck inputView:txtInput accessibilityItem:txtInput viewGroup:viewGroup dataSource:textInputHandler];
        }
        textInputHandler.textField = txtInput;
        txtInput.delegate = textInputHandler;
        SEL textFielsDidChangeSel = NSSelectorFromString(@"textFieldDidChange:");
        if ([textInputHandler respondsToSelector:textFielsDidChangeSel]) {
            [txtInput addTarget:textInputHandler action:textFielsDidChangeSel forControlEvents:UIControlEventEditingChanged];
            }
    }

    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:inputview withAreaName:areaName];

    inputview.translatesAutoresizingMaskIntoConstraints = false;

    // configures for action
    if (renderAction) {
        if (isMultiline) {
            [inputs addObject:txtview];
        } else {
            [inputs addObject:inputview];
        }
        NSString *title = [NSString stringWithCString:action->GetTitle().c_str() encoding:NSUTF8StringEncoding];
        NSDictionary *imageViewMap = [rootView getImageMap];
        NSString *key = [NSString stringWithCString:action->GetIconUrl(ACTheme(rootView.theme)).c_str() encoding:[NSString defaultCStringEncoding]];
        UIImage *img = imageViewMap[key];
        button.iconPlacement = ACRNoTitle;
        button.accessibilityLabel = title;

        if (img) {
            UIImageView *iconView = [[ACRUIImageView alloc] init];
            iconView.image = img;
            [button addSubview:iconView];
            button.iconView = iconView;
            [button setImageView:img withConfig:acoConfig];
        } else if (key.length) {
            NSNumber *number = [NSNumber numberWithUnsignedLongLong:(unsigned long long)action.get()];
            NSString *k = [number stringValue];
            UIImageView *view = [rootView getImageView:k];
            button.iconView = view;
            [button addSubview:view];
            if (view && view.image) {
                [button setImageView:view.image withConfig:acoConfig];
            } else {
                [rootView setImageView:k view:button];
            }
            [NSLayoutConstraint constraintWithItem:button
                                         attribute:NSLayoutAttributeWidth
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:view
                                         attribute:NSLayoutAttributeWidth
                                        multiplier:1.0
                                          constant:0]
                .active = YES;

        } else {
            [button setTitle:title forState:UIControlStateNormal];
        }

        ACOBaseActionElement *acoSelectAction = [ACOBaseActionElement getACOActionElementFromAdaptiveElement:action];
        if (!acoSelectAction.tooltip && acoSelectAction.title && key.length) {
            acoSelectAction.tooltip = acoSelectAction.title;
        }

        NSObject *target;
        if (ACRRenderingStatus::ACROk == buildTargetForButton([rootView getQuickReplyTargetBuilderDirector], acoSelectAction, button, &target)) {
            if (action->GetElementType() == ActionType::Submit) {
                quickReplyView.target = (ACRAggregateTarget *)target;
                quickReplyView.userInteractionEnabled = [acoSelectAction isEnabled];
                if (![acoSelectAction isEnabled]) {
                    quickReplyView.accessibilityTraits |= UIAccessibilityTraitNotEnabled;
                }
            } else if (action->GetElementType() == ActionType::OpenUrl) {
                button.accessibilityTraits = UIAccessibilityTraitLink;
            }
            [viewGroup addTarget:target];
        }
    } else {
        [inputs addObject:inputview];
    }

    return inputview;
}

@end

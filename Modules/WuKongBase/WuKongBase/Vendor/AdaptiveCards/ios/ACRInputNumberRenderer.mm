//
//  ACRInputNumberRenderer
//  ACRInputNumberRenderer.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRInputNumberRenderer.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOBundle.h"
#import "ACOHostConfigPrivate.h"
#import "ACRContentHoldingUIView.h"
#import "ACRInputLabelViewPrivate.h"
#import "ACRNumericTextField.h"
#import "ACRTextInputHandler.h"
#import "NumberInput.h"
#import "UtiliOS.h"

@implementation ACRInputNumberRenderer

+ (ACRInputNumberRenderer *)getInstance
{
    static ACRInputNumberRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRNumberInput;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
           rootView:(ACRView *)rootView
             inputs:(NSMutableArray *)inputs
    baseCardElement:(ACOBaseCardElement *)acoElem
         hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<NumberInput> numInputBlck = std::dynamic_pointer_cast<NumberInput>(elem);

    ACRNumericTextField *numInput = [[ACRNumericTextField alloc] init];
    numInput.placeholder = [NSString stringWithCString:numInputBlck->GetPlaceholder().c_str() encoding:NSUTF8StringEncoding];

    ACRNumberInputHandler *numberInputHandler = [[ACRNumberInputHandler alloc] init:acoElem];

    numberInputHandler.textField = numInput;
    numInput.delegate = numberInputHandler;
    numInput.text = numberInputHandler.text;
    SEL textFielsDidChangeSel = NSSelectorFromString(@"textFieldDidChange:");
    if ([numberInputHandler respondsToSelector:textFielsDidChangeSel]) {
        [numInput addTarget:numberInputHandler action:textFielsDidChangeSel forControlEvents:UIControlEventEditingChanged];
    }

    ACRInputLabelView *inputLabelView = [[ACRInputLabelView alloc] initInputLabelView:rootView acoConfig:acoConfig adaptiveInputElement:numInputBlck inputView:numInput accessibilityItem:numInput viewGroup:viewGroup dataSource:numberInputHandler];
    
    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:inputLabelView withAreaName:areaName];

    [inputs addObject:inputLabelView];

    return inputLabelView;
}

@end

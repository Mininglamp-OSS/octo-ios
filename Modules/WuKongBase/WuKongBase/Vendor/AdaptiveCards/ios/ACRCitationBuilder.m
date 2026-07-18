//
//  ACRCitationBuilder.m
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 29/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRCitationBuilder.h"
#import "ACRTextBlockCitationParser.h"
#import "ACRInlineCitationTokenParser.h"
#import "ACRCitationParser.h"
#import "ACOReference.h"
#import "ACOCitation.h"
#import "ACRCitationParserDelegate.h"
#import "ACRView.h"

@interface ACRCitationBuilder () <ACRCitationParserDelegate>

@property (nonatomic, weak) id<ACRCitationBuilderDelegate> delegate;
@property (nonatomic, strong) ACRTextBlockCitationParser *textBlockParser;
@property (nonatomic, strong) ACRInlineCitationTokenParser *inlineCitationParser;
@property (nonatomic, strong) ACRCitationParser *citationRunParser;

@end

@implementation ACRCitationBuilder

- (instancetype)initWithDelegate:(id<ACRCitationBuilderDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

#pragma mark - Lazy Properties

- (ACRTextBlockCitationParser *)textBlockParser {
    if (!_textBlockParser) {
        _textBlockParser = [[ACRTextBlockCitationParser alloc] initWithDelegate:self];
    }
    return _textBlockParser;
}

- (ACRInlineCitationTokenParser *)inlineCitationParser {
    if (!_inlineCitationParser) {
        _inlineCitationParser = [[ACRInlineCitationTokenParser alloc] initWithDelegate:self];
    }
    return _inlineCitationParser;
}

- (ACRCitationParser *)citationRunParser {
    if (!_citationRunParser) {
        _citationRunParser = [[ACRCitationParser alloc] initWithDelegate:self];
    }
    return _citationRunParser;
}

#pragma mark - Public Methods

- (NSAttributedString *)buildCitationsFromAttributedString:(NSAttributedString *)attributedString
                                                references:(NSArray<ACOReference *> *)references
                                                 presenter:(id<ACICitationPresenter>)presenter
                                                     theme:(ACRTheme)theme
{
    self.inlineCitationParser.presenter = presenter;
    NSMutableAttributedString *result = [self.inlineCitationParser parseAttributedString:attributedString
                                                                          withReferences:references
                                                                                   theme:theme];
    return [result copy];
}

- (NSAttributedString *)buildCitationsFromAttributedString:(NSAttributedString *)attributedString
                                                 rootView:(ACRView *)rootView
{
    NSArray<ACOReference *> *references = rootView.card.references;
    id<ACICitationPresenter> presenter = rootView.citationPresenter;
    ACRTheme theme = rootView.theme;
    
    return [self buildCitationsFromAttributedString:attributedString
                                         references:references
                                          presenter:presenter
                                              theme:theme];
}

- (NSAttributedString *)buildCitationsFromNSLinkAttributesInAttributedString:(NSAttributedString *)attributedString
                                                                  references:(NSArray<ACOReference *> *)references
                                                                   presenter:(id<ACICitationPresenter>)presenter
                                                                       theme:(ACRTheme)theme
{
    self.textBlockParser.presenter = presenter;
    NSMutableAttributedString *result = [self.textBlockParser parseAttributedString:attributedString
                                                                     withReferences:references
                                                                              theme:theme];
    return [result copy];
}

- (NSAttributedString *)buildCitationsFromNSLinkAttributesInAttributedString:(NSAttributedString *)attributedString
                                                                    rootView:(ACRView *)rootView
{
    NSArray<ACOReference *> *references = rootView.card.references;
    id<ACICitationPresenter> presenter = rootView.citationPresenter;
    ACRTheme theme = rootView.theme;
    
    return [self buildCitationsFromNSLinkAttributesInAttributedString:attributedString
                                                           references:references
                                                            presenter:presenter
                                                                theme:theme];
}

- (NSAttributedString *)buildCitationAttachmentWithCitation:(ACOCitation *)citation
                                                 references:(NSArray<ACOReference *> *)references
                                                  presenter:(id<ACICitationPresenter>)presenter
{
    self.citationRunParser.presenter = presenter;
    return [self.citationRunParser parseAttributedStringWithCitation:citation
                                                       andReferences:references];
}

#pragma mark - ACRCitationParserDelegate

- (void)citationParser:(id)parser
        didTapCitation:(ACOCitation *)citation
         referenceData:(ACOReference * _Nullable)referenceData {
    // Analytics only — the presenter is called directly by the parser
    // via the per-button associated object set at attachment-creation time.
    if (self.delegate && [self.delegate respondsToSelector:@selector(citationBuilder:didTapCitation:referenceData:)]) {
        [self.delegate citationBuilder:self didTapCitation:citation referenceData:referenceData];
    }
}

@end

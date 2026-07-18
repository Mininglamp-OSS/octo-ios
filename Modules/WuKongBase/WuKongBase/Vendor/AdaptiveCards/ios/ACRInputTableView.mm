//
//  ACRInputTableView.mm
//  ACRInputTableView
//
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "ACRInputTableView.h"
#import "ACOBundle.h"
#import <Foundation/Foundation.h>

@implementation ACRInputTableView

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    return self;
}

- (instancetype)initWithSuperview:(UIView *)view
{
    self = [super initWithFrame:CGRectMake(0, 0, view.frame.size.width, view.frame.size.height) style:UITableViewStylePlain];
    if (self) {
        self.clipsToBounds = YES;
        self.contentMode = UIViewContentModeCenter;

        self.bounces = NO;
        self.scrollEnabled = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.showsVerticalScrollIndicator = NO;
        self.bouncesZoom = NO;

        self.backgroundColor = [UIColor clearColor];

        // Separator settings
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.separatorColor = [UIColor colorWithWhite:0.6666666667 alpha:1.0];

        // Section index colors set to transparent.
        self.sectionIndexColor = [UIColor clearColor];
        self.sectionIndexBackgroundColor = [UIColor clearColor];
        self.sectionIndexTrackingBackgroundColor = [UIColor clearColor];

        // Set row height and section header/footer height to auto.
        self.rowHeight = UITableViewAutomaticDimension;
        self.estimatedRowHeight = UITableViewAutomaticDimension;
        self.sectionHeaderHeight = UITableViewAutomaticDimension;
        self.sectionFooterHeight = UITableViewAutomaticDimension;

        // Set custom runtime attribute.
        self.inputTableViewSpacing = 10;
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    NSInteger numberOfRows = [self.dataSource tableView:self numberOfRowsInSection:0];
    CGFloat height = 0.0f;
    for (int i = 0; i < numberOfRows; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        height += [self.delegate tableView:self heightForRowAtIndexPath:indexPath];
    }
    return CGSizeMake(self.frame.size.width, height);
}

- (void)setAccessibilityLabel:(id)accessibilityLabel
{
    BOOL bUpdateTable = YES;
    if (_adaptiveAccessibilityLabel && ![_adaptiveAccessibilityLabel isEqualToString:accessibilityLabel]) {
        bUpdateTable = YES;
    }

    _adaptiveAccessibilityLabel = accessibilityLabel;

    if (bUpdateTable) {
        [self reloadData];
    }
}

@end

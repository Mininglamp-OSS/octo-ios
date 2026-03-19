//
//  WKConversationListTableView.m
//  WuKongBase
//
//  Created by tt on 2021/4/22.
//


/**
 此WKConversationListTableView主要解决如下的警告的问题
 Warning once only: UITableView was told to layout its visible cells and other contents without being in the view hierarchy....

 */
#import "WKConversationListTableView.h"
#import "WuKongBase.h"
@interface WKConversationListTableView ()

@property (nonatomic) BOOL needsReloadWhenPutOnScreen;

@end

@implementation WKConversationListTableView

-(void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window != nil)
    {
        if (self.needsReloadWhenPutOnScreen)
        {
            WKLogDebug(@"Got dirtied while offscreen. reload.");
            self.needsReloadWhenPutOnScreen = NO;
            [super reloadData];
        }

    }
}


// Allows multiple insert/delete/reload/move calls to be animated simultaneously. Nestable.
-(void)performBatchUpdates:(void (NS_NOESCAPE ^ _Nullable)(void))updates
                completion:(void (^ _Nullable)(BOOL finished))completion
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super performBatchUpdates:updates completion:completion];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] performBatchUpdates exception: %@", exception);
            [super reloadData];
        }
    }
}

// Use -performBatchUpdates:completion: instead of these methods, which will be deprecated in a future release.
-(void)beginUpdates
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        [super beginUpdates];
    }


}

-(void)endUpdates
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super endUpdates];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] endUpdates exception: %@", exception);
            [super reloadData];
        }
    }
}

-(void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super insertSections:sections withRowAnimation:animation];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] insertSections exception: %@", exception);
            [super reloadData];
        }
    }


}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super deleteSections:sections withRowAnimation:animation];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] deleteSections exception: %@", exception);
            [super reloadData];
        }
    }


}

-(void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super reloadSections:sections withRowAnimation:animation];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] reloadSections exception: %@", exception);
            [super reloadData];
        }
    }


}

-(void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super moveSection:section toSection:newSection];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] moveSection exception: %@", exception);
            [super reloadData];
        }
    }


}

-(void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] insertRowsAtIndexPaths exception: %@", exception);
            [super reloadData];
        }
    }
}

-(void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath*>*)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] deleteRowsAtIndexPaths exception: %@", exception);
            [super reloadData];
        }
    }
}

-(void)reloadRowsAtIndexPaths:(NSArray<NSIndexPath*>*)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] reloadRowsAtIndexPaths exception: %@", exception);
            [super reloadData];
        }
    }
}

-(void)moveRowAtIndexPath:(NSIndexPath*)indexPath toIndexPath:(NSIndexPath*)newIndexPath
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        @try {
            [super moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
        } @catch (NSException *exception) {
            NSLog(@"[WKConversationListTableView] moveRowAtIndexPath exception: %@", exception);
            [super reloadData];
        }
    }
}

-(void)reloadData
{
    if (self.window == nil)
    {
        self.needsReloadWhenPutOnScreen = YES;
    }
    else
    {
        [super reloadData];
    }
}



@end

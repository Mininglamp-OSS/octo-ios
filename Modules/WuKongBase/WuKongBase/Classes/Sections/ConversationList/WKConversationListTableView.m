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
            [self reloadData];
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
        [super performBatchUpdates:updates completion:completion];
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
        [super endUpdates];
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
        [super insertSections:sections withRowAnimation:animation];
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
        [super deleteSections:sections withRowAnimation:animation];
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
         [super reloadSections:sections withRowAnimation:animation];
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
        [super moveSection:section toSection:newSection];
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
        [super insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
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
        [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
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
        [super reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
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
        [super moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
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

//
//  WKEmojiContentView.m
//  WuKongBase
//
//  Created by tt on 2020/1/10.
//

#import "WKEmojiContentView.h"
#import "WKCollectionViewGridLayout.h"
#import "WKEmojiCell.h"
#import "WKResource.h"
#import "UIView+WK.h"
#import "WKEmojiCollectionTitleHeader.h"
#import "WuKongBase.h"
@interface WKEmojiContentView ()<UICollectionViewDataSource,UICollectionViewDelegate>

@property(nonatomic,strong) UICollectionView *collectionView;

// emoji服务
@property(nonatomic,strong) WKEmoticonService *emojiService;

@end

@implementation WKEmojiContentView

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.emojiService = [WKEmoticonService new];
        [self addSubview:self.collectionView];
        [self setBackgroundColor:[UIColor whiteColor]];
    }
    return self;
}


// grid布局
-(UICollectionViewFlowLayout *)newGridLayout
{
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    
//    layout.itemSpacing = 10;
//    layout.lineSpacing = 10;
//    layout.lineSize = 0;
//    layout.lineItemCount = 7;
//    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
//    layout.sectionsStartOnNewLine = NO;
    
    NSInteger num = 7;
    CGFloat itemSpaceing = 10.0f;
    
    CGSize itemSize = CGSizeMake((WKScreenWidth-itemSpaceing*(num+1))/num, (WKScreenWidth-itemSpaceing*(num+1))/num);
    layout.itemSize = itemSize;
    layout.minimumLineSpacing = itemSpaceing;
    layout.minimumInteritemSpacing = itemSpaceing;
    if(self.emojiService.recentEmotions.count >0) {
        layout.headerReferenceSize = CGSizeMake(WKScreenWidth, 30.0f);
    }
    
    
    return layout;
}

- (void)layoutSubviews {
    [super layoutSubviews];
     self.collectionView.lim_size = self.lim_size;
}

-(UICollectionView*) collectionView {
    if(!_collectionView) {
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) collectionViewLayout:[self newGridLayout]];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        [_collectionView setBackgroundColor:[UIColor clearColor]];
        [_collectionView setContentInset:UIEdgeInsetsMake(10, 10.0f, 10.0f, 10.0f)];
        [_collectionView registerClass:[WKEmojiCell class] forCellWithReuseIdentifier:[WKEmojiCell reuseIdentifier]];
        [_collectionView registerClass:[WKEmojiCollectionTitleHeader class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"WKEmojiCollectionTitleHeader"];
    }
    return _collectionView;
}


#pragma mark - UICollectionViewDataSource && UICollectionViewDelegate

-(BOOL) hasRecentEmotion {
    return self.emojiService.recentEmotions.count != 0;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
   
    if(section == 0 && [self hasRecentEmotion]) {
        return self.emojiService.recentEmotions.count;
    }
    return self.emojiService.emotions.count;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
   
    WKEmojiCollectionTitleHeader *headerView = (WKEmojiCollectionTitleHeader*)[collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"WKEmojiCollectionTitleHeader" forIndexPath:indexPath];
    if(indexPath.section == 0 && [self hasRecentEmotion]) {
        headerView.titleLbl.text = LLang(@"最近使用");
    }else{
        headerView.titleLbl.text = LLang(@"所有表情");
    }
    
    [headerView.titleLbl sizeToFit];
    return headerView;
}
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    if(![self hasRecentEmotion]) {
        return 1;
    }
  return 2;
}
 

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    WKEmojiCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[WKEmojiCell reuseIdentifier] forIndexPath:indexPath];
    
    return cell;
}
-(void)collectionView:(UICollectionView *)collectionView willDisplayCell:(WKEmojiCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath{
    WKEmotion *emoji ;
    if(indexPath.section == 0 && [self hasRecentEmotion]) {
        emoji = [self.emojiService.recentEmotions objectAtIndex:indexPath.row];
    }else{
        emoji = [self.emojiService.emotions objectAtIndex:indexPath.row];
    }
    
    [cell setEmoji: [self.emojiService emojiImageNamed:emoji.faceImageName]];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    WKEmotion *emoji ;
    if(indexPath.section == 0 &&  [self hasRecentEmotion]) {
        emoji = [self.emojiService.recentEmotions objectAtIndex:indexPath.row];
    }else{
        emoji = [self.emojiService.emotions objectAtIndex:indexPath.row];
    }
    if(self.onEmoji) {
        self.onEmoji(emoji);
        [self.emojiService recentEmoji:emoji];
    }else{
        [self.emojiService recentEmoji:emoji];
        [self.context inputInsertText:emoji.faceName];
    }
    
}

- (UIImage *)tabIcon {
    return [WKApp.shared loadImage:@"Conversation/Panel/IconFaceEmoji" moduleID:@"WuKongBase"];
}


@end

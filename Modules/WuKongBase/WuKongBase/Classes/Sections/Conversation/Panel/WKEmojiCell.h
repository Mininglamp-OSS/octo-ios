//
//  WKEmojiCell.h
//  WuKongBase
//
//  Created by tt on 2020/1/9.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKEmojiCell : UICollectionViewCell
+(NSString *)reuseIdentifier;

-(void)setEmoji:(UIImage *)image;
@end

NS_ASSUME_NONNULL_END

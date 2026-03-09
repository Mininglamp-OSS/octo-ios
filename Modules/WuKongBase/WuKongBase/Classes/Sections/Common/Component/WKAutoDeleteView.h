//
//  WKAutoDeleteView.h
//  WuKongBase
//
//  Created by tt on 2023/9/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKAutoDeleteView : UIView

@property(nonatomic,strong) UIImageView *iconImgView;
@property(nonatomic,strong) UILabel *timeLbl;

@property(nonatomic,assign) NSInteger second;

@end

NS_ASSUME_NONNULL_END

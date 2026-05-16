//
//  WKStickerCollectAddCell.m
//  WuKongBase
//
//  Created by tt on 2021/10/28.
//

#import "WKStickerCollectAddCell.h"
#import "WuKongBase.h"
@implementation WKStickerCollectAddCellModel



@end

@interface WKStickerCollectAddCell ()

@property(nonatomic,strong) UIImageView *addImgView;

@end

@implementation WKStickerCollectAddCell

+(NSString *)reuseIdentifier
{
    return NSStringFromClass(self);
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self.contentView addSubview:self.addImgView];
    }
    return self;
}



- (UIImageView *)addImgView {
    if(!_addImgView) {
        _addImgView = [[UIImageView alloc] initWithFrame:self.frame];
        _addImgView.image = [self imageName:@"Conversation/Panel/CollectionAdd"];
    }
    return _addImgView;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end

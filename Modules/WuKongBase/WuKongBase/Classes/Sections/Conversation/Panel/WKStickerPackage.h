//
//  WKStickerPackage.h
//  WuKongBase
//
//  Created by tt on 2021/9/28.
//


#import "WKModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKSticker : WKModel

@property(nonatomic,copy) NSString *path;
@property(nonatomic,strong) NSNumber *width;
@property(nonatomic,strong) NSNumber *height;
@property(nonatomic,copy) NSString *format;
@property(nonatomic,strong) NSNumber *sortNum;
@property(nonatomic,copy) NSString *category;
@property(nonatomic,copy) NSString *placeholder;

// ---------- 自定义属性 ----------
@property(nonatomic,assign) BOOL isEdit; //编辑模式
@property(nonatomic,assign) BOOL isSelected; //选中
@property(nonatomic,assign) BOOL isPlay; // 是否播放



@end

@interface WKStickerPackage : WKModel

@property(nonatomic,copy) NSString *title;
@property(nonatomic,copy) NSString *category;
@property(nonatomic,assign) BOOL added;
@property(nonatomic,copy) NSString *cover;
@property(nonatomic,copy) NSString *desc;
@property(nonatomic,strong) NSArray<WKSticker*> *list;

@end

NS_ASSUME_NONNULL_END

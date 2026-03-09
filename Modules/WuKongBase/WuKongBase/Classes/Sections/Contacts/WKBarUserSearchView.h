//
//  WKBarUserSearchView.h
//  ATIMExample
//
//  Created by chenyisi on 15/12/10.
//  Copyright © 2015年 qiyunxin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>

@interface WKBarUserSearchModel : NSObject

@property(nonatomic, strong) NSString *sid;

@property(nonatomic, strong) NSString *icon;

@property(nonatomic) id data;

- (instancetype)initWithSid:(NSString *)sid;

@end

@interface WKBarUserSearchView : UIView


- (instancetype)initWithFrame:(CGRect)frame searchByReturn:(BOOL)searchByReturn;

@property(nonatomic, strong) UITextField *searchFd;

/**
 *  移除ICON回调
 */
@property(nonatomic, strong) void (^removeIconBlock)
(WKBarUserSearchModel *model);

//搜索内容改变
@property(nonatomic, strong) void (^searchDidChangeBlock)(NSString *keyword);


- (void)addModel:(WKBarUserSearchModel *)model;

- (void)removeModel:(WKBarUserSearchModel *)model;

//被选中的对象集合
-(NSArray*) selectedModels;

@end

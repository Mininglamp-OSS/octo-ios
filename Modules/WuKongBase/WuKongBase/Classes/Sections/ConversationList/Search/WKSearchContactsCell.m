//
//  WKSearchContactsCell.m
//  WuKongBase
//
//  Created by tt on 2020/4/25.
//

#import "WKSearchContactsCell.h"
#import <SDWebImage/SDWebImage.h>
#import "WKApp.h"
#import "WuKongBase.h"
#import "WKExternalViewerResolver.h"
@implementation WKSearchContactsModel

- (Class)cell {
    return WKSearchContactsCell.class;
}

- (NSNumber *)showArrow {
    return @(NO);
}

@end

@interface WKSearchContactsCell ()

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UILabel *containLbl;
@property(nonatomic,strong) WKSearchContactsModel *searchModel;

@end

@implementation WKSearchContactsCell

+ (CGSize)sizeForModel:(WKFormItemModel *)model {
    return CGSizeMake(WKScreenWidth, 48.0f + 10.0f + 10.0f);
}

- (void)setupUI {
    [super setupUI];
    
    // avatar
    self.avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 48.0f, 48.0f)];
    self.avatarImgView.layer.masksToBounds = YES;
    self.avatarImgView.layer.cornerRadius = self.avatarImgView.lim_height/2.0f;
    [self addSubview:self.avatarImgView];
    
    // name
    self.nameLbl = [[UILabel alloc] init];
    [self addSubview:self.nameLbl];
    
    // contain
    self.containLbl = [[UILabel alloc] init];
    [self.containLbl setFont:[UIFont systemFontOfSize:14.0f]];
    [self.containLbl setTextColor:[UIColor grayColor]];
    [self addSubview:self.containLbl];
}

- (void)refresh:(WKSearchContactsModel *)model {
    [super refresh:model];
    self.searchModel = model;

    NSMutableAttributedString *nameAttr = [self highlightText:model.name?:@""];

    // YUJ-156 搜索结果外部成员/群 `@SpaceName` 跨 Space 后缀。
    // Pattern 复用 YUJ-135 WKMentionUserCell / YUJ-129 WKMessageCell —— 字段契约
    // (`home_space_id` / `home_space_name` / `is_external` / `source_space_name`) 走
    // viewer-relative resolver 判定。isExternal && sourceSpaceName 非空 → 在 <mark>
    // 高亮后拼灰紫 ` @{SpaceName}` 后缀；否则保持原 attributedText（YUJ-98 坑点：
    // cell 复用时不能残留上次外部渲染，所以 refresh 每次都重新构建 nameAttr）。
    WKExternalResolveResult *ext = [WKExternalViewerResolver
        resolveWithHomeSpaceId:model.home_space_id
                 homeSpaceName:model.home_space_name
              isExternalLegacy:model.is_external
         sourceSpaceNameLegacy:model.source_space_name
                 viewerSpaceId:[WKExternalViewerResolver currentViewerSpaceId]];
    if (ext.isExternal && ext.sourceSpaceName.length > 0) {
        // 灰紫 0x8B5CF6 与 WKMessageCell (YUJ-129) / Android ForegroundColorSpan 像素级一致。
        UIColor *suffixColor = [UIColor colorWithRed:0x8B/255.0 green:0x5C/255.0 blue:0xF6/255.0 alpha:1.0];
        NSString *suffix = [NSString stringWithFormat:@" @%@", ext.sourceSpaceName];
        [nameAttr appendAttributedString:[[NSAttributedString alloc] initWithString:suffix
                                                                        attributes:@{NSForegroundColorAttributeName: suffixColor}]];
    }

    self.nameLbl.attributedText = nameAttr;
    self.avatarImgView.url = model.avatar;

    
    self.containLbl.hidden = YES;
    if(model.contain && ![model.contain isEqualToString:@""]) {
        self.containLbl.hidden = NO;
        NSMutableAttributedString *containAttr = [[NSMutableAttributedString alloc] initWithString:model.contain];
        if(model.keyword) {
            NSRange colorRange = [[model.contain lowercaseString] rangeOfString:[model.keyword lowercaseString]];
            [containAttr addAttribute:NSForegroundColorAttributeName value:[WKApp shared].config.themeColor range:colorRange];
        }
        [containAttr insertAttributedString:[[NSAttributedString alloc] initWithString:LLang(@"包含:")] atIndex:0];
        self.containLbl.attributedText = containAttr;
    }
}

-(NSMutableAttributedString*)  highlightText:(NSString*)text {
    NSMutableAttributedString* attributedString = [[NSMutableAttributedString alloc] initWithString:text];
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"<mark>(.*?)</mark>" options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSArray* matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    
    for (NSTextCheckingResult* match in [matches reverseObjectEnumerator]) {
        NSRange contentRange = [match rangeAtIndex:1];
        NSString* content = [text substringWithRange:contentRange]; // 提取内容
        NSAttributedString* highlightedString = [[NSAttributedString alloc] initWithString:content attributes:@{NSForegroundColorAttributeName: WKApp.shared.config.themeColor}];
        // 替换 <mark> 标签部分，并保留属性
        [attributedString replaceCharactersInRange:[match range] withAttributedString:highlightedString];
    }
    
    return attributedString;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // avatar
    self.avatarImgView.lim_left = 20.0f;
    self.avatarImgView.lim_top = [self lim_centerY:self.avatarImgView];
    
    
    // name
    CGFloat nameLeftSpace = 15.0f;
    CGFloat nameHeight = 20.0f;
    self.nameLbl.lim_width = self.lim_width -( self.avatarImgView.lim_right + nameLeftSpace + 20.0f);
    self.nameLbl.lim_height = nameHeight;
    self.nameLbl.lim_left = self.avatarImgView.lim_right + nameLeftSpace;
    
    if(self.searchModel.contain && ![self.searchModel.contain isEqualToString:@""]) {
        self.nameLbl.lim_top = 10.0f;
        
        // contain
        self.containLbl.lim_width = self.nameLbl.lim_width;
        self.containLbl.lim_height = 15.0f;
        self.containLbl.lim_left = self.nameLbl.lim_left;
        self.containLbl.lim_top = self.nameLbl.lim_bottom + 10.0f;
    }else {
        self.nameLbl.lim_top = [self lim_centerY:self.nameLbl];
    }
}

@end

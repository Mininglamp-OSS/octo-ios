//
//  WuKongBase.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import <WuKongIMSDK/WuKongIMSDK.h>

#import "WKApp.h"
#import "WKLoginInfo.h"
#import "WKBaseVM.h"
#import "WKBaseVC.h"
#import "WKWebViewVC.h"
#import "WKBaseService.h"
#import "WKBaseModule.h"
#import "WKModuleProtocol.h"
#import "WKModuleManager.h"
#import "WKAnnotation.h"
#import "WKNavigationManager.h"
#import "UIView+WK.h"
#import "UIView+WKCommon.h"
#import "WKAPIClient.h"
#import "WKModel.h"
#import "WKLogs.h"
#import "WKKitDB.h"
#import "WKDBMigration.h"
#import "WKSync.h"
#import "WKDBaseDB.h"
#import "WKConstant.h"
#import "WKCommon.h"
#import "WKFriendRequestDB.h"
#import "WKGroupManager.h"
#import "WKMessageBaseCell.h"
#import "WKContactsSelectVC.h"
#import "WKContactsSelectCell.h"
#import "WKSystemMessageHandler.h"
#import "WKMessageLongMenusItem.h"
#import "WKMessageManager.h"
#import "WKAlertUtil.h"
#import "WKBaseTableVC.h"
#import "WKBaseTableVM.h"
#import "WKScanHandler.h"
#import "WKMoneyUtil.h"
#import "WKVideoRecordUtil.h"
#import "WKVideoBrowserData.h"
#import "WKTouchTableView.h"
#import "WKLoadProgressView.h"
#import "WKTimeTool.h"
#import "WKChineseSort.h"
#import "WKLabelItemSelectCell.h"
#import "WKConversationAddItem.h"
#import "UIImageView+WK.h"
#import "WKAutoDeleteView.h"

#import "UIColor+WK.h"
#import "WKUserColorUtil.h"
#import "WKSimpleInput.h"

#import "WKMessageUtil.h"
#import "WKDefaultWebImageMediator.h"

// UIKit
#import "WKRemoteImageAttachment.h"
#import "WKConversationListVC.h"
#import "WKCell.h"
#import "WKImageView.h"
#import "WKResource.h"
#import "WKMoreItemModel.h"
#import "WKMessageCell.h"
#import "WKAvatarUtil.h"
#import "WKCorePasswordView.h"
#import "WKPwdKeyboardInputView.h"
#import "WKUserAvatar.h"
#import "WKMediaPickerController.h"
#import "WKInputVC.h"
#import "WKReactionBaseView.h"
#import "WKEmojiContentView.h"
#import "WKUserHandleVC.h"
#import "WKInputMentionCache.h"
#import "WKMentionUserCell.h"
#import "UIButton+WK.h"
#import "WKIconButton.h"
#import "WKIconSwitchButton.h"

#import "WKOfficialTag.h"
#import "WKActionSheetView2.h"

#import "WKButtonItemCell2.h"
#import "WKLabelCell.h"
#import "WKSMSCodeItemCell.h" // 短信验证码
#import "WKTextFieldItemCell.h"
#import "WKAnimateIconCell.h"

//extends
#import "WKContactsHeaderItem.h"
#import "WKContactsManager.h"

#import "WKCheckBox.h"
#import "WKMeItem.h"

#import "WKNetworkListener.h"
#import "WKPhotoService.h"

#import "WKModelConvert.h"


#import "UIDevice+Utils.h"

#import "UIImage+WK.h"

#import "WKEmoticonService.h"
#import "WKMentionService.h"
#import "M80AttributedLabel+WK.h"

#import "NSString+WKLocalized.h"
#import "WKBrowserToolbar.h"
#import "NSMutableAttributedString+WK.h"
#import "UILabel+WK.h"
#import "WKChannelUtil.h"
#import "WKChannelSettingManager.h"
#import "WKJsonUtil.h"
#import "WKPhotoBrowser.h"
#import "WKPermissionShowAlertView.h"

#import "WKUserHeaderCell.h"
#import "WKMultiLabelItemCell.h"
#import "WKImageBrowser.h"

#import "WKMessageActionManager.h"
#import "WKSchemaManager.h"

#import "WKPanelDefaultFuncItem.h"
#import "WKDowloadTask.h"
#import "WKGenerateImageUtils.h"

#import "WKStickerManager.h"
#import "WKStickerGIFContentView.h"

#import "WKMemberListVC.h"
#import "WKOnlineStatusManager.h"

#import "WKConversationVC.h"
#import "WKConversationView.h"
#import "WKMessageListView.h"
#import "WKConversationWrapModel.h"
#import "WKChannelDataManager.h"
#import "WKGrowingTextView.h"

#import "WKMergeForwardDetailCell.h"

#import "WKMessageList.h"
#import "WKThemeUtil.h"
#import "WKSearchMediaCell.h"

#define LLang(a) [a Localized:self]
#define LLangW(a,w) [a Localized:w]
#define LLangC(a,c) [a LocalizedWithClass:c]
#define LLangB(a,b) [a LocalizedWithBundle:b]

#define LImage(name) [WKResource.shared imageNamed:name inClass:self.class]

#define WKFileHelperChannel [WKChannel personWithChannelID:@"fileHelper"] // 文件助手的频道

//
//  WKContextController.swift
//  WuKongBase
//
//  Created by tt on 2022/6/19.
//

import Foundation
import UIKit

class WKChatMessageContextExtractedContentSource : ContextExtractedContentSource {
    var keepInPlace: Bool
    
    var ignoreContentTouches: Bool
    
    var blurBackground: Bool
    
    func takeView() -> ContextControllerTakeViewInfo? {
        NSLog("WKChatMessageContextExtractedContentSource---->takeView")
        guard let visibleCells = self.context.visibleCells?() else {
            return nil
        }
        var result: ContextControllerTakeViewInfo?
        visibleCells.forEach { cell in
            guard let messageCell = cell as? WKMessageCell else {
                return
            }
            if(self.message.clientMsgNo == messageCell.messageModel.clientMsgNo) {
                NSLog("message-content-->%@", messageCell.messageModel.content.contentDict);
                let topView = WKNavigationManager.shared().topViewController().view!;
                let y = WKApp.shared().config.visibleEdgeInsets.top + WKApp.shared().config.visibleEdgeInsets.bottom
                messageCell.refresh(messageCell.messageModel)
                result = ContextControllerTakeViewInfo(contentContainingNode: messageCell.mainContextSourceNode, contentAreaInScreenSpace: CGRect(x: 0.0, y: y, width: topView.size.width, height: topView.size.height - y))
                return
            }
        }
        return result
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        let topView = WKNavigationManager.shared().topViewController().view!;
        let y = WKApp.shared().config.visibleEdgeInsets.top + WKApp.shared().config.visibleEdgeInsets.bottom
        let result = ContextControllerPutBackViewInfo(contentAreaInScreenSpace: CGRect(x: 0.0, y: y, width: topView.size.width, height: topView.size.height - y))
        
        return result
    }
    
    let context:WKConversationContext
    let message:WKMessageModel;
    init(message:WKMessageModel,context:WKConversationContext) {
        self.message = message
        self.context = context
        self.keepInPlace = false
        self.ignoreContentTouches = false;
        self.blurBackground = true
    }
}

public typealias OnDismissed = () -> Void
@objc public class WKMessageContextController:NSObject {
    var contextController:ContextController?
    let message:WKMessageModel;
    let context:WKConversationContext
    let gesture:ContextGesture?
    let menusItems: [WKMessageLongMenusItem]

    
    @objc public var reactionSelected: ((WKReactionContextItem,Bool) -> Void)?
    
    @objc public var onDismissed: OnDismissed?
    private(set) var controllers: [UIViewController] = []
    @objc public  init(message:WKMessageModel,context:WKConversationContext,menusItems:[WKMessageLongMenusItem],gesture:ContextGesture?) {
        self.message = message
        self.context = context
        self.gesture = gesture
        self.menusItems = menusItems
    }
    
    @objc public func setup() {
        var contextMenu = PresentationThemeContextMenu(
            dimColor: UIColor(rgb: 0x000a26, alpha: 0.2),
            backgroundColor: UIColor(rgb: 0xf9f9f9, alpha: 0.78),
            itemSeparatorColor: UIColor(rgb: 0x3c3c43, alpha: 0.2),
            sectionSeparatorColor: UIColor(rgb: 0x8a8a8a, alpha: 0.2),
            itemBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.0),
            itemHighlightedBackgroundColor: UIColor(rgb: 0x3c3c43, alpha: 0.2),
            primaryColor: UIColor(rgb: 0x000000),
            secondaryColor: UIColor(rgb: 0x000000, alpha: 0.5),
            destructiveColor: UIColor(rgb: 0xff3b30),
            badgeFillColor: UIColor(rgb: 0x007aff),
            badgeForegroundColor: UIColor(rgb: 0xffffff),
            badgeInactiveFillColor: UIColor(rgb: 0xb6b6bb),
            badgeInactiveForegroundColor: UIColor(rgb: 0xffffff),
            extractedContentTintColor: .white
        )
        if(WKApp.shared().config.style == WKSystemStyleDark) {
             contextMenu = PresentationThemeContextMenu(
                dimColor: UIColor(rgb: 0x000000, alpha: 0.6),
                backgroundColor: UIColor(rgb: 0x252525, alpha: 0.78),
                itemSeparatorColor: UIColor(rgb: 0xffffff, alpha: 0.15),
                sectionSeparatorColor: UIColor(rgb: 0x000000, alpha: 0.2),
                itemBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.0),
                itemHighlightedBackgroundColor: UIColor(rgb: 0xffffff, alpha: 0.15),
                primaryColor: UIColor(rgb: 0xffffff, alpha: 1.0),
                secondaryColor: UIColor(rgb: 0xffffff, alpha: 0.5),
                destructiveColor: UIColor(rgb: 0xeb5545),
                badgeFillColor: UIColor(rgb: 0xffffff),
                badgeForegroundColor: UIColor(rgb: 0x000000),
                badgeInactiveFillColor: UIColor(rgb: 0xffffff).withAlphaComponent(0.5),
                badgeInactiveForegroundColor: UIColor(rgb: 0x000000),
                extractedContentTintColor: UIColor(rgb: 0xffffff, alpha: 1.0)
            )
        }
        
        let presentationThemeRootController = PresentationThemeRootController(keyboardColor: .light)
        let presentationThemeActionSheet:PresentationThemeActionSheet = PresentationThemeActionSheet(backgroundType: .light, opaqueItemBackgroundColor: .red, opaqueItemHighlightedBackgroundColor: .blue, opaqueItemSeparatorColor: .green, controlAccentColor: .orange, destructiveActionTextColor: .gray)
        
        let theme = PresentationTheme(contextMenu: contextMenu, rootController: presentationThemeRootController, overallDarkAppearance: false, actionSheet: presentationThemeActionSheet)
        
        let presentationData = PresentationData(theme: theme, listsFontSize: .medium, strings: PresentationStrings(), reduceMotion: false)
        
        var items: [ContextMenuItem] = []
        
        // 上下单菜单选项
        for menusItem in menusItems {
            let action = ContextMenuActionItem(text: menusItem.title) { _ in
                return menusItem.icon
             } action: { _, f in
                 if let onTap = menusItem.onTap {
                     self.contextController?.dismiss(completion: {
                         onTap(self.context)
                     })
                 }
             }
            items.append(.action(action))
        }
        
        // 回应表情
        let reactionItems = WKApp.shared().invoke(WKPOINT_LONGMENUS_REACTIONS, param: ["message":self.message,"context":self.context] as [String : Any]) as? [ReactionContextItem]
        
        
        
        let account = Account()
        let shareAccountContext = DefaultSharedAccountContext(currentPresentationData: .init(value: presentationData))
        let accountContext = DefaultAccountContext(account: account, sharedContext: shareAccountContext)
        self.contextController = ContextController(account: account, presentationData: presentationData, source:.extracted( WKChatMessageContextExtractedContentSource(message: message, context: context)), items: .single(ContextController.Items(content: .list(items), context: accountContext, reactionItems: reactionItems ?? [], tip: nil)),gesture: self.gesture)
        
        
        self.contextController?.reactionSelected = { item, isLarge in
            self.reactionSelected?(WKReactionContextItem(reaction: item.reaction.rawValue, appearAnimation: item.appearAnimation, stillAnimation: item.stillAnimation, listAnimation: item.listAnimation, largeListAnimation: item.largeListAnimation, applicationAnimation: item.applicationAnimation, largeApplicationAnimation: item.largeApplicationAnimation),isLarge)
        }
        
        
    }
    
    @objc public func show() {
        let window = WKApp.shared().findWindow()
       
        if let contextController = self.contextController {

            let topView = WKNavigationManager.shared().topViewController().view!;
            contextController.view.frame = topView.bounds
            self.containerLayoutUpdated(size: topView.size)
            
            contextController.dismissed = {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.immediateDismiss()
                }
            }
            if let windowHost = window as? WindowHost {
                windowHost.presentInGlobalOverlay(self.contextController!)
                return
            }
            contextController.setIgnoreAppearanceMethodInvocations(true)
            window.addSubview(contextController.view)
//            WKNavigationManager.shared().topViewController().addChild(contextController)
            WKNavigationManager.shared().topViewController().addChild(contextController)
            contextController.setIgnoreAppearanceMethodInvocations(false)
            
            contextController.viewWillAppear(false)
            contextController.viewDidAppear(false)
            
            
        }
    }
    
    
    @objc public func containerLayoutUpdated(size:CGSize) {
        let visibleEdgeInsets = WKApp.shared().config.visibleEdgeInsets
        self.contextController?.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(), deviceMetrics: .iPhone12, intrinsicInsets: UIEdgeInsets(top: visibleEdgeInsets.top, left: 0.0, bottom: visibleEdgeInsets.bottom, right: 0.0), safeInsets: UIEdgeInsets(top: visibleEdgeInsets.top, left: 0.0, bottom: visibleEdgeInsets.bottom, right: 0.0), additionalInsets: UIEdgeInsets(top: 0, left: 0, bottom: visibleEdgeInsets.bottom, right: 0), statusBarHeight: 44.0, inputHeight: 0.0, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
    }
    
    @objc public func dismiss() {
        self.contextController?.dismiss()
    }

    
    @objc public func immediateDismiss() {
        self.contextController?.removeFromParent()
        self.contextController?.view.removeFromSuperview()
        self.onDismissed?();
    }
    

 
    
//    -(NSString*) getReactionURL:(NSString*)filePath  type:(NSString*)tp{
//        NSBundle *bundle = [NSBundle bundleForClass:self.class];
//        return  [NSString stringWithFormat:@"file://%@",[bundle pathForResource:filePath ofType:tp]];
//    }
}

func getReactionURL(filePath:String,tp:String,cls:AnyClass) -> String {
    let bundle = Bundle(for:cls)
    return bundle.path(forResource: filePath, ofType: tp)!
}



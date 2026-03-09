//
//  ContextMock.swift
//  WuKongBase
//
//  Created by tt on 2022/6/18.
//

import Foundation
import UIKit

public final class PresentationThemeContextMenu {
    public let dimColor: UIColor
    public let backgroundColor: UIColor
    public let itemSeparatorColor: UIColor
    public let sectionSeparatorColor: UIColor
    public let itemBackgroundColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let primaryColor: UIColor
    public let secondaryColor: UIColor
    public let destructiveColor: UIColor
    public let badgeFillColor: UIColor
    public let badgeForegroundColor: UIColor
    public let badgeInactiveFillColor: UIColor
    public let badgeInactiveForegroundColor: UIColor
    public let extractedContentTintColor: UIColor
    
    init(dimColor: UIColor, backgroundColor: UIColor, itemSeparatorColor: UIColor, sectionSeparatorColor: UIColor, itemBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, primaryColor: UIColor, secondaryColor: UIColor, destructiveColor: UIColor, badgeFillColor: UIColor, badgeForegroundColor: UIColor, badgeInactiveFillColor: UIColor, badgeInactiveForegroundColor: UIColor, extractedContentTintColor: UIColor) {
        self.dimColor = dimColor
        self.backgroundColor = backgroundColor
        self.itemSeparatorColor = itemSeparatorColor
        self.sectionSeparatorColor = sectionSeparatorColor
        self.itemBackgroundColor = itemBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.destructiveColor = destructiveColor
        self.badgeFillColor = badgeFillColor
        self.badgeForegroundColor = badgeForegroundColor
        self.badgeInactiveFillColor = badgeInactiveFillColor
        self.badgeInactiveForegroundColor = badgeInactiveForegroundColor
        self.extractedContentTintColor = extractedContentTintColor
    }
    
    public func withUpdated(dimColor: UIColor? = nil, backgroundColor: UIColor? = nil, itemSeparatorColor: UIColor? = nil, sectionSeparatorColor: UIColor? = nil, itemBackgroundColor: UIColor? = nil, itemHighlightedBackgroundColor: UIColor? = nil, primaryColor: UIColor? = nil, secondaryColor: UIColor? = nil, destructiveColor: UIColor? = nil) -> PresentationThemeContextMenu {
        return PresentationThemeContextMenu(dimColor: dimColor ?? self.dimColor, backgroundColor: backgroundColor ?? self.backgroundColor, itemSeparatorColor: itemSeparatorColor ?? self.itemSeparatorColor, sectionSeparatorColor: sectionSeparatorColor ?? self.sectionSeparatorColor, itemBackgroundColor: itemBackgroundColor ?? self.itemBackgroundColor, itemHighlightedBackgroundColor: itemHighlightedBackgroundColor ?? self.itemHighlightedBackgroundColor, primaryColor: primaryColor ?? self.primaryColor, secondaryColor: secondaryColor ?? self.secondaryColor, destructiveColor: destructiveColor ?? self.destructiveColor, badgeFillColor: self.badgeFillColor, badgeForegroundColor: self.badgeForegroundColor, badgeInactiveFillColor: self.badgeInactiveFillColor, badgeInactiveForegroundColor: self.badgeInactiveForegroundColor, extractedContentTintColor: self.extractedContentTintColor)
    }
}
public enum PresentationThemeActionSheetBackgroundType: Int32 {
    case light
    case dark
}

public final class PresentationThemeActionSheet {
    public let backgroundType: PresentationThemeActionSheetBackgroundType
    public let opaqueItemBackgroundColor: UIColor
    public let opaqueItemHighlightedBackgroundColor: UIColor
    public let opaqueItemSeparatorColor: UIColor
    public let controlAccentColor: UIColor
    public let destructiveActionTextColor: UIColor
    
    public init(backgroundType:PresentationThemeActionSheetBackgroundType,opaqueItemBackgroundColor:UIColor,opaqueItemHighlightedBackgroundColor:UIColor,opaqueItemSeparatorColor:UIColor,controlAccentColor:UIColor,destructiveActionTextColor:UIColor) {
        self.backgroundType = backgroundType
        self.opaqueItemBackgroundColor = opaqueItemBackgroundColor
        self.opaqueItemHighlightedBackgroundColor = opaqueItemHighlightedBackgroundColor
        self.opaqueItemSeparatorColor = opaqueItemSeparatorColor
        self.controlAccentColor = controlAccentColor
        self.destructiveActionTextColor = destructiveActionTextColor
    }
}

public final class PresentationTheme: Equatable {
    public let contextMenu: PresentationThemeContextMenu
    public let rootController: PresentationThemeRootController
    public let overallDarkAppearance: Bool
    public let actionSheet: PresentationThemeActionSheet
    
    public init(contextMenu:PresentationThemeContextMenu,rootController:PresentationThemeRootController,overallDarkAppearance:Bool,actionSheet:PresentationThemeActionSheet) {
        self.contextMenu = contextMenu
        self.rootController = rootController
        self.overallDarkAppearance = overallDarkAppearance
        self.actionSheet = actionSheet
    }
    
    public static func ==(lhs: PresentationTheme, rhs: PresentationTheme) -> Bool {
        return lhs === rhs
    }
    
    
}

public final class PresentationData: NSObject {
    public let theme: PresentationTheme
    public let listsFontSize: PresentationFontSize
    public let strings: PresentationStrings
    public let reduceMotion: Bool
    public init(theme:PresentationTheme,listsFontSize:PresentationFontSize,strings:PresentationStrings,reduceMotion:Bool) {
        self.theme = theme
        self.listsFontSize = listsFontSize
        self.strings = strings
        self.reduceMotion = reduceMotion
    }
//    public static func == (lhs: PresentationData, rhs: PresentationData) -> Bool {
//
//    }
    
    
    
}

public final class PresentationThemeRootController {
    public let keyboardColor: PresentationThemeKeyboardColor
    public init(keyboardColor:PresentationThemeKeyboardColor) {
        self.keyboardColor = keyboardColor
    }
}

public enum PresentationThemeKeyboardColor: Int32 {
    case light = 0
    case dark = 1
    
    public var keyboardAppearance: UIKeyboardAppearance {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

public enum PresentationFontSize: Int32, CaseIterable {
    case extraSmall = 0
    case small = 1
    case regular = 2
    case large = 3
    case extraLarge = 4
    case extraLargeX2 = 5
    case medium = 6
}

public extension PresentationFontSize {
    var baseDisplaySize: CGFloat {
        switch self {
        case .extraSmall:
            return 14.0
        case .small:
            return 15.0
        case .medium:
            return 16.0
        case .regular:
            return 17.0
        case .large:
            return 19.0
        case .extraLarge:
            return 23.0
        case .extraLargeX2:
            return 26.0
        }
    }
}

public class PresentationStrings {
    let Conversation_ContextMenuCopy:String = "复制"
    let Conversation_ContextMenuLookUp:String = "Look Up"
    let Conversation_ContextMenuTranslate:String = "翻译"
    let Conversation_ContextMenuShare = "分享"
    let ChatContextMenu_TextSelectionTip = ""
    let ChatContextMenu_MessageViewsPrivacyTip = ""
    let Conversation_CopyProtectionInfoChannel=""
    let Conversation_CopyProtectionInfoGroup=""
    let VoiceOver_DismissContextMenu = "VoiceOver_DismissContextMenu"
}

public protocol SharedAccountContext: AnyObject {
    var currentPresentationData: Atomic<PresentationData> { get }
}

public class DefaultSharedAccountContext : SharedAccountContext {
    public var currentPresentationData: Atomic<PresentationData>
    
    init(currentPresentationData: Atomic<PresentationData>) {
        self.currentPresentationData = currentPresentationData
    }
    
}

public protocol AccountContext: AnyObject {
    var sharedContext: SharedAccountContext { get }
    var account: Account { get }
    
}

public class DefaultAccountContext:AccountContext {
    public var sharedContext: SharedAccountContext
    
    public var account: Account
    
    init(account: Account,sharedContext:SharedAccountContext) {
        self.account = account
        self.sharedContext = sharedContext
    }
    
    
}

public class Account {
    
}


public class Postbox {
    
}

public class TelegramMediaFile {
    
}

@objc public class WKReactionContextItem:NSObject {
    @objc public let reaction:String
    @objc public let appearAnimation: WuKongReactionFile
    @objc public let stillAnimation: WuKongReactionFile
    @objc public let listAnimation: WuKongReactionFile
    @objc public let largeListAnimation: WuKongReactionFile
    @objc public let applicationAnimation: WuKongReactionFile
    @objc public let largeApplicationAnimation: WuKongReactionFile
    @objc public init(
        reaction: String,
        appearAnimation: WuKongReactionFile,
        stillAnimation: WuKongReactionFile,
        listAnimation: WuKongReactionFile,
        largeListAnimation: WuKongReactionFile,
        applicationAnimation: WuKongReactionFile,
        largeApplicationAnimation: WuKongReactionFile
    ) {
        self.reaction = reaction
        self.appearAnimation = appearAnimation
        self.stillAnimation = stillAnimation
        self.listAnimation = listAnimation
        self.largeListAnimation = largeListAnimation
        self.applicationAnimation = applicationAnimation
        self.largeApplicationAnimation = largeApplicationAnimation
    }
}

@objc public class WuKongReactionFile:NSObject {
    public var name:String
    public var path:String
    
    public init(name:String,path:String) {
        self.name = name
        self.path = path
    }
}

public class EnginePeer {
    
}

typealias MessageId = UInt64

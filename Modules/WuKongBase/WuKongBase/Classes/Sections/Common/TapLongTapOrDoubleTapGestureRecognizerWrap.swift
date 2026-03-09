//
//  WKTapLongTapOrDoubleTapGestureRecognizer.swift
//  WuKongBase
//
//  Created by tt on 2022/6/21.
//

import Foundation
import UIKit

@objc public class TapLongTapOrDoubleTapGestureRecognizerWrap: NSObject {
    @objc public  var gesture: TapLongTapOrDoubleTapGestureRecognizer?
    @objc public var tapAction:WKTapLongTapOrDoubleTapGesture
    @objc public var tapPoint:CGPoint
    let action:  (_ gesture:TapLongTapOrDoubleTapGestureRecognizerWrap)->Void?
    @objc public var tapActionAtPoint: ((CGPoint) ->WKTapLongTapOrDoubleTapGestureRecognizerEvent )?
    @objc public var longTap: ((CGPoint, TapLongTapOrDoubleTapGestureRecognizerWrap) -> Void)?
    
    @objc public init(action: @escaping (_ gesture:TapLongTapOrDoubleTapGestureRecognizerWrap)->Void) {
        self.action = action
        self.tapPoint = CGPoint()
        self.tapAction = WKTapLongTapOrDoubleTapGestureTap
       
    }
    
    @objc  public func setup() {
        self.gesture = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        
        self.gesture!.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if  let event = strongSelf.tapActionAtPoint?(point) {
                    
                    switch event.action {
                    case WKTapLongTapOrDoubleTapGestureRecognizerActionWaitForSingleTap:
                        return .waitForSingleTap
                    case WKTapLongTapOrDoubleTapGestureRecognizerActionFail:
                        return .fail
                    case WKTapLongTapOrDoubleTapGestureRecognizerActionKeepWithSingleTap:
                        return .keepWithSingleTap
                    default:
                        return .fail
                    }
                }
            }
            return .fail
        }
        
        self.gesture!.longTap = {  point, recognizer in
            self.longTap?(point,self)
        }

    }
    
    @objc public func attachTo(view:UIView) {
        view.addGestureRecognizer(self.gesture!)
    }
    @objc
    func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                self.tapPoint = location
                switch gesture {
                case .tap:
                    self.tapAction = WKTapLongTapOrDoubleTapGestureTap
                    break
                case .doubleTap:
                    self.tapAction = WKTapLongTapOrDoubleTapGestureDoubleTap
                    break
                case .longTap:
                    self.tapAction = WKTapLongTapOrDoubleTapGestureLongTap
                    break
                case .hold:
                    self.tapAction = WKTapLongTapOrDoubleTapGestureHold
                    break
                }
                self.action(self)
                
                
            }
        default:
            break
        }
    }

}



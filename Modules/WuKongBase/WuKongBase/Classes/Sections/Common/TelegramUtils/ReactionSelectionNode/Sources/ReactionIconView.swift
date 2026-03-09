//
//  ReactionIconView.swift
//  WuKongBase
//
//  Created by tt on 2022/6/20.
//

import Foundation


public final class ReactionIconView: PortalSourceView {
    public let imageView: UIImageView
    
    override public init(frame: CGRect) {
        self.imageView = UIImageView()
        
        super.init(frame: frame)
        
        self.addSubview(self.imageView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.imageView, frame: CGRect(origin: CGPoint(), size: size))
    }
}

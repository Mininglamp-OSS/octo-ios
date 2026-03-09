//
//  WKBaseSwiftModule.swift
//  WuKongBase
//
//  Created by tt on 2023/9/9.
//

import Foundation


 public typealias WKSwiftHandler = @convention(block) (Any?) -> Any?

public func handlerToObcBlock(handler:@escaping WKSwiftHandler) -> Any {
    let blockObject = unsafeBitCast(handler, to: AnyObject.self)
    return blockObject
}

open  class WKBaseSwiftModule:WKBaseModule {
    
    
}

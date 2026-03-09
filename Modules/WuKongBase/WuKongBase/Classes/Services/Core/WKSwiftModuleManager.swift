//
//  WKSwiftModuleManager.swift
//  WuKongUsernameLogin
//
//  Created by tt on 2023/9/8.
//

import Foundation

@objc open class WKSwiftModuleManager:NSObject {
    @objc public static let shared = WKSwiftModuleManager()
    private var modules:[String: WKModuleProtocol] = [:]
    
    var moduleContext: WKModuleContext = WKModuleContext()
    
  
    
    @objc public func registerModule(_ module:WKModuleProtocol) {
        self.modules[module.moduleId()] = module
    }
    
    @objc public func getAllModules() -> [WKModuleProtocol] {
        var modules:[WKModuleProtocol] = []
        for v in self.modules.values {
            modules.append(v)
        }
       let newModules = modules.sorted { obj1, obj2 in
            if obj1.moduleType() != WKModuleTypeResource && obj2.moduleType() == WKModuleTypeResource {
                    return true
                }
                
                if obj1.moduleType() == WKModuleTypeResource && obj2.moduleType() != WKModuleTypeResource {
                    return false
                }
                
                if obj2.moduleSort() > obj1.moduleSort() {
                    return true
                }
                
                return false
        }
        return newModules
        
    }
    
    @objc public func getModuleWithId(_ moduleId:String) ->WKModuleProtocol? {
        return self.modules[moduleId]
    }
    
   @objc public func getResourceModules() -> [WKModuleProtocol] {
        var resourceModules: [WKModuleProtocol] = []
        let modules = getAllModules()
        if !modules.isEmpty {
            for module in modules {
                if module.moduleType() == WKModuleTypeResource {
                    resourceModules.append(module)
                }
            }
        }
        return resourceModules
    }
    
    @objc public func didModuleInit() {
        let modules = getAllModules()
        if !modules.isEmpty {
            for module in modules {
                // 模块初始化
                module.moduleInit?(moduleContext)
            }
        }
    }
    
    @objc public func didFinishLaunching() -> Bool {
        let modules = getAllModules()
        if  !modules.isEmpty {
            for module in modules {
                module.moduleDidFinishLaunching?(moduleContext)
            }
        }
        return true
    }
    
    @objc public  func didDatabaseLoad() {
        let modules = getAllModules()
        for module in modules {
            module.moduleDidDatabaseLoad?(moduleContext)
        }
    }
    
    @objc public func didOpen(_ url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let modules = getAllModules()
        for module in modules {
            let open = module.moduleOpen?(url, options: options)
            if open ?? false {
                return open ?? false
            }
        }
        return false
    }
    
    @objc public func didContinue(_ userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        let modules = getAllModules()
        for module in modules {
            let open = module.moduleContinue?(userActivity, restorationHandler: restorationHandler)
            if open ?? false {
                return open ?? false
            }
        }
        return false
    }
    
    @objc public  func moduleDidReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let modules = getAllModules()
        for module in modules {
            module.moduleDidReceiveRemoteNotification?(userInfo, fetchCompletionHandler: completionHandler)
        }
    }
        
}

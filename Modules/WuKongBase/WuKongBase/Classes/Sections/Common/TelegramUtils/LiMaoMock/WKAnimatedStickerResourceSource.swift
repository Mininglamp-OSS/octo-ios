//
//  WKAnimatedStickerResourceSource.swift
//  WuKongBase
//
//  Created by tt on 2022/6/19.
//

public class WKLocalPathAnimatedStickerResourceSource:AnimatedStickerNodeSource {
    public var fitzModifier: EmojiFitzModifier?
    
    public var isVideo: Bool
    public var path:String
    
    init(path:String) {
        self.isVideo = false
        self.path = path
    }
    
    public func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError> {
        return .never()
    }
    
    public func directDataPath() -> Signal<String, NoError> {
        return .single(path)
    }
    
    
}

public class WKAnimatedStickerResourceSource :AnimatedStickerNodeSource {
    public var fitzModifier: EmojiFitzModifier?
    
    public var isVideo: Bool
    public var downloadURL:String
    
    init(downloadURL:String) {
        self.downloadURL = downloadURL
        self.isVideo = false
    }
    
    public func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError> {
        let storePath = self.getStorePath()
        let exist =  WKFileUtil.fileIsExist(ofPath: storePath)
        if(exist) {
            return .single((storePath,true))
        }
        return .never()
    }
    
    private func getStorePath() -> String {
        let key = self.getKey()
        let storePath = WKSDK.shared().options.messageFileRootDir + "\\" + key;
        return storePath
    }
    private func getKey() -> String {
        let data = downloadURL.data(using: .utf8)
        return (data?.base64EncodedString())!+"_sticker";
    }
    
    public func directDataPath() -> Signal<String, NoError> {

        let storePath = self.getStorePath()
        
        return Signal { subscriber in
            var task = WKSDK.shared().mediaManager.taskManager.get(self.downloadURL) as? WKDowloadTask
             if((task) == nil) {
                 task = WKDowloadTask(url: self.downloadURL, storePath: storePath)
                WKSDK.shared().mediaManager.taskManager.add(task!)
             }
            if(task?.status == WKTaskStatusSuccess) {
                subscriber.putNext(task!.storePath as String)
                subscriber.putCompletion()
            }else if(task?.status == WKTaskStatusWait){
                task?.addListener({
                    if(task!.status == WKTaskStatusSuccess) {
                        subscriber.putNext(task!.storePath as String)
                        subscriber.putCompletion()
                    }else if(task!.status == WKTaskStatusError) {
                        subscriber.putCompletion()
                    }
                    
                }, target: self)
            }
           
            return EmptyDisposable
        }
    }
    
    
}


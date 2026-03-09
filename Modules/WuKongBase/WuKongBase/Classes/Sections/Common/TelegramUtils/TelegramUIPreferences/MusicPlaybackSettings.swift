//
//  MusicPlaybackSettings.swift
//  25519
//
//  Created by tt on 2022/6/18.
//


public enum AudioPlaybackRate: Int32 {
    case x0_5 = 500
    case x1 = 1000
    case x1_5 = 1500
    case x2 = 2000
    case x4 = 4000
    case x8 = 8000
    case x16 = 16000
    
    public var doubleValue: Double {
        return Double(self.rawValue) / 1000.0
    }

    public init(_ value: Double) {
        if let resolved = AudioPlaybackRate(rawValue: Int32(value * 1000.0)) {
            self = resolved
        } else {
            self = .x1
        }
    }
}

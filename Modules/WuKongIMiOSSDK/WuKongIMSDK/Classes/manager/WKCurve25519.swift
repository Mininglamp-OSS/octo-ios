//
// WKCurve25519.swift
// WuKongIMSDK
//
// Copyright (c) 2026 MININGLAMP Technology
// SPDX-License-Identifier: Apache-2.0
//
// Curve25519 wrapper backed by Apple CryptoKit (iOS 13+).
// Replaces the GPL-v2 FredericJacobs/25519 pod so the SDK can be
// distributed under permissive licenses. Wire-format compatible:
// publicKey / sharedSecret are the raw 32-byte X25519 outputs,
// matching crypto_scalarmult_curve25519 and the previous pod.

import Foundation
import CryptoKit

@objc(WKECKeyPair)
public final class WKECKeyPair: NSObject {
    @objc public let publicKey: Data
    fileprivate let privateKey: Curve25519.KeyAgreement.PrivateKey

    fileprivate init(privateKey: Curve25519.KeyAgreement.PrivateKey) {
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey.rawRepresentation
        super.init()
    }
}

@objc(WKCurve25519)
public final class WKCurve25519: NSObject {
    @objc public class func generateKeyPair() -> WKECKeyPair {
        return WKECKeyPair(privateKey: Curve25519.KeyAgreement.PrivateKey())
    }

    @objc public class func sharedSecret(fromPublicKey publicKeyData: Data,
                                         keyPair: WKECKeyPair) -> Data? {
        guard let pub = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKeyData),
              let secret = try? keyPair.privateKey.sharedSecretFromKeyAgreement(with: pub) else {
            return nil
        }
        return secret.withUnsafeBytes { Data($0) }
    }
}

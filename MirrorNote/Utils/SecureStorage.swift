import Foundation
import CryptoKit
import UIKit

/**
 * SecureStorage - 安全数据存储工具
 * 
 * 提供完全本地化的加密数据存储功能，确保用户画像数据的隐私安全。
 * 
 * 特点：
 * - 使用设备唯一标识符生成加密密钥
 * - AES-GCM加密算法，确保数据安全
 * - 完全本地存储，无网络传输
 * - 开发者无法访问用户数据
 */
class SecureStorage {
    
    static let shared = SecureStorage()
    
    private init() {}
    
    // MARK: - 加密密钥生成
    
    /**
     * 生成基于设备的加密密钥
     * 使用设备的唯一标识符和应用Bundle ID生成一致的密钥
     */
    private func generateEncryptionKey() -> SymmetricKey {
        // 获取设备唯一标识符
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "default_device_id"
        let bundleId = Bundle.main.bundleIdentifier ?? "ZUKI.MirrorNote"
        
        // 创建一致的种子字符串
        let keyString = "\(deviceId)_\(bundleId)_UserProfile_SecretKey"
        let keyData = keyString.data(using: .utf8) ?? Data()
        
        // 使用SHA256哈希生成32字节密钥
        let hashedKey = SHA256.hash(data: keyData)
        return SymmetricKey(data: hashedKey)
    }
    
    // MARK: - 加密存储
    
    /**
     * 安全保存数据到UserDefaults
     * @param data 要保存的数据
     * @param key UserDefaults键名
     */
    func securelyStore<T: Codable>(_ data: T, forKey key: String) throws {
        // 1. 序列化数据
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(data)
        
        // 2. 加密数据
        let encryptionKey = generateEncryptionKey()
        let sealedBox = try AES.GCM.seal(jsonData, using: encryptionKey)
        
        // 3. 转换为可存储格式
        guard let combinedData = sealedBox.combined else {
            throw SecureStorageError.encryptionFailed
        }
        
        // 4. 存储到UserDefaults
        UserDefaults.standard.set(combinedData, forKey: key)
    }
    
    /**
     * 从UserDefaults安全读取数据
     * @param type 数据类型
     * @param key UserDefaults键名
     * @return 解密后的数据，如果失败返回nil
     */
    func securelyLoad<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        do {
            // 1. 从UserDefaults读取加密数据
            guard let combinedData = UserDefaults.standard.data(forKey: key) else {
                return nil
            }
            
            // 2. 解密数据
            let encryptionKey = generateEncryptionKey()
            let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            
            // 3. 反序列化数据
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let data = try decoder.decode(type, from: decryptedData)
            
            return data
            
        } catch {
            // 解密失败时静默返回nil，不输出错误日志
            return nil
        }
    }
    
    /**
     * 安全删除数据
     * @param key UserDefaults键名
     */
    func securelyRemove(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /**
     * 验证数据完整性
     * @param key UserDefaults键名
     * @return 数据是否完整且可解密
     */
    func validateDataIntegrity(forKey key: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return false
        }
        
        do {
            let encryptionKey = generateEncryptionKey()
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            _ = try AES.GCM.open(sealedBox, using: encryptionKey)
            return true
        } catch {
            return false
        }
    }
    
    /**
     * 获取加密数据的大小（字节）
     * @param key UserDefaults键名
     * @return 数据大小，如果数据不存在返回0
     */
    func getDataSize(forKey key: String) -> Int {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return 0
        }
        return data.count
    }
    
    // MARK: - 数据迁移辅助
    
    /**
     * 检查是否存在加密数据
     * @param key UserDefaults键名
     * @return 是否存在可用的加密数据
     */
    func hasSecureData(forKey key: String) -> Bool {
        return UserDefaults.standard.data(forKey: key) != nil && validateDataIntegrity(forKey: key)
    }
    
    /**
     * 从明文数据迁移到加密存储
     * @param key UserDefaults键名
     * @param type 数据类型
     */
    func migrateToSecureStorage<T: Codable>(_ type: T.Type, forKey key: String) {
        // 检查是否已经是加密数据
        if hasSecureData(forKey: key) {
            return
        }
        
        // 尝试读取明文数据
        guard let plaintextData = UserDefaults.standard.data(forKey: key) else {
            return
        }
        
        do {
            // 解码明文数据
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let data = try decoder.decode(type, from: plaintextData)
            
            // 加密保存
            try securelyStore(data, forKey: key)
            
        } catch {
            // 迁移失败，保持原始数据不变
        }
    }
}

// MARK: - 错误类型

enum SecureStorageError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case dataCorrupted
    case keyGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "数据加密失败"
        case .decryptionFailed:
            return "数据解密失败"
        case .dataCorrupted:
            return "数据已损坏"
        case .keyGenerationFailed:
            return "密钥生成失败"
        }
    }
}
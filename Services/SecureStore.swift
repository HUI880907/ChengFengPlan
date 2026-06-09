// MARK: - Imports
import Foundation
import Security

// MARK: - SecureStore

/// Keychain 安全存储服务
final class SecureStore {

    // MARK: - Shared Instance

    static let shared = SecureStore()

    // MARK: - Constants

    private let serviceIdentifier = "com.chengfengplan.securestore"

    // MARK: - Initialization

    private init() {}

    // MARK: - Data Operations

    /// 保存数据到 Keychain
    @discardableResult
    func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// 从 Keychain 加载数据
    func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// 从 Keychain 删除数据
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - String Operations

    /// 保存字符串到 Keychain
    @discardableResult
    func saveString(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }

    /// 从 Keychain 加载字符串
    func loadString(key: String) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Integer Operations

    /// 保存整数到 Keychain
    @discardableResult
    func saveInt(key: String, value: Int) -> Bool {
        var intValue = value
        let data = Data(bytes: &intValue, count: MemoryLayout<Int>.size)
        return save(key: key, data: data)
    }

    /// 从 Keychain 加载整数
    func loadInt(key: String) -> Int? {
        guard let data = load(key: key), data.count == MemoryLayout<Int>.size else { return nil }
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }

    // MARK: - Bool Operations

    /// 保存布尔值到 Keychain
    @discardableResult
    func saveBool(key: String, value: Bool) -> Bool {
        var boolValue = value
        let data = Data(bytes: &boolValue, count: MemoryLayout<Bool>.size)
        return save(key: key, data: data)
    }

    /// 从 Keychain 加载布尔值
    func loadBool(key: String) -> Bool? {
        guard let data = load(key: key), data.count == MemoryLayout<Bool>.size else { return nil }
        return data.withUnsafeBytes { $0.load(as: Bool.self) }
    }

    // MARK: - Date Operations

    /// 保存日期到 Keychain
    @discardableResult
    func saveDate(key: String, value: Date) -> Bool {
        let timeInterval = value.timeIntervalSince1970
        var intervalValue = timeInterval
        let data = Data(bytes: &intervalValue, count: MemoryLayout<TimeInterval>.size)
        return save(key: key, data: data)
    }

    /// 从 Keychain 加载日期
    func loadDate(key: String) -> Date? {
        guard let data = load(key: key), data.count == MemoryLayout<TimeInterval>.size else { return nil }
        let interval = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return Date(timeIntervalSince1970: interval)
    }

    // MARK: - Double Operations

    /// 保存 Double 到 Keychain
    @discardableResult
    func saveDouble(key: String, value: Double) -> Bool {
        var doubleValue = value
        let data = Data(bytes: &doubleValue, count: MemoryLayout<Double>.size)
        return save(key: key, data: data)
    }

    /// 从 Keychain 加载 Double
    func loadDouble(key: String) -> Double? {
        guard let data = load(key: key), data.count == MemoryLayout<Double>.size else { return nil }
        return data.withUnsafeBytes { $0.load(as: Double.self) }
    }

    // MARK: - Batch Operations

    /// 批量保存键值对
    func saveBatch(_ items: [(key: String, data: Data)]) -> [(key: String, success: Bool)] {
        items.map { (key: $0.key, success: save(key: $0.key, data: $0.data)) }
    }

    /// 清空所有存储的数据
    func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

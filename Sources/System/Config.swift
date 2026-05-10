// Sources/System/Config.swift
import Foundation

enum Language: String, Codable, CaseIterable {
    case zh, en, fr
}

enum HotkeyModifier: String, Codable {
    case leftOption = "left_option"
    case rightOption = "right_option"
}

struct Config: Codable, Equatable {
    var openaiApiKey: String = ""
    var defaultLanguage: Language = .en
    var hotkeyModifier: HotkeyModifier = .leftOption
    var dailyCapMinutes: Int = 60

    enum CodingKeys: String, CodingKey {
        case openaiApiKey = "openai_api_key"
        case defaultLanguage = "default_language"
        case hotkeyModifier = "hotkey_modifier"
        case dailyCapMinutes = "daily_cap_minutes"
    }
}

struct ConfigStore {
    let directory: URL
    private let filename = "config.json"

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Shuo", isDirectory: true)
    }

    init(directory: URL = ConfigStore.defaultDirectory()) {
        self.directory = directory
    }

    private var fileURL: URL { directory.appendingPathComponent(filename) }

    func load() throws -> Config {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return Config() }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    func save(_ config: Config) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o600 as Int16)],
                                              ofItemAtPath: fileURL.path)
    }
}

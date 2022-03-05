@preconcurrency import Foundation

private let encoder = JSONEncoder()
private let decoder = JSONDecoder()

public enum StorageError: Error, Equatable, Hashable {
    case loadingFailed(_ underlying: Error)
    case storageFailed(_ underlying: Error)
    case deletionFailed(_ underlying: Error)

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(localizedDescription)
    }
}

public actor Storage {
    /// The root directory that files should be saved in
    private let containerURL: URL

    private let fileManager: FileManager

    /// File-based storage
    ///
    /// This will store files based on their ID and type:
    ///
    ///  ```
    ///  containerURL
    ///  |- SomeEntityType
    ///  |-- id1.json
    ///  |-- id2.json
    ///  |- SomeOtherEntityType
    ///  |-- id1.json
    ///  ```
    ///
    /// - Parameters:
    ///   - containerURL: The root URL of the file tree
    ///   - fileManager: The FileManager to use
    ///   - queue: The queue to execute read/write operations on
    public init(containerURL: URL,
                fileManager: FileManager = .default) {
        self.containerURL = containerURL
        self.fileManager = fileManager
    }

    private func folderURL<T>(for type: T.Type) -> URL {
        containerURL.appendingPathComponent(String(describing: type))
    }

    /// Loads a stored entity
    /// - Parameters:
    ///   - id: The ID of the entity to load
    /// - Returns: The Entity (if it exists)
    public func load<T: Codable & Identifiable>(_ id: T.ID) async throws -> T {

        do {
            let url = folderURL(for: T.self)
                .appendingPathComponent("\(id).json")
            let data = try Data(contentsOf: url)
            let instance = try decoder.decode(T.self, from: data)

            return instance
        } catch {
            throw StorageError.loadingFailed(error)
        }
    }

    /// Loads all entities of a given type
    /// - Parameters:
    ///   - kind: The type of the entities to load
    /// - Returns: All entities of the specified kind
    public func loadAll<T: Codable & Identifiable>(_ kind: T.Type) async throws -> [T] {
        do {
            let url = folderURL(for: T.self)
            guard fileManager.fileExists(atPath: url.path) else { return [] }
            let instances = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []).map { url -> T in

                    let data = try Data(contentsOf: url)
                    return try decoder.decode(T.self, from: data)
                }
            return instances
        } catch {
            throw StorageError.loadingFailed(error)
        }
    }

    /// Store an entity
    /// - Parameters:
    ///   - entity: The entity to store
    /// - Returns: Nothing on success, or any error
    public func store<T: Codable & Identifiable>(entity: T) async throws {
        do {
            let data = try encoder.encode(entity)
            let url = folderURL(for: T.self)
                .appendingPathComponent("\(entity.id).json")
            try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomicWrite)
        } catch {
            throw StorageError.storageFailed(error)
        }
    }

    /// Deletes a given entity
    /// - Parameters:
    ///   - entity: The entity to delete
    /// - Returns: Nothing on success, or any error
    public func delete<T: Codable & Identifiable>(_ entity: T) async throws {
        do {
            let url = folderURL(for: T.self)
                .appendingPathComponent("\(entity.id).json")
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch {
            throw StorageError.deletionFailed(error)
        }
    }

    /// Deletes all entities of a given type
    /// - Parameters:
    ///   - kind: The type of the entities to delete
    /// - Returns: Nothing on success, or any error
    public func deleteAll<T: Codable & Identifiable>(_ kind: T.Type) async throws {
        do {
            let url = folderURL(for: T.self)
            try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []).forEach { url in
                    if fileManager.fileExists(atPath: url.path) {
                        try fileManager.removeItem(at: url)
                    }
                }
        } catch {
            throw StorageError.deletionFailed(error)
        }
    }
}

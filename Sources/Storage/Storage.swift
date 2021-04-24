import Foundation
import Combine

private let encoder = JSONEncoder()
private let decoder = JSONDecoder()

public enum StorageError: Error, Equatable, Hashable {
    case loadingFailed(_ underlying: Error)
    case storageFailed(_ underlying: Error)
    case deletionFailed(_ underlying: Error)

    public static func == (lhs: StorageError, rhs: StorageError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(localizedDescription)
    }
}

public struct Storage {
    /// The root directory that files should be saved in
    private let containerURL: URL

    private let fileManager: FileManager

    private let queue = DispatchQueue(label: "storage background queue")

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
    ///  |- CustomFolder
    ///  |-- SomePrivateEntity
    ///  |--- id1.json
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
    ///   - folder: An optional custom folder to load items in
    /// - Returns: The Entity (if it exists)
    public func load<T: Codable & Identifiable>(_ id: T.ID, in folder: String? = nil) -> AnyPublisher<T, Error> {
        Future<T, Error> { promise in
            queue.async {
                do {
                    let url = folderURL(for: T.self)
                        .appendingOptionalPathComponent(folder)
                        .appendingPathComponent("\(id).json")
                    let data = try Data(contentsOf: url)
                    let instance = try decoder.decode(T.self, from: data)

                    promise(.success(instance))
                } catch {
                    promise(.failure(StorageError.loadingFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }

    /// Loads all entities of a given type
    /// - Parameters:
    ///   - kind: The type of the entities to load
    ///   - folder: An optional custom folder to load items in
    /// - Returns: All entities of the specified kind
    public func loadAll<T: Codable & Identifiable>(_ kind: T.Type, in folder: String? = nil) -> AnyPublisher<[T], Error> {
        Future<[T], Error> { promise in
            queue.async {
                do {
                    let url = folderURL(for: T.self)
                        .appendingOptionalPathComponent(folder)
                    guard fileManager.fileExists(atPath: url.path) else { return promise(.success([])) }
                    let instances = try fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: nil,
                        options: []).map { url -> T in

                            let data = try Data(contentsOf: url)
                            return try decoder.decode(T.self, from: data)
                        }
                    promise(.success(instances))
                } catch {
                    promise(.failure(StorageError.loadingFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }

    /// Store an entity
    /// - Parameters:
    ///   - entity: The entity to store
    ///   - folder: An optional custome folder to store the entity in
    /// - Returns: Nothing on success, or any error
    public func store<T: Codable & Identifiable>(entity: T, in folder: String? = nil) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            queue.async {
                do {
                    let data = try encoder.encode(entity)
                    let url = folderURL(for: T.self)
                        .appendingOptionalPathComponent(folder)
                        .appendingPathComponent("\(entity.id).json")
                    try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: url, options: .atomicWrite)
                    promise(.success(()))
                } catch {
                    promise(.failure(StorageError.storageFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }

    /// Deletes a given entity
    /// - Parameters:
    ///   - entity: The entity to delete
    ///   - folder: An optional custom folder to delete the entity in
    /// - Returns: Nothing on success, or any error
    public func delete<T: Codable & Identifiable>(_ entity: T, in folder: String? = nil) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            queue.async {
                do {
                    let url = folderURL(for: T.self)
                        .appendingOptionalPathComponent(folder)
                        .appendingPathComponent("\(entity.id).json")
                    if fileManager.fileExists(atPath: url.path) {
                        try fileManager.removeItem(at: url)
                    }
                    promise(.success(()))
                } catch {
                    promise(.failure(StorageError.deletionFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }

    /// Deletes all entities of a given type
    /// - Parameters:
    ///   - kind: The type of the entities to delete
    ///   - folder: An optional custom folder to delete entities in
    /// - Returns: Nothing on success, or any error
    public func deleteAll<T: Codable & Identifiable>(_ kind: T.Type, in folder: String? = nil) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            queue.async {
                do {
                    let url = folderURL(for: T.self)
                        .appendingOptionalPathComponent(folder)
                    try fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: nil,
                        options: []).forEach { url in
                            if fileManager.fileExists(atPath: url.path) {
                                try fileManager.removeItem(at: url)
                            }
                        }
                    promise(.success(()))
                } catch {
                    promise(.failure(StorageError.deletionFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }
}

private extension URL {
    func appendingOptionalPathComponent(_ component: String?) -> URL {
        if let component = component {
            return self.appendingPathComponent(component)
        } else {
            return self
        }
    }
}

@preconcurrency import XCTest
@testable import Storage

struct Entity: Codable, Hashable, Identifiable {
    let id: Int
    let data: String
}

final class StorageTests: XCTestCase {
    private let tempFile = try! TemporaryFile(creatingTempDirectoryForFilename: #file)
    private let testEntity1 = Entity(id: 1, data: "data 1")
    private let testEntity2 = Entity(id: 2, data: "data 2")
    private let testEntity3 = Entity(id: 3, data: "data 3")

    override func tearDown() async throws {
        try tempFile.deleteDirectory()
        try await super.tearDown()
    }

    func testStoringAndLoadingTheSameEntityShouldRestoreItIdentically() async throws {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)

        // When
        try await storage.store(entity: testEntity1)
        let value: Entity = try await storage.load(self.testEntity1.id)

        // Then
        XCTAssertEqual(value, self.testEntity1)
    }

    func testLoadingANonExistingEntityShouldFail() async throws {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)

        // Then
        await XCTAssertThrowsError(try await storage.load(self.testEntity1.id) as Entity)
    }

    func testStoringAndDeletingShouldRemoveTheEntity() async throws {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)

        // When
        try await storage.store(entity: testEntity1)
        try await storage.delete(self.testEntity1)
        let entities = try await storage.loadAll(Entity.self)
        // Then
        XCTAssert(entities.isEmpty)
    }

    func testDeletingANonExistingEntityShouldSignalSuccess() async throws {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)

        // When
        try await storage.delete(self.testEntity1)

        // Then
        // Pass! No error was thrown
    }

    func testLoadAllShouldLoadAllEntitiesOfAKind() async throws {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)

        // When
        try await storage.store(entity: testEntity1)
        try await storage.store(entity: self.testEntity2)
        let entities = try await storage.loadAll(Entity.self)

        // Then
        XCTAssertEqual(entities.count, 2)
    }

    func testDeleteAllShouldDeleteAllEntitiesOfAKind() async throws {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        try await storage.store(entity: testEntity1)
        try await storage.store(entity: self.testEntity2)
        let entitiesBeforeDeletion = try await storage.loadAll(Entity.self)
        XCTAssertEqual(entitiesBeforeDeletion.count, 2)

        // When
        try await storage.deleteAll(Entity.self)
        let entitiesAfterDeletion = try await storage.loadAll(Entity.self)

        // Then
        XCTAssert(entitiesAfterDeletion.isEmpty)
    }
}

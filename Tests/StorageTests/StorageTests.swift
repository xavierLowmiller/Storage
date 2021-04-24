import XCTest
import Combine
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

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try tempFile.deleteDirectory()
    }

    func testStoringAndLoadingTheSameEntityShouldRestoreItIdentically() throws {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.store(entity: testEntity1)
            .flatMap { storage.load(self.testEntity1.id) }
            .sink { result in
                result.assertSuccess()
                exp.fulfill()
            } receiveValue: {
                // Then
                XCTAssertEqual($0, self.testEntity1)
            }

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    func testLoadingANonExistingEntityShouldFail() throws {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.load(self.testEntity1.id)
            .sink { result in
                // Then
                result.assertFailure()
                exp.fulfill()
            } receiveValue: { (result: Entity) in
                XCTFail("Shouldn't load an entity that doesn't exist")
            }

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    func testStoringAndDeletingShouldRemoveTheEntity() {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.store(entity: testEntity1)
            .flatMap { storage.delete(self.testEntity1) }
            .flatMap { storage.loadAll(Entity.self) }
            .sink(receiveCompletion: { result in
                result.assertSuccess()
                exp.fulfill()
            }, receiveValue: { entities in
                XCTAssert(entities.isEmpty)
            })

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    func testDeletingANonExistingEntityShouldSignalSuccess() throws {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.delete(self.testEntity1)
            .sink { result in
                // Then
                result.assertSuccess()
                exp.fulfill()
            } receiveValue: {
                // Void should be received
            }

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    func testLoadAllShouldLoadAllEntitiesOfAKind() {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.store(entity: testEntity1)
            .flatMap { storage.store(entity: self.testEntity2) }
            .flatMap { storage.loadAll(Entity.self) }
            .sink(receiveCompletion: { result in
                result.assertSuccess()
                exp.fulfill()
            }, receiveValue: { entities in
                XCTAssertEqual(entities.count, 2)
            })

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    func testDeleteAllShouldDeleteAllEntitiesOfAKind() {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.store(entity: testEntity1)
            .flatMap { storage.store(entity: self.testEntity2) }
            .flatMap { storage.loadAll(Entity.self) }
            .handleEvents(receiveOutput: {
                XCTAssertEqual($0.count, 2)
            })
            .flatMap { _ in storage.deleteAll(Entity.self) }
            .flatMap { storage.loadAll(Entity.self) }
            .sink(receiveCompletion: { result in
                result.assertSuccess()
                exp.fulfill()
            }, receiveValue: { entities in
                XCTAssert(entities.isEmpty)
            })

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    // MARK: - Folder Tests

    func testStoringAndLoadingInFolder() {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.store(entity: testEntity1, in: "user1")
            .flatMap { storage.load(self.testEntity1.id, in: "user1") }
            .sink { result in
                result.assertSuccess()
                exp.fulfill()
            } receiveValue: {
                // Then
                XCTAssertEqual($0, self.testEntity1)
            }

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    func testStoringAndLoadingInDifferentFolder() {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.store(entity: testEntity1, in: "user1")
            .flatMap { storage.load(self.testEntity1.id, in: "user2") }
            .sink { result in
                result.assertFailure()
                exp.fulfill()
            } receiveValue: { (result: Entity) in
                // Then
                XCTFail("Shouldn't load contents of different folder")
            }

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    func testStoringAndDeletingShouldRemoveTheEntityInsideFolders() {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.store(entity: testEntity1, in: "user1")
            .flatMap { storage.delete(self.testEntity1, in: "user1") }
            .flatMap { storage.loadAll(Entity.self, in: "user1") }
            .sink(receiveCompletion: { result in
                result.assertSuccess()
                exp.fulfill()
            }, receiveValue: { entities in
                XCTAssert(entities.isEmpty)
            })

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    func testStoringAndDeletingShouldNotTouchTheEntityInDifferentFolders() {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.store(entity: testEntity1, in: "user1")
            .flatMap { storage.delete(self.testEntity1, in: "user2") }
            .flatMap { storage.loadAll(Entity.self, in: "user1") }
            .sink(receiveCompletion: { result in
                result.assertSuccess()
                exp.fulfill()
            }, receiveValue: { entities in
                XCTAssertEqual(entities, [self.testEntity1])
            })

        wait(for: [exp], timeout: 1)
        token.cancel()
    }

    func testLoadAllShouldLoadAllEntitiesOfAKindInAFolder() {
        // Given
        let storage = Storage(containerURL: tempFile.directoryURL)
        let exp = XCTestExpectation(description: #function)

        // When
        let token = storage.store(entity: testEntity1, in: "user1")
            .flatMap { storage.store(entity: self.testEntity2, in: "user2") }
            .flatMap { storage.store(entity: self.testEntity3, in: "user1") }
            .flatMap { storage.loadAll(Entity.self, in: "user1") }
            .sink(receiveCompletion: { result in
                result.assertSuccess()
                exp.fulfill()
            }, receiveValue: { entities in
                XCTAssertEqual(entities, [self.testEntity1, self.testEntity3])
            })

        wait(for: [exp], timeout: 1)
        token.cancel()
    }
}

extension Subscribers.Completion {
    func assertSuccess() {
        switch self {
        case .finished:
            // Pass!
            break
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func assertFailure() {
        switch self {
        case .finished:
            XCTFail("Unexpectedly, the operation succeeded")
        case .failure:
            // Pass!
            break
        }
    }
}

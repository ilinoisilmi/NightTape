import Foundation

/// One folder per night under Documents/Sessions/<uuid>/:
///   session.json  +  clip-*.m4a
final class SessionStore {
    static let shared = SessionStore()

    let root: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = docs.appendingPathComponent("Sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    // MARK: Paths

    func sessionDir(_ id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func sessionFile(_ id: UUID) -> URL {
        sessionDir(id).appendingPathComponent("session.json")
    }

    func clipURL(sessionID: UUID, event: SleepEvent) -> URL? {
        guard let name = event.clipFileName else { return nil }
        return sessionDir(sessionID).appendingPathComponent(name)
    }

    /// Creates the folder for a new night and returns it (clips land here).
    func beginSessionDir(_ id: UUID) -> URL {
        let dir = sessionDir(id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Persistence

    func save(_ session: SleepSession) {
        let dir = sessionDir(session.id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(session) {
            try? data.write(to: sessionFile(session.id), options: .atomic)
        }
    }

    func loadAll() -> [SleepSession] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        var sessions: [SleepSession] = []
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        for dir in dirs {
            let f = dir.appendingPathComponent("session.json")
            guard let data = try? Data(contentsOf: f),
                  let s = try? dec.decode(SleepSession.self, from: data) else { continue }
            sessions.append(s)
        }
        return sessions.sorted { $0.startedAt > $1.startedAt }
    }

    func delete(_ session: SleepSession) {
        try? FileManager.default.removeItem(at: sessionDir(session.id))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    // MARK: Maintenance

    func cleanup(olderThanDays days: Int) {
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        for s in loadAll() where s.startedAt < cutoff {
            delete(s)
        }
    }

    /// Closes sessions that never ended (app force-quit or crash mid-night).
    func recoverInterrupted() {
        var changed = false
        for var s in loadAll() where s.endedAt == nil {
            s.endedAt = Date()
            s.endedReason = "interrupted"
            save(s)
            changed = true
        }
        _ = changed
    }

    func storageSizeBytes() -> Int64 {
        let fm = FileManager.default
        guard let e = fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in e {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}

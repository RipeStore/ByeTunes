import Foundation
import UIKit
import Combine

extension Notification.Name {
    static let backgroundMetadataFetchCompleted = Notification.Name("BackgroundMetadataFetchCompleted")
}

@MainActor
final class BackgroundMetadataFetchManager: ObservableObject {
    static let shared = BackgroundMetadataFetchManager()

    private static let readySongsKey = "backgroundMetadataFetchReadySongs.v1"

    @Published private(set) var isProcessing = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var drainTask: Task<Void, Never>?

    private init() {}

    nonisolated static var isEnabled: Bool {
        if let stored = UserDefaults.standard.object(forKey: "backgroundMetadataFetchEnabled") as? Bool {
            return stored
        }
        return true
    }

    func processPendingDownloadsInBackground() {
        guard Self.isEnabled else { return }
        guard !isProcessing else { return }

        isProcessing = true
        beginBackgroundTaskIfNeeded()

        drainTask = Task { @MainActor in
            defer {
                endBackgroundTaskIfNeeded()
                isProcessing = false
                drainTask = nil
            }
            await drainQueue()
        }
    }

    func cancel() {
        guard isProcessing else { return }
        log("Manual cancel requested")
        drainTask?.cancel()
        drainTask = nil
        isProcessing = false
        endBackgroundTaskIfNeeded()
        MetadataBackgroundURLSession.shared.cancelAllTasks()
    }

    func drainReadySongs() -> [SongMetadata] {
        let persisted = load([PersistedSong].self, forKey: Self.readySongsKey) ?? []
        guard !persisted.isEmpty else { return [] }
        UserDefaults.standard.removeObject(forKey: Self.readySongsKey)

        return persisted.compactMap { item in
            let url = URL(fileURLWithPath: item.localURLPath)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return item.songMetadata(localURL: url)
        }
    }

    private func drainQueue() async {
        while !Task.isCancelled {
            let pending = QueuePersistenceStore.loadPendingDownloadedImports()
            guard let item = pending.first else { break }

            let url = URL(fileURLWithPath: item.localURLPath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                removePendingImport(item)
                continue
            }

            var song = await parseSong(at: url)
            song = await SongMetadataNetworking.$useBackgroundSession.withValue(true) {
                await enrich(song)
            }
            song = await persistDownloadedSongIfNeeded(song)

            appendReadySong(song)
            removePendingImport(item)
            log("Enriched \(song.title) [\(item.trackID ?? "unknown")] in the background.")
            NotificationCenter.default.post(name: .backgroundMetadataFetchCompleted, object: nil)
        }
    }

    private func parseSong(at url: URL) async -> SongMetadata {
        if let parsed = try? await SongMetadata.fromURL(url, includeArtwork: true) {
            return parsed
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        log("Fallback metadata used for \(url.lastPathComponent) during background fetch.")
        return SongMetadata(
            localURL: url,
            title: url.deletingPathExtension().lastPathComponent,
            artist: "Unknown Artist",
            album: "Unknown Album",
            albumArtist: nil,
            genre: "Unknown Genre",
            year: Calendar.current.component(.year, from: Date()),
            durationMs: 0,
            fileSize: fileSize,
            remoteFilename: SongMetadata.generateRemoteFilename(withExtension: url.pathExtension.lowercased()),
            artworkData: nil,
            trackNumber: nil,
            trackCount: nil,
            discNumber: nil,
            discCount: nil,
            lyrics: nil
        )
    }

    private func enrich(_ initialSong: SongMetadata) async -> SongMetadata {
        var song = initialSong

        let metadataSource = UserDefaults.standard.string(forKey: "metadataSource") ?? "local"
        let autofetch = UserDefaults.standard.bool(forKey: "autofetchMetadata")
        let fetchLyrics = UserDefaults.standard.bool(forKey: "fetchLyrics")

        if metadataSource == "apple" && autofetch {
            song = await SongMetadata.enrichWithAppleMusicMetadata(song)
        } else if metadataSource == "itunes" && autofetch {
            song = await SongMetadata.enrichWithiTunesMetadata(song)
        } else if metadataSource == "deezer" && autofetch {
            song = await SongMetadata.enrichWithDeezerMetadata(song)
        } else if metadataSource == "local" && autofetch {
            if UserDefaults.standard.bool(forKey: "appleRichMetadata") {
                song = await SongMetadata.matchAppleMusicMetadata(song)
            }
        }

        let appleSubscriptionLyrics = UserDefaults.standard.bool(forKey: "appleSubscriptionLyrics")
        if fetchLyrics && !appleSubscriptionLyrics && (song.lyrics == nil || song.lyrics?.isEmpty == true) {
            if let fetchedLyrics = await SongMetadata.fetchLyrics(
                title: song.title,
                artist: song.artist,
                album: song.album,
                durationMs: song.durationMs
            ) {
                song.lyrics = fetchedLyrics
            }
        }

        return song
    }

    private func persistDownloadedSongIfNeeded(_ song: SongMetadata) async -> SongMetadata {
        guard UserDefaults.standard.bool(forKey: "keepDownloadedSongs") else { return song }

        let directory = SongMetadata.persistentDownloadsDirectory()
        let needsSecurityScope = directory.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                directory.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            log("Failed to create persistent download folder: \(error)")
            return song
        }

        let ext = song.localURL.pathExtension.isEmpty ? "flac" : song.localURL.pathExtension
        let baseName = "\(song.artist) - \(song.title)"
        let safeBaseName = baseName
            .components(separatedBy: CharacterSet(charactersIn: "/:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var destination = directory.appendingPathComponent("\(safeBaseName.isEmpty ? song.localURL.deletingPathExtension().lastPathComponent : safeBaseName).\(ext)")
        var suffix = 1
        while FileManager.default.fileExists(atPath: destination.path) && destination.path != song.localURL.path {
            destination = directory.appendingPathComponent("\(safeBaseName.isEmpty ? song.localURL.deletingPathExtension().lastPathComponent : safeBaseName)-\(suffix).\(ext)")
            suffix += 1
        }

        if destination.path == song.localURL.path {
            return song
        }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            let source = song.localURL
            let dest = destination
            try await Task.detached(priority: .utility) {
                try FileManager.default.copyItem(at: source, to: dest)
            }.value
            try? FileManager.default.removeItem(at: song.localURL)
            var updatedSong = song
            updatedSong.localURL = destination
            return updatedSong
        } catch {
            log("Failed to persist downloaded song \(song.title): \(error)")
            return song
        }
    }

    private func appendReadySong(_ song: SongMetadata) {
        var persisted = load([PersistedSong].self, forKey: Self.readySongsKey) ?? []
        persisted.append(PersistedSong(song: song))
        save(persisted, forKey: Self.readySongsKey)
    }

    private func removePendingImport(_ item: PersistedPendingDownloadedImport) {
        let remaining = QueuePersistenceStore.loadPendingDownloadedImports().filter { pending in
            pending.localURLPath != item.localURLPath
        }
        QueuePersistenceStore.savePendingDownloadedImports(remaining)
    }

    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "BackgroundMetadataFetch") { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.log("Background task expired while metadata fetch was active; cancelling drain")
                self.drainTask?.cancel()
                self.drainTask = nil
                self.isProcessing = false
                self.endBackgroundTaskIfNeeded()
            }
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            log("Failed to save \(key): \(error)")
        }
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            log("Failed to load \(key): \(error)")
            return nil
        }
    }

    private func log(_ message: String) {
        Logger.shared.log("[BGMetadata] \(message)")
    }
}

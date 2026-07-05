import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var manager: DeviceManager
    @Binding var status: String
    
    @State private var showingPairingPicker = false
    @State private var showingDownloadFolderPicker = false
    @State private var showingDeleteAlert = false
    
    @State private var showingLogViewer = false
    @State private var exportedDbURLs: [URL] = []
    @State private var showingDbExportSheet = false
    @State private var isExportingDb = false
    @State private var isCheckingForUpdate = false
    @State private var settingsUpdate: AppUpdateInfo?
    @State private var supporters: [String] = []
    @State private var supportersLoaded = false
    
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastIcon = ""

    @AppStorage("metadataSource") private var metadataSource = "local"
    @AppStorage("autofetchMetadata") private var autofetchMetadata = true
    @AppStorage("fetchLyrics") private var fetchLyrics = false
    @AppStorage("appleSubscriptionLyrics") private var appleSubscriptionLyrics = false
    @AppStorage("storeRegion") private var storeRegion = "US"
    @AppStorage("appleRichMetadata") private var appleRichMetadata = true
    @AppStorage("keepDownloadedSongs") private var keepDownloadedSongs = false
    @AppStorage("backgroundDownloadsEnabled") private var backgroundDownloadsEnabled = false
    @AppStorage("backgroundMetadataFetchEnabled") private var backgroundMetadataFetchEnabled = true
    @AppStorage("downloadLiveActivitiesEnabled") private var downloadLiveActivitiesEnabled = true
    @AppStorage("fullBackupSnapshots") private var fullBackupSnapshots = false
    @AppStorage("downloadServer") private var downloadServer = DownloaderServerPreference.byeTunesAPI.rawValue
    @AppStorage("downloadSearchProvider") private var downloadSearchProvider = DownloadSearchProviderOption.appleMusic.rawValue
    @AppStorage("autoDownloadTier") private var autoDownloadTier = "high"
    @AppStorage("yoinkifyFormat") private var yoinkifyFormat = "flac"
    @AppStorage("qobuzFallbackQuality") private var qobuzFallbackQuality = "27"
    @AppStorage("tidalFallbackQuality") private var tidalFallbackQuality = "LOSSLESS"
    
    var body: some View {
        NavigationStack {
        ZStack(alignment: .bottom) {

        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                
                Text("Settings")
                    .font(.system(size: 34, weight: .bold))
                    .padding(.top, 8)
                
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("CONNECTION")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    VStack(spacing: 0) {
                        
                        Button {
                            showingPairingPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(manager.expectedPairingFileTitle)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(manager.connectionStatus)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 28)
                            
                            Text("Status")
                                .font(.body)
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(manager.heartbeatReady ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(manager.connectionStatus)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Button {
                                    manager.startHeartbeat(forceReconnect: true)
                                } label: {
                                    Text("Refresh")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                }
                                .padding(.leading, 8)
                                .disabled(!manager.hasValidExpectedPairingFile)
                                .opacity(manager.hasValidExpectedPairingFile ? 1 : 0.55)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }
                
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("ABOUT")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    VStack(spacing: 0) {
                        Button {
                            if let settingsUpdate {
                                openURL(settingsUpdate.releaseURL)
                            } else {
                                checkForSettingsUpdate()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Version")
                                        .font(.body)
                                        .foregroundColor(.primary)

                                    Text(settingsUpdate == nil ? "Tap to check for updates" : "Tap to download the latest release")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isCheckingForUpdate {
                                    ProgressView()
                                } else {
                                    Text(settingsUpdate.map { "Update \($0.version)" } ?? AppUpdateChecker.currentVersion)
                                        .font(.subheadline)
                                        .foregroundColor(settingsUpdate == nil ? .secondary : .accentColor)
                                }
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .disabled(isCheckingForUpdate)
                        
                        Divider().padding(.leading, 56)
                        
                        HStack {
                            Image(systemName: "music.note")
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 28)
                            
                            Text("Music Formats")
                                .font(.body)
                            
                            Spacer()
                            
                            Text("MP3, FLAC, M4A, WAV, Opus")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        
                        Divider().padding(.leading, 56)
                        
                        HStack {
                            Image(systemName: "bell.badge")
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 28)
                            
                            Text("Ringtone Formats")
                                .font(.body)
                            
                            Spacer()
                            
                            Text("M4R, MP3 (Ringtones injection disabled for now")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }
                
                
                
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("LIBRARY REPAIR & MAINTENANCE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    VStack(spacing: 0) {
                        NavigationLink {
                            LibraryRepairView(manager: manager, status: $status)
                        } label: {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Repair & Maintenance")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("Clean, repair, and fix artwork in your library")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }


                VStack(alignment: .leading, spacing: 12) {
                    Text("DOWNLOADS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    VStack(spacing: 0) {
                        NavigationLink {
                            DownloaderSettingsScreen(
                                metadataSource: $metadataSource,
                                autofetchMetadata: $autofetchMetadata,
                                fetchLyrics: $fetchLyrics,
                                appleSubscriptionLyrics: $appleSubscriptionLyrics,
                                storeRegion: $storeRegion,
                                appleRichMetadata: $appleRichMetadata,
                                downloadServer: $downloadServer,
                                downloadSearchProvider: $downloadSearchProvider,
                                keepDownloadedSongs: $keepDownloadedSongs,
                                backgroundDownloadsEnabled: $backgroundDownloadsEnabled,
                                backgroundMetadataFetchEnabled: $backgroundMetadataFetchEnabled,
                                downloadLiveActivitiesEnabled: $downloadLiveActivitiesEnabled,
                                showingDownloadFolderPicker: $showingDownloadFolderPicker,
                                autoDownloadTier: $autoDownloadTier,
                                yoinkifyFormat: $yoinkifyFormat,
                                qobuzFallbackQuality: $qobuzFallbackQuality,
                                tidalFallbackQuality: $tidalFallbackQuality,
                                downloadFolderSubtitle: downloadFolderSubtitle
                            )
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Metadata & Download Settings")
                                        .font(.body)
                                    Text("Metadata source, downloader, quality, and saved downloads")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("DEVICE LIBRARY")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    VStack(spacing: 0) {
                        NavigationLink {
                            DeviceLibraryBrowserView(manager: manager)
                        } label: {
                            HStack {
                                Image(systemName: "music.note.list")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("On-Device Library")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("Edit, delete, and export songs already on the phone")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                        .disabled(!manager.heartbeatReady)
                        .opacity(manager.heartbeatReady ? 1 : 0.55)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )

                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("BACKUP & RESTORE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    VStack(spacing: 0) {
                        NavigationLink {
                            BackupRestoreView(manager: manager)
                        } label: {
                            HStack {
                                Image(systemName: "archivebox.fill")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Backup & Restore")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("Back up database/snapshots or backup & restore playlists")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("SHORTCUTS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    VStack(spacing: 0) {
                        Link(destination: URL(string: "https://www.icloud.com/shortcuts/49de36f87bf44b21a38056d3c33e41fe")!) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .font(.body)
                                    .foregroundColor(.purple)
                                    .frame(width: 28)
                                
                                Text("Add ByeTunes Shortcut")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }
                
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("HELP & SUPPORT")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    VStack(spacing: 0) {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("1. Ensure you are connected to your Local Tunnel VPN (e.g., StosVPN, LocalDev VPN).")
                                Text("2. If connected after opening the app, press 'Retry' next to the 'Connecting' status.")
                                Text("3. Go to the Music tab.")
                                Text("4. Tap 'Add Songs' to select your audio files.")
                                Text("5. Tap 'Inject to Device' to sync them to your library.")
                            }
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("How to Use")
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()
                        
                        Divider().padding(.leading)
                        
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("• App Stuck on White/Black Screen?")
                                Text("  Restart your iPhone to force a library reload.")
                                Text("• Songs Not Showing Up?")
                                Text("  The songs likely didn't import correctly. Restart this app and try again.")
                            }
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("App Crashing / No Songs?")
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("• Artwork Disappeared?")
                                Text("  Restart the music app to refresh the cache.")
                                Text("• Song Not Injected?")
                                Text("  To prevent artwork mix-ups, 'Unknown' songs are skipped in batches. Inject them individually to add them.")
                            }
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Image(systemName: "photo.artframe")
                                    .foregroundColor(.purple)
                                Text("Artwork / Missing Songs")
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()
                        
                        Divider().padding(.leading)
                        
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("• What is Auto-Inject?")
                                Text("  When you share audio files to MusicManager from other apps (like Files), they are automatically injected to your device if connected.")
                                Text("• Supported Music Formats:")
                                Text("  MP3, M4A, FLAC, WAV, AIFF, Opus")
                                Text("• Supported Ringtone Formats:")
                                Text("  M4R only (MP3 ringtones must be added manually inside the app)")
                            }
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down.on.square.fill")
                                    .foregroundColor(.green)
                                Text("Auto-Inject")
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()


                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }
                
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("CREDITS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                                .frame(width: 28)
                            
                            Link("EduAlexxis", destination: URL(string: "https://github.com/EduAlexxis")!)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        
                        Divider().padding(.leading, 56)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.indigo)
                                .frame(width: 28)
                            
                            Link("stossy11", destination: URL(string: "https://github.com/stossy11")!)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        
                        Divider().padding(.leading, 56)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "paintbrush.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.orange)
                                .frame(width: 28)
                            
                            Text("u/Zephyrax_g14")
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        
                        Divider().padding(.leading, 56)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                                .frame(width: 28)
                            
                            Link("jkcoxson", destination: URL(string: "https://github.com/jkcoxson/idevice")!)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }


                VStack(alignment: .leading, spacing: 12) {
                    Text("DEBUG")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    VStack(spacing: 0) {
                        
                        Button {
                            showingLogViewer = true
                        } label: {
                            HStack {
                                Image(systemName: "terminal.fill")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)
                                
                                Text("Console")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        Button {
                            exportDatabase()
                        } label: {
                            HStack {
                                if isExportingDb {
                                    ProgressView()
                                        .frame(width: 28)
                                } else {
                                    Image(systemName: "cylinder.split.1x2")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .frame(width: 28)
                                }
                                
                                Text(isExportingDb ? "Exporting…" : "Export Database")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                        .disabled(isExportingDb || !manager.heartbeatReady)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("SUPPORT")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    VStack(spacing: 0) {
                        Button {
                            openURL(URL(string: "https://buymeacoffee.com/EduAlexxis")!)
                        } label: {
                            HStack {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Buy Me a Coffee")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text("Support ByeTunes development")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }

                        Divider().padding(.leading, 44)

                        HStack(alignment: .top) {
                            Image(systemName: "heart.fill")
                                .font(.body)
                                .foregroundColor(.pink)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Supporters")
                                    .font(.body)
                                    .foregroundColor(.primary)

                                if !supportersLoaded {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(height: 20)
                                } else if supporters.isEmpty {
                                    Text("Be the first to support!")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    FlowLayout(spacing: 6) {
                                        ForEach(supporters, id: \.self) { name in
                                            Text(name)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(Color(.systemGray6))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                    .task {
                        await fetchSupporters()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("DANGER ZONE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.body)
                                .foregroundColor(.red)
                                .frame(width: 28)
                            
                            Text("Delete Music Library")
                                .font(.body)
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                    }
                }

                

                }
                .frame(width: max(proxy.size.width - 40, 0), alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
                }
                .frame(width: proxy.size.width, alignment: .topLeading)
                .clipped()
            }
        }
        .sheet(isPresented: $showingPairingPicker) {
            DocumentPicker(types: [.data, .xml, .propertyList, .item]) { url in
                handlePairingImport(url: url)
            }
        }
        .sheet(isPresented: $showingDownloadFolderPicker) {
            DocumentPicker(types: [.folder], asCopy: false) { url in
                handleDownloadFolderSelection(url: url)
            }
        }
        .sheet(isPresented: $showingLogViewer) {
            LogViewer()
        }
        .sheet(isPresented: $showingDbExportSheet) {
            LogShareSheet(activityItems: exportedDbURLs)
        }
        .alert("Delete Library?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                manager.deleteMediaLibrary { success in
                    DispatchQueue.main.async {
                        if success {
                            self.showToastMessage(title: "Library Deleted", icon: "trash.circle.fill")
                        } else {
                            self.showToastMessage(title: "Deletion Failed", icon: "exclamationmark.triangle.fill")
                        }
                    }
                }
            }
        } message: {
            Text("This will permanently delete your Music library database and playlists from the device. This action cannot be undone.")
        }
        .onAppear {
            if downloadSearchProvider == DownloadSearchProviderOption.tidal.rawValue || downloadSearchProvider == DownloadSearchProviderOption.spotify.rawValue {
                downloadSearchProvider = DownloadSearchProviderOption.appleMusic.rawValue
            }
        }

        if showToast {
            HStack(spacing: 12) {
                Image(systemName: toastIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)

                Text(toastTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        }
        .animation(.spring(), value: showToast)
        }
    }

    // MARK: - Supporters
    private func fetchSupporters() async {
        guard !supportersLoaded || supporters.isEmpty else { return }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "https://raw.githubusercontent.com/EduAlexxis/EduAlexxis-Altstore-Repo/main/supporters.json?t=\(timestamp)") else { return }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Response: Decodable { let supporters: [String] }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            await MainActor.run {
                supporters = decoded.supporters
                supportersLoaded = true
            }
        } catch {
            print("Failed to fetch supporters: \(error)")
            await MainActor.run {
                supportersLoaded = true
            }
        }
    }

    private func exportDatabase() {
        isExportingDb = true

        let tmp = FileManager.default.temporaryDirectory
        let files: [(remote: String, local: URL)] = [
            ("/iTunes_Control/iTunes/MediaLibrary.sqlitedb",
             tmp.appendingPathComponent("MediaLibrary.sqlitedb")),
            ("/iTunes_Control/iTunes/MediaLibrary.sqlitedb-shm",
             tmp.appendingPathComponent("MediaLibrary.sqlitedb-shm")),
            ("/iTunes_Control/iTunes/MediaLibrary.sqlitedb-wal",
             tmp.appendingPathComponent("MediaLibrary.sqlitedb-wal")),
            ("/iTunes_Control/Ringtones/Ringtones.plist",
             tmp.appendingPathComponent("Ringtones.plist"))
        ]

        var downloaded: [URL] = []

        func downloadNext(_ index: Int) {
            guard index < files.count else {
                DispatchQueue.main.async {
                    self.isExportingDb = false
                    if downloaded.isEmpty {
                        self.showToastMessage(title: "Export Failed", icon: "xmark.circle.fill")
                    } else {
                        self.exportedDbURLs = downloaded
                        self.showingDbExportSheet = true
                    }
                }
                return
            }

            let file = files[index]
            manager.downloadFileFromDevice(remotePath: file.remote, localURL: file.local) { success in
                if success {
                    downloaded.append(file.local)
                }
                downloadNext(index + 1)
            }
        }

        downloadNext(0)
    }



    private func checkForSettingsUpdate() {
        isCheckingForUpdate = true
        Task {
            do {
                let update = try await AppUpdateChecker.checkForUpdate()
                await MainActor.run {
                    self.isCheckingForUpdate = false
                    self.settingsUpdate = update
                    if let update {
                        self.showToastMessage(title: "ByeTunes \(update.version) is available", icon: "arrow.down.circle.fill")
                    } else {
                        self.showToastMessage(title: "ByeTunes is up to date", icon: "checkmark.circle.fill")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCheckingForUpdate = false
                    self.showToastMessage(title: "Update Check Failed", icon: "xmark.circle.fill")
                }
                Logger.shared.log("[Update] Settings version check failed: \(error.localizedDescription)")
            }
        }
    }

    private func showToastMessage(title: String, icon: String) {
        withAnimation(.spring()) {
            self.toastTitle = title
            self.toastIcon = icon
            self.showToast = true
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                self.showToast = false
            }
        }
    }
    
    func handlePairingImport(url: URL?) {
        guard let url = url else { return }
        
        do {
            try manager.importPairingFile(from: url)
            status = "\(manager.expectedPairingFileTitle) imported"
            
            manager.startHeartbeat()
        } catch {
            status = error.localizedDescription
        }
    }

    private var downloadFolderSubtitle: String {
        let directory = SongMetadata.persistentDownloadsDirectory()
        if SongMetadata.customPersistentDownloadsDirectory() != nil {
            return directory.lastPathComponent
        }
        return "App Folder"
    }

    private func handleDownloadFolderSelection(url: URL?) {
        guard let url else { return }

        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: "downloadedSongsFolderBookmark")
            showToastMessage(title: "Download Folder Updated", icon: "folder.badge.checkmark")
        } catch {
            showToastMessage(title: "Folder Selection Failed", icon: "exclamationmark.triangle.fill")
        }
    }
}

private struct DownloaderSettingsScreen: View {
    @Binding var metadataSource: String
    @Binding var autofetchMetadata: Bool
    @Binding var fetchLyrics: Bool
    @Binding var appleSubscriptionLyrics: Bool
    @Binding var storeRegion: String
    @Binding var appleRichMetadata: Bool
    @Binding var downloadServer: String
    @Binding var downloadSearchProvider: String
    @Binding var keepDownloadedSongs: Bool
    @Binding var backgroundDownloadsEnabled: Bool
    @Binding var backgroundMetadataFetchEnabled: Bool
    @Binding var downloadLiveActivitiesEnabled: Bool
    @Binding var showingDownloadFolderPicker: Bool
    @Binding var autoDownloadTier: String
    @Binding var yoinkifyFormat: String
    @Binding var qobuzFallbackQuality: String
    @Binding var tidalFallbackQuality: String

    let downloadFolderSubtitle: String

    @State private var infoAlertTitle = ""
    @State private var infoAlertMessage = ""
    @State private var showingInfoAlert = false

    private func showInfo(_ title: String, _ message: String) {
        infoAlertTitle = title
        infoAlertMessage = message
        showingInfoAlert = true
    }

    private var infoButton: some View {
        Image(systemName: "info.circle")
            .font(.body)
            .foregroundColor(.secondary)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 12) {
                    Text("METADATA")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    VStack(spacing: 0) {
                        serverPickerRow(
                            icon: "wand.and.stars",
                            title: "Import Metadata Source",
                            subtitle: "How imported songs get matched.",
                            info: "Choose which service ByeTunes uses to look up metadata for songs you import. Local Files uses only what's already tagged on the file; iTunes, Deezer, and Apple Music look up matches online to fill in and correct title, artist, album, and artwork.",
                            selection: $metadataSource,
                            options: MetadataSourceOption.allCases
                        )

                        if metadataSource != "apple" {
                            Divider().padding(.leading, 56)

                            Toggle(isOn: $appleRichMetadata) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(.body)
                                        .foregroundColor(.orange)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Rich Apple Metadata")
                                            .font(.body)
                                        Text("Extra Apple-specific metadata.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        showInfo(
                                            "Rich Apple Metadata",
                                            "Also fetches Apple's internal Store ID, XID, and copyright details for matched songs. Useful for advanced metadata completeness, not required for normal playback."
                                        )
                                    } label: {
                                        infoButton
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }

                        if metadataSource == "itunes" || metadataSource == "deezer" || metadataSource == "apple" {
                            Divider().padding(.leading, 56)

                            Toggle(isOn: $autofetchMetadata) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Autofetch")
                                            .font(.body)
                                        Text("Fetch metadata on import.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        showInfo(
                                            "Autofetch",
                                            "Automatically looks up and fills in metadata, using the source selected above, as soon as a song is imported, so you don't need to fetch it manually."
                                        )
                                    } label: {
                                        infoButton
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }

                        if !appleSubscriptionLyrics {
                            Divider().padding(.leading, 56)

                            Toggle(isOn: $fetchLyrics) {
                                HStack {
                                    Image(systemName: "quote.bubble.fill")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Fetch Lyrics")
                                            .font(.body)
                                        Text("Automatically fetch lyrics.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        showInfo(
                                            "Fetch Lyrics",
                                            "Looks up lyrics automatically when importing or downloading a song. Tries LRCLIB first, then falls back to Musixmatch, then NetEase if the earlier sources don't have a match."
                                        )
                                    } label: {
                                        infoButton
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }

                        Divider().padding(.leading, 56)

                        Toggle(isOn: $appleSubscriptionLyrics) {
                            HStack {
                                Image(systemName: "music.note.list")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Apple Music Subscription Lyrics")
                                        .font(.body)
                                    Text("Use Apple Music's synced lyrics.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button {
                                    showInfo(
                                        "Apple Music Subscription Lyrics",
                                        "If you have an active Apple Music subscription, use Apple's own time-synced lyrics instead of the community sources above. Requires an internet connection."
                                    )
                                } label: {
                                    infoButton
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)

                        if metadataSource == "itunes" {
                            Divider().padding(.leading, 56)

                            serverPickerRow(
                                icon: "globe",
                                title: "Store Region",
                                subtitle: "Storefront for iTunes lookups.",
                                info: "Choose which country's iTunes Store to query when looking up metadata. Some songs or metadata details are only available in certain storefronts.",
                                selection: $storeRegion,
                                options: MetadataStoreRegionOption.allCases
                            )
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )

                    Text("DOWNLOADS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    VStack(spacing: 0) {
                        serverPickerRow(
                            icon: "magnifyingglass",
                            title: "Search Source",
                            subtitle: "Where the Download tab searches.",
                            info: "Choose which service the Download tab searches for songs: Apple Music search results, or a match by metadata across all supported download sources.",
                            selection: $downloadSearchProvider,
                            options: DownloadSearchProviderOption.allCases
                        )

                        Divider().padding(.leading, 56)

                        Toggle(isOn: $keepDownloadedSongs) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.on.square")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Keep Downloaded Songs")
                                        .font(.body)
                                    Text("Save downloads to this device.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button {
                                    showInfo(
                                        "Keep Downloaded Songs",
                                        "When on, downloaded songs are saved locally in the app's Documents folder, so they're available offline and can be added to your device library. Turn off to skip keeping a local copy."
                                    )
                                } label: {
                                    infoButton
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)

                        Divider().padding(.leading, 56)

                        Toggle(isOn: $backgroundDownloadsEnabled) {
                            HStack {
                                Image(systemName: "arrow.down.circle.dotted")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Allow Background Downloads")
                                        .font(.body)
                                    Text("Continue downloads in the background.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button {
                                    showInfo(
                                        "Allow Background Downloads",
                                        "Lets in-progress downloads keep running after you leave the app or lock your phone, instead of pausing until you come back."
                                    )
                                } label: {
                                    infoButton
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .onChange(of: backgroundDownloadsEnabled) { enabled in
                            if !enabled {
                                DownloadLiveActivityManager.shared.clear()
                            }
                        }

                        if backgroundDownloadsEnabled {
                            Divider().padding(.leading, 56)

                            Toggle(isOn: $downloadLiveActivitiesEnabled) {
                                HStack {
                                    Image(systemName: "waveform.badge.magnifyingglass")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Live Activity Progress")
                                            .font(.body)
                                        Text("Show progress on Lock Screen.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        showInfo(
                                            "Live Activity Progress",
                                            "Shows a Live Activity with download progress on your Lock Screen and in the Dynamic Island while background downloads are running."
                                        )
                                    } label: {
                                        infoButton
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .onChange(of: downloadLiveActivitiesEnabled) { enabled in
                                if !enabled {
                                    DownloadLiveActivityManager.shared.clear()
                                }
                            }

                            Divider().padding(.leading, 56)

                            Toggle(isOn: $backgroundMetadataFetchEnabled) {
                                HStack {
                                    Image(systemName: "text.magnifyingglass")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Background Metadata Fetch")
                                            .font(.body)
                                        Text("Fetch metadata for downloads automatically.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        showInfo(
                                            "Background Metadata Fetch",
                                            "Automatically fetches metadata for newly downloaded songs in the background, even if you never open the Music tab to trigger it manually."
                                        )
                                    } label: {
                                        infoButton
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }

                        if keepDownloadedSongs {
                            Divider().padding(.leading, 56)

                            HStack {
                                Button {
                                    showingDownloadFolderPicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "folder")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Download Folder")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(downloadFolderSubtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    showInfo("Download Folder", "Choose where downloaded song files are saved on this device.")
                                } label: {
                                    infoButton
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showingDownloadFolderPicker = true
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(Color(.systemGray3))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )

                    Text("DOWNLOAD FORMAT")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        serverPickerRow(
                            icon: "sparkles.rectangle.stack",
                            title: "Output Format",
                            subtitle: "Preferred download format.",
                            info: "Choose your preferred audio format for downloads. ByeTunes is tried first; Deezer is used automatically as a fallback if a track isn't available there in your preferred format.",
                            selection: $yoinkifyFormat,
                            options: DownloaderYoinkifyFormatOption.allCases
                        )
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )

                    }
                    .frame(width: max(proxy.size.width - 40, 0), alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .frame(width: proxy.size.width, alignment: .topLeading)
                .clipped()
            }
        }
        .navigationTitle("Metadata & Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            downloadServer = DownloaderServerPreference.auto.rawValue
        }
        .alert(infoAlertTitle, isPresented: $showingInfoAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoAlertMessage)
        }
    }

    private func serverPickerRow<Option: Identifiable & CustomStringConvertible>(
        icon: String,
        title: String,
        subtitle: String,
        info: String? = nil,
        selection: Binding<String>,
        options: [Option]
    ) -> some View where Option: RawRepresentable, Option.RawValue == String {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let info {
                Button {
                    showInfo(title, info)
                } label: {
                    infoButton
                }
                .buttonStyle(.plain)
            }

            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option.description).tag(option.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

}

private enum MetadataSourceOption: String, CaseIterable, Identifiable, CustomStringConvertible {
    case local
    case itunes
    case deezer
    case apple

    var id: String { rawValue }

    var description: String {
        switch self {
        case .local: return "Local Files"
        case .itunes: return "iTunes API"
        case .deezer: return "Deezer API"
        case .apple: return "Apple Music"
        }
    }
}

private enum DownloadSearchProviderOption: String, CaseIterable, Identifiable, CustomStringConvertible {
    case appleMusic
    case spotify
    case tidal
    case metadata

    static var allCases: [DownloadSearchProviderOption] {
        [.appleMusic, .metadata]
    }

    var id: String { rawValue }

    var description: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .tidal: return "Tidal"
        case .metadata: return "iTunes + Deezer"
        }
    }
}

private enum MetadataStoreRegionOption: String, CaseIterable, Identifiable, CustomStringConvertible {
    case us = "US"
    case mx = "MX"
    case es = "ES"
    case gb = "GB"
    case jp = "JP"
    case br = "BR"
    case de = "DE"
    case fr = "FR"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .us: return "US"
        case .mx: return "MX"
        case .es: return "ES"
        case .gb: return "GB"
        case .jp: return "JP"
        case .br: return "BR"
        case .de: return "DE"
        case .fr: return "FR"
        }
    }
}

private enum DownloaderYoinkifyFormatOption: String, CaseIterable, Identifiable, CustomStringConvertible {
    case mp3
    case flac
    case alac

    var id: String { rawValue }
    var description: String { rawValue.uppercased() }
}

// MARK: - FlowLayout
// A simple left-to-right wrapping layout for supporter chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let containerWidth = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > containerWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        y += rowHeight
        return CGSize(width: containerWidth, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

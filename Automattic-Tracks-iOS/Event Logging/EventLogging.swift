import Foundation
import CommonCrypto
import CocoaLumberjack
import Sodium

public class EventLogging {

    /// Add a Log File to the list of events that need to be uploaded
    public func enqueueLogForUpload(log: LogFile) throws {
        try uploadQueue.add(log)

        /// Restart the automatic upload queue when log files are added
        self.resumeAutomaticUpload()
    }

    /// Maintains a list of events that need to be uploaded
    private let uploadQueue: EventLoggingUploadQueue

    /// Uploads Events
    private let uploadManager: EventLoggingUploadManager

    /// Data Source
    let dataSource: EventLoggingDataSource

    /// Delegate
    let delegate: EventLoggingDelegate

    public init(dataSource: EventLoggingDataSource,
         delegate: EventLoggingDelegate,
         fileManager: FileManager = FileManager.default
    ) {
        self.dataSource = dataSource
        self.delegate = delegate

        self.uploadManager = EventLoggingUploadManager(dataSource: dataSource, delegate: delegate)
        self.uploadQueue = EventLoggingUploadQueue(
            storageDirectory: dataSource.logUploadQueueStorageURL,
            fileManager: fileManager
        )

        /// Start taking items off the queue and uploading them if needed
        resumeAutomaticUpload()
    }

    /// Automated Event Upload
    private let dispatchQueue = DispatchQueue(label: "event-logging")

    /// Pause uploading available log files
    public private(set) var isPaused = true
    public func pauseAutomaticUpload() {
        isPaused = true
    }

    /// Resume uploading available log files
    public func resumeAutomaticUpload() {
        isPaused = false
        encryptAndUploadLogsIfNeeded()
    }

    /// Support adding additional time between requests if they are failing – reset after an hour to match the server
    private var exponentialBackoffTimer = ExponentialBackoffTimer(minimumDelay: 2, maximumDelay: 3600)

    /// The date that uploads will automatically resume after being paused due to failure
    public var uploadsPausedUntil: Date? {
        guard exponentialBackoffTimer.delay != 0 else {
            return nil
        }

        return exponentialBackoffTimer.nextDate
    }
}

extension EventLogging {

    /// Encrypt and upload any log files in the queue
    private func encryptAndUploadLogsIfNeeded() {

        /// Don't start uploading anything if the queue is paused
        guard !isPaused else {
            return
        }

        let encryptionKey = Data(base64Encoded: dataSource.loggingEncryptionKey)
        precondition(encryptionKey != nil, "The encryption key is not a valid base64 encoded string")

        /// If the queue is empty, pause upload
        guard let log = self.uploadQueue.first else {
            self.pauseAutomaticUpload()
            return
        }

        /// If the delegate is reporting that we shouldn't upload log files, pause upload
        /// This prevents an infinite set of attempts to upload
        guard delegate.shouldUploadLogFiles else {
            self.pauseAutomaticUpload()
            return
        }

        /// Lock the dispatch queue until this upload is complete – only one at a time
        let group = DispatchGroup()
        group.enter()

        dispatchQueue.async {
            do {
                /// Encrypt the log
                let encryptedLog = try self.encryptLog(log, withKey: Bytes(encryptionKey!))

                /// Upload the log
                self.uploadManager.upload(encryptedLog) { result in
                    if case .success = result {
                        try? self.uploadQueue.remove(log)

                        /// Reset the timer if requests are succeeding
                        self.exponentialBackoffTimer.reset()
                    }
                    else {
                        /// Wait longer between requests if they are failing
                        self.exponentialBackoffTimer.increment()
                    }
                }
            }
            catch let err {
                 /// This is almost certainly a file error – encryption errors would assert and crash the app
                 CrashLogging.logError(err)

                 /// Release the lock if there was an error encrypting the log
                 group.leave()
             }

            /// Wait until the lock is released
            group.wait()

            /// Kick off another round of uploads on any queue but this one (respecting incremental backoff)
            DispatchQueue.global(qos: .background).asyncAfter(deadline: self.exponentialBackoffTimer.next) {
                self.encryptAndUploadLogsIfNeeded()
            }
        }
    }

    internal func encryptLog(_ log: LogFile, withKey key: Bytes) throws -> LogFile {
        let encryptedURL = try LogEncryptor(withPublicKey: key).encryptLog(log)
        return LogFile(url: encryptedURL, uuid: log.uuid)
    }
}
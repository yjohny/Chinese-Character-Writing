import Foundation
import MetricKit
import os.log

private let logger = Logger(subsystem: "com.chinesewriting.app", category: "MetricKit")

/// Subscribes to MetricKit so the system delivers crash reports, hang
/// diagnostics, and aggregate performance metrics. Payloads are logged via
/// `os.Logger`, which makes them visible in Console.app and in sysdiagnose
/// captures — no third-party SDK or user permissions required.
///
/// Apple delivers payloads roughly once a day, plus crash diagnostics shortly
/// after launch when a previous run crashed.
final class MetricKitService: NSObject, MXMetricManagerSubscriber {
    override init() {
        super.init()
        MXMetricManager.shared.add(self)
        logger.info("MetricKit subscribed")
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            logger.info("Metric payload received: \(payload.jsonRepresentation().count) bytes")
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                let json = String(data: crash.jsonRepresentation(), encoding: .utf8) ?? "<unreadable>"
                logger.error("Crash diagnostic: \(json, privacy: .public)")
            }
            for hang in payload.hangDiagnostics ?? [] {
                let json = String(data: hang.jsonRepresentation(), encoding: .utf8) ?? "<unreadable>"
                logger.error("Hang diagnostic: \(json, privacy: .public)")
            }
            for cpuException in payload.cpuExceptionDiagnostics ?? [] {
                let json = String(data: cpuException.jsonRepresentation(), encoding: .utf8) ?? "<unreadable>"
                logger.error("CPU exception: \(json, privacy: .public)")
            }
            for diskWrite in payload.diskWriteExceptionDiagnostics ?? [] {
                let json = String(data: diskWrite.jsonRepresentation(), encoding: .utf8) ?? "<unreadable>"
                logger.error("Disk write exception: \(json, privacy: .public)")
            }
        }
    }
}

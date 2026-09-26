import os

/// Read with: log show --predicate 'subsystem == "local.kept.app"' --info
/// Counts and codes only. Spoken and selected text stay out of the log.
enum KeptLog {
    static let capture = Logger(subsystem: "local.kept.app", category: "capture")
    static let edit = Logger(subsystem: "local.kept.app", category: "edit")
}

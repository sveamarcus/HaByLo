//===----------------------------------------------------------------------===//
//
// This source file is part of the fltrECC open source project
//
// Copyright (c) 2022-2026 fltrWallet AG and the fltrECC project authors
// Licensed under Apache License v2.0
//
// See LICENSE.md for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging

import struct Foundation.Date
import struct Foundation.TimeInterval

#if canImport(os)
    import class Foundation.NSString
    import os.log
#endif

#if DEBUG
    nonisolated(unsafe) public let logger: any HaByLoLogger = PrintLogger()
#else
    nonisolated(unsafe) public let logger: any HaByLoLogger = NoLogger()
#endif

nonisolated(unsafe) public var LOG_LEVEL = LogLevel.Info

public struct NoLogger: HaByLoLogger {
    public func primaryLog(_ logLevel: LogLevel, _ msgfunc: () -> String, _ values: [Any?]) {
    }
}

public protocol HaByLoLogger {
    func primaryLog(
        _ logLevel: LogLevel, _ msgfunc: () -> String,
        _ values: [Any?])
}

public extension HaByLoLogger {
    @inlinable
    func error(_ msg: @autoclosure () -> String, _ values: Any?...) {
        primaryLog(.Error, msg, values)
    }
    @inlinable
    func warn(_ msg: @autoclosure () -> String, _ values: Any?...) {
        primaryLog(.Warn, msg, values)
    }
    @inlinable
    func log(_ msg: @autoclosure () -> String, _ values: Any?...) {
        primaryLog(.Log, msg, values)
    }
    @inlinable
    func info(_ msg: @autoclosure () -> String, _ values: Any?...) {
        primaryLog(.Info, msg, values)
    }
    @inlinable
    func trace(_ msg: @autoclosure () -> String, _ values: Any?...) {
        primaryLog(.Trace, msg, values)
    }
}

public enum LogLevel: Int8, Sendable {
    case Error
    case Warn
    case Log
    case Info
    case Trace

    @usableFromInline
    var logPrefix: String {
        switch self {
        case .Error: return "ERROR: "
        case .Warn: return "WARN:  "
        case .Info: return "INFO:  "
        case .Trace: return "Trace: "
        case .Log: return ""
        }
    }
}

extension LogLevel {
    // Maps HaByLo levels onto swift-log's Logger.Level (the cross-platform sink).
    @usableFromInline
    var swiftLogLevel: Logging.Logger.Level {
        switch self {
        case .Error: return .error
        case .Warn: return .warning
        case .Info: return .info
        case .Trace: return .trace
        case .Log: return .notice
        }
    }
}

public struct PrintLogger: HaByLoLogger {
    @usableFromInline
    let _logLevel: LogLevel?
    @usableFromInline
    let backing: Logging.Logger
    @usableFromInline
    var logLevel: LogLevel {
        return _logLevel ?? LOG_LEVEL
    }
    @usableFromInline
    let startTime: TimeInterval
    @inlinable
    public var elapsedTime: TimeInterval {
        Date().timeIntervalSinceReferenceDate - startTime
    }

    @inlinable
    public init(logLevel: LogLevel? = nil) {
        self.startTime = Date().timeIntervalSinceReferenceDate
        self._logLevel = logLevel
        var backing = Logging.Logger(label: "blix")
        // HaByLo performs its own LOG_LEVEL filtering in primaryLog, so let
        // swift-log forward everything to the configured LogHandler.
        backing.logLevel = .trace
        self.backing = backing
    }

    @inlinable
    public func primaryLog(
        _ logLevel: LogLevel,
        _ msgfunc: () -> String,
        _ values: [Any?]
    ) {
        guard logLevel.rawValue <= self.logLevel.rawValue else { return }

        let prefix = logLevel.logPrefix
        let s = msgfunc()
        let time = timeString(for: elapsedTime)

        let message: String
        if values.isEmpty {
            message = "[\(time)]\(prefix)\(s)"
        } else {
            var ms = ""
            appendValues(values, to: &ms)
            message = "[\(time)]\(prefix)\(s)\(ms)"
        }
        backing.log(level: logLevel.swiftLogLevel, "\(message)")
    }

    @usableFromInline
    func timeString(for interval: TimeInterval) -> String {
        let i = UInt64(interval)
        let (hours, hRemainder) = i.quotientAndRemainder(dividingBy: 3600)
        let (minutes, seconds) = hRemainder.quotientAndRemainder(dividingBy: 60)

        return "\(hours)h \(minutes)m \(seconds)s"
    }

    @usableFromInline
    func appendValues(_ values: [Any?], to ms: inout String) {
        for v in values {
            ms += " "
            if let v = v as? CustomStringConvertible {
                ms += v.description
            } else if let v = v as? String {
                ms += v
            } else if let v = v {
                ms += "\(v)"
            } else {
                ms += "<nil>"
            }
        }
    }
}

public final class LogKeyForLine: Sendable {
    @usableFromInline
    let file: StaticString
    @usableFromInline
    let line: Int

    @inlinable
    public init(_ file: StaticString, _ line: Int) {
        self.file = file
        self.line = line
    }
}

// MARK: - Signpost tracing
//
// os_signpost / OSLog are Apple-only. On every other Swift 6 platform (Linux,
// Android, Windows, WASI, FreeBSD, …) the same public `trace` entry points are
// provided as pass-through / no-ops, so callers compile and behave consistently
// everywhere without `#if` at the call site.
#if canImport(os)

    @usableFromInline
    func logHandleFor(
        subsystem: StaticString = "blixlib", line: Int = #line, category: StaticString = #fileID
    ) -> (OSLog, OSSignpostID) {
        let subsystemString = "app.fltr." + String(describing: subsystem)
        let osLog = OSLog(subsystem: subsystemString, category: String(describing: category))
        let osSignpostId = OSSignpostID(log: osLog, object: LogKeyForLine(category, line))
        return (osLog, osSignpostId)
    }

    @inlinable
    public func trace(
        event: String, number: Int? = nil, function: StaticString = #function, line: Int = #line,
        category: StaticString = #fileID
    ) {
        let (osLog, id) = logHandleFor(line: line, category: category)
        os_signpost(
            .event, log: osLog, name: function, signpostID: id, "%s", event,
            (number ?? 0) as NSInteger)
    }

    @inlinable
    public func trace<T>(
        begin message: StaticString = "%s",
        function: StaticString = #function,
        line: Int = #line,
        category: StaticString = #fileID,
        commands: () throws -> T
    ) rethrows -> T {
        let (osLog, id) = logHandleFor(line: line, category: category)

        guard osLog.signpostsEnabled
        else {
            return try commands()
        }

        let signpostName = function
        os_signpost(.begin, log: osLog, name: signpostName, signpostID: id)
        let result = try commands()
        defer {
            os_signpost(
                .end, log: osLog, name: signpostName, signpostID: id, message,
                String(reflecting: result) as NSString)
        }
        return result
    }

#else

    @inlinable
    public func trace(
        event: String, number: Int? = nil, function: StaticString = #function, line: Int = #line,
        category: StaticString = #fileID
    ) {
        // No signpost facility on this platform; trace events are dropped.
    }

    @inlinable
    public func trace<T>(
        begin message: StaticString = "%s",
        function: StaticString = #function,
        line: Int = #line,
        category: StaticString = #fileID,
        commands: () throws -> T
    ) rethrows -> T {
        try commands()
    }

#endif

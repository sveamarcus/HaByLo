// Wall-clock Unix time, multiplexed so each function uses the best primitive
// available on the host. Platform C libraries are selected by capability so the
// same source compiles on Apple (Darwin + CoreFoundation), Linux (Glibc/Musl),
// Android (Android/Bionic), WASI (WASILibc) and Windows (ucrt); any other Swift 6
// platform falls back to Foundation.
#if canImport(Darwin)
    import CoreFoundation
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif canImport(Android)
    import Android
#elseif canImport(Bionic)
    import Bionic
#elseif canImport(WASILibc)
    import WASILibc
#elseif canImport(ucrt)
    import ucrt
#endif

#if canImport(Foundation)
    import struct Foundation.Date
#endif

/// Whole seconds since the Unix epoch.
///
/// Uses POSIX/CRT `time(2)` where available — a single call with no floating-point
/// work — which is the fastest way to obtain integer seconds on every supported
/// platform. Falls back to truncating `unixTime()` only where no C library is present.
@inlinable
public func unixTimeInSeconds() -> UInt64 {
    #if canImport(Darwin) || canImport(Glibc) || canImport(Musl) || canImport(Android) || canImport(Bionic) || canImport(WASILibc) || canImport(ucrt)
        return UInt64(time(nil))
    #else
        return UInt64(unixTime())
    #endif
}

/// Seconds since the Unix epoch with sub-second precision.
///
/// On Apple platforms this uses `CFAbsoluteTimeGetCurrent()`, the recommended
/// high-resolution wall clock on iOS/macOS. Elsewhere it prefers
/// `clock_gettime(CLOCK_REALTIME)` (POSIX, nanosecond resolution), uses the C11
/// `timespec_get(TIME_UTC)` on Windows, and falls back to `Foundation.Date`.
@inlinable
public func unixTime() -> Double {
    #if canImport(Darwin)
        // Apple's recommended high-resolution wall clock. Gated on `canImport(Darwin)`
        // (Apple-only) rather than `canImport(CoreFoundation)` so that Linux — whose
        // corelibs Foundation also ships CoreFoundation — still takes the lighter
        // `clock_gettime` path below instead of pulling in CoreFoundation.
        return CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970
    #elseif canImport(Glibc) || canImport(Musl) || canImport(Android) || canImport(Bionic) || canImport(WASILibc)
        var ts = timespec()
        clock_gettime(CLOCK_REALTIME, &ts)
        return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1_000_000_000
    #elseif canImport(ucrt)
        var ts = timespec()
        _ = timespec_get(&ts, TIME_UTC)
        return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1_000_000_000
    #else
        return Date().timeIntervalSince1970
    #endif
}

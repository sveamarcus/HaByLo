@inlinable
public func undefined<T>(
    _ message: String, function: String = #function, file: String = #file, line: Int = #line,
    as: T.Type = T.self
) -> T {
    fatalError(
        "*** Undefined/work in progress: \(message)\n*** [fn: \(function)] [file: \(file)] [line: \(line)]"
    )
}

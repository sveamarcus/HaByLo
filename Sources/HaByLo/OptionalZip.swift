@inlinable
public func zip<W>(_ lhs: W?, _ rhs: W?) -> (W, W)? {
    lhs.flatMap { lhs in
        rhs.map { rhs in
            (lhs, rhs)
        }
    }
}

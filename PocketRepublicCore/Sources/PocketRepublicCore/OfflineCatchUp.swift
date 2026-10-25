public enum OfflineCatchUp {
    public static func days(elapsedSeconds: Double) -> Int? {
        guard elapsedSeconds.isFinite else { return nil }
        if elapsedSeconds <= 0 { return 0 }
        if elapsedSeconds >= 64800 { return 3 }
        return Int(elapsedSeconds / 21600)
    }
}

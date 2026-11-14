//
//  ScreenshotLaunch.swift
//  CondoOwnersCost
//

import Foundation

enum ScreenshotLaunch {
    /// Debug-only. A normal launch never sets this.
    static var mode: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screenshot"), index + 1 < args.count else { return nil }
        return args[index + 1]
        #else
        return nil
        #endif
    }
}

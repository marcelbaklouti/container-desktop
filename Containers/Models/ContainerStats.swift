import Foundation

nonisolated struct ContainerStatsSample: Codable, Sendable, Hashable {
    let id: String
    let cpuUsageUsec: Int
    let memoryUsageBytes: Int
    let memoryLimitBytes: Int
    let blockReadBytes: Int
    let blockWriteBytes: Int
    let networkRxBytes: Int
    let networkTxBytes: Int
    let numProcesses: Int
}

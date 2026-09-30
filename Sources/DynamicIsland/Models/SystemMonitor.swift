import Foundation
import AppKit
import IOKit.ps
import Darwin

public struct SystemStats {
    public var cpuUsage: Double = 0.0 // 0.0 to 100.0
    public var ramUsedGB: Double = 0.0
    public var ramTotalGB: Double = 0.0
    public var batteryPercent: Int = 100
    public var isCharging: Bool = false
    public var isPluggedIn: Bool = false
    public var wifiName: String = "Connected"
    public var isMuted: Bool = false
    public var systemVolume: Double = 0.5
}

public class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()
    
    @Published public var stats = SystemStats()
    
    private var timer: Timer?
    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuInfoCount: mach_msg_type_number_t = 0
    
    private init() {
        startMonitoring()
    }
    
    public func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshAll()
        }
    }
    
    public func refreshAll() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let cpu = self.calculateCpuUsage()
            let (usedRam, totalRam) = self.getMemoryUsage()
            let (batteryPct, charging, plugged) = self.getBatteryInfo()
            let vol = self.getSystemVolume()
            
            DispatchQueue.main.async {
                self.stats.cpuUsage = cpu
                self.stats.ramUsedGB = usedRam
                self.stats.ramTotalGB = totalRam
                self.stats.batteryPercent = batteryPct
                self.stats.isCharging = charging
                self.stats.isPluggedIn = plugged
                self.stats.systemVolume = vol
            }
        }
    }
    
    // MARK: - CPU Calculation
    private func calculateCpuUsage() -> Double {
        var numProcessors: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numProcessors,
            &cpuInfo,
            &numCpuInfo
        )
        
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return 0.0
        }
        
        var totalUsage: Double = 0.0
        if let prev = previousCpuInfo {
            for i in 0..<Int(numProcessors) {
                let offset = Int(CPU_STATE_MAX) * i
                let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)] - prev[offset + Int(CPU_STATE_USER)])
                let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)] - prev[offset + Int(CPU_STATE_SYSTEM)])
                let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)] - prev[offset + Int(CPU_STATE_NICE)])
                let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)] - prev[offset + Int(CPU_STATE_IDLE)])
                
                let inUse = user + system + nice
                let total = inUse + idle
                if total > 0 {
                    totalUsage += (inUse / total)
                }
            }
            totalUsage = (totalUsage / Double(numProcessors)) * 100.0
            
            // Deallocate previous info
            let prevSize = vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), prevSize)
        }
        
        previousCpuInfo = cpuInfo
        previousCpuInfoCount = numCpuInfo
        
        return max(0.0, min(100.0, totalUsage))
    }
    
    // MARK: - Memory Calculation
    private func getMemoryUsage() -> (Double, Double) {
        let hostPort = mach_host_self()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var vmStats = vm_statistics64()
        
        let kerr = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &size)
            }
        }
        
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(totalBytes) / (1024.0 * 1024.0 * 1024.0)
        
        guard kerr == KERN_SUCCESS else {
            return (0.0, totalGB)
        }
        
        let pageSize = Double(vm_kernel_page_size)
        let active = Double(vmStats.active_count) * pageSize
        let wired = Double(vmStats.wire_count) * pageSize
        let compressed = Double(vmStats.compressor_page_count) * pageSize
        let usedBytes = active + wired + compressed
        let usedGB = usedBytes / (1024.0 * 1024.0 * 1024.0)
        
        return (usedGB, totalGB)
    }
    
    // MARK: - Battery Calculation
    private func getBatteryInfo() -> (Int, Bool, Bool) {
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
        
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source).takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let pct = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let powerSource = desc[kIOPSPowerSourceStateKey] as? String ?? ""
            let isPlugged = powerSource == kIOPSACPowerValue
            return (pct, isCharging, isPlugged)
        }
        return (100, false, true)
    }
    
    // MARK: - Volume Controls
    private func getSystemVolume() -> Double {
        var error: NSDictionary?
        let script = "output volume of (get volume settings)"
        if let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue,
           let volInt = Double(output) {
            return volInt / 100.0
        }
        return 0.5
    }
    
    public func setSystemVolume(_ val: Double) {
        let pct = Int(val * 100.0)
        let script = "set volume output volume \(pct)"
        _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
        stats.systemVolume = val
    }
    
    // MARK: - Quick Actions
    public func lockScreen() {
        SoundManager.shared.play(.click)
        let script = "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"
        _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
    }
    
    public func sleepDisplay() {
        SoundManager.shared.play(.click)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }
    
    public func toggleMute() {
        SoundManager.shared.play(.click)
        let script = "set volume output muted not (output muted of (get volume settings))"
        _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
        stats.isMuted.toggle()
    }
    
    public func emptyTrash() {
        SoundManager.shared.play(.click)
        let script = "tell application \"Finder\" to empty trash"
        _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
    }
}

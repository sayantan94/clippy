import Foundation
import Darwin

class ProcessInspector {
    /// Check if a given PID is a descendant of any watched terminal PID.
    static func isDescendantOf(pid: pid_t, ancestors: Set<pid_t>) -> pid_t? {
        var current = pid
        for _ in 0..<20 {
            let parent = getParentPid(of: current)
            if parent <= 1 { return nil }
            if ancestors.contains(parent) { return parent }
            current = parent
        }
        return nil
    }

    /// Get parent PID using sysctl.
    static func getParentPid(of pid: pid_t) -> pid_t {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0 else { return 0 }
        return info.kp_eproc.e_ppid
    }

    /// Get process name.
    static func getProcessName(pid: pid_t) -> String? {
        let bufSize = Int(MAXPATHLEN)
        let nameBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)
        defer { nameBuffer.deallocate() }
        let result = proc_name(pid, nameBuffer, UInt32(bufSize))
        guard result > 0 else { return nil }
        return String(cString: nameBuffer)
    }

    /// Get full command line of a process via KERN_PROCARGS2.
    static func getCommandLine(pid: pid_t) -> [String]? {
        var size = 0
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        guard sysctl(&mib, 3, buffer, &size, nil, 0) == 0 else { return nil }

        let argc = buffer.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        var offset = MemoryLayout<Int32>.size

        // Skip exec_path
        while offset < size && buffer[offset] != 0 { offset += 1 }
        while offset < size && buffer[offset] == 0 { offset += 1 }

        // Read argv
        var args: [String] = []
        for _ in 0..<argc {
            guard offset < size else { break }
            let start = buffer + offset
            let arg = String(cString: start)
            args.append(arg)
            offset += arg.utf8.count + 1
        }

        return args
    }
}

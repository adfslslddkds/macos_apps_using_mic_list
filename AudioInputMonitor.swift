import AppKit
import CoreAudio

struct AudioInputProcess {
    let pid: pid_t
    let name: String?
    let bundleIdentifier: String?
}

enum AudioProcessError: Error {
    case unsupportedMacOSVersion
    case coreAudio(OSStatus)
}

private func readUInt32(
    from objectID: AudioObjectID,
    selector: AudioObjectPropertySelector
) throws -> UInt32 {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectGetPropertyData(
        objectID,
        &address,
        0,
        nil,
        &size,
        &value
    )

    guard status == noErr else {
        throw AudioProcessError.coreAudio(status)
    }

    return value
}

private func readPID(from objectID: AudioObjectID) throws -> pid_t {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyPID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var pid: pid_t = 0
    var size = UInt32(MemoryLayout<pid_t>.size)

    let status = AudioObjectGetPropertyData(
        objectID,
        &address,
        0,
        nil,
        &size,
        &pid
    )

    guard status == noErr else {
        throw AudioProcessError.coreAudio(status)
    }

    return pid
}

func appsUsingAudioInput() throws -> [AudioInputProcess] {
    guard #available(macOS 14.0, *) else {
        throw AudioProcessError.unsupportedMacOSVersion
    }

    let systemObject = AudioObjectID(kAudioObjectSystemObject)

    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(
        systemObject,
        &address,
        0,
        nil,
        &dataSize
    )

    guard status == noErr else {
        throw AudioProcessError.coreAudio(status)
    }

    let count = Int(dataSize) / MemoryLayout<AudioObjectID>.stride
    var processObjects = [AudioObjectID](repeating: 0, count: count)

    status = processObjects.withUnsafeMutableBytes { buffer in
        guard let baseAddress = buffer.baseAddress else {
            return noErr
        }

        return AudioObjectGetPropertyData(
            systemObject,
            &address,
            0,
            nil,
            &dataSize,
            baseAddress
        )
    }

    guard status == noErr else {
        throw AudioProcessError.coreAudio(status)
    }

    var result: [AudioInputProcess] = []

    for processObject in processObjects {
        // Свойство читается как UInt32: 0 — нет, ненулевое значение — да.
        guard (try? readUInt32(
            from: processObject,
            selector: kAudioProcessPropertyIsRunningInput
        )) != 0,
        let pid = try? readPID(from: processObject) else {
            continue
        }

        let app = NSRunningApplication(processIdentifier: pid)

        result.append(
            AudioInputProcess(
                pid: pid,
                name: app?.localizedName,
                bundleIdentifier: app?.bundleIdentifier
            )
        )
    }

    return result
}

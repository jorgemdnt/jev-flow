import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation
import KeptCore
import SwiftUI

struct InputDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let deviceID: AudioDeviceID
}

enum InputDevices {
    static let system = ""

    static func inputs() -> [InputDevice] {
        deviceIDs().compactMap(device(id:)).filter(hasInput)
    }

    static func systemDefault() -> InputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != 0 else { return nil }
        return device(id: deviceID)
    }

    static func resolve(uid: String) -> InputDevice? {
        if uid.isEmpty { return systemDefault() }
        return inputs().first { $0.id == uid } ?? systemDefault()
    }

    static func name(uid: String) -> String {
        resolve(uid: uid)?.name ?? "System microphone"
    }

    @discardableResult
    static func apply(uid: String, to engine: AVAudioEngine) -> String {
        let chosen = resolve(uid: uid)
        // The engine already follows the system input. Forcing that device
        // disconnects the aggregate and opens the speaker path first. That
        // is the mic light bursting, and the next hold then fails to start.
        guard !uid.isEmpty, let chosen, let audioUnit = engine.inputNode.audioUnit else {
            return chosen?.name ?? "System microphone"
        }
        var deviceID = chosen.deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr, let fallback = systemDefault() {
            return fallback.name
        }
        return chosen.name
    }

    static func startWatching(_ onChange: @escaping @Sendable () -> Void) {
        InputRoute.start(onChange)
    }

    static func consumeRouteChange() -> Bool {
        InputRoute.consume()
    }

    private static func deviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func device(id: AudioDeviceID) -> InputDevice? {
        guard let uid = string(id: id, selector: kAudioDevicePropertyDeviceUID),
              let name = string(id: id, selector: kAudioDevicePropertyDeviceNameCFString),
              !uid.isEmpty, !name.isEmpty
        else { return nil }
        return InputDevice(id: uid, name: name, deviceID: id)
    }

    private static func hasInput(_ device: InputDevice) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device.deviceID, &address, 0, nil, &size) == noErr else {
            return false
        }
        return size >= UInt32(MemoryLayout<AudioStreamID>.size)
    }

    private static func string(id: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        guard status == noErr, let value else { return nil }
        return value.takeUnretainedValue() as String
    }
}

private final class InputRouteState: @unchecked Sendable {
    let lock = NSLock()
    var started = false
    var changed = false
    var onChange: @Sendable () -> Void = {}
}

private let inputRoute = InputRouteState()

private enum InputRoute {
    static func start(_ onChange: @escaping @Sendable () -> Void) {
        inputRoute.lock.lock()
        inputRoute.onChange = onChange
        let needsInstall = !inputRoute.started
        inputRoute.started = true
        inputRoute.lock.unlock()
        guard needsInstall else { return }
        let system = AudioObjectID(kAudioObjectSystemObject)
        var defaultInput = address(kAudioHardwarePropertyDefaultInputDevice)
        AudioObjectAddPropertyListener(system, &defaultInput, routeChanged, nil)
    }

    static func markChanged() {
        inputRoute.lock.lock()
        inputRoute.changed = true
        let notify = inputRoute.onChange
        inputRoute.lock.unlock()
        notify()
    }

    static func consume() -> Bool {
        inputRoute.lock.lock()
        defer { inputRoute.lock.unlock() }
        let value = inputRoute.changed
        inputRoute.changed = false
        return value
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}

private func routeChanged(
    _ objectID: AudioObjectID,
    _ addressCount: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ client: UnsafeMutableRawPointer?
) -> OSStatus {
    InputRoute.markChanged()
    return noErr
}

private let microphoneFile = KeptPaths.applicationSupport.appendingPathComponent("microphone.txt")

@MainActor
@Observable
final class MicStore {
    static let shared = MicStore()

    var uid = ""
    var devices: [InputDevice] = []

    private init() {
        uid = Self.read()
        devices = InputDevices.inputs()
    }

    func refresh() {
        devices = InputDevices.inputs()
        if !uid.isEmpty, !devices.contains(where: { $0.id == uid }) {
            uid = ""
        }
    }

    func choose(_ uid: String) {
        self.uid = uid
        try? FileManager.default.createDirectory(
            at: microphoneFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? uid.write(to: microphoneFile, atomically: true, encoding: .utf8)
        InputRoute.markChanged()
    }

    nonisolated static func savedUID() -> String {
        read()
    }

    nonisolated private static func read() -> String {
        (try? String(contentsOf: microphoneFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct MicrophoneSettings: View {
    @Bindable var store: MicStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Microphone")
                .font(.system(size: 13, weight: .semibold))
            Text(caption)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Picker("Microphone", selection: Binding(
                get: { store.uid },
                set: { store.choose($0) }
            )) {
                Text("System default").tag(InputDevices.system)
                ForEach(store.devices) { device in
                    Text(device.name).tag(device.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KeptColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { store.refresh() }
    }

    private var caption: String {
        let name = InputDevices.name(uid: store.uid)
        return store.uid.isEmpty ? "Using the system microphone, \(name)." : "Pinned to \(name)."
    }
}

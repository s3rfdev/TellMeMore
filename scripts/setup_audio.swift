#!/usr/bin/env swift
import Foundation
import CoreAudio

// Tell Memo — автоматическая настройка связки наушников/колонок и BlackHole 2ch
// Создаёт stacked Multi-Output Device, дублирующий звук в наушники и BlackHole.

func getDeviceList() -> [AudioDeviceID] {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    var devIDs = [AudioDeviceID](repeating: 0, count: count)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devIDs)
    return devIDs
}

func getOutputChannelCount(_ devID: AudioDeviceID) -> Int {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    let err = AudioObjectGetPropertyDataSize(devID, &addr, 0, nil, &size)
    if err != noErr || size == 0 { return 0 }
    
    let rawBufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
    defer { rawBufferList.deallocate() }
    
    let err2 = AudioObjectGetPropertyData(devID, &addr, 0, nil, &size, rawBufferList)
    if err2 != noErr { return 0 }
    
    let bufferList = UnsafeMutableAudioBufferListPointer(rawBufferList)
    var channels = 0
    for buf in bufferList {
        channels += Int(buf.mNumberChannels)
    }
    return channels
}

func getDeviceName(_ id: AudioDeviceID) -> String {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var name: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name)
    return name?.takeRetainedValue() as String? ?? ""
}

func getDeviceUID(_ id: AudioDeviceID) -> String {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var uid: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &uid)
    return uid?.takeRetainedValue() as String? ?? ""
}

// 1. Удаляем старые виртуальные агрегаты Tell Memo
for devID in getDeviceList() {
    let uid = getDeviceUID(devID)
    if uid.contains("tellmemo") {
        AudioHardwareDestroyAggregateDevice(devID)
    }
}

// 2. Ищем физическое устройство вывода (приоритет: наушники/AirPods/Bluetooth, иначе встроенный выход)
var targetUID: String? = nil
var targetName: String = ""

for devID in getDeviceList() {
    let ch = getOutputChannelCount(devID)
    guard ch > 0 else { continue }
    let uid = getDeviceUID(devID)
    let name = getDeviceName(devID)
    if uid.contains("BlackHole") || uid.contains("tellmemo") || uid.contains("NoMachine") {
        continue
    }
    if name.contains("Buds") || name.contains("AirPods") || name.contains("Headphone") {
        targetUID = uid
        targetName = name
        break
    }
    if targetUID == nil && name.contains("Built-in Output") {
        targetUID = uid
        targetName = name
    }
}

guard let chosenUID = targetUID else {
    print("❌ Не найдено физическое устройство вывода звука")
    exit(1)
}

print("🎧 Физический вывод: '\(targetName)' (\(chosenUID))")

var newID: AudioDeviceID = 0
let desc: [String: Any] = [
    kAudioAggregateDeviceNameKey: "Tell Memo Multi-Output",
    kAudioAggregateDeviceUIDKey: "tellmemo.multiout",
    kAudioAggregateDeviceSubDeviceListKey: [
        [kAudioSubDeviceUIDKey: chosenUID],
        [kAudioSubDeviceUIDKey: "BlackHole2ch_UID", kAudioSubDeviceDriftCompensationKey: UInt32(1)]
    ],
    kAudioAggregateDeviceMasterSubDeviceKey: chosenUID,
    kAudioAggregateDeviceIsStackedKey: UInt32(1)
]

let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &newID)
if status == 0 {
    print("✅ Создано устройство 'Tell Memo Multi-Output' (ID: \(newID))")
} else {
    print("❌ Ошибка создания Multi-Output устройства: \(status)")
    exit(1)
}

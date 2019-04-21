//
//  Workout+FitWriter.swift
//  GpxExport
//
//  Created by Mario Martelli on 23.02.19.
//  Copyright © 2019 Mario Martelli. All rights reserved.
//

import Foundation
import HealthKit
import CoreLocation
import FitDataProtocol
import FitnessUnits
import AntMessageProtocol

extension Workout {
    // swiftlint:disable function_body_length
    func writeFit(completionHandler: @escaping(_ url: URL?) -> Void) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"

        let fileName = "\(formatter.string(from: startDate)) - \(activityType)"

        let targetURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(fileName)
            .appendingPathExtension("fit")

        DispatchQueue.global(qos: .background).sync {
            let time = FitTime(date: self.startDate)
            let serial = ValidatedBinaryInteger(value: UInt32(123), valid: true)

            let file: FileHandle

            do {
                let manager = FileManager.default
                if manager.fileExists(atPath: targetURL.path) {
                    try manager.removeItem(atPath: targetURL.path)
                }
                manager.createFile(atPath: targetURL.path, contents: Data())
                file = try FileHandle(forWritingTo: targetURL)
            } catch let err {
                print(err)

                DispatchQueue.main.async {
                    completionHandler(nil)
                }

                return
            }

            let records = self.createRecords()
            let productId = ValidatedBinaryInteger(value: UInt16(16), valid: true)

            var messages: [FitMessage] = []
            messages.append(self.createActivityMessage())
            messages.append(contentsOf: records)
            messages.append(self.createSessionMessage(time: time,
                                                      position: records.first!.position,
                                                      duration: Measurement(value: self.duration, unit: UnitDuration.seconds)))
            messages.append(self.createDeviceInfoMessage())
            do {
                let encoder = FitFileEncoder(dataValidityStrategy: .garminConnect)
                let data = try encoder.encode(fildIdMessage: self.createFileId(serial: serial, time: time, product: productId), messages: messages)
                file.write(data)
                file.synchronizeFile()
                file.closeFile()

                DispatchQueue.main.async {
                    completionHandler(targetURL)
                }
            } catch {
                print(error)

                DispatchQueue.main.async {
                    completionHandler(nil)
                }
            }
       }
    }
    // swiftlint:enable function_body_length

    func createActivityMessage() -> ActivityMessage {
        let time = FitTime(date: startDate)
        let duration = Measurement(value: self.duration, unit: UnitDuration.seconds)
        let activity = ActivityMessage(timeStamp: time,
                                       totalTimerTime: duration,
                                       localTimeStamp: nil,
                                       numberOfSessions: ValidatedBinaryInteger(value: 1, valid: true),
                                       activity: Activity.manual,
                                       event: Event.activity,
                                       eventType: EventType.start,
                                       eventGroup: nil)
        return activity
    }

    func createFileId(serial: ValidatedBinaryInteger<UInt32>, time: FitTime, product: ValidatedBinaryInteger<UInt16>) -> FileIdMessage {
        let fileId = FileIdMessage(deviceSerialNumber: serial,
                                   fileCreationDate: time,
                                   manufacturer: .northPoleEngineering,
                                   product: product,
                                   fileNumber: nil,
                                   fileType: FileType.activity,
                                   productName: nil)
        return fileId
    }

    func createRecords() -> [RecordMessage] {
        var currentHeartrateIndex = 0
        var currentHeartrate: Double = -1
        let bpmUnit = HKUnit(from: "count/min")
        var records: [RecordMessage] = []

        let stanceTime = StanceTime.nilSelf
        let torqueEffectiveness = TorqueEffectiveness.nilSelf
        let pedalSmoothness = PedalSmoothness.nilSelf

        for location in self.route {
            var heartrate: UInt8 = 0
            while (currentHeartrateIndex < self.heartRate.count) && (location.timestamp > self.heartRate[currentHeartrateIndex].startDate) {
                currentHeartrate = self.heartRate[currentHeartrateIndex].quantity.doubleValue(for: bpmUnit)
                currentHeartrateIndex += 1
                heartrate = UInt8(currentHeartrate)
            }
            let latitude = ValidatedMeasurement(value: location.coordinate.latitude, valid: true, unit: UnitAngle.degrees)
            let longitude = ValidatedMeasurement(value: location.coordinate.longitude, valid: true, unit: UnitAngle.degrees)
            let altitude = ValidatedMeasurement(value: location.altitude, valid: true, unit: UnitLength.meters)
            let record = RecordMessage(timeStamp: FitTime(date: location.timestamp),
                                       position: Position(latitude: latitude, longitude: longitude),
                                       distance: nil, timeFromCourse: nil, cycles: nil, totalCycles: nil,
                                       accumulatedPower: nil, altitude: altitude, speed: nil, power: nil,
                                       gpsAccuracy: nil, verticalSpeed: nil, calories: nil, verticalOscillation: nil,
                                       stanceTime: stanceTime, heartRate: heartrate, cadence: nil, grade: nil,
                                       resistance: nil, cycleLength: nil, temperature: nil, activity: nil,
                                       torqueEffectiveness: torqueEffectiveness, pedalSmoothness: pedalSmoothness,
                                       stroke: nil, zone: nil, ballSpeed: nil, deviceIndex: nil)
            records.append(record)
        }
        return records
    }

    func createDeviceInfoMessage() -> FitMessage {
        let time = FitTime(date: startDate)
        let serial = ValidatedBinaryInteger(value: UInt32(123), valid: true)

        let devinfo = DeviceInfoMessage(timeStamp: time, serialNumber: serial, cumulativeOpTime: nil, productName: nil,
                                        manufacturer: .northPoleEngineering, product: nil, softwareVersion: nil,
                                        hardwareVersion: nil, batteryVoltage: nil, batteryStatus: nil, deviceNumber: nil,
                                        deviceType: nil, deviceIndex: nil, sensorDescription: nil, bodylocation: nil,
                                        transmissionType: nil, antNetwork: nil, source: nil)

        return devinfo
    }

    func createSessionMessage(time: FitTime, position: Position, duration: Measurement<UnitDuration>) -> SessionMessage {
        let session = SessionMessage(timeStamp: time, messageIndex: nil, event: Event.session, eventType: EventType.start, startTime: time,
                                     startPosition: position, sport: self.antSport, subSport: nil,
                                     totalElapsedTime: duration, totalTimerTime: nil,
                                     totalDistance: nil, totalCycles: nil,
                                     totalCalories: nil, totalFatCalories: nil, averageSpeed: nil, maximumSpeed: nil, averageHeartRate: nil,
                                     maximumHeartRate: nil, averageCadence: nil, maximumCadence: nil, averagePower: nil, maximumPower: nil,
                                     totalAscent: nil, totalDescent: nil, totalTrainingEffect: nil, firstLapIndex: nil, numberOfLaps: nil,
                                     eventGroup: nil, trigger: nil, necPosition: position, swcPosition: position, normalizedPower: nil,
                                     averageStrokeDistance: nil, swimStroke: nil, poolLength: nil, poolLengthUnit: nil, thresholdPower: nil,
                                     activeLengths: nil, totalWork: nil, averageAltitude: nil, maximumAltitude: nil, gpsAccuracy: nil,
                                     averageGrade: nil, averagePositiveGrade: nil, averageNegitiveGrade: nil, maximumPositiveGrade: nil,
                                     maximumNegitiveGrade: nil, averageTemperature: nil, maximumTemperature: nil, totalMovingTime: nil,
                                     averagePositiveVerticalSpeed: nil, averageNegitiveVerticalSpeed: nil, maximumPositiveVerticalSpeed: nil,
                                     maximumNegitiveVerticalSpeed: nil, minimumHeartRate: nil, averageLapTime: nil, bestLapIndex: nil,
                                     minimumAltitude: nil, score: Score.nilSelf, opponentName: nil, maximumBallSpeed: nil, averageBallSpeed: nil,
                                     averageVerticalOscillation: nil, averageStanceTime: StanceTime.nilSelf, sportIndex: nil,
                                     averageAscentSpeed: nil)
        return session
    }
}

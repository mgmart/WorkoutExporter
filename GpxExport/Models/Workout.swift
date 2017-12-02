//
//  Workout.swift
//  GpxExport
//
//  Created by Mario Martelli on 30.11.17.
//  Copyright © 2017 Mario Martelli. All rights reserved.
//

import Foundation
import CoreLocation
import HealthKit

struct Workout {
  private var hkWorkout: HKWorkout
  private var route:[CLLocation]
  private var heartRate:[HKQuantitySample]
  private var startDate: Date

  var activityType:String {
    let activity: String = {
      switch hkWorkout.workoutActivityType {
      case .cycling: return "Cycle"
      case .running: return "Run"
      case .walking: return "Walk"
      default: return "Workout"
      }
    }()
    return activity
  }

  var name:String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .medium

    return "\(activityType) - \(formatter.string(from: startDate))"
  }

  init(workout: HKWorkout, route: [CLLocation], heartRate: [HKQuantitySample]) {
    self.route = route
    self.heartRate = heartRate

    if let timestamp = route.first?.timestamp {
      self.startDate = timestamp
    } else {
      self.startDate = Date()
    }
    self.hkWorkout = workout
  }

  func writeFile() -> URL? {

    var current_heart_rate_index = 0
    var current_hr: Double = -1
    let bpm_unit = HKUnit(from: "count/min")
    var hr_string = ""

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"

    let fileName = "\(formatter.string(from: startDate)) - \(activityType)"

    let file: FileHandle
    let targetURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(fileName)
      .appendingPathExtension("gpx")

    do {
      let manager = FileManager.default
      if manager.fileExists(atPath: targetURL.path){
        try manager.removeItem(atPath: targetURL.path)
      }
      manager.createFile(atPath: targetURL.path, contents: Data())
      file = try FileHandle(forWritingTo: targetURL)
    }catch let err {
      print(err)
      return nil
    }

    if let header = self.gpxHeader(title: name, startDate: startDate).data(using: .utf8) {
      file.write(header)
    }

    for location in route {

      while (current_heart_rate_index < heartRate.count) && (location.timestamp > heartRate[current_heart_rate_index].startDate) {
        current_hr = heartRate[current_heart_rate_index].quantity.doubleValue(for: bpm_unit)
        current_heart_rate_index += 1
        hr_string = self.gpxHeartRate(current_hr: current_hr)
      }
      if let trackpoint = self.gpxTrackPoint(location: location, hr_string: hr_string).data(using: .utf8) {
        file.write(trackpoint)
      }
    }
    file.write("""
  </trkseg>
  </trk>
  </gpx>

  """.data(using: .utf8)!)
    file.closeFile()


    return targetURL
  }

  private func gpxTrackPoint(location: CLLocation, hr_string: String) -> String {
    let iso_formatter = ISO8601DateFormatter()

    return """
      <trkpt lat=\"\(location.coordinate.latitude)" lon="\(location.coordinate.longitude)">
        <ele>\(location.altitude.magnitude)</ele>
        <time>\(iso_formatter.string(from: location.timestamp))</time>        \(hr_string)
      </trkpt>"

    """
  }

  private func gpxHeartRate(current_hr: Double) -> String {
    return """

        <extensions>
          <gpxtpx:TrackPointExtension>
          <gpxtpx:hr>\(current_hr)</gpxtpx:hr>
          </gpxtpx:TrackPointExtension>
        </extensions>
    """
  }
  private func gpxHeader(title: String, startDate: Date) -> String {
    let iso_formatter = ISO8601DateFormatter()

    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .medium

    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx creator="StravaGPX" version="1.1" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3">

      <metadata>
        <time>\(iso_formatter.string(from: startDate))</time>
      </metadata>
      <trk>
        <name>\(title)</name>
        <trkseg>

    """
  }
}
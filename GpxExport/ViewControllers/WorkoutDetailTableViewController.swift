//
//  WorkoutDetailTableViewController.swift
//  GpxExport
//
//  Created by Patrick Steiner on 21.01.19.
//  Copyright © 2019 Mario Martelli. All rights reserved.
//

import UIKit
import MapKit
import HealthKit

class WorkoutDetailTableViewController: UITableViewController {
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet private weak var distanceLabel: UILabel!
    @IBOutlet private weak var durationLabel: UILabel!
    @IBOutlet private weak var maxHeartRateLabel: UILabel!
    @IBOutlet private weak var averageHeartRateLabel: UILabel!
    @IBOutlet private weak var mapView: MKMapView!

    private lazy var workoutStore: WorkoutDataStore = {
        return WorkoutDataStore()
    }()

    var hkWorkout: HKWorkout!
    var workout: Workout?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        loadData()
    }

    // MARK: Data source

    private func loadData() {
        workoutStore.heartRate(for: hkWorkout) { (rates, error) in
            guard let heartRateSamples = rates, error == nil else {
                print(error!.localizedDescription)
                DispatchQueue.main.async {
                    self.resetData()
                }

                return
            }

            self.workoutStore.route(for: self.hkWorkout) { (maybeLocations, error) in
                guard let locations = maybeLocations, error == nil else {
                    print(error!.localizedDescription)
                    DispatchQueue.main.async {
                        self.resetData()
                    }

                    return
                }

                self.workout = Workout(workout: self.hkWorkout, route: locations, heartRate: heartRateSamples)

                DispatchQueue.main.async {
                    self.setData()
                }
            }
        }
    }

    // MARK: UI

    private func setupUI() {
        mapView.delegate = self
    }

    private func setData() {
        guard let workout = workout else {
            resetData()
            return
        }

        self.title = workout.activityType
        dateLabel.text = workout.formattedDate

        distanceLabel.text = hkWorkout.formattedTotalDistance
        durationLabel.text = hkWorkout.duration.formatted
        maxHeartRateLabel.text = workout.formattedMaxHeartRate
        averageHeartRateLabel.text = workout.formattedAverageHeartRate

        if workout.polyline.boundingMapRect.size.height > 0 {
            mapView.addOverlay(workout.polyline)

            var region = MKCoordinateRegion.init(workout.polyline.boundingMapRect)
            region.span.latitudeDelta *= 1.2   // Increase span by 20% to add some margin
            region.span.longitudeDelta *= 1.2

            mapView.setRegion(region, animated: false)
        }
    }

    private func resetData() {
        dateLabel.text = nil
        distanceLabel.text = nil
        durationLabel.text = nil
        averageHeartRateLabel.text = nil
    }

    @IBAction func shouldShowSharingDialog(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: NSLocalizedString("actionSheet.formatSelection.title", comment: "Format Selection Title"),
                                      message: NSLocalizedString("actionSheet.formatSelection.content", comment: "Format Selection Content"),
                                      preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "GPX", style: .default, handler: {(_: UIAlertAction) in
            self.handlingAction(.gpx, barButtonItem: sender)
        }))
        alert.addAction(UIAlertAction(title: "Fit", style: .default, handler: {(_: UIAlertAction) in
            //Sign out action
            self.handlingAction(.fit, barButtonItem: sender)
        }))

        self.present(alert, animated: true)
    }

    func handlingAction(_ fileType: ExportFileType, barButtonItem: UIBarButtonItem) {
        workout?.writeFile(fileType, completionHandler: { [weak self] (targetURL) in
            let activityViewController = UIActivityViewController(activityItems: [targetURL as Any], applicationActivities: nil)

            if let popoverPresentationController = activityViewController.popoverPresentationController {
                popoverPresentationController.barButtonItem = barButtonItem
            }

            self?.present(activityViewController, animated: true)
        })
    }
}

// MARK: - MKMapViewDelegate

extension WorkoutDetailTableViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRender = MKPolylineRenderer(overlay: overlay)

        if overlay is MKPolyline {
            polylineRender.strokeColor = UIColor.blue.withAlphaComponent(0.5)
            polylineRender.lineWidth = 3
        }

        return polylineRender
    }
}

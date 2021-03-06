//
//  WorkoutDataStore.swift
//  GpxExport
//
//  Created by Mario Martelli on 30.11.17.
//  Copyright © 2017 Mario Martelli. All rights reserved.
//

import HealthKit
import WatchKit

class WorkoutDataStore {
    private var healthStore: HKHealthStore

    init() {
        healthStore = HKHealthStore()
    }

    public func heartRate(for workout: HKWorkout, completion: @escaping (([HKQuantitySample]?, Error?) -> Swift.Void)) {
        var allSamples = [HKQuantitySample]()

        let hrType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: HKQueryOptions.strictStartDate)

        let heartRateQuery = HKSampleQuery(sampleType: hrType,
                                           predicate: predicate,
                                           limit: HKObjectQueryNoLimit,
                                           sortDescriptors: [sortDescriptor]) { (_, samples, error) in
                                            guard let heartRateSamples: [HKQuantitySample] = samples as? [HKQuantitySample], error == nil else {
                                                completion(nil, error)
                                                return
                                            }

                                            if heartRateSamples.count == 0 {
                                                completion([HKQuantitySample](), nil)
                                                return
                                            }

                                            for heartRateSample in heartRateSamples {
                                                allSamples.append(heartRateSample)
                                            }
                                            completion(allSamples, nil)
        }
        healthStore.execute(heartRateQuery)
    }

    public func route(for workout: HKWorkout, completion: @escaping (([CLLocation]?, Error?) -> Void)) {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: routeType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sortDescriptor]) { (_, samples, error) in
                                    if let err = error {
                                        print(err)
                                        return
                                    }

                                    var routeLocations = [CLLocation]()
                                    guard let routeSamples: [HKWorkoutRoute] = samples as? [HKWorkoutRoute] else {
                                        print("No route samples")
                                        return
                                    }

                                    if routeSamples.count == 0 {
                                        completion([CLLocation](), nil)
                                        return
                                    }

                                    var sampleCounter = 0

                                    for routeSample: HKWorkoutRoute in routeSamples {
                                        let locationQuery = HKWorkoutRouteQuery(route: routeSample) { _, locationResults, done, error in
                                            guard locationResults != nil else {
                                                print("Error occured while querying for locations: \(error?.localizedDescription ?? "")")
                                                completion(nil, error)
                                                return
                                            }

                                            if done {
                                                sampleCounter += 1
                                                if sampleCounter != routeSamples.count {
                                                    if let locations = locationResults {
                                                        routeLocations.append(contentsOf: locations)
                                                    }
                                                } else {
                                                    if let locations = locationResults {
                                                        routeLocations.append(contentsOf: locations)
                                                        let sortedLocations = routeLocations.sorted(by: {$0.timestamp < $1.timestamp})

                                                        completion(sortedLocations, error)
                                                    }
                                                }
                                            } else {
                                                if let locations = locationResults {
                                                    routeLocations.append(contentsOf: locations)
                                                }
                                            }
                                        }
                                        self.healthStore.execute(locationQuery)
                                    }
        }
        healthStore.execute(query)
    }

    func loadWorkouts(completion: @escaping (([HKWorkout]?, Error?) -> Void)) {
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .walking),
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForWorkouts(with: .hiking),
            HKQuery.predicateForWorkouts(with: .cycling),
            HKQuery.predicateForWorkouts(with: .swimming)
            ])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { (_, samples, error) in
            DispatchQueue.main.async {
                guard let samples = samples as? [HKWorkout], error == nil else {
                    completion(nil, error)
                    return
                }
                completion(samples, nil)
            }
        }
        healthStore.execute(query)
    }
}

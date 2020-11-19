// ComposableWorkoutLive.swift
// Copyright (c) 2020 Copilot

#if canImport(CoreMotion) && (os(iOS) || os(watchOS))
import Combine
import ComposableArchitecture
import Foundation
import CoreMotion

extension AltimeterManager {
    public static let live = AltimeterManager(
        create: { id in
          .fireAndForget {
            if managers[id] != nil {
              assertionFailure(
                """
                You are attempting to create a altimter manager with the id \(id), but there is already \
                a running manager with that id. This is considered a programmer error since you may \
                be accidentally overwriting an existing manager without knowing.
                To fix you should either destroy the existing manager before creating a new one, or \
                you should not try creating a new one before this one is destroyed.
                """)
            }
            managers[id] = CMAltimeter()
          }
        },
        destroy: { id in
          .fireAndForget { managers[id] = nil }
        },
        authorizationStatus: {
            CMAltimeter.authorizationStatus()
        },
        isRelativeAltitudeAvailable: {
            CMAltimeter.isRelativeAltitudeAvailable()
        },
        startRelativeAltitudeUpdates: { id, queue in
            return Effect.run { subscriber in
                guard let manager = requireAltimeterManager(id: id) else {
                    return AnyCancellable {}
                }
                
                guard deviceRelativeAltitudeUpdatesSubscribers[id] == nil else {
                    return AnyCancellable {}
                }
                
                deviceRelativeAltitudeUpdatesSubscribers[id] = subscriber
                manager.startRelativeAltitudeUpdates(to: queue) { (data, error) in
                    if let data = data {
                        subscriber.send(.init(data))
                    } else if let error = error {
                        subscriber.send(completion: .failure(error))
                    }
                }
                
                return AnyCancellable {
                    manager.stopRelativeAltitudeUpdates()
                }
            }
        },
        stopRelativeAltitudeUpdates: { id -> Effect<Never, Never> in
            .fireAndForget {
                guard let manager = managers[id]
                else {
                    couldNotFindAltimeterManager(id: id)
                    return
                }
                manager.stopRelativeAltitudeUpdates()
                deviceRelativeAltitudeUpdatesSubscribers[id]?.send(completion: .finished)
                deviceRelativeAltitudeUpdatesSubscribers[id] = nil
            }
        })
    
    private static var managers: [AnyHashable: CMAltimeter] = [:]
    
    private static func requireAltimeterManager(id: AnyHashable) -> CMAltimeter? {
        if managers[id] == nil {
            couldNotFindAltimeterManager(id: id)
        }
        return managers[id]
    }
}

private var deviceRelativeAltitudeUpdatesSubscribers: [AnyHashable: Effect<RelativeAltitudeData, Error>.Subscriber] = [:]

private func couldNotFindAltimeterManager(id: Any) {
    assertionFailure(
        """
    A altimeter manager could not be found with the id \(id). This is considered a programmer error. \
    You should not invoke methods on a altimeter manager before it has been created or after it \
    has been destroyed. Refactor your code to make sure there is a altimeter manager created by the \
    time you invoke this endpoint.
    """)
}

#endif

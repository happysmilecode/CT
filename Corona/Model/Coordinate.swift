//
//  Coordinate.swift
//  Corona Tracker
//
//  Created by Mohammad on 3/11/20.
//  Copyright © 2020 Samabox. All rights reserved.
//

import MapKit

public struct Coordinate: Codable {
	static let zero = Coordinate(latitude: 0, longitude: 0)

	let latitude: Double
	let longitude: Double
}

extension Coordinate {
	public static func center(of coordinates: [Coordinate]) -> Coordinate {
		let totals = coordinates.reduce((latitude: 0.0, longitude: 0.0)) {
			($0.latitude + $1.latitude, $0.longitude + $1.longitude)
		}

		let center = Coordinate(latitude: totals.latitude / Double(coordinates.count),
								longitude: totals.longitude / Double(coordinates.count))

		return coordinates.min {
			center.distance(from: $0) < center.distance(from: $1)
		}!
	}

	public var isZero: Bool { latitude == 0 && longitude == 0 }

	public var clLocation: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

	func distance(from other: Coordinate) -> Double {
		hypot(latitude - other.latitude, longitude - other.longitude)
	}
}

extension Coordinate: Equatable {
	public static func == (lhs: Coordinate, rhs: Coordinate) -> Bool {
		Int(lhs.latitude * 1000) == Int(rhs.latitude * 1000) &&
			Int(lhs.longitude * 1000) == Int(rhs.longitude * 1000)
	}
}

extension Coordinate: CustomStringConvertible {
	public var description: String {
		"Coordinate: \(latitude),\(longitude)"
	}
}

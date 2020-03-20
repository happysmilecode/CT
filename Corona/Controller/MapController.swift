//
//  ViewController.swift
//  Corona
//
//  Created by Mohammad on 3/2/20.
//  Copyright © 2020 Samabox. All rights reserved.
//

import UIKit
import MapKit

import FloatingPanel

class MapController: UIViewController {
	private static let cityZoomLevel = CGFloat(4)
	private static let updateInterval: TimeInterval = 60 * 5 /// 5 mins

	static var instance: MapController!

	private var allAnnotations: [RegionAnnotation] = []
	private var countryAnnotations: [RegionAnnotation] = []
	private var currentAnnotations: [RegionAnnotation] = []

	private var panelController: FloatingPanelController!
	private var regionContainerController: RegionContainerController!

	@IBOutlet var mapView: MKMapView!
	@IBOutlet var effectView: UIVisualEffectView!
	@IBOutlet var buttonUpdate: UIButton!

	override func viewDidLoad() {
		super.viewDidLoad()

		MapController.instance = self

		initializeView()
		initializeBottomSheet()

		DataManager.instance.load { _ in
			self.update()
			self.downloadIfNeeded()
		}

		Timer.scheduledTimer(withTimeInterval: Self.updateInterval, repeats: true) { _ in
			self.downloadIfNeeded()
		}

		checkForAppUpdate()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		panelController.addPanel(toParent: self, animated: true)
		regionContainerController.regionController.tableView.setContentOffset(.zero, animated: false)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		panelController.removePanelFromParent(animated: animated)
	}

	private func initializeView() {
		buttonUpdate.layer.cornerRadius = buttonUpdate.bounds.height / 2

		if #available(iOS 13.0, *) {
			effectView.effect = UIBlurEffect(style: .systemThinMaterial)
		}

		if #available(iOS 11.0, *) {
			mapView.mapType = .mutedStandard
			mapView.register(RegionAnnotationView.self,
							 forAnnotationViewWithReuseIdentifier: RegionAnnotationView.reuseIdentifier)
		}
	}

	private func initializeBottomSheet() {
		let identifier = String(describing: RegionContainerController.self)
		regionContainerController = storyboard?.instantiateViewController(
			withIdentifier: identifier) as? RegionContainerController

		panelController = FloatingPanelController()
		panelController.delegate = self
		panelController.surfaceView.cornerRadius = 12
		panelController.surfaceView.shadowHidden = false
		panelController.set(contentViewController: regionContainerController)
		panelController.track(scrollView: regionContainerController.regionController.tableView)
		panelController.surfaceView.backgroundColor = .clear
		panelController.surfaceView.contentView.backgroundColor = .clear

		#if targetEnvironment(macCatalyst)
		panelController.additionalSafeAreaInsets = .init(top: 0, left: 0, bottom: 10, right: 0)
		#endif
	}

	func updateRegionScreen(region: Region?) {
		regionContainerController.regionController.region = region
		regionContainerController.regionController.update()
	}

	func showRegionScreen() {
		panelController.move(to: .full, animated: true)
	}

	func hideRegionScreen() {
		panelController.move(to: .half, animated: true)
	}

	func showRegionOnMap(region: Region) {
		let coordinateRegion = MKCoordinateRegion(center: region.location.clLocation,
												  span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12))
		mapView.setRegion(coordinateRegion, animated: true)

		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			if let annotation = self.currentAnnotations.first(where: { $0.region == region }) {
				self.mapView.selectAnnotation(annotation, animated: true)
			}
		}
	}

	private func update() {
		allAnnotations = DataManager.instance.regions(of: .province)
			.filter({ $0.report?.stat.confirmedCount ?? 0 > 0 })
			.map({ RegionAnnotation(region: $0) })

		countryAnnotations = DataManager.instance.regions(of: .country)
			.filter({ $0.report?.stat.confirmedCount ?? 0 > 0 })
			.map({ RegionAnnotation(region: $0) })

		currentAnnotations = mapView.zoomLevel > Self.cityZoomLevel ? allAnnotations : countryAnnotations

		mapView.removeAnnotations(mapView.annotations)
		mapView.addAnnotations(currentAnnotations)

		regionContainerController.regionController.region = nil
		regionContainerController.regionController.update()
	}

	func downloadIfNeeded() {
		let showSpinner = allAnnotations.isEmpty
		if showSpinner {
			showHUD(message: "Updating...")
		}
		regionContainerController.isUpdating = true

		DataManager.instance.download { success in
			DispatchQueue.main.async {
				self.regionContainerController.isUpdating = false

				if success {
					self.hideHUD()
					self.update()
				}
				else {
					if showSpinner {
						self.showMessage(title: "Can't update the data",
										 message: "Please make sure you're connected to the internet.")
					}
				}
			}
		}
	}

	private func checkForAppUpdate() {
		App.checkForAppUpdate { updateAvailable in
			if updateAvailable {
				DispatchQueue.main.async {
					self.buttonUpdate.isHidden = false
				}
			}
		}
	}

	@IBAction func buttonUpdateTapped(_ sender: Any) {
		let alertController = UIAlertController.init(
			title: "New Version Available",
			message: "Please update from \(App.updateURL.absoluteString)",
			preferredStyle: .alert)

		#if targetEnvironment(macCatalyst)
		alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		alertController.addAction(UIAlertAction(title: "Open", style: .default, handler: { _ in
			App.openUpdatePage(viewController: self)
		}))
		#else
		alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
		#endif

		present(alertController, animated: true)

		buttonUpdate.isHidden = true
	}
}

extension MapController: MKMapViewDelegate {
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		guard !(annotation is MKUserLocation) else {
			return nil
		}

		var annotationView: RegionAnnotationView
		if #available(iOS 11.0, *) {
			guard let view = mapView.dequeueReusableAnnotationView(
				withIdentifier: RegionAnnotationView.reuseIdentifier,
				for: annotation) as? RegionAnnotationView else { return nil }
			annotationView = view
		} else {
			/// iOS 10
			let view = mapView.dequeueReusableAnnotationView(
				withIdentifier: RegionAnnotationView.reuseIdentifier) as? RegionAnnotationView
			annotationView = view ?? RegionAnnotationView(annotation: annotation,
														  reuseIdentifier: RegionAnnotationView.reuseIdentifier)
		}

		annotationView.mapZoomLevel = mapView.zoomLevel

		return annotationView
	}

	func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
		for annotation in currentAnnotations {
			if let view = mapView.view(for: annotation) as? RegionAnnotationView {
				view.mapZoomLevel = mapView.zoomLevel
			}
		}
	}

	func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
		if mapView.zoomLevel > Self.cityZoomLevel {
			if currentAnnotations.count != allAnnotations.count {
				mapView.removeAnnotations(mapView.annotations)
				currentAnnotations = allAnnotations
				mapView.addAnnotations(currentAnnotations)
			}
		}
		else {
			if currentAnnotations.count != countryAnnotations.count {
				mapView.removeAnnotations(mapView.annotations)
				currentAnnotations = countryAnnotations
				mapView.addAnnotations(currentAnnotations)
			}
		}
	}

	func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
		updateRegionScreen(region: (view as? RegionAnnotationView)?.region)
	}

	func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
		updateRegionScreen(region: nil)
	}
}

extension MapController: FloatingPanelControllerDelegate {
	func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
		(newCollection.userInterfaceIdiom == .pad ||
			newCollection.verticalSizeClass == .compact) ? LandscapePanelLayout() : PanelLayout()
	}

	func floatingPanelWillBeginDragging(_ vc: FloatingPanelController) {
		let currentPosition = vc.position

		// currentPosition == .full means deceleration will start from top to bottom (i.e. user dragging the panel down)
		if currentPosition == .full, regionContainerController.isSearching {
			// Reset to region container's default mode then hide the keyboard
			self.regionContainerController.isSearching = false
        }
    }
}

class PanelLayout: FloatingPanelLayout {
	public var initialPosition: FloatingPanelPosition {
		return .half
	}

	public func insetFor(position: FloatingPanelPosition) -> CGFloat? {
		switch position {
		case .full: return 16
		case .half: return 215
		case .tip: return 68
		default: return nil
		}
	}

	func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
		if #available(iOS 11.0, *) {
			return [
				surfaceView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 0.0),
				surfaceView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: 0.0),
			]
		} else {
			/// iOS 10
			return [
				surfaceView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0.0),
				surfaceView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0.0),
			]
		}
	}

	func backdropAlphaFor(position: FloatingPanelPosition) -> CGFloat {
		return position == .full ? 0.3 : 0.0
	}
}

class LandscapePanelLayout: PanelLayout {
	override func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
		if #available(iOS 11.0, *) {
			return [
				surfaceView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 8.0),
				surfaceView.widthAnchor.constraint(equalToConstant: 400),
			]
		} else {
			/// iOS 10
			return [
				surfaceView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8.0),
				surfaceView.widthAnchor.constraint(equalToConstant: 400),
			]
		}
	}

	override func backdropAlphaFor(position: FloatingPanelPosition) -> CGFloat {
		return 0.0
	}
}

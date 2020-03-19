//
//  Menu.swift
//  Corona Tracker
//
//  Created by Mohammad on 3/19/20.
//  Copyright © 2020 Samabox. All rights reserved.
//

import UIKit

class Menu {
	static func show(above controller: UIViewController, sourceView: UIView, items: [MenuItem]) {
		let menuController = MenuController(items: items)
		let segue = MenuSegue(identifier: nil, source: controller, destination: menuController)
		segue.sourceView = sourceView
		controller.prepare(for: segue, sender: sourceView)
		segue.perform()
	}
}

struct MenuItem {
	var title: String
	var image: UIImage
	var action: () -> Void
}

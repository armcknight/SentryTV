//
//  OrganizationTableViewCell.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/24/22.
//

import Foundation
import UIKit

class OrganizationTableViewCell: UITableViewCell {
    @IBOutlet weak var iconImage: UIImageView!
    @IBOutlet weak var label: UILabel!

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        context.previouslyFocusedView?.backgroundColor = UIColor.clear
        context.nextFocusedView?.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
    }
}

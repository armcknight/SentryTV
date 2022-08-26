//
//  OrganizationTableViewCell.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/24/22.
//

import Anchorage
import Foundation
import UIKit

class ProjectTableViewCell: UITableViewCell {
    let iconImage = UIImageView(frame: .zero)
    let label = UILabel(frame: .zero)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = UIColor.clear

        [iconImage, label].do {
            $0.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
            UIStackView(arrangedSubviews: $0).do {
                contentView.addSubview($0)
                $0.edgeAnchors == contentView.edgeAnchors
            }
        }

        iconImage.widthAnchor == 240
        iconImage.widthAnchor == iconImage.heightAnchor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        context.previouslyFocusedView?.backgroundColor = UIColor.clear
        context.nextFocusedView?.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
    }
}

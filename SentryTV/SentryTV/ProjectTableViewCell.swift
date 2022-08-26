//
//  OrganizationTableViewCell.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/24/22.
//

import Anchorage
import Charts
import Foundation
import Then
import UIKit

class ProjectTableViewCell: UITableViewCell {
    let iconImage = UIImageView(frame: .zero)
    let label = UILabel(frame: .zero)
    let eventsChart = LineChartView(frame: .zero)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = UIColor.clear

        [iconImage, label, eventsChart].do {
            $0.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
            UIStackView(arrangedSubviews: $0).do {
                $0.spacing = 16
                contentView.addSubview($0)
                $0.edgeAnchors == contentView.edgeAnchors
            }
        }

        iconImage.widthAnchor == 240
        iconImage.widthAnchor == iconImage.heightAnchor

        eventsChart.do {
            $0.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
            $0.layer.cornerRadius = 20
            $0.clipsToBounds = true
            $0.xAxis.enabled = false
            [$0.leftAxis, $0.rightAxis].forEach {
                $0.enabled = false
            }
            $0.legend.enabled = false
            $0.tintColor = .white
            $0.noDataText = ""
            $0.widthAnchor == 240
        }
    }

    func setTimeseries(_ timeseries: [[Int]]) {
        let entries = timeseries.compactMap({ value -> ChartDataEntry? in
            // unix timestamp: number of occurrences
            ChartDataEntry(x: Double(value[0]), y: Double(value[1]))
        })

        eventsChart.data = LineChartData(dataSet: LineChartDataSet(entries: entries, label: "Occurrences").with {
            $0.mode = .cubicBezier
            $0.drawCirclesEnabled = false
            $0.drawValuesEnabled = false
            $0.lineWidth = 2
            $0.drawFilledEnabled = true
            let gradientColors = [UIColor(white: 1, alpha: 0.2).cgColor,
                                  UIColor(white: 1, alpha: 0.7).cgColor]
            let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!

            $0.fillAlpha = 1
            $0.fill = LinearGradientFill(gradient: gradient, angle: 90)
            $0.colors = [.white]
        })

        eventsChart.animate(yAxisDuration: 0.5, easingOption: .easeOutSine)
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

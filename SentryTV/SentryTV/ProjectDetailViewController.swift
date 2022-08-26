//
//  ProjectDetailViewController.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/25/22.
//

import Anchorage
import Charts
import Then
import UIKit

class ProjectDetailViewController: UIViewController {
    private let project: SentryProject
    private let organization: SentryOrganization
    private let apiClient = SentryAPIClient()
    private var issues: SentryJSONCollection?

    private let titleLabel = UILabel(frame: .zero)
    private let issuesChartView = LineChartView(frame: .zero)
    private let issueListTableView = UITableView(frame: .zero)
    private let logoImageView = UIImageView(frame: .zero).then {
        $0.image = UIImage(imageLiteralResourceName: "logo")
    }
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    let isoDF = ISO8601DateFormatter().then {
        $0.formatOptions = .withInternetDateTime.subtracting(.withTimeZone)
    }
    let humanReadableDF = DateFormatter().then {
        $0.dateStyle = .long
        $0.timeStyle = .long
    }

    init(organization: SentryOrganization, project: SentryProject) {
        self.organization = organization
        self.project = project
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = UIColor(red: 41.0/255.0, green: 29.0/255.0, blue: 54.0/255.0, alpha: 1)

        guard let name = project["name"] as? String ?? project["slug"] as? String else {
            fatalError("Project has no name or slug")
        }
        titleLabel.text = "\(name) Issues"
        titleLabel.font = .preferredFont(forTextStyle: .title1)

        issueListTableView.dataSource = self
        issueListTableView.delegate = self
        issueListTableView.register(UITableViewCell.self, forCellReuseIdentifier: "IssueCell")

        issuesChartView.do {
            $0.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
            $0.layer.cornerRadius = 20
            $0.clipsToBounds = true
            $0.xAxis.labelFont = .systemFont(ofSize: 20)
            [$0.leftAxis, $0.rightAxis].forEach {
                $0.labelFont = .systemFont(ofSize: 20)
            }
            $0.legend.font = .systemFont(ofSize: 20)
            $0.legend.form = .circle
            $0.tintColor = .white
            $0.noDataText = ""
        }

        class XAxisTimestampValueFormatter: NSObject, AxisValueFormatter {
            private let df = DateFormatter().then {
                $0.timeStyle = .short
                $0.dateStyle = .none
            }
            func stringForValue(_ value: Double, axis: AxisBase?) -> String {
                df.string(from: Date(timeIntervalSinceReferenceDate: value))
            }
        }
        issuesChartView.xAxis.valueFormatter = XAxisTimestampValueFormatter()

        [titleLabel, issuesChartView, issueListTableView, logoImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, UIStackView(arrangedSubviews: [issuesChartView, issueListTableView]).then {
                $0.axis = .vertical
                $0.distribution = .fillEqually
                $0.spacing = 8
            }]).then {
                $0.axis = .vertical
                $0.spacing = 8
                view.addSubview($0)
                $0.verticalAnchors == view.safeAreaLayoutGuide.verticalAnchors
                $0.trailingAnchor == view.safeAreaLayoutGuide.trailingAnchor
            }

        activityIndicator.do {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.centerAnchors == issuesChartView.centerAnchors
            $0.startAnimating()
        }

        logoImageView.do {
            view.addSubview($0)
            $0.widthAnchor == 220
            $0.heightAnchor == logoImageView.widthAnchor
            $0.leadingAnchor == view.safeAreaLayoutGuide.leadingAnchor
            $0.topAnchor == view.safeAreaLayoutGuide.topAnchor
            stack.leadingAnchor == $0.trailingAnchor + 16
        }

        guard let orgSlug = organization["slug"] as? String, let projectSlug = project["slug"] as? String else {
            fatalError("Couldn't get org/project slug for request.")
        }

        apiClient.getIssues(org: orgSlug, project: projectSlug) { result in
            switch result {
            case .failure(let error): fatalError(error.localizedDescription)
            case .success(let json):
                self.issues = json
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                }
                DispatchQueue.main.async {
                    self.issueListTableView.reloadData()
                }
                DispatchQueue.main.async {
                    guard let first = json.first else {
                        return
                    }
                    self.reloadChart(with: first)
                }
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadChart(with issue: SentryJSON) {
        guard let hourlyArray = (issue["stats"] as? SentryJSON)?["24h"] as? [[Int]] else {
            fatalError("Unexpected data structure.")
        }

        let timeseries = hourlyArray.compactMap({ value -> ChartDataEntry? in
            // unix timestamp: number of occurrences
            ChartDataEntry(x: Double(value[0]), y: Double(value[1]))
        })

        issuesChartView.data = LineChartData(dataSet: LineChartDataSet(entries: timeseries, label: "Occurrences").with {
            $0.mode = .cubicBezier
            $0.drawCirclesEnabled = false
            $0.drawValuesEnabled = false
            $0.lineWidth = 3
            $0.drawFilledEnabled = true
            let gradientColors = [UIColor(white: 1, alpha: 0.2).cgColor,
                                  UIColor(white: 1, alpha: 0.7).cgColor]
            let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!

            $0.fillAlpha = 1
            $0.fill = LinearGradientFill(gradient: gradient, angle: 90)
            $0.colors = [.white]
        })

        issuesChartView.animate(yAxisDuration: 0.5, easingOption: .easeOutSine)
    }
}

extension UIListContentConfiguration: Then {}

extension ProjectDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return issues?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "IssueCell", for: indexPath)
        if let issue = issues?[indexPath.row] {
            cell.contentConfiguration = UIListContentConfiguration.valueCell().with {
                $0.text = issue["title"] as? String
                guard let level = issue["level"] as? String, let count = issue["count"] as? String, let lastSeen = issue["lastSeen"] as? String else {
                    fatalError("Unexpected data types.")
                }
                guard let isoDate = isoDF.date(from: lastSeen) else {
                    fatalError("Unexpected data format.")
                }
                let lastSeenString = humanReadableDF.string(from: isoDate)

                $0.secondaryText = "\(level) / \(count) / Last seen \(lastSeenString)"
            }
        }
        return cell
    }
}

extension ProjectDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

    }

    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        guard let row = context.nextFocusedIndexPath?.row else {
            fatalError("Can't get indexPath")
        }
        guard let issue = issues?[row] else {
            fatalError("Missing issue data for row.")
        }
        reloadChart(with: issue)
    }
}

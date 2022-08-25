//
//  ViewController.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/24/22.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    private var projectJSON: SentryProjects?
    private let apiClient = SentryAPIClient()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension

        apiClient.getOrganizations { result in
            print("here")
        }
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProjectCell", for: indexPath)
        if let projectCell = cell as? ProjectTableViewCell {
            projectCell.label.text = "Project Name"
            projectCell.iconImage.image = UIImage(imageLiteralResourceName: "reading-logo")
        }
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 250
    }
}

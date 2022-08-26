//
//  OrganizationViewController.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/24/22.
//

import UIKit

class OrganizationViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    private var organizations: SentryOrganizations?
    private var projects: SentryProjects?
    private let apiClient = SentryAPIClient()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension

        apiClient.getOrganizations { result in
            switch result {
            case .failure(let error): fatalError(error.localizedDescription)
            case .success(let organizations):
                self.organizations = organizations
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }
}

extension OrganizationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return organizations?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OrganizationCell", for: indexPath)
        if let organization = organizations?[indexPath.row] {
            if let organizationCell = cell as? OrganizationTableViewCell {
                organizationCell.label.text = organization["name"] as? String
                organizationCell.iconImage.image = UIImage(imageLiteralResourceName: "reading-logo")
            }
        }
        return cell
    }
}

extension OrganizationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 250
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let org = organizations![indexPath.row]
        navigationController?.pushViewController(ProjectsViewController(organization: org), animated: true)
    }
}

//
//  ProjectsViewController.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/25/22.
//

import Anchorage
import UIKit

class ProjectsViewController: UIViewController {

    private let tableView = UITableView(frame: .zero)
    private let logoImageView = UIImageView(frame: .zero)
    private let titleLabel = UILabel(frame: .zero)

    private var projects: SentryProjects?
    private let apiClient = SentryAPIClient()
    private var organization: SentryOrganization

    init(organization: SentryOrganization) {
        self.organization = organization
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = UIColor(red: 41.0/255.0, green: 29.0/255.0, blue: 54.0/255.0, alpha: 1)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ProjectTableViewCell.self, forCellReuseIdentifier: "ProjectCell")
        tableView.backgroundColor = UIColor.clear

        logoImageView.image = UIImage(imageLiteralResourceName: "logo")
        titleLabel.text = "Select Your Project"

        [tableView, logoImageView, titleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        logoImageView.topAnchor == view.safeAreaLayoutGuide.topAnchor + 8
        logoImageView.leadingAnchor == view.safeAreaLayoutGuide.leadingAnchor + 16
        logoImageView.widthAnchor == 220
        logoImageView.heightAnchor == logoImageView.widthAnchor

        titleLabel.topAnchor == logoImageView.topAnchor
        titleLabel.leadingAnchor == logoImageView.trailingAnchor + 16
        titleLabel.trailingAnchor == view.safeAreaLayoutGuide.trailingAnchor - 16

        tableView.topAnchor == titleLabel.bottomAnchor + 8
        tableView.leadingAnchor == titleLabel.leadingAnchor
        tableView.trailingAnchor == titleLabel.trailingAnchor
        tableView.bottomAnchor == view.safeAreaLayoutGuide.bottomAnchor - 8

        let orgName = organization["slug"] as! String
        apiClient.getProjects(organization: orgName) { result in
            switch result {
            case .failure(let error): fatalError(error.localizedDescription)
            case .success(let projects):
                self.projects = projects
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
     }
}

extension ProjectsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return projects?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProjectCell", for: indexPath)
        if let project = projects?[indexPath.row] {
            if let projectCell = cell as? ProjectTableViewCell {
                projectCell.label.text = project["slug"] as? String
                projectCell.iconImage.image = UIImage(imageLiteralResourceName: "reading-logo")
            }
        }
        return cell
    }
}

extension ProjectsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 250
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        ProjectDetailViewController(organization: organization, project: projects![indexPath.row]).do {
            navigationController?.pushViewController($0, animated: true)
        }
    }
}

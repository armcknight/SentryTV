//
//  SentryAPI.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/24/22.
//

import Keys
import Then
import UIKit

typealias SentryOrganizationSlug = String
typealias SentryProjectSlug = String
typealias SentryIssueID = String
typealias SentryJSON = [String: Any]
typealias SentryJSONCollection = [SentryJSON]
typealias SentryOrganization = SentryJSON
typealias SentryProject = SentryJSON
typealias SentryOrganizations = SentryJSONCollection
typealias SentryProjects = SentryJSONCollection

enum SentryAPI {
    case authorize
    case organizations
    case projects(SentryOrganizationSlug)
    case issues(SentryOrganizationSlug, SentryProjectSlug)
    case issue(SentryIssueID)
    case issueLatestEvent(SentryIssueID)
    case projectEvents(SentryOrganizationSlug, SentryProjectSlug)

    var path: String {
        switch self {
        case .authorize: return "/api/0/"
        case .organizations: return "/api/0/organizations/"
        case .projects(let org): return "/api/0/organizations/\(org)/projects/"
        case .issues(let org, let proj): return "/api/0/projects/\(org)/\(proj)/issues/"
        case .issue(let id): return "/api/0/issues/\(id)/"
        case .issueLatestEvent(let id): return "/api/0/issues/\(id)/events/latest/"
        case .projectEvents(let org, let proj): return "/api/0/projects/\(org)/\(proj)/stats/"
        }
    }

    var query: String? {
        switch self {
        case .organizations: return "member=1"
        default: return nil
        }
    }
}

class SentryAPIClient: NSObject {
    enum SentryAPIClientError: Error {
        case error(String)
    }

    enum CacheKey: String, CaseIterable {
        case organizations = "io.sentry.tv.cached-organizations"
        case projects = "io.sentry.tv.cached-projects"
    }

    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }()
    private var token: String = SentryTVKeys().sentryAuthToken

    private lazy var cachedOrganizations: SentryOrganizations? = {
        guard let data = UserDefaults.standard.object(forKey: "io.sentry.tv.cached-organizations") as? Data else {
            return nil
        }
        do {
            return try NSKeyedUnarchiver(forReadingFrom: data).decodeObject(forKey: "json") as? SentryOrganizations
        } catch {
            print("[SentryTV] failed to unarchive cache: \(error)")
            return nil
        }
    }()

    typealias SentryProjectCache = [SentryOrganizationSlug: SentryProjects]
    private lazy var cachedProjects: SentryProjectCache? = {
        guard let data = UserDefaults.standard.object(forKey: "io.sentry.tv.cached-projects") as? Data else {
            return nil
        }
        return try? NSKeyedUnarchiver(forReadingFrom: data).decodeObject(forKey: "json") as? SentryProjectCache
    }()
}

extension SentryAPIClient {
    func getOrganizations(handler: @escaping (Result<SentryOrganizations, Error>) -> Void) {
        if let cachedOrganizations = cachedOrganizations {
            handler(.success(cachedOrganizations))
            return
        }

        switch buildRequest(.organizations) {
        case .failure(let error): handler(.failure(error))
        case .success(let request):
            self.get(request: request) { requestResult in
                handler(requestResult.map { json -> SentryOrganizations in
                    self.cachedOrganizations = json
                    NSKeyedArchiver(requiringSecureCoding: false).do {
                        $0.encode(json, forKey: "json")
                        UserDefaults.standard.set($0.encodedData, forKey: "io.sentry.tv.cached-organizations")
                    }
                    return json
                })
            }
        }
    }

    func getProjects(organization: SentryOrganizationSlug, handler: @escaping (Result<SentryProjects, Error>) -> Void) {
        if let cachedProjects = cachedProjects {
            guard let cache = cachedProjects[organization] else {
                handler(.failure(SentryAPIClientError.error("No projects cached for organization \(organization)")))
                return
            }
            handler(.success(cache))
            return
        }

        switch buildRequest(.projects(organization)) {
        case .failure(let error): handler(.failure(error))
        case .success(let request):
            self.get(request: request) { requestResult in
                handler(requestResult.map { json -> SentryProjects in
                    if var cache = self.cachedProjects {
                        cache[organization] = json
                    } else {
                        self.cachedProjects = [organization: json]
                    }
                    NSKeyedArchiver(requiringSecureCoding: false).do {
                        $0.encode(self.cachedProjects, forKey: "json")
                        UserDefaults.standard.set($0.encodedData, forKey: "io.sentry.tv.cached-projects")
                    }
                    return json
                })
            }
        }
    }

    func getIssues(org: SentryOrganizationSlug, project: SentryProjectSlug, handler: @escaping (Result<SentryProjects, Error>) -> Void) {
        switch buildRequest(.issues(org, project)) {
        case .failure(let error): handler(.failure(error))
        case .success(let request):
            self.get(request: request) { result in
                handler(result)
            }
        }
    }

    func getProjectEvents(org: SentryOrganizationSlug, project: SentryProjectSlug, handler: @escaping (Result<[[Int]], Error>) -> Void) {
        switch buildRequest(.projectEvents(org, project)) {
        case .failure(let error): handler(.failure(error))
        case .success(let request):
            print("[SentryTV] performing request: \(String(describing: request))")
            let task = urlSession.dataTask(with: request) { data, response, error in
                guard error == nil else {
                    handler(.failure(SentryAPIClientError.error("Request failed with error: \(String(describing: error))")))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    handler(.failure(SentryAPIClientError.error("Response was not an HTTP response.")))
                    return
                }

                guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 else {
                    handler(.failure(SentryAPIClientError.error("Received unsuccessful HTTP response: \(httpResponse.statusCode)")))
                    return
                }

                guard let data = data else {
                    handler(.failure(SentryAPIClientError.error("Received no data from request.")))
                    return
                }

                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [[Int]] else {
                        handler(.failure(SentryAPIClientError.error("Unexpected JSON structure.")))
                        return
                    }
                    handler(.success(json))
                } catch {
                    handler(.failure(SentryAPIClientError.error("Error deserializing data: \(error)")))
                }
            }
            task.resume()
        }
    }
}

extension URLComponents: Then {}

private extension SentryAPIClient {
    func buildRequest(_ endpoint: SentryAPI) -> Result<URLRequest, Error> {
        let components = URLComponents().with {
            $0.scheme = "https"
            $0.host = "sentry.io"
            $0.path = endpoint.path
            $0.query = endpoint.query
        }

        guard let url = components.url else {
            return .failure(SentryAPIClientError.error("Couldn't construct URL"))
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.addValue("Content Type", forHTTPHeaderField: "application/json; charset=utf-8")
        urlRequest.addValue("Authorization", forHTTPHeaderField: "Bearer \(token)")

        return .success(urlRequest)
    }

    func get(request: URLRequest, handler: @escaping (Result<SentryJSONCollection, Error>) -> Void) {
        print("[SentryTV] performing request: \(String(describing: request))")
        let task = urlSession.dataTask(with: request) { data, response, error in
            self.decodedJSONFromRequest(data: data, response: response, error: error) { result in
                switch result {
                case .success(let json):
                    handler(.success(json))
                    break
                case .failure(let error): handler(.failure(error))
                }
            }
        }

        task.resume()
    }

    func decodedJSONFromRequest(data: Data?, response: URLResponse?, error: Error?, handler: @escaping (Result<SentryJSONCollection, Error>) -> Void) {
        guard error == nil else {
            handler(.failure(SentryAPIClientError.error("Request failed with error: \(String(describing: error))")))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            handler(.failure(SentryAPIClientError.error("Response was not an HTTP response.")))
            return
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 else {
            handler(.failure(SentryAPIClientError.error("Received unsuccessful HTTP response: \(httpResponse.statusCode)")))
            return
        }

        guard let data = data else {
            handler(.failure(SentryAPIClientError.error("Received no data from request.")))
            return
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? SentryJSONCollection else {
                handler(.failure(SentryAPIClientError.error("Unexpected JSON structure.")))
                return
            }
            handler(.success(json))
        } catch {
            handler(.failure(SentryAPIClientError.error("Error deserializing data: \(error)")))
        }
    }
}

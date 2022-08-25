//
//  SentryAPI.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/24/22.
//

import UIKit

typealias SentryOrganization = [String: Any]
typealias SentryProject = [String: Any]

enum SentryAPI {
    case authorize
    case organizations

    typealias SentryOrganizationID = String
    case projects(SentryOrganizationID)

    var path: String {
        switch self {
        case .authorize: return ""
        case .organizations: return "organizations"
        case .projects(let org): return ["organizations", org, "projects"].joined(separator: "/")
        }
    }
}

struct SentryAPIClient {
    enum SentryAPIClientError: Error {
        case error(String)
    }

    private static let urlSession = URLSession(configuration: .default)
    private static var token: String?

    private static var cachedOrganizations: SentryOrganization?
    private static var cachedProjects: SentryProject?
}

extension SentryAPIClient {
    static func authorize(handler: @escaping (Result<String, Error>) -> Void) {
        if let token = token {
            handler(.success(token))
        }

        switch buildRequest(.authorize) {
        case .failure(let error): handler(.failure(error))
        case .success(let request):
            get(request: request) { result in
                switch result {
                case .failure(let error): handler(.failure(error))
                case .success(let response):
                    guard let token = response["token"] as? String else {
                        handler(.failure(SentryAPIClientError.error("Couldn't parse token from authorization response.")))
                        return
                    }
                    handler(.success(token))
                }
            }
        }
    }

    static func getOrganizations(handler: @escaping (Result<SentryOrganization, Error>) -> Void) {
        if let cachedOrganizations = cachedOrganizations {
            handler(.success(cachedOrganizations))
            return
        }

        switch buildRequest(.organizations) {
        case .failure(let error): handler(.failure(error))
        case .success(var request):
            authorize { result in
                switch result {
                case .failure(let error): handler(.failure(error))
                case .success(let token):
                    request.addValue("Authorization", forHTTPHeaderField: "Bearer \(token)")
                    get(request: request) { requestResult in
                        handler(requestResult.map { json -> SentryOrganization in
                            cachedOrganizations = json
                            return json
                        })
                    }
                }
            }
        }
    }

    static func getProjects(organization: String, handler: @escaping (Result<SentryProject, Error>) -> Void) {
        if let cachedProjects = cachedProjects {
            handler(.success(cachedProjects))
            return
        }

        switch buildRequest(.projects(organization)) {
        case .failure(let error): handler(.failure(error))
        case .success(var request):
            authorize { result in
                switch result {
                case .failure(let error): handler(.failure(error))
                case .success(let token):
                    request.addValue("Authorization", forHTTPHeaderField: "Bearer \(token)")
                    get(request: request) { requestResult in
                        handler(requestResult.map { json -> SentryOrganization in
                            cachedProjects = json
                            return json
                        })
                    }
                }
            }
        }
    }
}

private extension SentryAPIClient {
    static func buildRequest(_ endpoint: SentryAPI) -> Result<URLRequest, Error> {
        guard let url = URL(string: "https://sentry.io/api/0/\(endpoint.path)") else {
            return .failure(SentryAPIClientError.error("Couldn't construct URL"))
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.addValue("Content Type", forHTTPHeaderField: "application/json; charset=utf-8")

        return .success(urlRequest)
    }

    static func get(request: URLRequest, handler: @escaping (Result<[String: Any], Error>) -> Void) {
        let task = urlSession.dataTask(with: request) { data, response, error in
            decodedJSONFromRequest(data: data, response: response, error: error) { result in
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

    static func decodedJSONFromRequest(data: Data?, response: URLResponse?, error: Error?, handler: @escaping (Result<[String: Any], Error>) -> Void) {
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
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                handler(.failure(SentryAPIClientError.error("Unexpected JSON structure.")))
                return
            }
            handler(.success(json))
        } catch {
            handler(.failure(SentryAPIClientError.error("Error deserializing data: \(error)")))
        }
    }
}

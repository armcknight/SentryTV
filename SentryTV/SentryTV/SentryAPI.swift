//
//  SentryAPI.swift
//  SentryTV
//
//  Created by Andrew McKnight on 8/24/22.
//

import Keys
import Then
import UIKit

typealias SentryJSON = [String: Any]
typealias SentryJSONCollection = [SentryJSON]
typealias SentryOrganizations = SentryJSONCollection
typealias SentryProjects = SentryJSONCollection

enum SentryAPI {
    case authorize
    case organizations

    typealias SentryOrganizationID = String
    case projects(SentryOrganizationID)

    var path: String {
        switch self {
        case .authorize: return "/api/0/"
        case .organizations: return "/api/0/organizations/"
        case .projects(let org): return "/api/0/organizations\(org)/projects/"
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

    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }()
    private var token: String = SentryTVKeys().sentryAuthToken

    private var cachedOrganizations: SentryOrganizations?
    private var cachedProjects: SentryProjects?
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
                    return json
                })
            }
        }
    }

    func getProjects(organization: String, handler: @escaping (Result<SentryProjects, Error>) -> Void) {
        if let cachedProjects = cachedProjects {
            handler(.success(cachedProjects))
            return
        }

        switch buildRequest(.projects(organization)) {
        case .failure(let error): handler(.failure(error))
        case .success(let request):
            self.get(request: request) { requestResult in
                handler(requestResult.map { json -> SentryOrganizations in
                    self.cachedProjects = json
                    return json
                })
            }
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
            let string = String(data: data, encoding: .utf8)
            let json = try JSONSerialization.jsonObject(with: data)
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

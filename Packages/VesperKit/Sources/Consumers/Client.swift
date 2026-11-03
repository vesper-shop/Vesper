import Foundation
import Identity

struct Client {
    /// The consumer APIs emit ISO 8601 timestamps with milliseconds (JavaScript `toISOString`).
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let format = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        decoder.dateDecodingStrategy = .custom { decoder in
            try format.parse(decoder.singleValueContainer().decode(String.self))
        }
        return decoder
    }()

    let api: ConsumerAPI

    init(_ api: ConsumerAPI) {
        self.api = api
    }

    func json<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: RequestBody? = nil,
        operation: String
    ) async throws -> T {
        try Self.decoder.decode(T.self, from: await data(path, method: method, query: query, body: body, operation: operation))
    }

    func data(
        _ path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: RequestBody? = nil,
        operation: String
    ) async throws -> Data {
        var url = api.baseURL.appending(path: "api").appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("Bearer \(try await Identity.shared.token())", forHTTPHeaderField: "Authorization")
        switch body {
        case .json(let value):
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(value)
        case .form(let form):
            request.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = form.body
            request.timeoutInterval = 300
        case nil where method != "GET":
            // SvelteKit rejects a bodiless write with no content type as a cross-site form (403).
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case nil:
            break
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as! HTTPURLResponse).statusCode
        if code == 401 {
            await Identity.shared.invalidate()
        }
        guard (200..<300).contains(code) else {
            throw ConsumerError.status(operation: operation, code: code)
        }
        return data
    }
}

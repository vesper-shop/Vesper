import Foundation
import Identity

struct Client {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = date(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an ISO 8601 date: \(text)"))
            }
            return date
        }
        return decoder
    }()

    static func day(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    }

    /// Vesper writes ISO 8601 with an offset, with or without fractional seconds.
    static func date(_ text: String) -> Date? {
        let formats = [Date.ISO8601FormatStyle(includingFractionalSeconds: true), Date.ISO8601FormatStyle()]
        return formats.lazy.compactMap { try? $0.parse(text) }.first
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
        var url = Identity.origin.appending(path: "api").appending(path: path)
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
        case .raw(let data, let type, let headers):
            request.setValue(type, forHTTPHeaderField: "Content-Type")
            headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
            request.httpBody = data
            request.timeoutInterval = 300
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

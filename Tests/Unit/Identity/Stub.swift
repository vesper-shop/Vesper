import Foundation
import Synchronization

/// Answers every request to the token endpoint with `Stub.state`, after a delay long enough
/// for concurrent callers to overlap, and counts the requests.
final class Stub: URLProtocol {
    static let state = Mutex((requests: 0, status: 200, body: Data()))

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host() == "noted-this.date"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let (status, body) = Self.state.withLock { state in
            state.requests += 1
            return (state.status, state.body)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [self] in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client!.urlProtocol(self, didLoad: body)
            client!.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}


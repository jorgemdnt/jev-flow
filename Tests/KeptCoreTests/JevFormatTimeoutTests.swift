import Foundation
import Testing
@testable import Kept

@Test func stalledJevTransportFallsBackWithinTheTotalBudget() async {
    let started = ContinuousClock.now
    let outcome = await JevFormat.prepare(raw: "ship RT", dictionary: ["Artie"], key: "test-key") { request in
        #expect(request.timeoutInterval == 1.5)
        try await Task.sleep(for: .seconds(5))
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    let elapsed = Int((ContinuousClock.now - started) / .milliseconds(1))
    print("Jev stalled transport fallback: \(elapsed) ms")
    #expect(outcome == .local("Ship Artie.", note: "Formatting failed. Inserted local text."))
    #expect(elapsed >= 1200 && elapsed < 2500)
}

@Test func retryWaitCannotExceedTheTotalBudget() async {
    let started = ContinuousClock.now
    let outcome = await JevFormat.prepare(raw: "nao", dictionary: [], key: "test-key") { request in
        try await Task.sleep(for: .milliseconds(300))
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "1.5"])!)
    }
    let elapsed = Int((ContinuousClock.now - started) / .milliseconds(1))
    print("Jev retry budget fallback: \(elapsed) ms")
    #expect(outcome == .local("Não.", note: "Formatting failed. Inserted local text."))
    #expect(elapsed >= 1200 && elapsed < 2500)
}

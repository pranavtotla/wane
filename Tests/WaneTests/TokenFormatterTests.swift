import XCTest
@testable import Wane

final class TokenFormatterTests: XCTestCase {
    func testCompactSubThousand() {
        XCTAssertEqual(TokenFormatter.compact(0), "0")
        XCTAssertEqual(TokenFormatter.compact(1), "1")
        XCTAssertEqual(TokenFormatter.compact(847), "847")
        XCTAssertEqual(TokenFormatter.compact(999), "999")
    }

    func testExactFormat() {
        XCTAssertEqual(TokenFormatter.exact(31_506), "31,506")
        XCTAssertEqual(TokenFormatter.exact(1_247), "1,247")
        XCTAssertEqual(TokenFormatter.exact(0), "0")
    }

    func testCompactThousandsAndMillionsAndBillions() {
        XCTAssertEqual(TokenFormatter.compact(1_000), "1K")
        XCTAssertEqual(TokenFormatter.compact(1_247), "1.2K")
        XCTAssertEqual(TokenFormatter.compact(8_432), "8.4K")
        XCTAssertEqual(TokenFormatter.compact(31_506), "31.5K")
        XCTAssertEqual(TokenFormatter.compact(312_000), "312K")
        XCTAssertEqual(TokenFormatter.compact(999_999), "1M")

        XCTAssertEqual(TokenFormatter.compact(1_000_000), "1M")
        XCTAssertEqual(TokenFormatter.compact(1_200_000), "1.2M")
        XCTAssertEqual(TokenFormatter.compact(84_300_000), "84.3M")

        XCTAssertEqual(TokenFormatter.compact(1_000_000_000), "1B")
        XCTAssertEqual(TokenFormatter.compact(1_200_000_000), "1.2B")
        XCTAssertEqual(TokenFormatter.compact(4_600_000_000), "4.6B")
    }
}

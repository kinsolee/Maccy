import XCTest
import SwiftUI
import Defaults
@testable import Maccy

class SearchTests: XCTestCase {
  let savedSearchMode = Defaults[.searchMode]
  var items: [Search.Searchable]!

  override func setUpWithError() throws {
    try XCTSkipUnless(AppDelegate.isUnitTesting, "Requires isolated test preferences and storage.")
  }

  override func tearDown() {
    super.tearDown()
    Defaults[.searchMode] = savedSearchMode
  }

  @MainActor
  func testSimpleSearch() { // swiftlint:disable:this function_body_length
    Defaults[.searchMode] = Search.Mode.exact
    items = [
      HistoryItemDecorator(historyItemWithTitle("foo bar baz")),
      HistoryItemDecorator(historyItemWithTitle("foo bar zaz")),
      HistoryItemDecorator(historyItemWithTitle("xxx yyy zzz"))
    ]

    XCTAssertEqual(search(""), [
      Search.SearchResult(score: nil, object: items[0], ranges: []),
      Search.SearchResult(score: nil, object: items[1], ranges: []),
      Search.SearchResult(score: nil, object: items[2], ranges: [])
    ])
    XCTAssertEqual(search("z"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 10, to: 10, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 8, to: 8, in: items[1])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 8, to: 8, in: items[2])]
      )
    ])
    XCTAssertEqual(search("foo"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 0, to: 2, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 0, to: 2, in: items[1])]
      )
    ])
    XCTAssertEqual(search("za"), [
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 8, to: 9, in: items[1])]
      )
    ])
    XCTAssertEqual(search("yyy"), [
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 4, to: 6, in: items[2])]
      )
    ])
    XCTAssertEqual(search("fbb"), [])
    XCTAssertEqual(search("m"), [])
  }

  @MainActor
  func testFuzzySearch() { // swiftlint:disable:this function_body_length
    Defaults[.searchMode] = Search.Mode.fuzzy
    items = [
      HistoryItemDecorator(historyItemWithTitle("foo bar baz")),
      HistoryItemDecorator(historyItemWithTitle("foo bar zaz")),
      HistoryItemDecorator(historyItemWithTitle("xxx yyy zzz"))
    ]

    XCTAssertEqual(search(""), [
      Search.SearchResult(score: nil, object: items[0], ranges: []),
      Search.SearchResult(score: nil, object: items[1], ranges: []),
      Search.SearchResult(score: nil, object: items[2], ranges: [])
    ])
    XCTAssertEqual(search("z"), [
      Search.SearchResult(
        score: 0.08,
        object: items[1],
        ranges: [range(from: 8, to: 8, in: items[1]), range(from: 10, to: 10, in: items[1])]
      ),
      Search.SearchResult(
        score: 0.08,
        object: items[2],
        ranges: [range(from: 8, to: 10, in: items[2])]
      ),
      Search.SearchResult(
        score: 0.1,
        object: items[0],
        ranges: [range(from: 10, to: 10, in: items[0])]
      )
    ])
    XCTAssertEqual(search("foo"), [
      Search.SearchResult(
        score: 0.0,
        object: items[0],
        ranges: [range(from: 0, to: 2, in: items[0])]
      ),
      Search.SearchResult(
        score: 0.0,
        object: items[1],
        ranges: [range(from: 0, to: 2, in: items[1])]
      )
    ])
    XCTAssertEqual(search("za"), [
      Search.SearchResult(
        score: 0.08,
        object: items[1],
        ranges: [range(from: 5, to: 5, in: items[1]), range(from: 8, to: 9, in: items[1])]
      ),
      Search.SearchResult(
        score: 0.54,
        object: items[0],
        ranges: [range(from: 5, to: 5, in: items[0]), range(from: 9, to: 10, in: items[0])]
      ),
      Search.SearchResult(
        score: 0.58,
        object: items[2],
        ranges: [range(from: 8, to: 10, in: items[2])]
      )
    ])
    XCTAssertEqual(search("yyy"), [
      Search.SearchResult(
        score: 0.04,
        object: items[2],
        ranges: [range(from: 4, to: 6, in: items[2])]
      )
    ])
    XCTAssertEqual(search("fbb"), [
      Search.SearchResult(
        score: 0.6666666666666666,
        object: items[0],
        ranges: [
          range(from: 0, to: 0, in: items[0]),
          range(from: 4, to: 4, in: items[0]),
          range(from: 8, to: 8, in: items[0])
        ]
      ),
      Search.SearchResult(
        score: 0.6666666666666666,
        object: items[1],
        ranges: [range(from: 0, to: 0, in: items[1]), range(from: 4, to: 4, in: items[1])])
    ])
    XCTAssertEqual(search("m"), [])
  }

  @MainActor
  func testRegexpSearch() { // swiftlint:disable:this function_body_length
    Defaults[.searchMode] = Search.Mode.regexp
    items = [
      HistoryItemDecorator(historyItemWithTitle("foo bar baz")),
      HistoryItemDecorator(historyItemWithTitle("foo bar zaz")),
      HistoryItemDecorator(historyItemWithTitle("xxx yyy zzz"))
    ]

    XCTAssertEqual(search(""), [
      Search.SearchResult(score: nil, object: items[0], ranges: []),
      Search.SearchResult(score: nil, object: items[1], ranges: []),
      Search.SearchResult(score: nil, object: items[2], ranges: [])
    ])
    XCTAssertEqual(search("z+"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 10, to: 10, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 8, to: 8, in: items[1])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 8, to: 10, in: items[2])]
      )
    ])
    XCTAssertEqual(search("z*"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 0, to: -1, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 0, to: -1, in: items[1])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 0, to: -1, in: items[2])]
      )
    ])
    XCTAssertEqual(search("^foo"), [
      Search.SearchResult(
        score: nil,
        object: items[0], ranges: [range(from: 0, to: 2, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1], ranges: [range(from: 0, to: 2, in: items[1])]
      )
    ])
    XCTAssertEqual(search(" za"), [
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 7, to: 9, in: items[1])]
      )
    ])
    XCTAssertEqual(search("[y]+"), [
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 4, to: 6, in: items[2])]
      )
    ])
    XCTAssertEqual(search("fbb"), [])
    XCTAssertEqual(search("m"), [])
  }

  @MainActor
  func testFullBodyBeyondAllFormerLimitsAndFuzzyTailTypo() throws {
    let body = String(repeating: "x", count: 11_000) + "\nneedle-订单"
    let item = HistoryItemDecorator(historyItemWithTitle(body))
    XCTAssertLessThan(item.title.count, body.count)
    for mode in Search.Mode.allCases {
      Defaults[.searchMode] = mode
      let result = try XCTUnwrap(Search().search(string: "needle", within: [item]).first, "\(mode)")
      XCTAssertEqual(result.text, body)
      XCTAssertTrue(String(result.match.summary.characters).contains("needle"))
      XCTAssertTrue(result.match.summary.runs.contains { $0.font != nil })
    }
    Defaults[.searchMode] = .fuzzy
    XCTAssertNotNil(Search().search(string: "neadle", within: [item]).first)
  }

  @MainActor
  func testFuzzyFindsLateShortBodyAndPrefersPreciseBodyOverAlias() throws {
    Defaults[.searchMode] = .fuzzy
    let short = HistoryItemDecorator(historyItemWithTitle(String(repeating: "x", count: 200) + "needle"))
    XCTAssertNotNil(Search().search(string: "needle", within: [short]).first)
    let body = String(repeating: "e", count: 11_000) + "needle"
    let model = historyItemWithTitle(body)
    model.title = "neadle"
    let item = HistoryItemDecorator(model)
    let exact = try XCTUnwrap(Search().search(string: "needle", within: [item]).first)
    XCTAssertEqual(exact.text, body)
    XCTAssertTrue(String(exact.match.summary.characters).contains("needle"))
    let approximate = try XCTUnwrap(Search().match("neadle", in: body, mode: .fuzzy))
    XCTAssertTrue(String(approximate.summary.characters).contains("needle"))
  }

  @MainActor
  func testAliasAndOCRTitleRemainSearchableAlongsideBody() throws {
    let model = historyItemWithTitle("full raw body")
    model.title = "saved alias OCR"
    let item = HistoryItemDecorator(model)
    Defaults[.searchMode] = .exact
    XCTAssertEqual(Search().search(string: "alias", within: [item]).first?.text, "saved alias OCR")
    XCTAssertEqual(Search().search(string: "raw", within: [item]).first?.text, "full raw body")
    let result = try XCTUnwrap(Search().search(string: "alias", within: [item]).first)
    item.title = "changed since the search"
    item.highlight("alias", result.ranges, text: result.text)
    XCTAssertTrue(String(try XCTUnwrap(item.attributedTitle).characters).contains("alias"))
    item.highlight("", [], text: result.text)
    XCTAssertNil(item.attributedTitle)
  }

  func testUnicodeSnapshotAndSummaryUseTheSameIndexSpace() throws {
    let body = String(repeating: "长文", count: 6_000) + " \u{FFFC}\u{301} İ 👩🏽‍💻 e\u{301} fim"
    let search = Search()
    for mode in [Search.Mode.exact, .regexp, .mixed, .fuzzy] {
      let result = try XCTUnwrap(search.match("👩🏽‍💻 e\u{301}", in: body, mode: mode))
      XCTAssertFalse(result.text.containsScalarsUnsafeForTitleLayout)
      XCTAssertTrue(String(result.summary.characters).contains("👩🏽‍💻 e\u{301}"))
      for range in result.ranges { XCTAssertFalse(result.text[range].isEmpty) }
    }
    let uppercase = try XCTUnwrap(search.match("i\u{307}", in: "İ", mode: .fuzzy))
    XCTAssertEqual(String(uppercase.text[try XCTUnwrap(uppercase.ranges.first)]), "İ")
  }

  func testMultilineSummaryKeepsNeedleVisibleAndHighlightsOriginalUnicodeSpan() throws {
    let body = "第一行\r\n尾部\u{2028}👩🏽‍💻 e\u{301} NEEDLE"
    let result = try XCTUnwrap(Search().match("👩🏽‍💻 e\u{301} NEEDLE", in: body, mode: .exact))
    let summary = result.summary
    XCTAssertEqual(result.text, body)
    XCTAssertFalse(String(summary.characters).unicodeScalars.contains(where: CharacterSet.newlines.contains))
    XCTAssertTrue(String(summary.characters).contains("👩🏽‍💻 e\u{301} NEEDLE"))
    let highlighted = summary.runs.filter { $0.font != nil || $0.backgroundColor != nil || $0.underlineStyle != nil }
      .map { String(summary[$0.range].characters) }.joined()
    XCTAssertEqual(highlighted, "👩🏽‍💻 e\u{301} NEEDLE")
  }

  private func search(_ string: String) -> [Search.SearchResult] {
    return Search().search(string: string, within: items)
  }

  // swiftlint:disable:next identifier_name
  private func range(from: Int, to: Int, in item: HistoryItemDecorator) -> Range<String.Index> {
    let startIndex = item.title.startIndex
    let lowerBound = item.title.index(startIndex, offsetBy: from)
    let upperBound = item.title.index(startIndex, offsetBy: to + 1)

    return lowerBound..<upperBound
  }

  @MainActor
  private func historyItemWithTitle(_ value: String?) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value?.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.title = item.generateTitle()

    return item
  }
}

import AppKit
import Defaults
import Fuse

class Search {
  enum Mode: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
    case exact
    case fuzzy
    case regexp
    case mixed

    var id: Self { self }

    var description: String {
      switch self {
      case .exact:
        return NSLocalizedString("Exact", tableName: "GeneralSettings", comment: "")
      case .fuzzy:
        return NSLocalizedString("Fuzzy", tableName: "GeneralSettings", comment: "")
      case .regexp:
        return NSLocalizedString("Regex", tableName: "GeneralSettings", comment: "")
      case .mixed:
        return NSLocalizedString("Mixed", tableName: "GeneralSettings", comment: "")
      }
    }
  }

  struct Match: Equatable {
    let text: String
    var score: Double?
    var ranges: [Range<String.Index>] = []

    // Slice and highlight the same immutable snapshot. Raw contents remain untouched.
    var summary: AttributedString {
      let anchor = ranges.first(where: { !$0.isEmpty })?.lowerBound ?? text.startIndex
      let start = text.index(anchor, offsetBy: -12, limitedBy: text.startIndex) ?? text.startIndex
      let end = text.index(start, offsetBy: 220, limitedBy: text.endIndex) ?? text.endIndex
      let prefix = start == text.startIndex ? "" : "…"
      // Preserve UTF-16 offsets while keeping the matching text visible in a one-line row.
      let excerpt = String(String.UnicodeScalarView(text[start..<end].unicodeScalars.map {
        CharacterSet.newlines.contains($0) ? Unicode.Scalar(32)! : $0
      }))
      let displayed = prefix + excerpt + (end == text.endIndex ? "" : "…")
      var result = AttributedString(displayed)
      for range in ranges {
        let lower = max(start, range.lowerBound)
        let upper = min(end, range.upperBound)
        guard lower < upper else { continue }
        // UTF-16 offsets also cover regex matches within a grapheme cluster.
        let offset = prefix.utf16.count + text[start..<lower].utf16.count
        let length = text[lower..<upper].utf16.count
        guard let remapped = Range(NSRange(location: offset, length: length), in: displayed),
              let from = AttributedString.Index(remapped.lowerBound, within: result),
              let to = AttributedString.Index(remapped.upperBound, within: result) else { continue }
        switch Defaults[.highlightMatch] {
        case .bold: result[from..<to].font = .bold(.body)()
        case .italic: result[from..<to].font = .italic(.body)()
        case .underline: result[from..<to].underlineStyle = .single
        default:
          result[from..<to].backgroundColor = .findHighlightColor
          result[from..<to].foregroundColor = .black
        }
      }
      return result
    }
  }

  struct SearchResult: Equatable {
    var score: Double?
    var object: Searchable
    var ranges: [Range<String.Index>]
    let text: String

    init(score: Double? = nil, object: Searchable, ranges: [Range<String.Index>] = [], text: String? = nil) {
      self.score = score
      self.object = object
      self.ranges = ranges
      self.text = text ?? object.title
    }

    var match: Match { Match(text: text, score: score, ranges: ranges) }
  }

  typealias Searchable = HistoryItemDecorator

  func search(string: String, within: [Searchable]) -> [SearchResult] {
    guard !string.isEmpty else { return within.map { SearchResult(object: $0) } }
    let modes: [Mode] = Defaults[.searchMode] == .mixed ? [.exact, .regexp, .fuzzy] : [Defaults[.searchMode]]
    for mode in modes {
      var results: [SearchResult] = within.compactMap { item in
        // Keep aliases and existing OCR. The body comes from the model, never decorator.text.
        let title = item.title
        let body = item.item.previewableText
        let titleMatch = match(string, in: title, mode: mode, fullText: title.count > 100)
        let bodyMatch = body == title ? nil : match(string, in: body, mode: mode)
        let found: Match?
        if mode == .fuzzy, let titleMatch, let bodyMatch {
          found = (bodyMatch.score ?? 1) < (titleMatch.score ?? 1) ? bodyMatch : titleMatch
        } else { found = titleMatch ?? bodyMatch }
        guard let found else { return nil }
        return SearchResult(score: found.score, object: item, ranges: found.ranges, text: found.text)
      }
      if mode == .fuzzy { results.sort { ($0.score ?? 0) < ($1.score ?? 0) } }
      if !results.isEmpty { return results }
    }
    return []
  }

  func match(_ query: String, in source: String, mode: Mode = Defaults[.searchMode],
             fullText: Bool = true) -> Match? {
    let text = source.removingScalarsUnsafeForTitleLayout()
    if query.isEmpty { return Match(text: text) }
    if mode == .mixed {
      return match(query, in: text, mode: .exact, fullText: fullText)
        ?? match(query, in: text, mode: .regexp, fullText: fullText)
        ?? match(query, in: text, mode: .fuzzy, fullText: fullText)
    }
    if mode != .fuzzy {
      let options: String.CompareOptions = mode == .regexp ? .regularExpression : .caseInsensitive
      guard let range = text.range(of: query, options: options) else { return nil }
      return Match(text: text, ranges: [range])
    }

    // Fuse works with Character offsets in lowercase text. Map those offsets explicitly.
    var normalized = ""
    var originalRanges: [Range<String.Index>] = []
    for index in text.indices {
      let next = text.index(after: index)
      let lowercased = String(text[index..<next]).lowercased()
      normalized += lowercased
      originalRanges.append(contentsOf: Array(repeating: index..<next, count: lowercased.count))
    }
    let needle = query.lowercased()
    // Fuse's bit mask is one machine word; longer queries use an exact full-text match.
    guard needle.count < Int.bitWidth else {
      return match(query, in: text, mode: .exact, fullText: fullText)
    }
    guard normalized.count == originalRanges.count else { return nil }
    if fullText {
      if let exact = text.range(of: query, options: .caseInsensitive) {
        return Match(text: text, score: 0, ranges: [exact])
      }
      return fuzzySubstring(Array(needle), in: Array(normalized), original: text, mapping: originalRanges)
    }
    let fuse = Fuse(threshold: 0.7, isCaseSensitive: true)
    guard let result = fuse.search(fuse.createPattern(from: needle), in: normalized) else { return nil }
    let ranges = result.ranges.compactMap { range -> Range<String.Index>? in
      guard range.lowerBound >= 0, range.upperBound < originalRanges.count else { return nil }
      return originalRanges[range.lowerBound].lowerBound..<originalRanges[range.upperBound].upperBound
    }
    return Match(text: text, score: result.score, ranges: ranges)
  }

  // Fuse's match mask includes unrelated letters anywhere in the input; it is not a matching span.
  // For full bodies, track the best substring while computing edit distance so its highlight is local.
  // ponytail: O(body * query), query bounded below one machine word; index only if measured latency needs it.
  private func fuzzySubstring(_ query: [Character], in text: [Character], original: String,
                              mapping: [Range<String.Index>]) -> Match? {
    guard !query.isEmpty, !text.isEmpty else { return nil }
    var previous = Array(0...query.count)
    var starts = Array(repeating: 0, count: query.count + 1)
    var bestDistance = Int.max
    var bestSpan: Range<Int>?
    for (index, character) in text.enumerated() {
      var current = Array(repeating: 0, count: query.count + 1)
      var nextStarts = Array(repeating: index + 1, count: query.count + 1)
      for position in 1...query.count {
        var distance = previous[position - 1] + (character == query[position - 1] ? 0 : 1)
        var start = starts[position - 1]
        if previous[position] + 1 < distance { distance = previous[position] + 1; start = starts[position] }
        if current[position - 1] + 1 < distance { distance = current[position - 1] + 1; start = nextStarts[position - 1] }
        current[position] = distance
        nextStarts[position] = start
      }
      if current[query.count] < bestDistance, nextStarts[query.count] <= index {
        bestDistance = current[query.count]
        bestSpan = nextStarts[query.count]..<(index + 1)
      }
      previous = current
      starts = nextStarts
    }
    let score = Double(bestDistance) / Double(query.count)
    guard score <= 0.7, let span = bestSpan else { return nil }
    return Match(text: original, score: score,
                 ranges: [mapping[span.lowerBound].lowerBound..<mapping[span.upperBound - 1].upperBound])

  }
}

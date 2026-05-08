import Foundation
import UIKit

class CSSParser {
    static let shared = CSSParser()
    
    struct CSSStyle {
        var properties: [String: String] = [:]
        var selectors: [String] = []
    }
    
    struct ParsedCSS {
        var rules: [CSSRule] = []
        var mediaRules: [CSSMediaRule] = []
    }
    
    struct CSSRule {
        var selector: String
        var declarations: [CSSDeclaration]
    }
    
    struct CSSDeclaration {
        var property: String
        var value: String
        var important: Bool = false
    }
    
    struct CSSMediaRule {
        var condition: String
        var rules: [CSSRule]
    }
    
    func parse(_ css: String) -> ParsedCSS {
        var parsed = ParsedCSS()
        var cssContent = css
        
        cssContent = removeComments(cssContent)
        
        cssContent = parseMediaQueries(cssContent, into: &parsed)
        
        let ruleStrings = splitIntoRules(cssContent)
        
        for ruleString in ruleStrings {
            if let rule = parseRule(ruleString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                parsed.rules.append(rule)
            }
        }
        
        return parsed
    }
    
    private func removeComments(_ css: String) -> String {
        var result = css
        while let startRange = result.range(of: "/*") {
            if let endRange = result.range(of: "*/", range: startRange.upperBound..<result.endIndex) {
                result.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            } else {
                break
            }
        }
        return result
    }
    
    private func parseMediaQueries(_ css: String, into parsed: inout ParsedCSS) -> String {
        var result = css
        let mediaPattern = "@media[^@]*\\{([\\s\\S]*?)\\}"
        
        guard let regex = try? NSRegularExpression(pattern: mediaPattern, options: []) else {
            return result
        }
        
        let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
        
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let conditionRange = Range(match.range(at: 1), in: result),
                  let contentRange = Range(match.range(at: 2), in: result) else {
                continue
            }
            
            let condition = String(result[conditionRange])
            let content = String(result[contentRange])
            
            var mediaRule = CSSMediaRule(condition: condition, rules: [])
            let ruleStrings = splitIntoRules(content)
            
            for ruleString in ruleStrings {
                if let rule = parseRule(ruleString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    mediaRule.rules.append(rule)
                }
            }
            
            parsed.mediaRules.append(mediaRule)
            result.removeSubrange(fullRange)
        }
        
        return result
    }
    
    private func splitIntoRules(_ css: String) -> [String] {
        var rules: [String] = []
        var currentRule = ""
        var braceCount = 0
        var inString = false
        var stringChar: Character = "\""
        
        for char in css {
            if !inString && (char == "\"" || char == "'") {
                inString = true
                stringChar = char
            } else if inString && char == stringChar {
                inString = false
            }
            
            if !inString {
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                }
            }
            
            currentRule.append(char)
            
            if !inString && braceCount == 0 && char == "}" {
                rules.append(currentRule)
                currentRule = ""
            }
        }
        
        if !currentRule.isEmpty {
            rules.append(currentRule)
        }
        
        return rules
    }
    
    private func parseRule(_ ruleString: String) -> CSSRule? {
        guard let openBraceIndex = ruleString.firstIndex(of: "{") else {
            return nil
        }
        
        let selector = String(ruleString[..<openBraceIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let declarationsString = String(ruleString[ruleString.index(after: openBraceIndex)...])
        
        guard let closeBraceIndex = declarationsString.lastIndex(of: "}") else {
            return nil
        }
        
        let declarationsContent = String(declarationsString[..<closeBraceIndex])
        let declarations = parseDeclarations(declarationsContent)
        
        return CSSRule(selector: selector, declarations: declarations)
    }
    
    private func parseDeclarations(_ declarationsString: String) -> [CSSDeclaration] {
        var declarations: [CSSDeclaration] = []
        let propertyStrings = declarationsString.components(separatedBy: ";")
        
        for propString in propertyStrings {
            let trimmed = propString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            
            guard parts.count == 2 else { continue }
            
            var value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            var important = false
            
            if value.lowercased().contains("!important") {
                important = true
                value = value.replacingOccurrences(of: "!important", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            let property = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            declarations.append(CSSDeclaration(property: property, value: value, important: important))
        }
        
        return declarations
    }
    
    func mergeCSS(_ css1: String, _ css2: String) -> String {
        return css1 + "\n" + css2
    }
}

class CSSStyleEngine {
    static let shared = CSSStyleEngine()
    
    private var styleCache: [String: [String: String]] = [:]
    
    func computeStyle(for element: XHTMLElement, stylesheets: [CSSParser.ParsedCSS], parentStyle: [String: String]? = nil) -> [String: String] {
        let cacheKey = "\(element.tagName)_\(element.classes.joined())_\(element.id ?? "")"
        
        if let cached = styleCache[cacheKey] {
            return mergeWithParent(cached, parent: parentStyle)
        }
        
        var computedStyle: [String: String] = parentStyle ?? defaultStyles()
        
        for stylesheet in stylesheets {
            for rule in stylesheet.rules {
                if matchesSelector(element, selector: rule.selector) {
                    for declaration in rule.declarations {
                        if declaration.important || !computedStyle.keys.contains(declaration.property) {
                            computedStyle[declaration.property] = declaration.value
                        }
                    }
                }
            }
        }
        
        for (key, value) in element.inlineStyles {
            computedStyle[key] = value
        }
        
        styleCache[cacheKey] = computedStyle
        
        return computedStyle
    }
    
    private func matchesSelector(_ element: XHTMLElement, selector: String) -> Bool {
        let selectors = selector.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for sel in selectors {
            if matchSingleSelector(element, selector: sel) {
                return true
            }
        }
        
        return false
    }
    
    private func matchSingleSelector(_ element: XHTMLElement, selector: String) -> Bool {
        var current = selector
        var negation = false
        
        if current.hasPrefix(":not(") && current.hasSuffix(")") {
            negation = true
            current = String(current.dropFirst(5).dropLast(1))
        }
        
        let result = matchSelectorPart(element, selector: current)
        return negation ? !result : result
    }
    
    private func matchSelectorPart(_ element: XHTMLElement, selector: String) -> Bool {
        var tagMatched = true
        var idMatched = true
        var classMatched = true
        
        var remainingSelector = selector
        
        if let idRange = selector.range(of: "#") {
            let beforeId = String(selector[..<idRange.lowerBound])
            let afterId = String(selector[idRange.upperBound...])
            
            if !beforeId.isEmpty {
                tagMatched = matchesTag(element.tagName, pattern: beforeId)
            }
            
            if let spaceRange = afterId.range(of: " ") {
                let elementId = String(afterId[..<spaceRange.lowerBound])
                idMatched = element.id == elementId
            } else {
                idMatched = element.id == afterId
            }
        }
        
        let classPatterns = selector.components(separatedBy: ".").filter { !$0.isEmpty }
        if classPatterns.count > 1 {
            let tagClass = classPatterns[0]
            if !tagClass.isEmpty && tagClass != "*" {
                tagMatched = matchesTag(element.tagName, pattern: tagClass)
            }
            
            for i in 1..<classPatterns.count {
                let className = classPatterns[i]
                classMatched = classMatched && element.classes.contains(className)
            }
        }
        
        if selector.contains(".") && !selector.contains("#") {
            let parts = selector.split(separator: ".")
            if let first = parts.first, !first.isEmpty && first != "*" {
                tagMatched = matchesTag(element.tagName, pattern: String(first))
            }
            if let lastPart = parts.last {
                classMatched = element.classes.contains(String(lastPart))
            }
        }
        
        if !selector.contains("#") && !selector.contains(".") {
            tagMatched = matchesTag(element.tagName, pattern: selector)
        }
        
        return tagMatched && idMatched && classMatched
    }
    
    private func matchesTag(_ tagName: String, pattern: String) -> Bool {
        let normalizedTag = tagName.lowercased()
        let normalizedPattern = pattern.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if normalizedPattern == "*" {
            return true
        }
        
        return normalizedTag == normalizedPattern
    }
    
    private func mergeWithParent(_ child: [String: String], parent: [String: String]?) -> [String: String] {
        guard let parent = parent else { return child }
        
        var merged = parent
        for (key, value) in child {
            merged[key] = value
        }
        return merged
    }
    
    private func defaultStyles() -> [String: String] {
        return [
            "display": "inline",
            "font-size": "16px",
            "font-family": "serif",
            "color": "black",
            "background-color": "transparent",
            "line-height": "1.5",
            "text-align": "left",
            "margin-top": "0",
            "margin-right": "0",
            "margin-bottom": "0",
            "margin-left": "0",
            "padding-top": "0",
            "padding-right": "0",
            "padding-bottom": "0",
            "padding-left": "0",
            "border-top-width": "0",
            "border-right-width": "0",
            "border-bottom-width": "0",
            "border-left-width": "0",
            "border-top-style": "none",
            "border-right-style": "none",
            "border-bottom-style": "none",
            "border-left-style": "none",
            "font-weight": "normal",
            "font-style": "normal",
            "text-decoration": "none",
            "vertical-align": "baseline",
            "width": "auto",
            "height": "auto",
            "max-width": "none",
            "max-height": "none"
        ]
    }
    
    func clearCache() {
        styleCache.removeAll()
    }
}

struct XHTMLElement {
    var tagName: String
    var id: String?
    var classes: [String] = []
    var inlineStyles: [String: String] = [:]
    var attributes: [String: String] = [:]
    var children: [XHTMLElement] = []
    var textContent: String = ""
    
    init(tagName: String) {
        self.tagName = tagName.lowercased()
    }
    
    func getAttribute(_ name: String) -> String? {
        return attributes[name]
    }
    
    mutating func setAttribute(_ name: String, value: String) {
        attributes[name] = value
    }
}

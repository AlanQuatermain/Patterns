//
//  GrammarTests.swift
//
//
//  Created by Kåre Morstøl on 27/05/2020.
//

import Patterns
import XCTest

class GrammarTests: XCTestCase {
	let grammar1: Grammar = {
		let g = Grammar()
		g.letter <- Capture(letter)
		g.space <- whitespace
		return g
	}()

	func testNamesAnonymousCaptures() {
		XCTAssertEqual((grammar1.patterns["letter"]?.wrapped as? Capture<OneOf>)?.name, "letter")
	}

	func testSetsFirstPattern() {
		XCTAssertEqual(grammar1.firstPattern, "letter")
	}

	func testDirectRecursion() throws {
		let g1 = Grammar()
		g1.a <- "a" / any • g1.a
		assertParseAll(g1, input: " aa", count: 2)

		let g2 = Grammar()
		g2.balancedParentheses <- "(" • (!OneOf("()") • any / g2.balancedParentheses)* • ")"
		assertParseAll(g2, input: "( )", count: 1)
		assertParseAll(g2, input: "((( )( )))", count: 1)
		assertParseAll(g2, input: "(( )", count: 0)

	}
}

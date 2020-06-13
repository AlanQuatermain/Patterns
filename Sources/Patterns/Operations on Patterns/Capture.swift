//
//  Capture.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct Capture<Wrapped: Pattern>: Pattern {
	public var description: String {
		let result: String
		switch (name, wrapped) {
		case (nil, nil):
			result = ""
		case let (name?, wrapped?):
			result = "name: \(name), \(wrapped)"
		case let (name?, nil):
			result = "name: \(name)"
		case let (nil, wrapped?):
			result = wrapped.description
		}
		return "Capture(\(result))"
	}

	public let name: String?
	public let wrapped: Wrapped?

	public init(name: String? = nil, _ pattern: Wrapped) {
		self.wrapped = pattern
		self.name = name
	}

	public func createInstructions(_ instructions: inout Instructions) throws {
		instructions.append(.captureStart(name: name))
		try wrapped?.createInstructions(&instructions)
		instructions.append(.captureEnd)
	}

	public struct Start: Pattern {
		public var description: String { "[" }
		public let name: String?

		public init(name: String? = nil) {
			self.name = name
		}

		public func createInstructions(_ instructions: inout Instructions) {
			instructions.append(.captureStart(name: name))
		}
	}

	public struct End: Pattern {
		public var description: String { "]" }

		public init() {}

		public func createInstructions(_ instructions: inout Instructions) {
			instructions.append(.captureEnd)
		}
	}
}

extension Capture where Wrapped == AnyPattern {
	public init(name: String? = nil) {
		self.wrapped = nil
		self.name = name
	}
}

extension Capture where Wrapped == Literal {
	public init(name: String? = nil, _ patterns: Literal) {
		self.wrapped = patterns
		self.name = name
	}
}

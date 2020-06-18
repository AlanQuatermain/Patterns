//
//  VMBacktrack.swift
//
//
//  Created by Kåre Morstøl on 18/04/2020.
//

// TODO: struct?
public class VMBacktrackEngine<Input: BidirectionalCollection> where Input.Element: Hashable {
	public typealias Instructions = ContiguousArray<Instruction<Input>>
	let instructions: Instructions

	@usableFromInline
	required init<P: Pattern>(_ pattern: P) throws where Input == P.Input {
		var instructions = (try pattern.createInstructions() + [Instruction<Input>.match])
		Self.moveMovablesForward(instructions: &instructions)
		Self.replaceSkips(instructions: &instructions)
		self.instructions = instructions
	}

	@usableFromInline
	func match(in input: Input, from startIndex: Input.Index) -> Parser<Input>.Match? {
		VMBacktrackEngine<Input>.backtrackingVM(instructions, input: input, startIndex: startIndex)
	}
}

extension Parser.Match {
	init(_ thread: VMBacktrackEngine<Input>.Thread, instructions: VMBacktrackEngine<Input>.Instructions) {
		var captures = [(name: String?, range: Range<Input.Index>)]()
		captures.reserveCapacity(thread.captures.count / 2)
		var captureBeginnings = [(name: String?, start: Input.Index)]()
		captureBeginnings.reserveCapacity(captures.capacity)
		for capture in thread.captures {
			switch instructions[capture.instruction] {
			case let .captureStart(name, _):
				captureBeginnings.append((name, capture.index))
			case .captureEnd:
				let beginning = captureBeginnings.removeLast()
				captures.append((name: beginning.name, range: beginning.start ..< capture.index))
			default:
				fatalError("Captured wrong instructions.")
			}
		}
		assert(captureBeginnings.isEmpty)
		self.endIndex = thread.inputIndex
		self.captures = captures
	}
}

extension VMBacktrackEngine {
	// TODO: private
	public struct Thread {
		var instructionIndex: Instructions.Index
		var inputIndex: Input.Index
		var captures: ContiguousArray<(index: Input.Index, instruction: Instructions.Index)>
		var isReturnAddress: Bool = false

		init(startAt instructionIndex: Int, withDataFrom other: Thread) {
			self.instructionIndex = instructionIndex
			self.inputIndex = other.inputIndex
			self.captures = other.captures
		}

		init(instructionIndex: Instructions.Index, inputIndex: Input.Index) {
			self.instructionIndex = instructionIndex
			self.inputIndex = inputIndex
			self.captures = []
		}
	}

	@usableFromInline
	static func backtrackingVM(_ instructions: Instructions, input: Input, startIndex: Input.Index? = nil) -> Parser<Input>.Match? {
		let thread = Thread(instructionIndex: instructions.startIndex, inputIndex: startIndex ?? input.startIndex)
		return backtrackingVM(instructions, input: input, thread: thread)
			.map { Parser.Match($0, instructions: instructions) }
	}

	// TODO: make nonstatic when Skip has been fixed.
	@usableFromInline
	static func backtrackingVM(_ instructions: Instructions, input: Input, thread: Thread) -> Thread? {
		var stack = ContiguousArray<Thread>()[...]

		stack.append(thread)
		while var thread = stack.popLast() {
			assert(!thread.isReturnAddress, "Stack unexpectedly contains .returnAddress after fail")
			defer { // Fail, when `break loop` is called.
				stack.removeSuffix(where: { $0.isReturnAddress })
			}

			loop: while true {
				switch instructions[thread.instructionIndex] {
				case let .elementEquals(char):
					guard thread.inputIndex != input.endIndex, input[thread.inputIndex] == char else { break loop }
					input.formIndex(after: &thread.inputIndex)
					thread.instructionIndex += 1
				case let .checkElement(test):
					guard thread.inputIndex != input.endIndex, test(input[thread.inputIndex]) else { break loop }
					input.formIndex(after: &thread.inputIndex)
					thread.instructionIndex += 1
				case let .checkIndex(test, offset):
					let index = input.index(thread.inputIndex, offsetBy: offset)
					guard test(input, index) else { break loop }
					thread.instructionIndex += 1
				case let .moveIndex(distance):
					guard input.formIndexSafely(&thread.inputIndex, offsetBy: distance) else { break loop }
					thread.instructionIndex += 1
				case let .function(function):
					guard function(input, &thread) else { break loop }
				case let .jump(distance):
					thread.instructionIndex += distance
				case let .captureStart(_, offset):
					let index = input.index(thread.inputIndex, offsetBy: offset)
					thread.captures.append((index: index, instruction: thread.instructionIndex))
					thread.instructionIndex += 1
				case let .captureEnd(offset):
					let index = input.index(thread.inputIndex, offsetBy: offset)
					thread.captures.append((index: index, instruction: thread.instructionIndex))
					thread.instructionIndex += 1
				case let .choice(offset, atIndex):
					defer { thread.instructionIndex += 1 }
					var newThread = Thread(startAt: thread.instructionIndex + offset, withDataFrom: thread)
					if atIndex != 0 {
						guard input.formIndexSafely(&newThread.inputIndex, offsetBy: atIndex) else { break }
					}
					stack.append(newThread)
				case .choiceEnd:
					thread.instructionIndex += 1
				case .commit:
					let entry = stack.popLast()
					// `.choice` will not add to stack if `input.formIndexSafely` fails, so it might be empty.
					// assert(entry != nil, "Empty stack during .commit")
					// TODO: have  “choice” add a dummy thread that always fails
					assert(entry.map { !$0.isReturnAddress } ?? true, "Missing thread during .cancelLastSplit")
					thread.instructionIndex += 1
				case let .call(offset):
					var returnAddress = thread
					returnAddress.instructionIndex += 1
					returnAddress.isReturnAddress = true
					returnAddress.captures.removeAll()
					stack.append(returnAddress)
					thread.instructionIndex += offset
				case .return:
					guard let entry = stack.popLast() else { fatalError("Missing return address upon .return.") }
					assert(entry.isReturnAddress, "Unexpected uncommited thread in stack.")
					thread.instructionIndex = entry.instructionIndex
				case .fail:
					break loop
				case .match:
					return thread
				case .openCall:
					fatalError("`.openCall` should be removed by Grammar.")
				case .skip:
					fatalError("`.skip` should be removed  by Parser in preprocessing.")
				}
			}
		}
		return nil
	}
}

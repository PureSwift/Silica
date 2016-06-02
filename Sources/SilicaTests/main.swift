//
//  main.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/1/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest

#if os(OSX) || os(iOS) || os(watchOS)
    func XCTMain(_ testCases: [XCTestCaseEntry]) { fatalError("Not Implemented. Linux only") }
    
    func testCase<T: XCTestCase>(_ allTests: [(String, (T) -> () throws -> Void)]) -> XCTestCaseEntry { fatalError("Not Implemented. Linux only") }
    
    struct XCTestCaseEntry { }
#endif

XCTMain([testCase(FontTests.allTests)])

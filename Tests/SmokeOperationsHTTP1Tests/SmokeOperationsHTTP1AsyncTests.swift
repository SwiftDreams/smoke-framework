// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// SmokeOperationsAsyncTests.swift
// SmokeOperationsTests
//

import XCTest
@testable import SmokeOperationsHTTP1
import SmokeOperations
import NIOHTTP1
import SmokeHTTP1

func handleExampleOperationVoidAsync(input: ExampleInput, context: ExampleContext,
                                responseHandler: (Error?) -> ()) throws {
    responseHandler(nil)
}

func handleBadOperationVoidAsync(input: ExampleInput, context: ExampleContext,
                                responseHandler: (Error?) -> ()) throws {
    let error = MyError.theError(reason: "Is bad!")
    
    responseHandler(error)
}

func handleBadOperationVoidAsyncWithThrow(input: ExampleInput, context: ExampleContext,
                                responseHandler: (Error?) -> ()) throws {
    throw MyError.theError(reason: "Is bad!")
}

func handleExampleOperationAsync(input: ExampleInput, context: ExampleContext,
                                 responseHandler: (SmokeResult<OutputAttributes>) -> ()) throws {
    let attributes = OutputAttributes(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                                       isGreat: true)
    
    responseHandler(.response(attributes))
}

func handleBadOperationAsync(input: ExampleInput, context: ExampleContext,
                             responseHandler: (SmokeResult<OutputAttributes>) -> ()) throws {
    let error = MyError.theError(reason: "Is bad!")
    
    responseHandler(.error(error))
}

func handleBadOperationAsyncWithThrow(input: ExampleInput, context: ExampleContext,
                             responseHandler: (SmokeResult<OutputAttributes>) -> ()) throws {
    throw MyError.theError(reason: "Is bad!")
}

fileprivate let handlerSelector: StandardSmokeHTTP1HandlerSelector<ExampleContext, JSONPayloadHTTP1OperationDelegate> = {
    var newHandlerSelector = StandardSmokeHTTP1HandlerSelector<ExampleContext, JSONPayloadHTTP1OperationDelegate>()
    newHandlerSelector.addHandlerForUri("exampleoperation", httpMethod: .POST,
                                        handler: OperationHandler(operation: handleExampleOperationAsync,
                                                                  allowedErrors: allowedErrors))
    
    newHandlerSelector.addHandlerForUri("examplegetoperation", httpMethod: .GET,
                                        handler: OperationHandler(operation: handleExampleOperationAsync,
                                                                  allowedErrors: allowedErrors))
    
    newHandlerSelector.addHandlerForUri("examplenobodyoperation", httpMethod: .POST,
                                        handler: OperationHandler(operation: handleExampleOperationVoidAsync,
                                                                  allowedErrors: allowedErrors))
    
    newHandlerSelector.addHandlerForUri("badoperationvoidresponse", httpMethod: .POST,
                                        handler: OperationHandler(operation: handleBadOperationVoidAsync,
                                                                  allowedErrors: allowedErrors))
    
    newHandlerSelector.addHandlerForUri("badoperationvoidresponsewiththrow", httpMethod: .POST,
                                        handler: OperationHandler(operation: handleBadOperationVoidAsyncWithThrow,
                                                                  allowedErrors: allowedErrors))
    
    newHandlerSelector.addHandlerForUri("badoperation", httpMethod: .POST,
                                        handler: OperationHandler(operation: handleBadOperationAsync,
                                                                  allowedErrors: allowedErrors))
    
    newHandlerSelector.addHandlerForUri("badoperationwiththrow", httpMethod: .POST,
                                        handler: OperationHandler(operation: handleBadOperationAsync,
                                                                  allowedErrors: allowedErrors))
    
    return newHandlerSelector
}()

private func verifyPathOutput(uri: String, body: Data) -> OperationResponse {
    let handler = OperationServerHTTP1RequestHandler(handlerSelector: handlerSelector,
                                                     context: ExampleContext(),
                                                     defaultOperationDelegate: JSONPayloadHTTP1OperationDelegate())
    
    let httpRequestHead = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1),
                                          method: .POST,
                                          uri: uri)
    
    let responseHandler = TestHttpResponseHandler()
    
    handler.handle(requestHead: httpRequestHead, body: body,
                   responseHandler: responseHandler)
    
    return responseHandler.response!
}

private func verifyErrorResponse(uri: String) {
    let response = verifyPathOutput(uri: uri,
                                    body: serializedAlternateInput.data(using: .utf8)!)


    XCTAssertEqual(response.status.code, 400)
    let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                          from: response.body!.data)

    XCTAssertEqual("TheError", output.type)
    XCTAssertEqual("Is bad!", output.reason)
}

class SmokeOperationsAsyncTests: XCTestCase {
    
    func testExampleHandler() {
        let response = verifyPathOutput(uri: "exampleOperation",
                                        body: serializedInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 200)
        let output = try! JSONDecoder.getFrameworkDecoder().decode(OutputAttributes.self,
                                                              from: response.body!.data)
        let expectedOutput = OutputAttributes(bodyColor: .blue, isGreat: true)
        XCTAssertEqual(expectedOutput, output)
    }

    func testExampleVoidHandler() {
        let response = verifyPathOutput(uri: "exampleNoBodyOperation",
                                        body: serializedInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 200)
        XCTAssertNil(response.body)
    }
  
    func testInputValidationError() {
        let response = verifyPathOutput(uri: "exampleOperation",
                                        body: serializedInvalidInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 400)
        let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: response.body!.data)
        
        XCTAssertEqual("ValidationError", output.type)
    }
   
    func testOutputValidationError() {
        let response = verifyPathOutput(uri: "exampleOperation",
                                        body: serializedAlternateInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 500)
        let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: response.body!.data)
        
        XCTAssertEqual("InternalError", output.type)
    }
    
    func testThrownError() {
        verifyErrorResponse(uri: "badOperationVoidResponse")
        verifyErrorResponse(uri: "badOperationVoidResponseWithThrow")
        verifyErrorResponse(uri: "badOperation")
        verifyErrorResponse(uri: "badOperationWithThrow")
    }
    
    func testInvalidOperation() {
        let response = verifyPathOutput(uri: "unknownOperation",
                                        body: serializedAlternateInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 400)
        let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: response.body!.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
    
    func testIncorrectHTTPMethodOperation() {
        let response = verifyPathOutput(uri: "examplegetoperation",
                                        body: serializedAlternateInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 400)
        let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: response.body!.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }

    static var allTests = [
        ("testExampleHandler", testExampleHandler),
        ("testExampleVoidHandler", testExampleVoidHandler),
        ("testInputValidationError", testInputValidationError),
        ("testOutputValidationError", testOutputValidationError),
        ("testThrownError", testThrownError),
        ("testInvalidOperation", testInvalidOperation),
        ("testIncorrectHTTPMethodOperation", testIncorrectHTTPMethodOperation),
    ]
}

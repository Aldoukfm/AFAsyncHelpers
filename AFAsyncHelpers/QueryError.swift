//
//  QueryError.swift
//  GQLControl
//
//  Created by Aldo Fuentes on 2/26/19.
//  Copyright © 2019 aldofuentes. All rights reserved.
//

import Foundation

public enum QueryError: String, Error {
    case nonImplemented
    case noData
    case decodingError
    case nonRequested
    case noURL
    case noOperationQueue
    case unkown
}

extension QueryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .nonImplemented:
            return "Query method \"execute\" non implemented"
        case .noData:
            return "Query returned no data"
        case .decodingError:
            return "Query could not decode result to specified object"
        case .nonRequested:
            return "Query did not fetch any data"
        case .noURL:
            return "Query could not initialize URL"
        case .noOperationQueue:
            return "No OperationQueue set to execute"
        case .unkown:
            return "An unkown error occurred"
        }
    }
}

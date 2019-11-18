//
//  Query.swift
//
//  Created by Aldo Fuentes on 5/25/19.
//  Copyright © 2019 aldofuentes. All rights reserved.
//

import Foundation


public typealias ID = String

public protocol _Query: class {
    associatedtype Value
    
    func execute(completion: @escaping (Result<Value, Error>)->())
    func cancel()
}

extension _Query {
    func execute(completion: (Result<Value, Error>)->()) {
        completion(Result.failure(QueryError.nonImplemented))
    }
    func execute() -> Result<Value, Error> {
        var newResult = Result<Value, Error>.failure(QueryError.nonImplemented)
        let group = DispatchGroup()
        group.enter()
        execute { (result) in
            newResult = result
            group.leave()
        }
        group.wait()
        return newResult
    }
    
}

public protocol QueryObserver: class {
    var observerID: Int { get set }
    func query<Value>(_ query: Query<Value>, didCompleteWith result: Result<Value, Error>)
    func query<Value>(willBeing operation: Query<Value>)
    func query<Value>(didCancel operation: Query<Value>)
}

public extension QueryObserver {
    func query<Value>(willBeing operation: Query<Value>) { }
    func query<Value>(didCancel operation: Query<Value>) { }
}

open class Query<Value>: ObservableOperation2, _Query {
    
    open var queue: OperationQueue?
    
    open var _execution: ( ( ((Result<Value, Error>) -> ())? ) -> ())!
    open var _completion: ((Result<Value, Error>) -> ())?
    open var cancellation: (() -> ())?
    open var _catch: ((Error) -> ())?
    
    public init(query: @escaping ( ( ((Result<Value, Error>) -> ())? ) -> ()) ) {
        _execution = query
    }
    
    public override init() {
        super.init()
        _execution = {[weak self] completion in
            self?.execution(completion: { (result) in
                completion?(result)
            })
        }
    }
    
    public init(error: Error) {
        _execution = { completion in
            completion?(Result.failure(error))
        }
    }
    
    open override func main() {
        observer?.query(willBeing: self)
        _execution {[weak self] (result) in
            guard let self = self else { return }
            if self.isCancelled { return }
            self._completion?(result)
            self.observer?.query(self, didCompleteWith: result)
            self.state = .Finished
        }
    }
    
    public func withID(_ id: ID) -> Query<Value> {
        self.id = id
        return self
    }
    
    open func execution(completion: @escaping (Result<Value, Error>) -> ()) {
        completion(Result.failure(QueryError.nonImplemented))
    }
    
    open func execute(completion: @escaping (Result<Value, Error>) -> ()) {
        self._completion = completion
        let queue = self.queue ?? OperationQueue.default
        queue.addOperation(self)
    }
    
    public func execute() {
        let queue = self.queue ?? OperationQueue.default
        queue.addOperation(self)
    }
    
    public func execute(on queue: OperationQueue) {
        self.queue = queue
        queue.addOperation(self)
    }
    
    public func then<NewValue>(_ execute: @escaping (Value) throws -> (Query<NewValue>)) -> Query<NewValue> {
        let query = ChainQuery.init(query: self, execute: execute)
        query.queue = self.queue
        return query
    }
    
    public func then<NewValue>(_ execute: @escaping () throws -> (Query<NewValue>)) -> Query<NewValue> {
        let query = ChainQuery.init(query: self, execute: execute)
        query.queue = self.queue
        return query
    }
    
    public func then(_ execute: @escaping (Value) throws -> ()) -> Query {
        let query = ChainQuery<Value>.init(query: self, execute: execute)
        query.queue = self.queue
        return query
    }
    
    public func then(onMainThread execute: @escaping (Value) -> ()) -> Query {
        let query = ChainQuery<Value>.init(query: self, onMainThread: execute)
        query.queue = self.queue
        return query
    }
    
    public func then<NewValue>(executeArray: @escaping (Value) throws -> ([Query<NewValue.Element>])) -> Query<NewValue> where NewValue: Sequence {
        let query = ChainQuery<NewValue>.init(query: self, executeArray: executeArray)
        query.queue = self.queue
        return query
    }

//    public func then<NewValue>(_ execute: @escaping (Value) throws -> ([Query<NewValue>])) -> Query<NewValue> {
//        let query = ChainQuery.init(query: self, execute: execute)
//        query.queue = self.queue
//        return query
//    }
    
    public func then(onMainThreadAfter delay: TimeInterval, execute: @escaping (Value) -> ()) -> Query {
        let query = ChainQuery<Value>.init(query: self, onMainThreadAfter: delay, execute: execute)
        query.queue = self.queue
        return query
    }
    
    public func map<NewValue>(_ transform: @escaping (Value) throws -> (NewValue)) -> Query<NewValue> {
        let query = ChainQuery<NewValue>.init(query: self, transform: transform)
        query.queue = self.queue
        return query
    }
    
    public func `catch`(_ catchBlock: @escaping (Error) -> ()) -> Query<Value> {
        let query = ChainQuery(query: self, catchBlock: catchBlock)
        query.queue = self.queue
        return query
    }
    
    public func `catch`(onMainThread catchBlock: @escaping (Error) -> ()) -> Query<Value> {
        let query = ChainQuery(query: self, onMainThread: catchBlock)
        query.queue = self.queue
        return query
    }
    
    open override func cancel() {
        cancellation?()
        observer?.query(didCancel: self)
        super.cancel()
    }
    
}



public func firstly(_ execute: @escaping () throws -> ()) -> Query<Void> {
    return Query<Void>.init(query: { (completion) in
        func empty() -> Void {}
        do {
            try execute()
            completion?(Result.success(empty()))
        } catch {
            completion?(Result.failure(error))
        }
    })
}

public func firstly<Value>(_ execute: @escaping () throws -> (Value)) -> Query<Value> {
    return Query<Value>.init(query: { (completion) in
        do {
            let value = try execute()
            completion?(Result.success(value))
        } catch {
            completion?(Result.failure(error))
        }
    })
}

public extension Error {
    func queryThrowingError<Value>() -> Query<Value> {
        return Query.init(error: self)
    }
}

public func QuerySuccess<Value>(_ value: Value) -> Query<Value> {
    return Query(query: { (completion) in
        completion?(Result.success(value))
    })
}

public func QueryThrowError<Value>(_ error: Error) -> Query<Value> {
    return Query(query: { (completion) in
        completion?(Result.failure(error))
    })
}

public func QueryBlock<Value>(passing value: Value, block: @escaping (Value) throws -> ()) -> Query<Value> {
    return Query(query: { (completion) in
        do {
            try block(value)
            completion?(Result.success(value))
        } catch {
            completion?(Result.failure(error))
        }
    })
}

public func QueryBlock<Value>(passingError error: Error, block: @escaping (Error) -> ()) -> Query<Value> {
    return Query(query: { (completion) in
        block(error)
        completion?(Result.failure(error))
    })
}

public func QueryBlock<Value>(passingOnMainThread value: Value, block: @escaping (Value) -> ()) -> Query<Value> {
    return Query(query: { (completion) in
        DispatchQueue.main.async {
            block(value)
        }
        completion?(Result.success(value))
    })
}

public func QueryBlock<Value>(passingErrorOnMainThread error: Error, block: @escaping (Error) -> ()) -> Query<Value> {
    return Query(query: { (completion) in
        DispatchQueue.main.async {
            block(error)
        }
        completion?(Result.failure(error))
    })
}

extension Array {
    func execute<Value>() where Element: Query<Value> {
        for query in self {
            let queue = query.queue ?? OperationQueue.default
            queue.addOperation(query)
        }
        
    }
    
    func execute<Value>(on queue: OperationQueue) where Element: Query<Value> {
        queue.addOperations(self, waitUntilFinished: false)
    }
}


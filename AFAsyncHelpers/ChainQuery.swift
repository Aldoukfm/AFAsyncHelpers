//
//  ChainQuery.swift
//
//  Created by Aldo Fuentes on 7/25/19.
//  Copyright © 2019 aldofuentes. All rights reserved.
//

import Foundation


class ChainQuery<Value>: Query<Value> {
    
    var chainQueue: OperationQueue = OperationQueue()
    
    var chainOperations: [Operation] = []
    
    override init(query: @escaping ((((Result<Value, Error>) -> ())?) -> ())) {
        super.init(query: query)
    }
    
    init<OldValue>(query: Query<OldValue>, execute: @escaping (OldValue) throws -> (Query<Value>)) {
        super.init { (_) in }
        chainOperations.append(query)
        
        _execution =  {[unowned self] (completion) in
            
            var then: Query<Value>?
            query._completion = { result in
                switch result {
                case .success(let value):
                    do {
                        then = try execute(value)
                    } catch {
                        if let _catch = self._catch {
                            then = QueryBlock(passingError: error, block: _catch)
                        } else {
                            completion?(Result.failure(error))
                        }
                    }
                case .failure(let error):
                    if let _catch = self._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            self.executeOperations()
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
            
        }
    }
    
    init<OldValue>(query: Query<OldValue>, execute: @escaping () throws -> (Query<Value>)) {
        super.init { (_) in }
        chainOperations.append(query)
        
        _execution =  {[unowned self] (completion) in
            
            var then: Query<Value>?
            query._completion = { result in
                switch result {
                case .success:
                    do {
                        then = try execute()
                    } catch {
                        if let _catch = self._catch {
                            then = QueryBlock(passingError: error, block: _catch)
                        } else {
                            completion?(Result.failure(error))
                        }
                    }
                case .failure(let error):
                    if let _catch = self._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            self.executeOperations()
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
            
        }
    }
    
    init(query: Query<Value>, execute: @escaping (Value) throws -> ()) {
        super.init { (_) in }
        chainOperations.append(query)
        
        _execution =  {[unowned self] (completion) in
            var then: Query<Value>?
            query._completion = { result in
                switch result {
                case .success(let value):
                    let _catch = self._catch
                    then = Query(query: { (completion2) in
                        do {
                            try execute(value)
                            completion2?(result)
                        } catch {
                            _catch?(error)
                            completion2?(result)
                        }
                    })
                case .failure(let error):
                    if let _catch = self._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            self.executeOperations()
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
        }
    }
    
    init<OldValue>(query: Query<OldValue>, executeArray: @escaping (OldValue) throws -> ([Query<Value.Element>])) where Value: Sequence {
        super.init { (_) in }
        chainOperations.append(query)
        _execution =  {[unowned self] (completion) in
            
            var then: [Query<Value.Element>]?
            query._completion = { result in
                switch result {
                case .success(let value):
                    do {
                        then = try executeArray(value)
                    } catch {
                        if let _catch = self._catch {
                            then = [QueryBlock(passingError: error, block: _catch)]
                        } else {
                            completion?(Result.failure(error))
                        }
                    }
                case .failure(let error):
                    if let _catch = self._catch {
                        then = [QueryBlock(passingError: error, block: _catch)]
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            self.executeOperations()
            guard let newQueries = then else { return }
            //            newQueries._completion = completion
            var errors: [Query<Value>] = []
            var results: [(Int, Value.Element)] = []
            for (i, query) in newQueries.enumerated() {
                query._completion = { result in
                    switch result {
                    case .success(let value):
                        results.append((i, value))
                    case .failure(let error):
                        if let _catch = self._catch {
                            errors.append(QueryBlock(passingError: error, block: _catch))
                        } else {
                            completion?(Result.failure(error))
                        }
                    }
                }
            }
            self.chainOperations = newQueries
            self.executeOperations()
            let resultsArr = results.sorted(by: { $0.0 < $1.0 }).map({ $0.1 }) as! Value
            if errors.isEmpty {
                completion?(Result.success(resultsArr))
            } else {
                self.chainOperations = errors
                self.executeOperations()
            }
        }
    }
    
    /*
     public func then<NewValue>(_ execute: @escaping () throws -> ([Query<NewValue>])) -> Query<NewValue> {
     let query = ChainQuery.init(query: self, execute: execute)
     query.queue = self.queue
     return query
     }
     
     public func then<NewValue>(_ execute: @escaping (Value) throws -> ([Query<NewValue>])) -> Query<NewValue> {
     let query = ChainQuery.init(query: self, execute: execute)
     query.queue = self.queue
     return query
     }
     */
    
    
    
    init(query: Query<Value>, onMainThread execute: @escaping (Value) -> ()) {
        super.init { (_) in }
        chainOperations.append(query)
        
        var then: Query<Value>?
        _execution =  {[unowned self] (completion) in
            query._completion = { result in
                switch result {
                case .success(let value):
                    then = QueryBlock(passingOnMainThread: value, block: execute)
                case .failure(let error):
                    if let _catch = self._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            self.executeOperations()
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
        }
    }
    
    init(query: Query<Value>, onMainThreadAfter delay: TimeInterval, execute: @escaping (Value) -> ()) {
        super.init { (_) in }
        chainOperations.append(query)
        
        var then: Query<Value>?
        _execution =  {[unowned self] (completion) in
            query._completion = { result in
                switch result {
                case .success(let value):
                    then = Query(query: { (completion) in
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                            execute(value)
                        })
                        completion?(Result.success(value))
                    })
                case .failure(let error):
                    if let _catch = self._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            self.executeOperations()
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
        }
    }
    
    init<OldValue>(query: Query<OldValue>, transform: @escaping (OldValue) throws -> (Value)) {
        super.init { (_) in }
        chainOperations.append(query)
        
        _execution =  {[unowned self] (completion) in
            var then: Query<Value>?
            query._completion = { result in
                switch result {
                case .success(let value):
                    let _catch = self._catch
                    then = Query<Value>(query: { (completion2) in
                        do {
                            let newValue = try transform(value)
                            completion2?(Result.success(newValue))
                        } catch {
                            _catch?(error)
                            completion2?(Result.failure(error))
                        }
                    })
                case .failure(let error):
                    if let _catch = self._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            self.executeOperations()
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
        }
    }
    
    init(query: Query<Value>, catchBlock: @escaping (Error) -> ()) {
        super.init { (_) in }
        _catch = catchBlock
        chainOperations.append(query)
        
        _execution =  {[unowned self] (completion) in
            var then: Query<Value>?
            query._completion = { result in
                switch result {
                case .success:
                    completion?(result)
                case .failure(let error):
                    then = QueryBlock(passingError: error, block: catchBlock)
                }
            }
            self.executeOperations()
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
        }
    }
    
    init(query: Query<Value>, onMainThread catchBlock: @escaping (Error) -> ()) {
        super.init { (_) in }
        _catch = catchBlock
        chainOperations.append(query)
        _execution =  {[unowned self] (completion) in
            var then: Query<Value>?
            query._completion = { result in
                switch result {
                case .success:
                    completion?(result)
                case .failure(let error):
                    then = QueryBlock(passingErrorOnMainThread: error, block: catchBlock)
                }
            }
            self.executeOperations()
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
        }
    }
    
    override func then<NewValue>(_ execute: @escaping (Value) throws -> (Query<NewValue>)) -> Query<NewValue> {
        
        
        let query = ChainQuery<NewValue>.init { (_) in }
        query._catch = self._catch
        query.cancellation = self.cancellation
        query.chainQueue = self.chainQueue
        query.chainOperations = self.chainOperations
        query._execution = {[unowned query] (completion) in
            var then: Query<NewValue>?
            self._execution { result in
                switch result {
                case .success(let value):
                    do {
                        then = try execute(value)
                    } catch {
                        if let _catch = query._catch {
                            then = QueryBlock(passingError: error, block: _catch)
                        } else {
                            completion?(Result.failure(error))
                        }
                    }
                case .failure(let error):
                    if let _catch = query._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            guard let newQuery = then else { return }
            newQuery._completion = completion
            query.chainOperations = [newQuery]
            query.executeOperations()
        }
        
        return query
    }
    
    override func then<NewValue>(_ execute: @escaping () throws -> (Query<NewValue>)) -> Query<NewValue> {
        
        let query = ChainQuery<NewValue>.init { (_) in }
        query._catch = self._catch
        query.cancellation = self.cancellation
        query.chainQueue = self.chainQueue
        query.chainOperations = self.chainOperations
        query.queue = self.queue
        query._execution = {[unowned query] (completion) in
            var then: Query<NewValue>?
            self._execution { result in
                switch result {
                case .success:
                    do {
                        then = try execute()
                    } catch {
                        if let _catch = query._catch {
                            then = QueryBlock(passingError: error, block: _catch)
                        } else {
                            completion?(Result.failure(error))
                        }
                    }
                case .failure(let error):
                    if let _catch = query._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            guard let newQuery = then else { return }
            newQuery._completion = completion
            query.chainOperations = [newQuery]
            query.executeOperations()
        }
        
        return query
    }
    
    //TODO: Override then 
//    override func then<NewValue>(_ execute: @escaping () throws -> ([Query<NewValue.Element>])) -> Query<NewValue> where NewValue : Sequence {
//
//    }
    /*
    init<OldValue>(query: Query<OldValue>, execute: @escaping (OldValue) throws -> ([Query<Value.Element>])) where Value: Sequence {
        super.init { (_) in }
        chainOperations.append(query)
        _execution =  {[unowned self] (completion) in
            
            var then: [Query<Value.Element>]?
            query._completion = { result in
                switch result {
                case .success(let value):
                    do {
                        then = try execute(value)
                    } catch {
                        if let _catch = self._catch {
                            then = [QueryBlock(passingError: error, block: _catch)]
                        } else {
                            completion?(Result.failure(error))
                        }
                    }
                case .failure(let error):
                    if let _catch = self._catch {
                        then = [QueryBlock(passingError: error, block: _catch)]
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            self.executeOperations()
            guard let newQueries = then else { return }
            //            newQueries._completion = completion
            var errors: [Query<Value>] = []
            var results: [(Int, Value.Element)] = []
            for (i, query) in newQueries.enumerated() {
                query._completion = { result in
                    switch result {
                    case .success(let value):
                        results.append((i, value))
                    case .failure(let error):
                        if let _catch = self._catch {
                            errors.append(QueryBlock(passingError: error, block: _catch))
                        } else {
                            completion?(Result.failure(error))
                        }
                    }
                }
            }
            self.chainOperations = newQueries
            self.executeOperations()
            let resultsArr = results.map({ $0.1 }) as! Value
            if errors.isEmpty {
                completion?(Result.success(resultsArr))
            } else {
                self.chainOperations = errors
                self.executeOperations()
            }
            
            
        }
    }
    */
    override func then(_ execute: @escaping (Value) throws -> ()) -> Query<Value> {
        let prevExecution = _execution!
        self._execution = {[unowned self] completion in
            var then: Query<Value>?
            prevExecution { result in
                switch result {
                case .success(let value):
                    let _catch = self._catch
                    then = Query(query: { (completion2) in
                        do {
                            try execute(value)
                            completion2?(result)
                        } catch {
                            _catch?(error)
                            completion2?(Result.failure(error))
                        }
                    })
                case .failure(let error):
                    if let _catch = self._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
        }
        return self
    }
    
    override func then(onMainThread execute: @escaping (Value) -> ()) -> Query<Value> {
        let prevExecution = _execution!
        self._execution = {[unowned self] completion in
            var then: Query<Value>?
            prevExecution { result in
                switch result {
                case .success(let value):
                    then = QueryBlock(passingOnMainThread: value, block: execute)
                case .failure(let error):
                    if let _catch = self._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            guard let newQuery = then else { return }
            newQuery._completion = completion
            self.chainOperations = [newQuery]
            self.executeOperations()
        }
        return self
    }
    
    override func map<NewValue>(_ transform: @escaping (Value) throws -> (NewValue)) -> Query<NewValue> {
        let query = ChainQuery<NewValue>.init { (_) in }
        query.cancellation = self.cancellation
        query.chainQueue = self.chainQueue
        query.chainOperations = self.chainOperations
        query.queue = self.queue
        query._execution = {[unowned query] (completion) in
            var then: Query<NewValue>?
            self._execution { result in
                switch result {
                case .success(let value):
                    let _catch = self._catch
                    then = Query(query: { (completion2) in
                        do {
                            let transformed = try transform(value)
                            completion2?(Result.success(transformed))
                        } catch {
                            _catch?(error)
                            completion2?(Result.failure(error))
                        }
                    })
                case .failure(let error):
                    if let _catch = self._catch {
                        then = QueryBlock(passingError: error, block: _catch)
                    } else {
                        completion?(Result.failure(error))
                    }
                }
            }
            guard let newQuery = then else { return }
            newQuery._completion = completion
            query.chainOperations = [newQuery]
            query.executeOperations()
        }
        
        return query
    }
    
    override func `catch`(_ catchBlock: @escaping (Error) -> ()) -> Query<Value> {
        _catch = catchBlock
        return self
    }
    
    override func `catch`(onMainThread catchBlock: @escaping (Error) -> ()) -> Query<Value> {
        _catch = { error in
            DispatchQueue.main.async {
                catchBlock(error)
            }
        }
        return self
    }
    
    func executeOperations() {
        chainQueue.addOperations(chainOperations, waitUntilFinished: true)
    }
    
    override func cancel() {
        for op in chainOperations {
            op.cancel()
        }
        super.cancel()
    }
}

//
//extension ChainQuery where Value: Sequence {
//    convenience init(queries: [Query<Value.Element>]) {
//        self.init { (_) in }
//        self.chainOperations.append(contentsOf: queries)
//        _execution = {[unowned self] (completion) in
//
//            var errors: [Query<Value>] = []
//            var results: [(Int, Value.Element)] = []
//            for (i, query) in queries.enumerated() {
//                query._completion = { result in
//                    switch result {
//                    case .success(let value):
//                        results.append((i, value))
//                    case .failure(let error):
//                        if let _catch = self._catch {
//                            errors.append(QueryBlock(passingError: error, block: _catch))
//                        } else {
//                            completion?(Result.failure(error))
//                        }
//                    }
//                }
//            }
//            self.executeOperations()
//            let resultsArr = results.sorted(by: { $0.0 < $1.0 }).map({ $0.1 }) as! Value
//            if errors.isEmpty {
//                completion?(Result.success(resultsArr))
//            } else {
//                self.chainOperations = errors
//                self.executeOperations()
//            }
//        }
//    }
//}

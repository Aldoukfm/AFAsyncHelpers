//
//  ObservableOperationController.swift
//  Lunch Box
//
//  Created by Aldo Fuentes on 6/28/19.
//  Copyright © 2019 aldofuentes. All rights reserved.
//

import Foundation


open class ObservableOperationController2: NSObject, QueryObserver {
    
    public var observerID: Int = 0
    
    private var operations: [ID: ObservableOperation2] = [:]
    
    private var observers: [ID: [Int: ObserverWrapper2]] = [:]
    
    public var keepOperations = false
    
    public var queue = OperationQueue.default
    
    open func addObserver(_ observer: QueryObserver, for id: ID) {
        let wrapper = ObserverWrapper2(observer)
        var newObservers: [Int: ObserverWrapper2] = observers[id] ?? [:]
        newObservers[observer.observerID] = wrapper
        
        observers.updateValue(newObservers, forKey: id)
    }
    
    open func addObservers(_ observers: [QueryObserver], for id: ID) {
        for observer in observers {
            addObserver(observer, for: id)
        }
    }
    
    open func removeObserver(_ observer: QueryObserver, for id: ID) {
        guard var currentObservers = observers[id] else { return }
        currentObservers.removeValue(forKey: observer.observerID)
    }
    
    open func removeObservers(_ observers: [QueryObserver], for id: ID) {
        for observer in observers {
            removeObserver(observer, for: id)
        }
    }
    
    open func removeAllObservers(for id: ID) {
        observers.removeValue(forKey: id)
    }
    
    open func removeAllObservers() {
        observers.removeAll()
    }
    
    open func execute<Value>(_ query: Query<Value>) {
        guard let id = query.id else {
            fatalError("Query has no ID")
        }
        if let currentOp = operations[id] {
            currentOp.cancel()
        }
        operations[id] = query
        query.observer = self
        queue.addOperation(query)
    }
    
    open func execute<Value>(_ operations: [Query<Value>]) {
        for op in operations {
            execute(op)
        }
    }
    
    open func pendingUpdate(for id: ID) -> Any? {
        return operations[id]?.update
    }
    
    open func isExecutingOperation(with id: ID) -> Bool {
        return operations[id]?.isExecuting ?? false
    }
    
    open func didFinishOperation(with id: ID) -> Bool {
        return operations[id]?.isFinished ?? false
    }
    
    open func cancelOperation(with id: ID) {
        operations[id]?.cancel()
    }
    
    open func cancelAllOperations() {
        operations.values.forEach({ $0.cancel() })
    }
    
    open func query<Value>(_ operation: Query<Value>, didCompleteWith result: Result<Value, Error>) {
        guard let id = operation.id else {
            fatalError("Query has no ID")
        }
        guard let currentObservers = observers[id] else { return }
        for wrapper in currentObservers.values {
            wrapper.observer?.query(operation, didCompleteWith: result)
        }
        //        if !keepOperations {
        //            if let index = operations.index(forKey: id) {
        //                operations[id] = nil
        ////                operations.remove(at: index)
        //            }
        ////            operations.removeValue(forKey: id)
        //        }
    }
    
    open func query<Value>(willBeing operation: Query<Value>) {
        guard let id = operation.id else {
            fatalError("Query has no ID")
        }
        guard let currentObservers = observers[id] else { return }
        for wrapper in currentObservers.values {
            wrapper.observer?.query(willBeing: operation)
        }
    }
    
    open func query<Value>(didCancel operation: Query<Value>) {
        guard let id = operation.id else {
            fatalError("Query has no ID")
        }
        guard let currentObservers = observers[id] else { return }
        for wrapper in currentObservers.values {
            wrapper.observer?.query(didCancel: operation)
        }
        if !keepOperations {
            operations.removeValue(forKey: id)
        }
    }
    
    deinit {
        for (id, op) in operations {
            observers.removeValue(forKey: id)
            op.cancel()
        }
    }
    
}


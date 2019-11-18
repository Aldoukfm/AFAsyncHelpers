//
//  ObserverWrapper.swift
//
//  Created by Aldo Fuentes on 6/28/19.
//  Copyright © 2019 aldofuentes. All rights reserved.
//

import Foundation

public struct ObserverWrapper2 {
    public weak var observer: QueryObserver?
    
    public init(_ observer: QueryObserver) {
        self.observer = observer
    }
}

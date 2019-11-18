//
//  ObservableOperation.swift
//
//  Created by Aldo Fuentes on 6/28/19.
//  Copyright © 2019 aldofuentes. All rights reserved.
//

import Foundation

open class ObservableOperation2: AsyncOperation {
    @objc public dynamic var update: Any?
    public weak var observer: QueryObserver?
    public var id: ID?
}

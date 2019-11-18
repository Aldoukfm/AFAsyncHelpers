//
//  QueueController.swift
//
//  Created by Aldo Fuentes on 7/5/19.
//  Copyright © 2019 aldofuentes. All rights reserved.
//

import Foundation

class QueueController {
    static var defaultOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "DefaultQueue"
        queue.qualityOfService = QualityOfService.userInitiated
        return queue
    }()
}


extension OperationQueue {
    static var `default`: OperationQueue {
        return QueueController.defaultOperationQueue
    }
}


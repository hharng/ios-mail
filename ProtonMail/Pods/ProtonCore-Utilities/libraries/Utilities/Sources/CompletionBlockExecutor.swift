//
//  CompletionBlockExecutor.swift
//  ProtonCore-Utilities - Created on 14.02.22.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore. If not, see https://www.gnu.org/licenses/.
//

public struct CompletionBlockExecutor {
    public init(executionContext: @escaping (@escaping () -> Void) -> Void) {
        self.executionContext = executionContext
    }
    
    public func execute(completionBlock: @escaping () -> Void) {
        executionContext(completionBlock)
    }
    
    private let executionContext: (@escaping () -> Void) -> Void
}

extension CompletionBlockExecutor {
    
    public static let asyncMainExecutor = asyncExecutor(dispatchQueue: .main)
    public static let immediateExecutor = CompletionBlockExecutor { $0() }
    
    public static func asyncExecutor(dispatchQueue: DispatchQueue) -> Self {
        .init { work in
            dispatchQueue.async(execute: work)
        }
    }

}
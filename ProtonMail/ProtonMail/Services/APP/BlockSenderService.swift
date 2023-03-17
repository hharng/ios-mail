// Copyright (c) 2023 Proton Technologies AG
//
// This file is part of Proton Mail.
//
// Proton Mail is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Mail is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Mail. If not, see https://www.gnu.org/licenses/.

import ProtonCore_Networking
import ProtonCore_Services

@available(*, deprecated, message: "TODO: create a use case to block (https://jira.protontech.ch/browse/MAILIOS-3191)")
final class BlockSenderService {
    let apiService: APIService

    init(apiService: APIService) {
        self.apiService = apiService
    }

    func block(emailAddress: String, completion: @escaping (Error?) -> Void) {
        let request = AddIncomingDefaultsRequest(location: .blocked, overwrite: true, target: .email(emailAddress))

        apiService.perform(
            request: request,
            callCompletionBlockUsing: .immediateExecutor
        ) { (_, result: Result<AddIncomingDefaultsResponse, ResponseError>) in
            completion(result.error)
        }
    }
}

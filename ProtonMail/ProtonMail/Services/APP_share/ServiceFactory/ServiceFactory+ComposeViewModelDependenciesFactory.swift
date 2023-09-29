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

import Foundation
import UIKit

protocol ComposerDependenciesFactory {
    func makeViewModelDependencies(user: UserManager) -> ComposeViewModel.Dependencies
    func makeComposer(viewModel: ComposeViewModel) -> UINavigationController
}

extension ServiceFactory {
    private struct ComposerFactory: ComposerDependenciesFactory {
        private let factory: ServiceFactory

        init(factory: ServiceFactory) {
            self.factory = factory
        }

        func makeViewModelDependencies(user: UserManager) -> ComposeViewModel.Dependencies {
            .init(
                coreDataContextProvider: factory.get(),
                coreKeyMaker: factory.get(),
                fetchAndVerifyContacts: FetchAndVerifyContacts(
                    user: user
                ),
                internetStatusProvider: InternetConnectionStatusProvider.shared,
                fetchAttachment: FetchAttachment(dependencies: .init(apiService: user.apiService)),
                contactProvider: user.contactService,
                helperDependencies: .init(
                    messageDataService: user.messageService,
                    cacheService: user.cacheService,
                    contextProvider: factory.get(),
                    copyMessage: CopyMessage(
                        dependencies: .init(
                            contextProvider: factory.get(),
                            messageDecrypter: user.messageService.messageDecrypter
                        ),
                        userDataSource: user
                    ),
                    attachmentMetadataStripStatusProvider: factory.userCachedStatus
                ),
                fetchMobileSignatureUseCase: FetchMobileSignature(
                    dependencies: .init(
                        coreKeyMaker: factory.get(),
                        cache: factory.userCachedStatus
                    )
                ),
                darkModeCache: factory.userCachedStatus,
                attachmentMetadataStrippingCache: factory.userCachedStatus,
                userCachedStatusProvider: factory.userCachedStatus
            )
        }

        func makeComposer(viewModel: ComposeViewModel) -> UINavigationController {
            return ComposerViewFactory.makeComposer(
                childViewModel: viewModel,
                contextProvider: factory.get(),
                userIntroductionProgressProvider: factory.userCachedStatus,
                attachmentMetadataStrippingCache: factory.userCachedStatus,
                featureFlagCache: factory.userCachedStatus
            )
        }
    }

    func makeComposeViewModelDependenciesFactory() -> ComposerDependenciesFactory {
        ComposerFactory(factory: self)
    }
}
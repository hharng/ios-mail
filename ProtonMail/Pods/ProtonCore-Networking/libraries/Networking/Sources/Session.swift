//
//  Session.swift
//  ProtonCore-Networking - Created on 6/24/21.
//
//  Copyright (c) 2021 Proton Technologies AG
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
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import TrustKit

public typealias ResponseCompletion = (_ task: URLSessionDataTask?, _ response: Any?, _ error: NSError?) -> Void
public typealias DownloadCompletion = (_ response: URLResponse?, _ url: URL?, _ error: NSError?) -> Void
public typealias ProgressCompletion = (_ progress: Progress) -> Void

public let defaultTimeout: TimeInterval = 60.0

public protocol Session {
    func generate(with method: HTTPMethod, urlString: String, parameters: Any?, timeout: TimeInterval?) throws -> SessionRequest
    
    func request(with request: SessionRequest, completion: @escaping ResponseCompletion) throws
    
    func upload(with request: SessionRequest,
                keyPacket: Data, dataPacket: Data, signature: Data?,
                completion: @escaping ResponseCompletion) throws

    // swiftlint:disable function_parameter_count
    func upload(with request: SessionRequest,
                keyPacket: Data, dataPacket: Data, signature: Data?,
                completion: @escaping ResponseCompletion,
                uploadProgress: ProgressCompletion?) throws
    
    func upload(with request: SessionRequest,
                files: [String: URL],
                completion: @escaping ResponseCompletion,
                uploadProgress: ProgressCompletion?) throws

    func uploadFromFile(with request: SessionRequest,
                        keyPacket: Data, dataPacketSourceFileURL: URL, signature: Data?,
                        completion: @escaping ResponseCompletion) throws

    // swiftlint:disable function_parameter_count
    func uploadFromFile(with request: SessionRequest,
                        keyPacket: Data, dataPacketSourceFileURL: URL, signature: Data?,
                        completion: @escaping ResponseCompletion,
                        uploadProgress: ProgressCompletion?) throws

    func download(with request: SessionRequest,
                  destinationDirectoryURL: URL,
                  completion: @escaping DownloadCompletion) throws
    
    func setChallenge(noTrustKit: Bool, trustKit: TrustKit?)
    
    func failsTLS(request: SessionRequest) -> String?
}

extension Session {
    
    public func generate(with method: HTTPMethod, urlString: String, parameters: Any? = nil, timeout: TimeInterval? = nil) throws -> SessionRequest {
        return SessionRequest.init(parameters: parameters,
                                   urlString: urlString,
                                   method: method,
                                   timeout: timeout ?? defaultTimeout)
    }
    
    public func uploadFromFile(with request: SessionRequest,
                               keyPacket: Data,
                               dataPacketSourceFileURL: URL,
                               signature: Data?,
                               completion: @escaping ResponseCompletion) throws {
        try self.uploadFromFile(with: request,
                                keyPacket: keyPacket,
                                dataPacketSourceFileURL: dataPacketSourceFileURL,
                                signature: signature,
                                completion: completion, uploadProgress: nil)
    }
    
    public func upload(with request: SessionRequest,
                       keyPacket: Data,
                       dataPacket: Data,
                       signature: Data?, completion: @escaping ResponseCompletion) throws {
        try self.upload(with: request,
                        keyPacket: keyPacket,
                        dataPacket: dataPacket,
                        signature: signature,
                        completion: completion, uploadProgress: nil)
    }
    
}

public enum SessionFactory {
    
    public static func createSessionInstance(url apiHostUrl: String) -> Session {
        #if canImport(Alamofire)
        AlamofireSession()
        #elseif canImport(AFNetworking)
        AFNetworkingSession(url: apiHostUrl)
        #endif
    }
    
    public static func createSessionRequest(
        parameters: Any?, urlString: String, method: HTTPMethod, timeout: TimeInterval
    ) -> SessionRequest {
        #if canImport(Alamofire)
        AlamofireRequest(parameters: parameters, urlString: urlString, method: method, timeout: timeout)
        #elseif canImport(AFNetworking)
        SessionRequest(parameters: parameters, urlString: urlString, method: method, timeout: timeout)
        #endif
    }
}

public class SessionRequest {
    init(parameters: Any?, urlString: String, method: HTTPMethod, timeout: TimeInterval) {
        self.parameters = parameters
        self.method = method
        self.urlString = urlString
        self.timeout = timeout
    }
    
    var _request: URLRequest?
    public var request: URLRequest? {
        get {
            return self._request
        }
        set {
            self._request = newValue
            self._request?.timeoutInterval = self.timeout
        }
    }
    
    let parameters: Any?
    let urlString: String
    let method: HTTPMethod
    let timeout: TimeInterval
    
    private var headers: [String: String] = [:]
    public func setValue(header: String, _ value: String?) {
        self.headers[header] = value
    }
    // must call after the request be set
    public func updateHeader() {
        for (header, value) in self.headers {
            self.request?.setValue(value, forHTTPHeaderField: header)
        }
    }
}
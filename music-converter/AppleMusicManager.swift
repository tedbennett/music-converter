//
//  AppleMusicManager.swift
//  music-converter
//
//  Created by Ted Bennett on 28/06/2020.
//  Copyright © 2020 Ted Bennett. All rights reserved.
//

import Foundation
import PromiseKit
import Alamofire

class AppleMusicManager {
    var baseURL = URL(string: "https://api.music.apple.com/v1/")!
    var developerToken = KeychainWrapper.standard.string(forKey: "appleMusicToken")
    static let shared = AppleMusicManager()
    
    private init() {}
    
    func authorize() -> Promise<Void> {
        if developerToken == nil {
            return getToken()
        } else {
            return Promise {$0.fulfill(())}
        }
    }
    
    private func getToken() -> Promise<Void> {
        firstly {
            FirebaseManager.shared.signInAnonymously()
        }.then { _ in
            FirebaseManager.shared.getAppleMusicToken()
        }.then { (token: String) -> Promise<Void> in
            self.developerToken = token
            return Promise {$0.fulfill(())}
        }
        
    }
    struct BackgroundError: Error {
        var errorDescription = "App in background"
    }
    
    func fetchIsrcId(id: String) -> Promise<Track> {
        return Promise { seal in
            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(developerToken!)"
            ]
            AF.request(baseURL.appendingPathComponent("catalog/us/songs/\(id)"), headers: headers)
                .validate()
                .response { response in
                    switch response.result {
                        case .success(let data):
                            do {
                                
                                let decoded = try JSONDecoder().decode(AppleMusicResponse<AppleMusicSong>.self, from: data!)
                                seal.fulfill(Track(fromAppleMusic: decoded.data[0]))
                            } catch {
                                seal.reject(error)
                        }
                        
                        case .failure(let error):
                            seal.reject(error)
                    }
            }
        }
    }
    
    func fetchTrackFromIsrcId(isrcId: String) -> Promise<Track?> {
        return Promise { seal in
            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(developerToken!)"
            ]
            let url = baseURL.appendingPathComponent("catalog/us/songs")
            let parameters: Parameters = ["filter[isrc]": isrcId]
            AF.request(url, parameters: parameters, headers: headers)
                .validate()
                .response { response in
                    switch response.result {
                        case .success(let data):
                            do {
                                let decoded = try JSONDecoder().decode(AppleMusicResponse<AppleMusicSong>.self, from: data!)
                                seal.fulfill(decoded.data.isEmpty ? nil : Track(fromAppleMusic: decoded.data[0]))
                            } catch {
                                seal.reject(error)
                        }
                        
                        case .failure(let error):
                            seal.reject(error)
                        
                    }
            }
        }
    }
    
    func fetchTrackSearchResults(for search: String) -> Promise<[Track]> {
        return Promise { seal in
            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(developerToken!)"
            ]
            
            let escapedString = search.replacingOccurrences(of: " ", with: "+")
            let parameters = [
                "term": escapedString,
                "types": "songs",
                "limit": "5",
                "include": "artists"
            ]
            
            AF.request(baseURL.appendingPathComponent("catalog/us/search"), parameters: parameters, headers: headers)
                .validate()
                .response { response in
                    switch response.result {
                        case .success(let data):
                            do {
                                let decoded = try JSONDecoder().decode(AppleMusicSearchResponse.self, from: data!)
                                seal.fulfill((decoded.results.songs?.data.map { Track(fromAppleMusic: $0) })!)
                            } catch {
                                seal.reject(error)
                        }
                        
                        case .failure(let error):
                            seal.reject(error)
                    }
            }
        }
    }
}

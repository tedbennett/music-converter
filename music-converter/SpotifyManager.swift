//
//  SpotifyManager.swift
//  music-converter
//
//  Created by Ted Bennett on 28/06/2020.
//  Copyright © 2020 Ted Bennett. All rights reserved.
//

import Foundation
import OAuth2
import PromiseKit
import Alamofire

class SpotifyManager {
    
    var baseURL = URL(string: "https://api.spotify.com/v1")!
    
    var authClient = OAuth2ClientCredentials(settings: [
        "client_id": KeychainWrapper.standard.string(forKey: "spotifyClient") as Any,
        "client_secret": KeychainWrapper.standard.string(forKey: "spotifySecret") as Any,
        "grant_type": "client_credentials",
        "token_uri": "https://accounts.spotify.com/api/token",
        "redirect_uris": ["music-manager://oauth-callback/"],
        "keychain": true,
        ] as OAuth2JSON)
    
    static let shared = SpotifyManager()
    
    private init() {}
    
    func authorize() -> Promise<Void> {
        checkCredentials().then{ success in
            return Promise { seal in
                if success {
                    self.authClient.obtainAccessToken(params: nil, callback: {authParameters, error in
                        if authParameters != nil {
                            seal.fulfill(())
                        }
                        else {
                            seal.reject(error!)
                        }
                        
                    })
                }
            }
        }
    }
    
    private func checkCredentials() -> Promise<Bool> {
        if authClient.clientId == nil {
            return getAuthClientCredentials()
        } else {
            return Promise {$0.fulfill(true)}
        }
    }
    
    private func getAuthClientCredentials() -> Promise<Bool> {
        firstly {
            FirebaseManager.shared.signInAnonymously()
        }.then { _ in
            FirebaseManager.shared.getSpotifyCredentials()
        }.then { (client: String, secret: String) -> Promise<Bool> in
            self.authClient.clientId = client
            self.authClient.clientSecret = secret
            KeychainWrapper.standard.set(client, forKey: "spotifyClient")
            KeychainWrapper.standard.set(secret, forKey: "spotifySecret")
            return Promise {$0.fulfill(true)}
        }
    }
    
    func fetchIsrcId(id: String) -> Promise<Track> {
        return Promise { seal in
            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(authClient.accessToken!)"
            ]
            AF.request(baseURL.appendingPathComponent("/tracks/\(id)"), headers: headers)
                .validate()
                .response { response in
                    switch response.result {
                        case .success(let data):
                            do {
                                let decoded = try JSONDecoder().decode(SpotifyTrack.self, from: data!)
                                seal.fulfill(Track(fromSpotify: decoded))
                            } catch {
                                seal.reject(error)
                        }
                        
                        case .failure(let error):
                            seal.reject(error)
                    }
            }
        }
    }
    
    func fetchTrackFromIsrcId(isrc: String) -> Promise<Track?>{
        return Promise { seal in
            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(authClient.accessToken!)"
            ]
            let parameters = [
                "q": "isrc:\(isrc)",
                "type": "track",
                "limit": "1"
            ]
            AF.request(baseURL.appendingPathComponent("/search"), parameters: parameters, headers: headers)
                .validate()
                .response { response in
                    switch response.result {
                        case .success(let data):
                            do {
                                let decoded = try JSONDecoder().decode(SpotifySearch.self, from: data!)
                                seal.fulfill(decoded.tracks?.items == nil ? nil : Track(fromSpotify: decoded.tracks!.items[0]))
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
                "Authorization": "Bearer \(authClient.accessToken!)"
            ]
            let parameters = [
                "q": search,
                "type": "track",
                "limit": "5"
            ]
            AF.request(baseURL.appendingPathComponent("/search"), parameters: parameters, headers: headers)
                .validate()
                .response { response in
                    switch response.result {
                        case .success(let data):
                            do {
                                let decoded = try JSONDecoder().decode(SpotifySearch.self, from: data!)
                                seal.fulfill(decoded.tracks!.items.map {
                                    Track(fromSpotify: $0)
                                })
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

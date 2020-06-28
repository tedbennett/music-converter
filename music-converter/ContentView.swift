//
//  ContentView.swift
//  music-converter
//
//  Created by Ted Bennett on 28/06/2020.
//  Copyright © 2020 Ted Bennett. All rights reserved.
//

import SwiftUI
import FirebaseFunctions
import FirebaseAuth
import PromiseKit

struct ContentView: View {
    @State private var client: String = "Hello"
    @State private var secret: String = "World"
    var body: some View {
        VStack {
            Text(client)
            Text(secret)
        }.onAppear {
            firstly {
                FirebaseManager.shared.signInAnonymously()
            }.then { _ in
                FirebaseManager.shared.getSpotifyCredentials()
            }.done { client, secret in
                self.client = client
                self.secret = secret
            }.catch { error in
                print(error)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class FirebaseManager {
    lazy var functions = Functions.functions()
    
    static var shared = FirebaseManager()
    
    private init() {}
    
    func signInAnonymously() -> Promise<String> {
        Promise { seal in
        Auth.auth().signInAnonymously() { (authResult, error) in
            if let error = error as NSError? {
                seal.reject(error)
            }
            if (authResult != nil) {
                seal.fulfill(authResult.debugDescription)
            }
        }
        }
    }
    
    
    func getAppleMusicToken() -> Promise<String> {
        Promise { seal in
        functions.httpsCallable("getAppleMusicToken").call { result, error in
            if let error = error as NSError? {
                seal.reject(error)
            }
            if let token = result?.data as? String {
                seal.fulfill(token)
            }
        }
        }
    }
    
    func getSpotifyCredentials() -> Promise<(String, String)> {
        Promise { seal in
            functions.httpsCallable("getSpotifyCredentials").call { result, error in
                if let error = error as NSError? {
                    seal.reject(error)
                }
                if let credentials = result?.data as? [String: Any] {
                    let client = credentials["client"] as! String
                    let secret = credentials["secret"] as! String
                    seal.fulfill((client, secret))
                }
            }
        }
    }
}

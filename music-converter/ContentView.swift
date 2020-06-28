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
    
    var body: some View {
        VStack {
            Text("")
        }.onAppear {
            AppleMusicManager.shared.authorize().then {
                SpotifyManager.shared.authorize()
            }.done { success in
                print(success)
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

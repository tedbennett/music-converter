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
import Alamofire

struct ContentView: View {
    @State private var status: Status = .InProgress
    @State private var cachedClipboardString: String?
    @State private var statusText: String?
    
    @State private var albumArt: UIImage?
    @State private var trackName: String?
    @State private var artistName: String?
    @State private var trackIsrcId: String?
    @State private var url: URL?
    
    
    // Animation helpers
    @State private var fadeOut = false
    @State private var trackAvailable = false
    
    var body: some View {
        NavigationView {
            VStack {
                if self.status == .InProgress {
                    SpinnerView()
                }
                if self.trackAvailable {
                    VStack() {
                        Image(uiImage: self.albumArt!).resizable()
                            .cornerRadius(10)
                            .frame(width: 300, height: 300, alignment: .center)
                            .padding(20)
                            .opacity(self.fadeOut ? 0 : 1)
                            .animation(.easeInOut(duration: 1.0))
                        HStack {
                            Text(self.trackName!).bold()
                                .padding(10)
                                .font(.largeTitle)
                                .opacity(self.fadeOut ? 0 : 1)
                                .animation(Animation.easeInOut(duration: 1.0).delay(0.5))
                                
                            Spacer()
                        }
                        HStack {
                        Text(self.artistName!).padding(10)
                            .font(.headline)
                            .opacity(self.fadeOut ? 0 : 1)
                            .animation(Animation.easeInOut(duration: 1.0).delay(1.0))
                            Spacer()
                        }
                        //if self.url != nil {
                        HStack {
                            Button(action: {
                                UIApplication.shared.open(self.url!)
                            }, label: {
                                if self.status == .TargetAppleMusic {
                                    Text("Open In Apple Music").font(.headline)
                                        .padding(20)
                                }
                                if self.status == .TargetSpotify {
                                    Text("Open In Spotify").font(.headline)
                                        .padding(20)
                                }
        
                            }).opacity(self.fadeOut ? 0 : 1)
                                .animation(Animation.easeInOut(duration: 1.0).delay(1.5))
                            Spacer()
                        }
                    }.frame(width: 300)
                        //.transition(.slide)
                }
                
                if self.status == .InvalidLink {
                    VStack {
                        Text("Can't find music URL in your clipboard").padding(10)
                        Text("Copy an 'open.spotify.com' or 'music.apple.com song' link").font(.subheadline)
                            .multilineTextAlignment(.center)
                    }.padding(15)
                        .animation(Animation.easeInOut(duration: 1.0))
                        .transition(.opacity)
                    
                }
            }.navigationBarTitle("Title")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            self.statusText = "Logging in to AM"
            AppleMusicManager.shared.authorize().then { () -> Promise<Void> in
                self.statusText = "Logging in to Spotify"
                return SpotifyManager.shared.authorize()
            }.done { success in
                self.statusText = "Checking clipboard"
                if self.cachedClipboardString == UIPasteboard.general.string {
                    return
                } else {
                    self.fadeOut = true
                    self.trackAvailable = false
                    self.albumArt = nil
                    self.artistName = nil
                    self.trackName = nil
                    self.trackIsrcId = nil
                    self.url = nil
                }
                self.convertClipboardLink(UIPasteboard.general.string)
            }.catch { error in
                print(error)
            }
        }
    }
    
    
    private func convertClipboardLink(_ link: String?) {
        cachedClipboardString = link
        let linkType = checkLinkValid(link)
        switch linkType {
            case .SpotifyTrack:
                status = .TargetAppleMusic
                getTrackFromAppleMusic(URL(string: link!)!)
            case .SpotifyAlbum:
                status = .TargetAppleMusic
                return //getAlbumFromAppleMusic(link)
            case .AppleMusicTrack:
                status = .TargetSpotify
                getTrackFromSpotify(URL(string: link!)!)
            case .AppleMusicAlbum:
                status = .TargetSpotify
                return //getAlbumFromSpotify(link)
            case .Invalid:
                status = .InvalidLink
                return
        }
    }
    
    private func checkLinkValid(_ link: String?) -> LinkType {
        if link != nil, let url = URL(string: link!) {
            if url.host == "open.spotify.com" {
                if url.pathComponents[1] == "track" {
                    return .SpotifyTrack
                } else if url.pathComponents[1] == "album" {
                    return .SpotifyAlbum
                }
            }
            if url.host == "music.apple.com" {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
                if url.pathComponents[2] == "album" {
                    if (components?.queryItems?.first(where: { $0.name == "i"})?.value) != nil {
                        return .AppleMusicTrack
                    } else {
                        return .AppleMusicAlbum // MARK check that this is valid.
                    }
                }
            }
        } else {
            return .Invalid
        }
        return .Invalid
    }
    
    private func getTrackFromSpotify(_ url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let id = components!.queryItems!.first(where: { $0.name == "i"})!.value!
        
        AppleMusicManager.shared.fetchIsrcId(id: id)
            .then { (track: Track) -> Promise<UIImage?> in
                self.trackName = track.name
                self.artistName = track.artists.isEmpty ? "Unknown Artist" : track.artists[0]
                self.trackIsrcId = track.isrcId
                return self.downloadImage(from: track.imageUrl)
        }
        .then { (image: UIImage?) -> Promise<Track?> in
            self.albumArt = image
            self.trackAvailable = true
            if self.trackIsrcId == nil {
                return Promise { $0.reject(IsrcMissingError()) }
            }
            return SpotifyManager.shared.fetchTrackFromIsrcId(isrc: self.trackIsrcId!)
        }
        .then { (track: Track?) -> Promise<[Track]> in
            if track == nil {
                return SpotifyManager.shared.fetchTrackSearchResults(for: self.trackName!)
            }
            self.url = track!.url
            return Promise{$0.fulfill([])}
        }
        .done { (tracks: [Track]) in
            if !tracks.isEmpty {
                for track in tracks {
                    if track.name == self.trackName! && track.artists[0] == self.artistName! {
                        self.url = tracks[0].url
                        return
                    }
                }
            }
            self.fadeOut = false
        }.catch { error in
            print(error)
        }
    }
    
    private func getTrackFromAppleMusic(_ url: URL) {
        firstly {
            SpotifyManager.shared.fetchIsrcId(id: url.lastPathComponent)
        }
        .then { (track: Track) -> Promise<UIImage?> in
            self.trackName = track.name
            self.artistName = track.artists.isEmpty ? "Unknown Artist" : track.artists[0]
            self.trackIsrcId = track.isrcId
            return self.downloadImage(from: track.imageUrl)
        }
        .then { (image: UIImage?) -> Promise<Track?> in
            self.albumArt = image
            if self.trackIsrcId == nil {
                return Promise { $0.reject(IsrcMissingError()) }
            }
            return AppleMusicManager.shared.fetchTrackFromIsrcId(isrcId: self.trackIsrcId!)
        }
        .then { (track: Track?) -> Promise<[Track]> in
            if track == nil {
                return AppleMusicManager.shared.fetchTrackSearchResults(for: self.trackName!)
            }
            self.url = track!.url
            return Promise{$0.fulfill([])}
        }
        .done { (tracks: [Track]) in
            if !tracks.isEmpty {
                for track in tracks {
                    if track.name == self.trackName! && track.artists[0] == self.artistName! {
                        self.url = tracks[0].url
                        self.statusText = "Done"
                        return
                    }
                }
            }
            self.fadeOut = false
            self.statusText = "Done"
            return
        }.catch { error in
            print(error)
        }
    }
    
    private func downloadImage(from imageUrl: URL?) -> Promise<UIImage?> {
        if let url = imageUrl {
            return Promise { seal in
                AF.request(url)
                    .validate()
                    .response { response in
                        switch response.result {
                            case .success(let data):
                                seal.fulfill(UIImage(data: data!))
                            
                            case .failure(let error):
                                seal.reject(error)
                        }
                }
            }
        } else {
            return Promise { $0.fulfill(nil) }
        }
    }
    
    private enum LinkType {
        case AppleMusicTrack
        case AppleMusicAlbum
        case SpotifyTrack
        case SpotifyAlbum
        case Invalid
    }
    
    private enum Status {
        case InProgress
        case InvalidLink
        case TargetAppleMusic
        case TargetSpotify
    }
    
    struct IsrcMissingError: Error {
        var errorDescription = "Isrc code missing"
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct TrackDetails: View {
    
    @Binding var albumArt: UIImage?
    @Binding var trackName: String?
    @Binding var artistName: String?
    @Binding var url: URL?
    
    var body: some View {
        VStack() {
            Image(uiImage: self.albumArt!).resizable()
                .cornerRadius(10)
                .frame(width: 300, height: 300, alignment: .center)
                .padding(20)
                .animation(.easeInOut(duration: 1.0))
//            HStack {
//                Text(self.trackName!).bold()
//                    .padding(10)
//                    .font(.largeTitle)
//
//
//                Spacer()
//            }.animation(Animation.easeInOut(duration: 1.0).delay(0.5))
//            HStack {
//                Text(self.artistName!).padding(10)
//                    .font(.headline)
//
//                Spacer()
//            }.animation(Animation.easeInOut(duration: 1.0).delay(1.0))
//            //if self.url != nil {
//            HStack {
//                Button(action: {
//                    UIApplication.shared.open(self.url!)
//                }, label: {
//                    if self.status == .TargetAppleMusic {
//                        Text("Open In Apple Music").font(.headline)
//                            .padding(20)
//                    }
//                    if self.status == .TargetSpotify {
//                        Text("Open In Spotify").font(.headline)
//                            .padding(20)
//                    }
//
//                }).opacity(self.fadeOut ? 0 : 1)
//                    .animation(Animation.easeInOut(duration: 1.0).delay(1.5))
//                Spacer()
//            }
        }.frame(width: 300)
    }
}

//struct InvalidLink: View {
//    var body: some View {
//
//
//    }
//}








struct SpinnerView: View {
    @State private var animateStrokeStart = false
    @State private var animateStrokeEnd = true
    @State private var isRotating = true
    
    var body: some View {
        Circle()
            .trim(from: animateStrokeStart ? 1/3 : 1/9, to: animateStrokeEnd ? 2/5 : 1)
            .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .frame(width: 100, height: 100)
            .foregroundColor(Color(UIColor.systemGray3))
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear() {
                
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false))
                {
                    self.isRotating.toggle()
                }
                
                withAnimation(Animation.linear(duration: 1).delay(0.5).repeatForever(autoreverses: true))
                {
                    self.animateStrokeStart.toggle()
                }
                
                withAnimation(Animation.linear(duration: 1).delay(1).repeatForever(autoreverses: true))
                {
                    self.animateStrokeEnd.toggle()
                }
        }
    }
}


struct TrackData {
    var albumArt: UIImage?
    var trackName: String
    var artistName: String
    var url: URL
    
    mutating func setArtwork(image: UIImage?) {
        if image != nil {
            self.albumArt = image
        }
        else {
            self.albumArt = UIImage(systemName: "ellipsis")
        }
    }
}

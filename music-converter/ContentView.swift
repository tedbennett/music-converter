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
    @State private var trackDataStatus: TrackDataStatus = .BothInBackground
    
    // Cache track data before transition
    @State private var albumArt: UIImage?
    @State private var trackName: String?
    @State private var artistName: String?
    @State private var albumName: String?
    @State private var trackIsrcId: String?
    @State private var url: URL?
    
    
    @State private var trackDataA : TrackData?
    @State private var trackDataB : TrackData?
    
    enum TrackDataStatus {
        case AInForeground
        case AInBackground
        case BothInBackground
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if self.status == .InProgress {
                    ZStack {
                        SpinnerView()
                        Image("switchit-icon").resizable().frame(width: 60, height: 50)
                    }
                }
                if (self.status == .TargetAppleMusic || self.status == .TargetSpotify) && self.trackDataStatus != .BothInBackground {
                    if self.trackDataStatus == .AInForeground {
                        VStack {
                            Spacer().frame(width: 0, height: 0)
                            TrackDetails(track: self.$trackDataA, status: self.$status)
                        }.frame(width:  geometry.size.width).transition(AnyTransition.slide.combined(with: AnyTransition.opacity.animation(.easeInOut(duration: 0.8))))
                    }
                    else {
                        VStack {
                            TrackDetails(track: self.$trackDataB, status: self.$status)
                        }.frame(width:  geometry.size.width).transition(AnyTransition.slide.combined(with: AnyTransition.opacity.animation(.easeInOut(duration: 0.8))))
                    }
                }
                
                if self.status == .InvalidLink {
                    VStack {
                        Text("Oops!").font(.largeTitle).padding(20)
                        Text("SwitchIt can't find a music link in your clipboard").font(.headline).padding(20)
                            .multilineTextAlignment(.center)
                        Text("Copy an 'open.spotify.com' or 'music.apple.com' song link").font(.subheadline).foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }.frame(width:350)
                    
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if self.cachedClipboardString == UIPasteboard.general.string {
                return
            }
            AppleMusicManager.shared.authorize().then { () -> Promise<Void> in
                SpotifyManager.shared.authorize()
            }.then { () -> Promise<Void> in
                
                self.albumArt = nil
                self.artistName = nil
                self.albumName = nil
                self.trackName = nil
                self.trackIsrcId = nil
                self.url = nil
                
                return self.convertClipboardLink(UIPasteboard.general.string)
            }.done {
                if self.trackDataStatus != .AInForeground {
                    self.trackDataA = TrackData(albumArt: self.albumArt, trackName: self.trackName!, artistName: self.artistName!, albumName: self.albumName!, url: self.url!)
                    self.trackDataStatus = .AInForeground
                } else {
                    self.trackDataB = TrackData(albumArt: self.albumArt, trackName: self.trackName!, artistName: self.artistName!, albumName: self.albumName!, url: self.url!)
                    self.trackDataStatus = .AInBackground
                }
                
            }.catch { error in
                print(error)
            }
        }
    }
    
    
    private func convertClipboardLink(_ link: String?) -> Promise<Void> {
        cachedClipboardString = link
        let linkType = checkLinkValid(link)
        switch linkType {
            case .SpotifyTrack:
                status = .TargetAppleMusic
                return getTrackFromAppleMusic(URL(string: link!)!)
            case .SpotifyAlbum:
                status = .TargetAppleMusic
                return Promise { $0.reject(LinkMissingError())} //getAlbumFromAppleMusic(link)
            case .AppleMusicTrack:
                status = .TargetSpotify
                return getTrackFromSpotify(URL(string: link!)!)
            case .AppleMusicAlbum:
                status = .TargetSpotify
                return Promise { $0.reject(LinkMissingError())}//getAlbumFromSpotify(link)
            case .Invalid:
                status = .InvalidLink
                return Promise { $0.reject(LinkMissingError()) }
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
    
    private func getTrackFromSpotify(_ url: URL) -> Promise<Void> {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let id = components!.queryItems!.first(where: { $0.name == "i"})!.value!
        
        return AppleMusicManager.shared.fetchIsrcId(id: id)
            .then { (track: Track) -> Promise<UIImage?> in
                self.trackName = track.name
                self.artistName = track.artists.isEmpty ? "Unknown Artist" : track.artists[0]
                self.albumName = track.albumName
                self.trackIsrcId = track.isrcId
                return self.downloadImage(from: track.imageUrl)
        }
        .then { (image: UIImage?) -> Promise<Track?> in
            self.albumArt = image
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
        .then { (tracks: [Track]) -> Promise<Void> in
            if !tracks.isEmpty {
                for track in tracks {
                    if track.name == self.trackName! && track.artists[0] == self.artistName! {
                        self.url = tracks[0].url
                        return Promise { $0.fulfill(()) }
                    }
                }
            }
            return Promise { $0.fulfill(()) }
        }
    }
    
    private func getTrackFromAppleMusic(_ url: URL) -> Promise<Void> {
        firstly {
            SpotifyManager.shared.fetchIsrcId(id: url.lastPathComponent)
        }
        .then { (track: Track) -> Promise<UIImage?> in
            self.trackName = track.name
            self.artistName = track.artists.isEmpty ? "Unknown Artist" : track.artists[0]
            self.albumName = track.albumName
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
        .then { (tracks: [Track]) -> Promise<Void> in
            if !tracks.isEmpty {
                for track in tracks {
                    if track.name == self.trackName! && track.artists[0] == self.artistName! {
                        self.url = tracks[0].url
                        return Promise { $0.fulfill(()) }
                    }
                }
            }
            self.statusText = "Done"
            return Promise { $0.fulfill(()) }
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
    
    struct IsrcMissingError: Error {
        var errorDescription = "Isrc code missing"
    }
    
    struct LinkMissingError: Error {
        var errorDescription = "link missing"
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

enum Status {
    case InProgress
    case InvalidLink
    case TargetAppleMusic
    case TargetSpotify
}

struct TrackDetails: View {
    @Binding var track: TrackData?
    @Binding var status: Status
    
    mutating func setArtwork(image: UIImage?) {
        if image != nil {
            self.track!.albumArt = image
        }
        else {
            self.track!.albumArt = UIImage(systemName: "camera")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Image(uiImage: self.track!.albumArt!).resizable()
                .cornerRadius(10)
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(1.0, contentMode: .fit)
                .animation(.easeInOut(duration: 0.7))
            
            Text(self.track!.trackName).bold()
                .padding(10)
                .font(.largeTitle)
                .animation(Animation.easeInOut(duration: 0.7).delay(0.3))
            
            Text(self.track!.albumName).padding(10)
                .font(.headline)
                .animation(Animation.easeInOut(duration: 0.7).delay(0.6))
            
            Text(self.track!.artistName).padding(10)
                .font(.headline)
                .animation(Animation.easeInOut(duration: 0.7).delay(0.9)).padding(.bottom, 10)
            
            Button(action: {
                UIApplication.shared.open(self.track!.url)
            }, label: {
                if self.status == .TargetAppleMusic {
                    Text("Open In Apple Music").font(Font(UIFont(name: "HelveticaNeue-Bold", size: 20)!)).frame(minWidth: 0, maxWidth: .infinity)
                    
                }
                if self.status == .TargetSpotify {
                    Text("Open In Spotify").font(Font(UIFont(name: "HelveticaNeue-Bold", size: 20)!)).frame(minWidth: 0, maxWidth: .infinity)
                    
                }
                
            }).padding(20)
                .foregroundColor(Color(.systemBackground))
                .background(Color(.label))
                .cornerRadius(20)
                .animation(Animation.easeInOut(duration: 0.7).delay(1.2))
            
        }.frame(width: 300)
    }
}


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
    var albumName: String
    var url: URL
}

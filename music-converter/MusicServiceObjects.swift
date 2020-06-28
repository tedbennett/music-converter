//
//  MusicServiceObjects.swift
//  music-converter
//
//  Created by Ted Bennett on 28/06/2020.
//  Copyright © 2020 Ted Bennett. All rights reserved.
//

import Foundation

struct Track {
    var id: String
    var name: String
    var artists: [String]
    var albumName: String
    var url: URL?
    var imageUrl: URL?
    var isrcId: String?
}

struct SpotifySimpleAlbum: Decodable {
    var albumType: String?
    var artists: [SpotifySimpleArtist]
    var availableMarkets: [String]
    var externalUrls: SpotifyExternalUrl
    var href: URL?
    var id: String?
    var images: [SpotifyImage]
    var name: String
    var releaseDate: String?
    var releaseDatePrecision: String?
    var type: String
    var uri: String?
    
    private enum CodingKeys : String, CodingKey {
        case albumType = "album_type",
        availableMarkets = "available_markets",
        externalUrls = "external_urls",
        releaseDate = "release_date",
        releaseDatePrecision = "release_date_precision",
        artists,
        href,
        id,
        images,
        name,
        type,
        uri
    }
}

struct SpotifyArtist: Decodable {
    var externalUrls: SpotifyExternalUrl
    var genres: [String]
    var href: URL
    var id: String
    var images: [SpotifyImage]
    var name: String
    var popularity: Int
    var type: String
    var uri: String
    
    private enum CodingKeys : String, CodingKey {
        case externalUrls = "external_urls",
        genres,
        href,
        id,
        images,
        name,
        popularity,
        type,
        uri
    }
}

struct SpotifySimpleArtist: Decodable {
    var externalUrls: SpotifyExternalUrl
    var href: URL?
    var id: String?
    var name: String
    var type: String
    var uri: String?
    
    private enum CodingKeys : String, CodingKey {
        case externalUrls = "external_urls",
        href,
        id,
        name,
        type,
        uri
    }
}

struct SpotifyTrack: Decodable {
    var album: SpotifySimpleAlbum
    var artists: [SpotifySimpleArtist]
    var availableMarkets: [String]
    var discNumber: Int
    var durationMs: Int
    var explicit: Bool
    var externalIds: SpotifyExternalId?
    var externalUrls: SpotifyExternalUrl
    var href: URL?
    var id: String?
    var name: String
    var popularity: Int
    var previewUrl: URL?
    var trackNumber: Int
    var type: String
    var uri: String
    var isLocal: Bool
    
    private enum CodingKeys : String, CodingKey {
        case availableMarkets = "available_markets",
        externalUrls = "external_urls",
        externalIds = "external_ids",
        discNumber = "disc_number",
        durationMs = "duration_ms",
        previewUrl = "preview_url",
        trackNumber = "track_number",
        isLocal = "is_local",
        album,
        artists,
        explicit,
        href,
        id,
        name,
        popularity,
        type,
        uri
    }
}

extension Track {
    init(fromSpotify response: SpotifyTrack) {
        let id = response.id ?? UUID().uuidString
        let name = response.name
        let url = response.externalUrls.spotify
        let imageUrl = response.album.images.first?.url
        let artists = response.artists.map { $0.name }
        let albumName = response.album.name
        let isrcId = response.externalIds?.isrc
        
        self.init(id: id, name: name, artists: artists, albumName: albumName, url: url, imageUrl: imageUrl, isrcId: isrcId)
    }
}

struct SpotifyExternalId: Decodable {
    var isrc: String?
}

struct SpotifyExternalUrl: Decodable {
    var spotify: URL?
}

struct SpotifyImage: Decodable {
    var height: Int?
    var width: Int?
    var url: URL
}

struct SpotifyPagingObject<Object: Decodable>: Decodable {
    var href: URL
    var items: [Object]
    var limit: Int
    var next: URL?
    var offset: Int
    var previous: URL?
    var total: Int
}

struct SpotifySearch: Decodable {
    var albums: SpotifyPagingObject<SpotifySimpleAlbum>?
    var artists: SpotifyPagingObject<SpotifyArtist>?
    //var playlists: SpotifyPagingObject<SpotifyPlaylist>?
    var tracks: SpotifyPagingObject<SpotifyTrack>?
}

protocol AppleMusicRelationship: Decodable {
    associatedtype Object
    var data: [Object] { get set }
    var href: URL? { get set }
    var next: URL? { get set }
}

protocol AppleMusicResource: Decodable {
    associatedtype Relationships
    associatedtype Attributes
    
    var relationships: Relationships? { get set }
    var attributes: Attributes? { get set }
    var type: String { get set }
    var href: URL? { get set }
    var id: String { get set }
}

struct AppleMusicSearchResponse: Decodable {
    var results: SearchResults
    
    struct SearchResults: Decodable {
        var albums: AppleMusicResponse<AppleMusicAlbum>?
        var artists: AppleMusicResponse<AppleMusicArtist>?
        //var playlists: AppleMusicResponse<AppleMusicPlaylist>?
        var songs: AppleMusicResponse<AppleMusicSong>?
    }
    
}


struct AppleMusicResponse<Object: AppleMusicResource>: Decodable {
    var data: [Object]
    var next: URL?
}

struct AppleMusicSong: AppleMusicResource {
    
    var relationships: Relationships?
    var attributes: Attributes?
    var type: String
    var href: URL?
    var id: String
    
    struct Relationships: Decodable {
        var albums: AlbumRelationship?
        var artists: ArtistRelationship?
    }
    
    struct Attributes: Decodable {
        var albumName: String
        var artistName: String
        var artwork: AppleMusicArtwork
        var composerName: String?
        var contentRating: String?
        var discNumber: Int
        var durationInMillis: Int?
        var editorialNotes: AppleMusicEditorialNotes?
        var genreNames: [String]
        var isrc: String
        var movementCount: Int?
        var movementName: String?
        var movementNumber: Int?
        var name: String
        var playParams: AppleMusicPlayParams?
        var previews: [AppleMusicPreview]
        var releaseDate: String
        var trackNumber: Int
        var url: URL
        var workName: String?
    }
}

struct AppleMusicAlbum: AppleMusicResource {
    var relationships: Relationships?
    var attributes: Attributes?
    var type: String
    var href: URL?
    var id: String
    
    struct Relationships: Decodable {
        var tracks: SongRelationship
        var artist: ArtistRelationship
    }
    
    struct Attributes: Decodable {
        var albumName: String
        var artistName: String
        var artwork: AppleMusicArtwork?
        var contentRating: String?
        var copyright: String?
        var editorialNotes: AppleMusicEditorialNotes?
        var genreNames: [String]
        var isComplete: Bool
        var isSingle: Bool
        var name: String
        var playParams: AppleMusicPlayParams?
        var recordLabel: String
        var releaseDate: String
        var trackCount: Int
        var url: URL
        var isMasteredForItunes: Bool
    }
}

struct AppleMusicArtist: AppleMusicResource {
    var relationships: Relationships?
    var attributes: Attributes?
    var type: String
    var href: URL?
    var id: String
    
    struct Relationships: Decodable {
        var albums: AlbumRelationship
    }
    
    struct Attributes: Decodable {
        var editorialNotes: AppleMusicEditorialNotes?
        var genreNames: [String]
        var name: String
        var url: URL
    }
}

struct AppleMusicArtwork: Decodable {
    var bgColor: String?
    var height: Int?
    var width: Int?
    var textColor1: String?
    var textColor2: String?
    var textColor3: String?
    var textColor4: String?
    var url: String
}

struct AppleMusicPreview: Decodable {
    var artwork: AppleMusicArtwork?
    var url: URL
}

struct AppleMusicEditorialNotes: Decodable {
    var short: String?
    var standard: String?
}

struct AppleMusicPlayParams: Decodable {
    var id: String
    var kind: String
    var catalogId: String?
    var globalId: String?
    var isLibrary: Bool?
}

struct SongRelationship: AppleMusicRelationship {
    var data: [AppleMusicSong]
    var href: URL?
    var next: URL?
}

struct AlbumRelationship: AppleMusicRelationship {
    var data: [AppleMusicAlbum]
    var href: URL?
    var next: URL?
}

struct ArtistRelationship: AppleMusicRelationship {
    var data: [AppleMusicArtist]
    var href: URL?
    var next: URL?
}

extension Track {
    init(fromAppleMusic response: AppleMusicSong) {
        let id = response.id
        let name = response.attributes!.name
        let url = response.attributes!.url
        let artists = [response.attributes!.artistName]
        let albumName = response.attributes!.albumName
        let isrc = response.attributes!.isrc
        var imageUrl: URL?
        if let artwork = response.attributes?.artwork {
            let imageUrlString = artwork.url.replacingOccurrences(of: "{w}", with: String(640))
                .replacingOccurrences(of: "{h}", with: String(640))
            imageUrl = URL(string: imageUrlString)
        }
        
        self.init(id: id, name: name, artists: artists, albumName: albumName, url: url, imageUrl: imageUrl, isrcId: isrc)
    }
}

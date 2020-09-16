# Switch-It

An iOS app to convert song links between Spotify and Apple Music.

Given it's simple functionality, I don't think this will be able to be distributed on the App Store, but it will be part of my larger [music-manager](https://github.com/tedbennett/music-manager) app.

## Description


Simply copy a song link, open Switch-It, and the app will search the other music service's library to obtain a link to the song.

This is a spin off from my music-manager app, to help me polish things off before dealing with larger issues with playlist transfers.

This app uses PromiseKit, AlamoFire and Firebase. It consumes the Apple Music and Spotify API's.

## To-Do

* Rework Animations
  * I found a bug in some transitions and animations not firing (opaque and slide combined) which required a messy work-around.
* Give more information when a search or auth fails
* Use Spotify/Apple Music players to play a snippet of the song

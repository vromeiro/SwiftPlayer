//
//  HysteriaManager.swift
//  Pods
//
//  Created by Vinicius Romeiro on 1/15/16.
//
//

import UIKit
import Foundation
import MediaPlayer
import HysteriaPlayer


import Foundation
import MediaPlayer
import HysteriaPlayer

// MARK: - HysteriaManager
class HysteriaManager: NSObject {

  static let sharedInstance = HysteriaManager()
  lazy var hysteriaPlayer = HysteriaPlayer.sharedInstance()

  var logs = true
  var queue = PlayerQueue()
  var delegate: SwiftPlayerDelegate?
  var controller: UIViewController?
  var queueDelegate: SwiftPlayerQueueDelegate?

  private let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
  private var isClicked = false
  private var lastIndexClicked = -1
  private var lastIndexShuffle = -1


  private override init() {
    super.init()
    initHysteriaPlayer()
  }

  private func initHysteriaPlayer() {
    hysteriaPlayer.delegate = self;
    hysteriaPlayer.datasource = self;
    hysteriaPlayer.enableMemoryCached(false)
    enableCommandCenter()

  }
}


// MARK: - HysteriaManager - UI
extension HysteriaManager {
  private func currentTime() {
    hysteriaPlayer.addPeriodicTimeObserverForInterval(CMTimeMake(100, 1000), queue: nil, usingBlock: {
      time in
      let totalSeconds = CMTimeGetSeconds(time)
      self.delegate?.playerCurrentTimeChanged(Float(totalSeconds))
    })
  }

  private func updateCurrentItem() {
    infoCenterWithTrack(currentItem())

    let duration = hysteriaPlayer.getPlayingItemDurationTime()
    if duration > 0 {
      delegate?.playerDurationTime(duration)
    }
  }

}


// MARK: - HysteriaManager - MPNowPlayingInfoCenter
extension HysteriaManager {

  func updateImageInfoCenter(image: UIImage) {
    if var dictionary = MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo {
      dictionary[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
    }
  }

  private func infoCenterWithTrack(track: PlayerTrack?) {
    guard let track = track else { return }

    var dictionary: [String : AnyObject] = [
      MPMediaItemPropertyAlbumTitle: "",
      MPMediaItemPropertyArtist: "",
      MPMediaItemPropertyPlaybackDuration: NSTimeInterval(hysteriaPlayer.getPlayingItemDurationTime()),
      MPMediaItemPropertyTitle: ""]

    if let albumName = track.album?.name {
      dictionary[MPMediaItemPropertyAlbumTitle] = albumName
    }
    if let artistName = track.artist?.name {
      dictionary[MPMediaItemPropertyArtist] = artistName
    }
    if let name = track.name {
      dictionary[MPMediaItemPropertyTitle] = name
    }
    if let image = track.image,
      let loaded = imageFromString(image) {
        dictionary[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: loaded)
    }

    MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = dictionary
  }

  private func imageFromString(imagePath: String) -> UIImage? {
    let detectorr = try! NSDataDetector(types: NSTextCheckingType.Link.rawValue)
    let matches = detectorr.matchesInString(imagePath, options: [], range: NSMakeRange(0, imagePath.characters.count))

    for match in matches {
      let url = (imagePath as NSString).substringWithRange(match.range)
      if let data = NSData(contentsOfURL: NSURL(string: url)!) {
        return UIImage(data: data)
      }
    }

    if let data = NSData(contentsOfFile: imagePath) {
      let image = UIImage(data: data)
      return image
    }

    return nil
  }
}


// MARK: - HysteriaManager - Remote Control Events
extension HysteriaManager {
  private func enableCommandCenter() {
    commandCenter.playCommand.addTargetWithHandler { _ in
      self.play()
      return MPRemoteCommandHandlerStatus.Success
    }

    commandCenter.pauseCommand.addTargetWithHandler { _ in
      self.pause()
      return MPRemoteCommandHandlerStatus.Success
    }

    commandCenter.nextTrackCommand.addTargetWithHandler { _ in
      self.next()
      return MPRemoteCommandHandlerStatus.Success
    }

    commandCenter.previousTrackCommand.addTargetWithHandler { _ in
      self.previous()
      return MPRemoteCommandHandlerStatus.Success
    }
  }
}


// MARK: - HysteriaManager - Actions
extension HysteriaManager {

  // Play Methods
  func play() {
    if !hysteriaPlayer.isPlaying() {
      hysteriaPlayer.play()
    }
  }

  func playAtIndex(index: Int) {
    fetchAndPlayAtIndex(index)
  }

  func playAllTracks() {
    fetchAndPlayAtIndex(0)
  }

  func pause() {
    if hysteriaPlayer.isPlaying() {
      hysteriaPlayer.pause()
    }
  }

  func next() {
    hysteriaPlayer.playNext()
  }

  func previous() {
    if let index = currentIndex() {
      queue.reorderQueuePrevious(index - 1, reorderHysteria: reorderHysteryaQueue())
      hysteriaPlayer.playPrevious()
    }
  }

  // Shuffle Methods
  func shuffleStatus() -> Bool {
    switch hysteriaPlayer.getPlayerShuffleMode() {
    case .On:
      return true
    case .Off:
      return false
    }
  }

  func enableShuffle() {
    hysteriaPlayer.setPlayerShuffleMode(.On)
  }

  func disableShuffle() {
    hysteriaPlayer.setPlayerShuffleMode(.Off)
  }

  // Repeat Methods
  func repeatStatus() -> (Bool, Bool, Bool) {
    switch hysteriaPlayer.getPlayerRepeatMode() {
    case .On:
      return (true, false, false)
    case .Once:
      return (false, true, false)
    case .Off:
      return (false, false, true)
    }
  }

  func enableRepeat() {
    hysteriaPlayer.setPlayerRepeatMode(.On)
  }

  func enableRepeatOne() {
    hysteriaPlayer.setPlayerRepeatMode(.Once)
  }

  func disableRepeat() {
    hysteriaPlayer.setPlayerRepeatMode(.Off)
  }

  func seekTo(slider: UISlider) {
    let duration = hysteriaPlayer.getPlayingItemDurationTime()
    if isfinite(duration) {
      let minValue = slider.minimumValue
      let maxValue = slider.maximumValue
      let value = slider.value

      let time = duration * (value - minValue) / (maxValue - minValue)
      hysteriaPlayer.seekToTime(Double(time))
    }
  }
}


// MARK: - Hysteria Playlist
extension HysteriaManager {
  func setPlaylist(playlist: [PlayerTrack]) {
    var nPlaylist = [PlayerTrack]()
    for (index, track) in playlist.enumerate() {
      var nTrack = track
      nTrack.position = index
      nPlaylist.append(nTrack)
    }
    queue.mainQueue = nPlaylist
  }

  func addPlayNext(track: PlayerTrack) {
    if logs {print("• player track added :track >> \(track)")}
    var nTrack = track
    nTrack.origin = TrackType.Next
    if let index = currentIndex() {
      queue.newNextTrack(nTrack, nowIndex: index)
      updateCount()
    }
  }

  private func addHistoryTrack(track: PlayerTrack) {
    queue.history.append(track)
  }

  func playMainAtIndex(index: Int) {
    if let qIndex = queue.indexToPlayAt(index) {
      if queue.nextQueue.count > 0 {
        lastIndexClicked = currentIndex()!
      }
      fetchAndPlayAtIndex(qIndex)
      isClicked = true
    }
  }

  func playNextAtIndex(index: Int) {
    if index == 0 {
      next()
      return
    }
    if let qIndex = queue.indexToPlayNextAt(index, nowIndex: currentIndex()!) {
      updateCount()
      fetchAndPlayAtIndex(qIndex)
    }
  }

  private func reorderHysteryaQueue() -> (from: Int, to: Int) -> Void {
    let closure: (from: Int, to: Int) -> Void = { from, to in
      self.hysteriaPlayer.moveItemFromIndex(from, toIndex: to)
    }
    return closure
  }
}


// MARK: - Hysteria Utils
extension HysteriaManager {
  private func updateCount() {
    hysteriaPlayer.itemsCount = hysteriaPlayerNumberOfItems()
  }

  private func currentItem() -> PlayerTrack? {
    if let index: NSNumber = hysteriaPlayer.getHysteriaIndex(hysteriaPlayer.getCurrentItem()) {
      let track = queue.trackAtIndex(Int(index))
      addHistoryTrack(track)
      return track
    }
    return nil
  }

  func currentItem() -> AVPlayerItem! {
    return hysteriaPlayer.getCurrentItem()
  }

  func currentIndex() -> Int? {
    if let index = hysteriaPlayer.getHysteriaIndex(hysteriaPlayer.getCurrentItem()) {
      return Int(index)
    }
    return nil
  }

  private func fetchAndPlayAtIndex(index: Int) {
    hysteriaPlayer.fetchAndPlayPlayerItem(index)
  }

  func playingItemDurationTime() -> Float {
    return hysteriaPlayer.getPlayingItemDurationTime()
  }

  func volumeViewFrom(view: UIView) -> MPVolumeView! {
    return MPVolumeView(frame: view.bounds)
  }
}


// MARK: - HysteriaPlayerDataSource
extension HysteriaManager: HysteriaPlayerDataSource {
  func hysteriaPlayerNumberOfItems() -> Int {
    return queue.totalTracks()
  }

  func hysteriaPlayerAsyncSetUrlForItemAtIndex(index: Int, preBuffer: Bool) {
    if preBuffer { return }

    if isClicked && lastIndexClicked != -1 {
      isClicked = false
      fetchAndPlayAtIndex(lastIndexClicked + 1)
      lastIndexClicked = -1
      return
    }

    if shuffleStatus() == true {
      if lastIndexShuffle != -1 {
        queue.removeNextAtIndex(lastIndexShuffle)
        hysteriaPlayer.removeItemAtIndex(lastIndexShuffle)
        lastIndexShuffle = -1
      }

      if let indexShufle = queue.indexForShuffle() {
        lastIndexShuffle = indexShufle
        hysteriaPlayer.setupPlayerItemWithUrl(NSURL(string: queue.trackAtIndex(indexShufle).url)!, index: indexShufle)
        return
      }
    }

    guard let track = queue.queueAtIndex(index) else {
      hysteriaPlayer.removeItemAtIndex(index - 1)
      fetchAndPlayAtIndex(index - 1)
      return
    }

    hysteriaPlayer.setupPlayerItemWithUrl(NSURL(string: track.url)!, index: index)
  }
}


// MARK: - HysteriaPlayerDelegate
extension HysteriaManager: HysteriaPlayerDelegate {

  func hysteriaPlayerWillChangedAtIndex(index: Int) {
    if logs {print("• player will changed :atindex >> \(index)")}
  }

  func hysteriaPlayerCurrentItemChanged(item: AVPlayerItem!) {
    if logs {print("• current item changed :item >> \(item)")}
    delegate?.playerCurrentTrackChanged(currentItem())
    queueDelegate?.queueUpdated()
    updateCurrentItem()
  }

  func hysteriaPlayerRateChanged(isPlaying: Bool) {
    if logs {print("• player rate changed :isplaying >> \(isPlaying)")}
    delegate?.playerRateChanged(isPlaying)
  }

  func hysteriaPlayerDidReachEnd() {
    if logs {print("• player did reach end")}
  }

  func hysteriaPlayerCurrentItemPreloaded(time: CMTime) {
    if logs {print("• current item preloaded :time >> \(CMTimeGetSeconds(time))")}
  }

  func hysteriaPlayerDidFailed(identifier: HysteriaPlayerFailed, error: NSError!) {
    if logs {print("• player did failed :error >> \(error.description)")}
    switch identifier {
    case .CurrentItem: next()
      break
    case .Player:
      break
    }
  }

  func hysteriaPlayerReadyToPlay(identifier: HysteriaPlayerReadyToPlay) {
    if logs {print("• player ready to play")}
    switch identifier {
    case .CurrentItem: updateCurrentItem()
      break
    case .Player: currentTime()
      break
    }
  }

  func hysteriaPlayerItemFailedToPlayEndTime(item: AVPlayerItem!, error: NSError!) {
    if logs {print("• item failed to play end time :error >> \(error.description)")}
  }

  func hysteriaPlayerItemPlaybackStall(item: AVPlayerItem!) {
    if logs {print("• item playback stall :item >> \(item)")}
  }

}

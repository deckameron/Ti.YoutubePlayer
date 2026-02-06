# Ti.YoutubePlayer

A native Titanium module for iOS that enables inline YouTube video playback without forcing the native iOS player. Built with  [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit).

![Titanium](https://img.shields.io/badge/Titanium-13.0+-red.svg) ![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg) ![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Maintained](https://img.shields.io/badge/Maintained-Yes-green.svg)

<p align="center">
  <img src="https://github.com/deckameron/Ti.YoutubePlayer/blob/main/assets/screenshot_1.png?raw=true"
       width="300"
       alt="screenshot_1" />
  <img src="https://github.com/deckameron/Ti.YoutubePlayer/blob/main/assets/screenshot_2.png?raw=true"
       width="300"
       alt="screenshot_2" />
</p>

### Roadmap

- [x] iOS support
- [ ] Android support

## Features

-   ✅ Inline playback (no forced fullscreen)
-   ✅ Configurable autoplay and loop
-   ✅ Mute/unmute control
-   ✅ Video quality control
-   ✅ Adjustable playback speed (0.25x - 2x)
-   ✅ Seek to any point in the video
-   ✅ Detailed state and metadata events
-   ✅ No native iOS controls
-   ✅ Caption support
-   ✅ Modern async API

## 📋 Requirements

-   Titanium SDK 13.0.0+
-   iOS 14.0+


## Installation

### 1. Download the Module

Download the latest version from the [releases page](https://github.com/deckameron/Ti.YoutubePlayer/releases).


### 2. Install the module in your Titanium project

```bash
# Copy the compiled module to:
{YOUR_PROJECT}/modules/iphone/
```

### 3. Configure tiapp.xml

Add the module to your `tiapp.xml`:

```xml
<modules>
    <module platform="iphone">ti.youtubeplayer</module>
</modules>
```

### Permissions

Add microphone permission to `tiapp.xml` for recording:

```xml
<ios>
    <plist>
        <dict>
            <key>NSAllowsArbitraryLoadsInWebContent</key>
            <true/>
        </dict>
    </plist>
</ios>
```

## Basic Usage

```javascript
const YouTubePlayer = require('ti.youtubeplayer');

const player = YouTubePlayer.createPlayerView({
    videoId: 'dQw4w9WgXcQ',
    autoplay: true,
    loop: true,
    showControls: false,
    muted: true,
    preferredQuality: YouTubePlayer.PLAYBACK_QUALITY_HIGH_RESOLUTION,
    width: Ti.UI.FILL,
    height: 300,
    backgroundColor: '#000'
});

win.add(player);

```

## Complete API

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `videoId` | String | **required** | YouTube video ID |
| `scalingMode` | String | `true` | `'SCALING_ASPECT_FIT'` or `'SCALING_ASPECT_FILL'` |
| `loop` | Boolean | `true` | Loop playback |
| `showControls` | Boolean | `false` | Show YouTube controls |
| `muted` | Boolean | `true` | Start muted |
| `showCaptions` | Boolean | `false` | Show captions |
| `showFullscreenButton` | Boolean | `false` | Show fullscreen button |
| `preferredQuality` | String | `'hd1080'` | Preferred quality (`'small'`, `'medium'`, `'large'`, `'hd720'`, `'hd1080'`, `'highres'`) |
| `autoplay` | Boolean | `true` | Start playback automatically |

**Note:** All standard `Ti.UI.View` properties also work (`width`, `height`, `top`, `left`, `backgroundColor`, etc.)

### Constants
#### Quality
- PLAYBACK_QUALITY_AUTO
- PLAYBACK_QUALITY_SMALL
- PLAYBACK_QUALITY_MEDIUM
- PLAYBACK_QUALITY_HD720
- PLAYBACK_QUALITY_HD1080
- PLAYBACK_QUALITY_HIGH_RESOLUTION
#### Scaling Aspects
- SCALING_ASPECT_FILL
- SCALING_ASPECT_FIT

### Methods

#### `play()`

Starts video playback.

```javascript
player.play();

```

----------

#### `pause()`

Pauses video playback.

```javascript
player.pause();

```

----------

#### `stop()`

Stops video playback completely.

```javascript
player.stop();

```

----------

#### `mute()`

Mutes the video audio.

```javascript
player.mute();

```

----------

#### `unmute()`

Unmutes the video audio.

```javascript
player.unmute();

```

----------

#### `isMuted()`

Returns whether the player is muted.

```javascript
const muted = player.isMuted();
Ti.API.info('Muted: ' + muted);

```

**Returns:**  `Boolean`

----------

#### `seek(seconds)`

Seeks to a specific point in the video.

```javascript
// Jump to 30 seconds
player.seek(30);

// Jump to 1 minute 30 seconds
player.seek(90);

```

**Parameters:**

-   `seconds`  (Number): Position in seconds

----------

#### `getDuration(callback)`

Gets the total video duration.

```javascript
player.getDuration(function(e) {
    Ti.API.info('Duration: ' + e.duration + ' seconds');
});

```

**Callback returns:**

-   `duration`  (Number): Duration in seconds

----------

#### `getCurrentTime(callback)`

Gets the current playback time.

```javascript
player.getCurrentTime(function(e) {
    Ti.API.info('Current time: ' + e.currentTime + ' seconds');
});

```

**Callback returns:**

-   `currentTime`  (Number): Current time in seconds

----------

#### `setPlaybackRate(rate)`

Sets the playback speed.

```javascript
// Normal speed
player.setPlaybackRate(1.0);

// 1.5x faster
player.setPlaybackRate(1.5);

// 0.5x slower
player.setPlaybackRate(0.5);

```

**Parameters:**

-   `rate`  (Number): Speed (valid values:  `0.25`,  `0.5`,  `0.75`,  `1.0`,  `1.25`,  `1.5`,  `1.75`,  `2.0`)

----------

#### `changeVideo(videoId)`

Changes the current video.

```javascript
player.changeVideo('dQw4w9WgXcQ');

```

**Parameters:**

-   `videoId`  (String): New video ID

----------

#### `loadVideo(params)`

Loads and plays a new video.

```javascript
player.loadVideo({
    videoId: 'dQw4w9WgXcQ',
    startSeconds: 10  // Optional: start at 10 seconds
});

```

**Parameters:**

-   `videoId`  (String): Video ID
-   `startSeconds`  (Number, optional): Start time in seconds

----------

#### `cueVideo(params)`

Loads a video without starting playback.

```javascript
player.cueVideo({
    videoId: 'dQw4w9WgXcQ',
    startSeconds: 10  // Optional
});

```

**Parameters:**

-   `videoId`  (String): Video ID
-   `startSeconds`  (Number, optional): Start time in seconds

----------

#### `reload()`

Reloads the current player.

```javascript
player.reload();

```

----------

#### `setPlaybackQuality(quality)`

Sets playback quality (not guaranteed by YouTube).

```javascript
player.setPlaybackQuality('hd1080');
// or
player.setPlaybackQuality(player.PLAYBACK_QUALITY_HD1080);

```

----------

#### `getAvailableQualityLevels(callback)`

Gets available qualities for the current video.

```javascript
player.getAvailableQualityLevels(function(e) {
    Ti.API.info('Available qualities: ' + JSON.stringify(e.levels));
});

```

**Callback returns:**

-   `levels`  (Array): List of available qualities

----------

### Events

#### `playerStateChange`

Fired when the overall player state changes.

```javascript
player.addEventListener('playerStateChange', function(e) {
    Ti.API.info('Player state: ' + e.playerState);
});

```

**Event properties:**

-   `playerState`  (String):  `'idle'`,  `'ready'`,  `'error'`

----------

#### `playbackStateChange`

Fired when the playback state changes.

```javascript
player.addEventListener('playbackStateChange', function(e) {
    Ti.API.info('State: ' + e.state);
    Ti.API.info('Code: ' + e.code);
    Ti.API.info('Is ready: ' + e.isFullyReady);
});

```

**Event properties:**

-   `state`  (String):  `'unstarted'`,  `'ended'`,  `'playing'`,  `'paused'`,  `'buffering'`,  `'cued'`
-   `code`  (Number):  `-1`  (unstarted),  `0`  (ended),  `1`  (playing),  `2`  (paused),  `3`  (buffering),  `5`  (cued)
-   `isFullyReady`  (Boolean): Indicates if the player is completely ready to receive commands

----------

#### `playbackQualityChange`

Fired when playback quality changes.

```javascript
player.addEventListener('playbackQualityChange', function(e) {
    Ti.API.info('Quality: ' + e.quality);
});

```

----------

#### `playbackRateChange`

Fired when playback speed changes.

```javascript
player.addEventListener('playbackRateChange', function(e) {
    Ti.API.info('Playback rate: ' + e.rate);
});

```

**Event properties:**

-   `rate`  (Number): Current playback rate

----------

#### `metadataReceived`

Fired when video metadata is loaded.

```javascript
player.addEventListener('metadataReceived', function(e) {
    Ti.API.info('Title: ' + e.title);
    Ti.API.info('Author: ' + e.author);
    Ti.API.info('Video ID: ' + e.videoId);
});

```

**Event properties:**

-   `title`  (String): Video title
-   `author`  (String): Channel name
-   `videoId`  (String): Video ID

----------

#### `muteChanged`

Fired when mute state changes.

```javascript
player.addEventListener('muteChanged', function(e) {
    Ti.API.info('Muted: ' + e.muted);
});

```

**Event properties:**

-   `muted`  (Boolean):  `true`  if muted,  `false`  if unmuted

----------

#### `error`

Fired when an error occurs.

```javascript
player.addEventListener('error', function(e) {
    Ti.API.error('Error: ' + e.message);
    Ti.API.error('Code: ' + e.code);
});

```

**Event properties:**

-   `message`  (String): Error message
-   `code`  (Number): Error code

----------

## Examples

### Example 1: Player with Mute Button

```javascript
const YouTubePlayer = require('ti.youtubeplayer');

const win = Ti.UI.createWindow({
    backgroundColor: '#fff'
});

const player = YouTubePlayer.createPlayerView({
    videoId: 'dQw4w9WgXcQ',
    autoplay: true,
    loop: true,
    muted: true,
    width: Ti.UI.FILL,
    height: 300,
    top: 0
});

const muteButton = Ti.UI.createButton({
    title: '🔇',
    width: 50,
    height: 50,
    right: 10,
    top: 10,
    backgroundColor: '#000',
    opacity: 0.7,
    borderRadius: 25
});

muteButton.addEventListener('click', function() {
    if (player.isMuted()) {
        player.unmute();
    } else {
        player.mute();
    }
});

player.addEventListener('muteChanged', function(e) {
    muteButton.title = e.muted ? '🔇' : '🔊';
});

win.add(player);
win.add(muteButton);
win.open();

```

----------

### Example 2: Video Playlist

```javascript
const YouTubePlayer = require('ti.youtubeplayer');

const videos = ['dQw4w9WgXcQ', 'kJQP7kiw5Fk', 'L_jWHffIx5E'];
let currentIndex = 0;

const player = YouTubePlayer.createPlayerView({
    videoId: videos[0],
    autoplay: true,
    loop: false,
    width: Ti.UI.FILL,
    height: 300
});

player.addEventListener('playbackStateChange', function(e) {
    if (e.state === 'ended') {
        currentIndex = (currentIndex + 1) % videos.length;
        player.changeVideo(videos[currentIndex]);
    }
});

win.add(player);

```

----------

### Example 3: Custom Controls

```javascript
const YouTubePlayer = require('ti.youtubeplayer');

const player = YouTubePlayer.createPlayerView({
    videoId: 'dQw4w9WgXcQ',
    autoplay: false,
    showControls: false,
    width: Ti.UI.FILL,
    height: 300
});

const controlsView = Ti.UI.createView({
    height: 60,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.7)'
});

const playButton = Ti.UI.createButton({
    title: '▶️',
    left: 10,
    width: 50
});

const pauseButton = Ti.UI.createButton({
    title: '⏸',
    left: 70,
    width: 50
});

const progressLabel = Ti.UI.createLabel({
    text: '0:00 / 0:00',
    right: 10,
    color: '#fff'
});

playButton.addEventListener('click', function() {
    player.play();
});

pauseButton.addEventListener('click', function() {
    player.pause();
});

// Update progress every second
setInterval(function() {
    player.getCurrentTime(function(e) {
        player.getDuration(function(d) {
            const current = Math.floor(e.currentTime);
            const total = Math.floor(d.duration);
            progressLabel.text = formatTime(current) + ' / ' + formatTime(total);
        });
    });
}, 1000);

function formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return mins + ':' + (secs < 10 ? '0' : '') + secs;
}

controlsView.add(playButton);
controlsView.add(pauseButton);
controlsView.add(progressLabel);

win.add(player);
win.add(controlsView);

```

----------

### Example 4: Wait for Player Ready

```javascript
const YouTubePlayer = require('ti.youtubeplayer');

const player = YouTubePlayer.createPlayerView({
    videoId: 'dQw4w9WgXcQ',
    autoplay: true,
    muted: true,
    width: Ti.UI.FILL,
    height: 300
});

player.addEventListener('playbackStateChange', function(e) {
    // Wait for player to be fully ready before executing commands
    if (e.state === 'playing') {
        Ti.API.info('Player is ready! Safe to call commands now.');
        
        // Now it's safe to unmute
        player.unmute();
        
        // Or change speed
        player.setPlaybackRate(1.5);
    }
});

win.add(player);

```

----------

### Example 5: Persist Mute State

If you want to persist the mute state between app sessions:

```javascript
const YouTubePlayer = require('ti.youtubeplayer');

// Load saved mute state
const savedMuteState = Ti.App.Properties.getBool('my_youtube_muted', true);

const player = YouTubePlayer.createPlayerView({
    videoId: 'dQw4w9WgXcQ',
    muted: savedMuteState,
    width: Ti.UI.FILL,
    height: 300
});

// Save mute state when it changes
player.addEventListener('muteChanged', function(e) {
    Ti.App.Properties.setBool('my_youtube_muted', e.muted);
    Ti.API.info('Mute state saved: ' + e.muted);
});

win.add(player);

```


### Video quality is low

YouTube decides quality based on connection. You can _suggest_ a quality:

```javascript
const player = YouTubePlayer.createPlayerView({
    videoId: 'VIDEO_ID',
    preferredQuality: 'hd1080'  // or 'highres' for 4K
});
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
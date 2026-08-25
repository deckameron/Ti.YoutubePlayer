# Ti.YoutubePlayer

A native Titanium module that enables inline YouTube video playback without forcing the native OS player. 
- Built with [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit) for iOS.
- Built with [android-youtube-player](https://github.com/PierfrancescoSoffritti/android-youtube-player) for Android.

![Version](https://img.shields.io/badge/version-1.1.0-blue.svg) ![Titanium](https://img.shields.io/badge/Titanium-13.0+-red.svg) ![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android-lightgrey.svg) ![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Maintained](https://img.shields.io/badge/Maintained-Yes-green.svg)

<p align="center">
  <img src="https://github.com/deckameron/Ti.YoutubePlayer/blob/main/assets/screenshot_1.png?raw=true"
       width="300"
       alt="screenshot_1" />
  <img src="https://github.com/deckameron/Ti.YoutubePlayer/blob/main/assets/screenshot_2.png?raw=true"
       width="300"
       alt="screenshot_2" />
</p>


## Features

-   ✅ Inline playback (no forced fullscreen)
-   ✅ Configurable autoplay and loop
-   ✅ Mute/unmute control
-   ✅ Video quality control (Youtube is ignoring this for now)
-   ✅ Adjustable playback speed (0.25x - 2x)
-   ✅ Seek to any point in the video
-   ✅ Detailed state and metadata events
-   ✅ No native controls (Optional)
-   ✅ Caption support
-   ✅ Fullscreen support (requires `showControls: true`)
-   ✅ Modern async API

## 📋 Requirements

-   Titanium SDK 13.0.0+
-   iOS 14.0+ / Android API 21+

Underlying players, pulled in by the module — you do not need to add them yourself:

| Platform | Library | Version |
|--|--|--|
| iOS | [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit) | 2.0.5+ (resolved via SPM at build time) |
| Android | [android-youtube-player](https://github.com/PierfrancescoSoffritti/android-youtube-player) | 13.0.0 |


## Installation

### 1. Download the Module

Download the latest version from the [releases page](https://github.com/deckameron/Ti.YoutubePlayer/releases).


### 2. Install the module in your Titanium project

```bash
# Copy the compiled module to:
{YOUR_PROJECT}/modules/iphone/     # iOS
{YOUR_PROJECT}/modules/android/    # Android
```

### 3. Configure tiapp.xml

Add the module to your `tiapp.xml`:

```xml
<modules>
    <module>ti.youtubeplayer</module>
</modules>
```

### App Transport Security (iOS only)

The player runs inside a `WKWebView`. If your app tightens ATS, allow arbitrary
loads in web content in `tiapp.xml`:

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
| `scalingMode` | Number | `SCALING_ASPECT_FIT` | `SCALING_ASPECT_FIT` or `SCALING_ASPECT_FILL` |
| `loop` | Boolean | `true` | Loop playback |
| `showControls` | Boolean | `false` | Show YouTube controls |
| `muted` | Boolean | `true` | Start muted |
| `showCaptions` | Boolean | `false` | Show captions |
| `showFullscreenButton` | Boolean | `false` | Show fullscreen button — **requires `showControls: true`** |
| `preferredQuality` | String | `'hd1080'` | Preferred quality (`'small'`, `'medium'`, `'large'`, `'hd720'`, `'hd1080'`, `'highres'`) |
| `autoplay` | Boolean | `true` | Start playback automatically |
| `startSeconds` | Number | `0` | Position, in seconds, to start playback from |
| `keyboardControlsDisabled` | Boolean | `true` | Disable keyboard shortcuts (iOS only) |

**Note:** All standard `Ti.UI.View` properties also work (`width`, `height`, `top`, `left`, `backgroundColor`, etc.)

### Constants
#### Quality
- PLAYBACK_QUALITY_AUTO
- PLAYBACK_QUALITY_SMALL
- PLAYBACK_QUALITY_MEDIUM
- PLAYBACK_QUALITY_LARGE
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

> **Safe to call immediately after creation.** The player needs a moment to build its
> web view and load YouTube's iFrame API. `play()`, `pause()`, `mute()` and `unmute()`
> issued before that is finished are recorded and applied as soon as the player becomes
> ready, so the common pattern below works without waiting for any event:
>
> ```javascript
> const player = YouTubePlayer.createPlayerView({ videoId: id, autoplay: false });
> container.add(player);
> player.play();   // aplicado assim que o player fica pronto
> ```
>
> `stop()` cancels a pending `play()` rather than queueing.

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

#### `setScalingMode(mode)`

Changes how the video is fitted inside the view at runtime.

```javascript
player.setScalingMode(YouTubePlayer.SCALING_ASPECT_FILL);

```

**Parameters:**

-   `mode`  (Number):  `SCALING_ASPECT_FIT`  or  `SCALING_ASPECT_FILL`

----------

#### `release()`

Tears the player down and frees the underlying web view. Call it before removing
the player from a window if you are not closing the window itself. The player
cannot be reused afterwards.

```javascript
player.release();

```

----------

#### `setPlaybackQuality(quality)`

Sets playback quality.

> **YouTube ignores this.** `setPlaybackQuality` has been a no-op in the IFrame API
> since 2019 — quality is chosen by the player based on bandwidth and viewport size.
> The method is kept for API compatibility and stores your preference, but do not
> rely on it. On Android the underlying library exposes no quality API at all, and
> `getAvailableQualityLevels()` always returns an empty array there.

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

> On iOS this is always `true` once `playbackStateChange` fires; the flag exists for
> Android, where the underlying player accepts commands slightly after `ready`.

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

-   `rate`  (Number): Current playback rate (`0.25`–`2.0`)

----------

#### `fullscreenChange`

Fired when the player enters or leaves fullscreen.

> Requires **both** `showFullscreenButton: true` **and** `showControls: true`. The
> fullscreen button is rendered inside YouTube's own control bar (`fs` only takes
> effect when `controls` is on), so with `showControls: false` no button is drawn
> and this event never fires.

```javascript
player.addEventListener('fullscreenChange', function(e) {
    Ti.API.info('Fullscreen: ' + e.fullscreen);
});

```

**Event properties:**

-   `fullscreen`  (Boolean):  `true`  when entering fullscreen,  `false`  when leaving

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
-   `type`  (String): Error type


YouTube IFrame API codes:

|Code|Type|Message|
|--|--|--|
|2|`invalid_parameter`|Invalid video ID|
|5|`html5_error`|HTML5 player error|
|100|`not_found`|Video not found, private, or age-restricted|
|101|`embedding_disabled`|Owner doesn't allow embedding|
|150|`embedding_disabled`|Same as 101|
|153|`missing_referer`|Missing HTTP Referer header or API Client identification|

Transport/setup failures reported by the module itself (negative codes):

|Code|Type|Message|Platform|
|--|--|--|--|
|-1|`iframe_api_failed`|The YouTube iFrame API failed to load|iOS|
|-2|`web_process_terminated`|The web content process was terminated|iOS|
|-3|`setup_failed`|Player setup failed|iOS|
|-4|`navigation_failed`|WebView navigation failed|iOS|
|-99|`unknown`|Unrecognised player error|iOS, Android|

----------

## Platform differences

The API is the same on both platforms, but the underlying players are not. These are
the behaviours that genuinely differ:

| Topic | iOS | Android |
|--|--|--|
| `stop()` | Unloads the video. A later `play()` will **not** resume it — use `loadVideo()` to start over. | Pauses and seeks to 0, so `play()` resumes. |
| `setPlaybackQuality()` | Forwarded to the player, which YouTube ignores. | No-op: the library exposes no quality API. |
| `getAvailableQualityLevels()` | Returns what the player reports. | Always returns an empty array. |
| `preferredQuality` | Applied as a hint, ignored by YouTube. | Stored only. |
| `keyboardControlsDisabled` | Supported. | Not applicable. |
| `error` codes | Full range, including the negative transport codes below. | YouTube codes, plus `-99` for unrecognised errors. |
| Playback rate | `0.25`–`2.0` in eight steps. | Four steps: `0.25`, `0.5`, `1.0`, `1.5`, `2.0`; other values fall back to `1.0`. |

Quality control is a YouTube limitation, not a module one: `setPlaybackQuality` has
been a no-op in the IFrame API since 2019, and the player picks quality from bandwidth
and viewport size.

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
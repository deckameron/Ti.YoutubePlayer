// Ti.YoutubePlayer - Example App
const YouTubePlayer = require('ti.youtubeplayer');

// Create main window with gradient background
const win = Ti.UI.createWindow({
    backgroundColor: '#1a1a2e',
    backgroundGradient: {
        type: 'linear',
        startPoint: { x: '0%', y: '0%' },
        endPoint: { x: '100%', y: '100%' },
        colors: [
            { color: '#0f0c29', offset: 0.0 },
            { color: '#302b63', offset: 0.5 },
            { color: '#24243e', offset: 1.0 }
        ]
    }
});

// Container for all content
const container = Ti.UI.createScrollView({
    layout: 'vertical',
    width: Ti.UI.FILL,
    height: Ti.UI.SIZE,
    showVerticalScrollIndicator: true
});

// Title
const titleLabel = Ti.UI.createLabel({
    text: 'YouTube Player',
    color: '#ffffff',
    font: {
        fontSize: 28,
        fontWeight: 'bold'
    },
    textAlign: Titanium.UI.TEXT_ALIGNMENT_CENTER,
    top: Titanium.UI.statusBarHeight + 16,
    width: Ti.UI.FILL
});

// Player container with shadow and rounded corners
const playerContainer = Ti.UI.createView({
    width: '90%',
    height: 220,
    top: 24,
    borderRadius: 20,
    backgroundColor: '#000',
    shadowColor: '#000',
    shadowOffset: { x: 0, y: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 10
});

// YouTube Player
const player = YouTubePlayer.createPlayerView({
    videoId: 'u00Y9e-Uxj0',
    autoplay: true,
    loop: true,
    showControls: false,
    muted: false,
    showFullscreenButton: true,
    preferredQuality: YouTubePlayer.PLAYBACK_QUALITY_HD1080,
    width: Ti.UI.FILL,
    height: Ti.UI.FILL
});

playerContainer.add(player);

// Video info card
const infoCard = Ti.UI.createView({
    width: '90%',
    height: Ti.UI.SIZE,
    top: 20,
    borderRadius: 15,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    layout: 'vertical'
});

const videoTitle = Ti.UI.createLabel({
    text: 'Loading...',
    color: '#ffffff',
    font: {
        fontSize: 18,
        fontWeight: 'bold'
    },
    left: 15,
    right: 15,
    top: 15,
    height: Ti.UI.SIZE
});

const videoAuthor = Ti.UI.createLabel({
    text: '',
    color: '#b8b8d1',
    font: {
        fontSize: 14
    },
    left: 15,
    right: 15,
    top: 5,
    bottom: 15,
    height: Ti.UI.SIZE
});

infoCard.add(videoTitle);
infoCard.add(videoAuthor);

// Progress bar container
const progressContainer = Ti.UI.createView({
    width: '90%',
    height: 60,
    top: 15,
    borderRadius: 15,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    layout: 'vertical'
});

const timeLabel = Ti.UI.createLabel({
    text: '0:00 / 0:00',
    color: '#ffffff',
    font: {
        fontSize: 14,
        fontWeight: 'bold'
    },
    textAlign: 'center',
    top: 10,
    width: Ti.UI.FILL
});

const progressBarBg = Ti.UI.createView({
    width: '85%',
    height: 6,
    top: 10,
    bottom: 12,
    borderRadius: 3,
    backgroundColor: 'rgba(255, 255, 255, 0.2)'
});

const progressBar = Ti.UI.createView({
    width: '0%',
    height: 6,
    left: 0,
    borderRadius: 3,
    backgroundColor: '#ff6b6b'
});

progressBarBg.add(progressBar);
progressContainer.add(timeLabel);
progressContainer.add(progressBarBg);

// Main controls
const controlsContainer = Ti.UI.createView({
    width: '90%',
    height: 70,
    top: 15,
    borderRadius: 15,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    layout: 'horizontal'
});

// Helper function to create control button
function createControlButton(icon, action) {
    const button = Ti.UI.createButton({
        image: icon,
        width: 60,
        height: 50,
        borderRadius: 12,
        tintColor: "#ffffff",
        backgroundColor: 'rgba(255, 255, 255, 0.15)',
        top: 10,
        left: 10
    });
    
    button.addEventListener('click', action);
    
    // Add touch feedback
    button.addEventListener('touchstart', function() {
        button.backgroundColor = 'rgba(255, 255, 255, 0.3)';
    });
    
    button.addEventListener('touchend', function() {
        button.backgroundColor = 'rgba(255, 255, 255, 0.15)';
    });
    
    return button;
}

const playButton = createControlButton(Ti.UI.iOS.systemImage('play.fill'), function() {
    player.play();
});
controlsContainer.add(playButton);

const pauseButton = createControlButton(Ti.UI.iOS.systemImage('pause.fill'), function() {
    player.pause();
});
controlsContainer.add(pauseButton);

const stopButton = createControlButton(Ti.UI.iOS.systemImage('stop.fill'), function() {
    player.stop();
});
controlsContainer.add(stopButton);

const muteButton = createControlButton(Ti.UI.iOS.systemImage('speaker.wave.2.fill'), function() {
    if (player.isMuted()) {
        player.unmute();
    } else {
        player.mute();
    }
});
controlsContainer.add(muteButton);

// Speed controls
const speedContainer = Ti.UI.createView({
    width: '90%',
    height: 70,
    top: 15,
    borderRadius: 15,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    layout: 'vertical'
});

const speedLabel = Ti.UI.createLabel({
    text: 'Playback Speed: 1.0x',
    color: '#ffffff',
    font: {
        fontSize: 14,
        fontWeight: 'bold'
    },
    textAlign: 'center',
    top: 10,
    width: Ti.UI.FILL
});

const speedButtonsContainer = Ti.UI.createView({
    width: Ti.UI.FILL,
    height: 40,
    top: 5,
    bottom: 10,
    layout: 'horizontal'
});

const speeds = [
    { value: 0.5, label: '0.5x' },
    { value: 0.75, label: '0.75x' },
    { value: 1.0, label: '1x' },
    { value: 1.25, label: '1.25x' },
    { value: 1.5, label: '1.5x' },
    { value: 2.0, label: '2x' }
];

speeds.forEach(function(speed) {
    const btn = Ti.UI.createButton({
        title: speed.label,
        width: 55,
        height: 35,
        borderRadius: 8,
        backgroundColor: speed.value === 1.0 ? '#ff6b6b' : 'rgba(255, 255, 255, 0.15)',
        color: '#ffffff',
        font: {
            fontSize: 12,
            fontWeight: 'bold'
        },
        left: 5
    });
    
    btn.addEventListener('click', function() {
        player.setPlaybackRate(speed.value);
        speedLabel.text = 'Playback Speed: ' + speed.label;
        
        // Update button states
        speedButtonsContainer.children.forEach(function(child) {
            child.backgroundColor = 'rgba(255, 255, 255, 0.15)';
        });
        btn.backgroundColor = '#ff6b6b';
    });
    
    speedButtonsContainer.add(btn);
});

speedContainer.add(speedLabel);
speedContainer.add(speedButtonsContainer);

// Video selection
const videoContainer = Ti.UI.createView({
    width: '90%',
    height: Ti.UI.SIZE,
    top: 15,
    borderRadius: 15,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    layout: 'vertical'
});

const videoSelectionLabel = Ti.UI.createLabel({
    text: 'Change Video',
    color: '#ffffff',
    font: {
        fontSize: 14,
        fontWeight: 'bold'
    },
    textAlign: 'center',
    top: 10,
    width: Ti.UI.FILL
});

const videosButtonContainer = Ti.UI.createView({
    width: Ti.UI.FILL,
    height: Ti.UI.SIZE,
    top: 5,
    bottom: 10,
    layout: 'horizontal'
});

const videos = [
    { id: 'nYSDC3cHoZs', name: 'Video 1' },
    { id: 'n_GFN3a0yj0', name: 'Video 2' },
    { id: '83zPG4aCyqk', name: 'Video 3' }
];

videos.forEach(function(video) {
    const btn = Ti.UI.createButton({
        title: video.name,
        width: 100,
        height: 40,
        borderRadius: 10,
        backgroundColor: 'rgba(255, 255, 255, 0.15)',
        color: '#ffffff',
        font: {
            fontSize: 14,
            fontWeight: 'bold'
        },
        left: 8
    });
    
    btn.addEventListener('click', function() {
        player.changeVideo(video.id);
        Ti.API.info('Changed to: ' + video.name);
    });
    
    videosButtonContainer.add(btn);
});

videoContainer.add(videoSelectionLabel);
videoContainer.add(videosButtonContainer);

// Status indicator
const statusLabel = Ti.UI.createLabel({
    text: '● Initializing...',
    color: '#ffd93d',
    font: {
        fontSize: 12
    },
    textAlign: 'center',
    top: 20,
    bottom: 30,
    width: Ti.UI.FILL
});

// Add all elements to container
container.add(titleLabel);
container.add(playerContainer);
container.add(infoCard);
container.add(progressContainer);
container.add(controlsContainer);
container.add(speedContainer);
container.add(videoContainer);
container.add(statusLabel);

win.add(container);

// Event Listeners
player.addEventListener('playbackStateChange', function(e) {
    const statusColors = {
        'unstarted': '#ffd93d',
        'playing': '#6bcf7f',
        'paused': '#ff6b6b',
        'buffering': '#4ecdc4',
        'ended': '#95afc0',
        'cued': '#ffd93d'
    };
    
    statusLabel.text = '● ' + e.state.toUpperCase();
    statusLabel.color = statusColors[e.state] || '#ffffff';
    
    Ti.API.info('State: ' + e.state + ', Ready: ' + e.isFullyReady);
});

player.addEventListener('metadataReceived', function(e) {
    videoTitle.text = e.title || 'Unknown Title';
    videoAuthor.text = e.author || 'Unknown Author';
    Ti.API.info('Metadata: ' + e.title);
});

player.addEventListener('muteChanged', function(e) {
    muteButton.image = e.muted ? Ti.UI.iOS.systemImage('speaker.slash.fill') : Ti.UI.iOS.systemImage('speaker.wave.2.fill');
    Ti.API.info('Muted: ' + e.muted);
});

player.addEventListener('playbackQualityChange', function(e) {
    Ti.API.info('Quality: ' + e.quality);
});

player.addEventListener('error', function(e) {
    statusLabel.text = '● ERROR: ' + e.message;
    statusLabel.color = '#ff6b6b';
    Ti.API.error('Player error: ' + e.message);
});

// Update progress bar
function formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return mins + ':' + (secs < 10 ? '0' : '') + secs;
}

let progressInterval = setInterval(function() {
    player.getCurrentTime(function(currentData) {
        if (currentData && currentData.currentTime !== null) {
            player.getDuration(function(durationData) {
                if (durationData && durationData.duration !== null) {
                    const current = currentData.currentTime;
                    const total = durationData.duration;
                    const percentage = (current / total) * 100;
                    
                    progressBar.width = percentage + '%';
                    timeLabel.text = formatTime(current) + ' / ' + formatTime(total);
                }
            });
        }
    });
}, 1000);

// Cleanup on window close
win.addEventListener('close', function() {
    clearInterval(progressInterval);
});

win.open();
package ti.youtubeplayer;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import androidx.annotation.NonNull;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.LifecycleRegistry;

import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.YouTubePlayer;
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.listeners.AbstractYouTubePlayerListener;
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.options.IFramePlayerOptions;
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.views.YouTubePlayerView;
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.PlayerConstants;

import org.appcelerator.kroll.KrollDict;
import org.appcelerator.kroll.KrollFunction;
import org.appcelerator.titanium.proxy.TiViewProxy;
import org.appcelerator.titanium.util.TiConvert;
import org.appcelerator.titanium.view.TiUIView;

import java.lang.ref.WeakReference;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class PlayerView extends TiUIView implements LifecycleOwner {

    private static final String TAG = "PlayerView";

    /** Verbose device diagnostics. Keep this off in release builds. */
    private static final boolean VERBOSE_DIAGNOSTICS = false;

    private YouTubePlayerView youTubePlayerView;
    private YouTubePlayer youTubePlayer;
    private LifecycleRegistry lifecycleRegistry;
    private FrameLayout containerView;
    private Handler mainHandler;

    private String currentVideoId;
    private volatile boolean isMuted = true;
    private volatile boolean isPlayerReady = false;
    private volatile float currentDuration = 0f;
    private volatile float currentTime = 0f;
    private String preferredQuality = "hd1080";
    private final boolean shouldLoop;
    private float startSeconds = 0f;
    private boolean isReleased = false;
    private int scalingMode = 0; // Default SCALING_ASPECT_FIT

    private volatile float videoAspectRatio = 16f / 9f; // Default 16:9
    private volatile int videoWidth = 0;
    private volatile int videoHeight = 0;

    private ExecutorService metadataExecutor;
    private Future<?> metadataFuture;

    // Bounds can be zero while the view is off-screen; retry a bounded number of
    // times instead of rescheduling forever.
    private int scalingRetryCount = 0;
    private static final int MAX_SCALING_RETRIES = 30;

    /**
     * What the caller last asked for, applied as soon as onReady() hands us a player.
     *
     * youTubePlayer only exists from onReady() onwards, so a play() issued right after
     * createPlayerView() would be dropped and — with autoplay off — the view would stay
     * black forever.
     */
    private static final int PLAYBACK_NONE = 0;
    private static final int PLAYBACK_PLAY = 1;
    private static final int PLAYBACK_PAUSE = 2;
    private volatile int desiredPlayback = PLAYBACK_NONE;

    private android.view.View fullscreenView;
    private kotlin.jvm.functions.Function0<kotlin.Unit> exitFullscreen;

    private Runnable readyRunnable;
    private Runnable loadVideoReadyRunnable;
    private Runnable cueVideoReadyRunnable;
    private Runnable reloadReadyRunnable;

    public PlayerView(TiViewProxy proxy) {
        super(proxy);

        lifecycleRegistry = new LifecycleRegistry(this);
        lifecycleRegistry.setCurrentState(Lifecycle.State.CREATED);

        mainHandler = new Handler(Looper.getMainLooper());

        logDiagnostics();

        // Container
        containerView = new FrameLayout(proxy.getActivity());
        containerView.setLayoutParams(new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        containerView.setClipChildren(true);

        // Get properties
        String videoId = TiConvert.toString(proxy.getProperty("videoId"));
        boolean autoplay = TiConvert.toBoolean(proxy.getProperty("autoplay"), true);
        boolean loop = TiConvert.toBoolean(proxy.getProperty("loop"), true);
        // `showControls` is the documented name; `controls` kept for back-compat.
        Object controlsProp = proxy.getProperty("showControls");
        if (controlsProp == null) {
            controlsProp = proxy.getProperty("controls");
        }
        boolean controls = TiConvert.toBoolean(controlsProp, false);
        isMuted = TiConvert.toBoolean(proxy.getProperty("muted"), true);
        boolean showCaptions = TiConvert.toBoolean(proxy.getProperty("showCaptions"), false);
        boolean showFullscreenButton = TiConvert.toBoolean(proxy.getProperty("showFullscreenButton"), false);

        if (showFullscreenButton && !controls) {
            Log.w(TAG, "[WARN] showFullscreenButton has no effect with showControls:false - "
                    + "YouTube renders the fullscreen button inside its control bar.");
        }

        this.shouldLoop = loop;
        this.startSeconds = TiConvert.toFloat(proxy.getProperty("startSeconds"), 0f);

        metadataExecutor = Executors.newSingleThreadExecutor();

        String quality = TiConvert.toString(proxy.getProperty("preferredQuality"));
        if (quality != null) {
            preferredQuality = quality;
        }

        Object scalingModeObj = proxy.getProperty("scalingMode");
        if (scalingModeObj != null) {
            scalingMode = TiConvert.toInt(scalingModeObj, 0);
            Log.d(TAG, "[DEBUG] Scaling mode: " + (scalingMode == 1 ? "ASPECT_FILL" : "ASPECT_FIT"));
        }

        if (videoId != null) {
            currentVideoId = videoId;
            initializePlayer(videoId, autoplay, controls, showCaptions, showFullscreenButton);
        }

        setNativeView(containerView);

        lifecycleRegistry.setCurrentState(Lifecycle.State.CREATED);
        lifecycleRegistry.setCurrentState(Lifecycle.State.STARTED);
        lifecycleRegistry.setCurrentState(Lifecycle.State.RESUMED);
    }

    private void logDiagnostics() {
        if (!VERBOSE_DIAGNOSTICS) return;
        try {
            // Android version
            Log.d(TAG, "[DIAGNOSTICS] Android Version: " + android.os.Build.VERSION.RELEASE);
            Log.d(TAG, "[DIAGNOSTICS] SDK Int: " + android.os.Build.VERSION.SDK_INT);

            // WebView available
            android.content.pm.PackageManager pm = proxy.getActivity().getPackageManager();
            try {
                android.content.pm.PackageInfo webViewPackage = pm.getPackageInfo("com.google.android.webview", 0);
                Log.d(TAG, "[DIAGNOSTICS] WebView Version: " + webViewPackage.versionName);
            } catch (android.content.pm.PackageManager.NameNotFoundException e) {
                Log.e(TAG, "[DIAGNOSTICS] WebView not found!");
            }

            // Google Play Services
            try {
                android.content.pm.PackageInfo gpsPackage = pm.getPackageInfo("com.google.android.gms", 0);
                Log.d(TAG, "[DIAGNOSTICS] Google Play Services Version: " + gpsPackage.versionName);
            } catch (android.content.pm.PackageManager.NameNotFoundException e) {
                Log.e(TAG, "[DIAGNOSTICS] Google Play Services not found!");
            }

            android.net.ConnectivityManager cm = (android.net.ConnectivityManager)
                    proxy.getActivity().getSystemService(android.content.Context.CONNECTIVITY_SERVICE);

            boolean isConnected = false;
            android.net.Network network = cm.getActiveNetwork();
            android.net.NetworkCapabilities capabilities = cm.getNetworkCapabilities(network);
            isConnected = capabilities != null &&
                    (capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI) ||
                            capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR) ||
                            capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_ETHERNET));

            Log.d(TAG, "[DIAGNOSTICS] Network Connected: " + isConnected);

        } catch (Exception e) {
            Log.e(TAG, "[DIAGNOSTICS] Error: " + e.getMessage());
            e.printStackTrace();
        }
    }

    @NonNull
    @Override
    public Lifecycle getLifecycle() {
        return lifecycleRegistry;
    }

    private void initializePlayer(String videoId, boolean autoplay, boolean controls,
                                  boolean showCaptions, boolean showFullscreenButton) {
        // Create player view
        youTubePlayerView = new YouTubePlayerView(proxy.getActivity());

        FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        );
        layoutParams.gravity = android.view.Gravity.CENTER;
        youTubePlayerView.setLayoutParams(layoutParams);

        youTubePlayerView.setEnableAutomaticInitialization(false);

        final WeakReference<PlayerView> weakThis = new WeakReference<>(this);
        final WeakReference<PlayerView> weakSelf = weakThis;

        // Configure IFrame options
        IFramePlayerOptions.Builder optionsBuilder = new IFramePlayerOptions.Builder(proxy.getActivity())
                .controls(controls ? 1 : 0)
                .ccLoadPolicy(showCaptions ? 1 : 0)
                .ivLoadPolicy(3)
                .rel(0)
                .autoplay(autoplay ? 1 : 0)
                .mute(isMuted ? 1 : 0)
                .fullscreen(showFullscreenButton ? 1 : 0);

        IFramePlayerOptions options = optionsBuilder.build();

        // The fullscreen button only does anything if a FullscreenListener is
        // registered; without one the control renders but taps are dropped.
        if (showFullscreenButton) {
            youTubePlayerView.addFullscreenListener(
                    new com.pierfrancescosoffritti.androidyoutubeplayer.core.player.listeners.FullscreenListener() {
                        @Override
                        public void onEnterFullscreen(@NonNull android.view.View fullscreenView,
                                                      @NonNull kotlin.jvm.functions.Function0<kotlin.Unit> exitFullscreen) {
                            PlayerView view = weakSelf.get();
                            if (view == null || view.isReleased || view.containerView == null) return;
                            view.exitFullscreen = exitFullscreen;
                            view.fullscreenView = fullscreenView;
                            if (view.youTubePlayerView != null) {
                                view.youTubePlayerView.setVisibility(android.view.View.GONE);
                            }
                            fullscreenView.setLayoutParams(new FrameLayout.LayoutParams(
                                    ViewGroup.LayoutParams.MATCH_PARENT,
                                    ViewGroup.LayoutParams.MATCH_PARENT));
                            view.containerView.addView(fullscreenView);
                            view.fireEvent("fullscreenChange", view.createEventDict("fullscreen", true));
                        }

                        @Override
                        public void onExitFullscreen() {
                            PlayerView view = weakSelf.get();
                            if (view == null || view.isReleased || view.containerView == null) return;
                            if (view.fullscreenView != null) {
                                view.containerView.removeView(view.fullscreenView);
                                view.fullscreenView = null;
                            }
                            view.exitFullscreen = null;
                            if (view.youTubePlayerView != null) {
                                view.youTubePlayerView.setVisibility(android.view.View.VISIBLE);
                            }
                            view.fireEvent("fullscreenChange", view.createEventDict("fullscreen", false));
                        }
                    });
        }

        // Add lifecycle observer
        getLifecycle().addObserver(youTubePlayerView);

        // Initialize player
        youTubePlayerView.initialize(new AbstractYouTubePlayerListener() {
            @Override
            public void onReady(@NonNull YouTubePlayer player) {
                PlayerView view = weakThis.get();
                if (view == null || view.isReleased) return;

                view.youTubePlayer = player;

                Log.d(TAG, "[DEBUG] Player is ready");

                // Load or cue video
                if (autoplay) {
                    player.loadVideo(videoId, view.startSeconds);
                } else {
                    player.cueVideo(videoId, view.startSeconds);
                }

                // Apply mute
                if (view.isMuted) {
                    player.mute();
                } else {
                    player.unMute();
                }

                // Replay whatever was requested before the player existed.
                if (view.desiredPlayback == PLAYBACK_PLAY) {
                    player.play();
                } else if (view.desiredPlayback == PLAYBACK_PAUSE) {
                    player.pause();
                }

                view.readyRunnable = () -> {
                    PlayerView v = weakThis.get();
                    if (v != null && !v.isReleased) {
                        v.isPlayerReady = true;
                        Log.d(TAG, "[DEBUG] Player is now fully ready");
                    }
                };
                view.mainHandler.postDelayed(view.readyRunnable, 2000);

                // Fire ready event
                view.fireEvent("playerStateChange", view.createEventDict("playerState", "ready"));
            }

            @Override
            public void onStateChange(@NonNull YouTubePlayer player, @NonNull PlayerConstants.PlayerState state) {
                PlayerView view = weakThis.get();
                if (view == null || view.isReleased) return;

                String stateString = "unknown";
                int stateCode = -1;

                switch (state) {
                    case UNSTARTED:
                        stateString = "unstarted";
                        break;
                    case ENDED:
                        stateString = "ended";
                        stateCode = 0;

                        if (view.shouldLoop && view.currentVideoId != null) {
                            Log.d(TAG, "[DEBUG] Looping video (manual implementation)");
                            player.seekTo(0);
                            player.play();
                        }
                        break;
                    case PLAYING:
                        stateString = "playing";
                        stateCode = 1;
                        Log.d(TAG, "[DEBUG] Player state: PLAYING");

                        if (view.videoWidth > 0 && view.videoHeight > 0) {
                            view.applyCalculatedScaling();
                        }

                        if (view.preferredQuality != null && !view.preferredQuality.isEmpty()) {
                            view.applyPreferredQuality();
                        }
                        break;
                    case PAUSED:
                        stateString = "paused";
                        stateCode = 2;
                        break;
                    case BUFFERING:
                        stateString = "buffering";
                        stateCode = 3;
                        break;
                    case VIDEO_CUED:
                        stateString = "cued";
                        stateCode = 5;
                        break;
                }

                KrollDict event = new KrollDict();
                event.put("state", stateString);
                event.put("code", stateCode);
                event.put("isFullyReady", view.isPlayerReady);

                view.fireEvent("playbackStateChange", event);
            }

            @Override
            public void onPlaybackQualityChange(@NonNull YouTubePlayer player, @NonNull PlayerConstants.PlaybackQuality quality) {
                PlayerView view = weakThis.get();
                if (view == null || view.isReleased) return;

                String qualityString = view.mapQualityToString(quality);
                Log.d(TAG, "[DEBUG] Quality changed to: " + qualityString);
                view.fireEvent("playbackQualityChange", view.createEventDict("quality", qualityString));
            }

            @Override
            public void onPlaybackRateChange(@NonNull YouTubePlayer player, @NonNull PlayerConstants.PlaybackRate rate) {
                PlayerView view = weakThis.get();
                if (view == null || view.isReleased) return;

                Log.d(TAG, "[DEBUG] Playback rate changed to: " + rate);
                view.fireEvent("playbackRateChange", view.createEventDict("rate", mapRateToNumber(rate)));
            }

            @Override
            public void onError(@NonNull YouTubePlayer player, @NonNull PlayerConstants.PlayerError error) {
                PlayerView view = weakThis.get();
                if (view == null || view.isReleased) return;

                int errorCode = view.mapErrorToCode(error);
                Log.e(TAG, "[ERROR] Player error: " + error + " (code: " + errorCode + ")");

                KrollDict event = new KrollDict();
                event.put("message", mapErrorToMessage(errorCode));
                event.put("code", errorCode);
                event.put("type", mapErrorToType(errorCode));
                view.fireEvent("error", event);
            }

            @Override
            public void onCurrentSecond(@NonNull YouTubePlayer player, float second) {
                PlayerView view = weakThis.get();
                if (view == null || view.isReleased) return;

                view.currentTime = second;
            }

            @Override
            public void onVideoDuration(@NonNull YouTubePlayer player, float duration) {
                PlayerView view = weakThis.get();
                if (view == null || view.isReleased) return;

                view.currentDuration = duration;
            }

            @Override
            public void onVideoId(@NonNull YouTubePlayer player, @NonNull String videoId) {
                PlayerView view = weakThis.get();
                if (view == null || view.isReleased) return;
                Log.d(TAG, "[DEBUG] Video ID: " + videoId);
                view.fetchVideoMetadataWithDimensions(videoId);
            }
        }, options);

        containerView.addView(youTubePlayerView);
    }

    private void applyPreferredQuality() {
        if (youTubePlayer == null || isReleased) return;

        PlayerConstants.PlaybackQuality quality = mapStringToQuality(preferredQuality);
        Log.d(TAG, "[DEBUG] Preferred quality: " + preferredQuality + " (not directly supported by library)");
    }

    private void applyCalculatedScaling() {
        if (youTubePlayerView == null || isReleased) return;

        // Dimensões do container
        int containerWidth = containerView.getWidth();
        int containerHeight = containerView.getHeight();

        if (containerWidth == 0 || containerHeight == 0) {
            if (mainHandler == null || scalingRetryCount >= MAX_SCALING_RETRIES) return;
            scalingRetryCount++;
            mainHandler.postDelayed(this::applyCalculatedScaling, 100);
            return;
        }

        scalingRetryCount = 0;

        float containerAspect = (float) containerWidth / (float) containerHeight;

        int playerWidth;
        int playerHeight;

        if (scalingMode == 1) {
            // ASPECT_FILL
            if (containerAspect > videoAspectRatio) {
                playerWidth = containerWidth;
                playerHeight = (int) (containerWidth / videoAspectRatio);
            } else {
                playerHeight = containerHeight;
                playerWidth = (int) (containerHeight * videoAspectRatio);
            }

            Log.d(TAG, "[DEBUG] ASPECT_FILL: player=" + playerWidth + "x" + playerHeight +
                    " container=" + containerWidth + "x" + containerHeight);
        } else {
            // ASPECT_FIT
            if (containerAspect > videoAspectRatio) {
                playerHeight = containerHeight;
                playerWidth = (int) (containerHeight * videoAspectRatio);
            } else {
                playerWidth = containerWidth;
                playerHeight = (int) (containerWidth / videoAspectRatio);
            }

            Log.d(TAG, "[DEBUG] ASPECT_FIT: player=" + playerWidth + "x" + playerHeight +
                    " container=" + containerWidth + "x" + containerHeight);
        }

        FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(
                playerWidth,
                playerHeight
        );
        layoutParams.gravity = android.view.Gravity.CENTER;

        youTubePlayerView.setLayoutParams(layoutParams);
    }

    public void setScalingMode(int mode) {
        scalingMode = mode;
        scalingRetryCount = 0;
        Log.d(TAG, "[DEBUG] Scaling mode changed to: " + (mode == 1 ? "ASPECT_FILL" : "ASPECT_FIT"));
        applyCalculatedScaling();
    }

    private int mapErrorToCode(PlayerConstants.PlayerError error) {
        return switch (error) {
            case INVALID_PARAMETER_IN_REQUEST -> 2;
            case HTML_5_PLAYER -> 5;
            case VIDEO_NOT_FOUND -> 100;
            case VIDEO_NOT_PLAYABLE_IN_EMBEDDED_PLAYER -> 101;
            default -> -99;
        };
    }

    private static String mapErrorToType(int code) {
        return switch (code) {
            case 2 -> "invalid_parameter";
            case 5 -> "html5_error";
            case 100 -> "not_found";
            case 101, 150 -> "embedding_disabled";
            case 153 -> "missing_referer";
            default -> "unknown";
        };
    }

    private static String mapErrorToMessage(int code) {
        return switch (code) {
            case 2 -> "Invalid video ID";
            case 5 -> "HTML5 player error";
            case 100 -> "Video not found, private, or age-restricted";
            case 101, 150 -> "Video owner does not allow embedding";
            case 153 -> "Missing HTTP Referer header or API Client identification";
            default -> "Unknown player error";
        };
    }

    private static double mapRateToNumber(PlayerConstants.PlaybackRate rate) {
        return switch (rate) {
            case RATE_0_25 -> 0.25d;
            case RATE_0_5 -> 0.5d;
            case RATE_1_5 -> 1.5d;
            case RATE_2 -> 2.0d;
            default -> 1.0d;
        };
    }

    private String mapQualityToString(PlayerConstants.PlaybackQuality quality) {
        return switch (quality) {
            case SMALL -> "small";
            case MEDIUM -> "medium";
            case LARGE -> "large";
            case HD720 -> "hd720";
            case HD1080 -> "hd1080";
            case HIGH_RES -> "highres";
            case DEFAULT -> "auto";
            default -> "unknown";
        };
    }

    private PlayerConstants.PlaybackQuality mapStringToQuality(String quality) {
        return switch (quality.toLowerCase()) {
            case "small" -> PlayerConstants.PlaybackQuality.SMALL;
            case "medium" -> PlayerConstants.PlaybackQuality.MEDIUM;
            case "large" -> PlayerConstants.PlaybackQuality.LARGE;
            case "hd720" -> PlayerConstants.PlaybackQuality.HD720;
            case "hd1080" -> PlayerConstants.PlaybackQuality.HD1080;
            case "highres" -> PlayerConstants.PlaybackQuality.HIGH_RES;
            default -> PlayerConstants.PlaybackQuality.DEFAULT;
        };
    }

    private KrollDict createEventDict(String key, Object value) {
        KrollDict dict = new KrollDict();
        dict.put(key, value);
        return dict;
    }

    private void cancelPendingRunnables() {
        if (readyRunnable != null) {
            mainHandler.removeCallbacks(readyRunnable);
            readyRunnable = null;
        }
        if (loadVideoReadyRunnable != null) {
            mainHandler.removeCallbacks(loadVideoReadyRunnable);
            loadVideoReadyRunnable = null;
        }
        if (cueVideoReadyRunnable != null) {
            mainHandler.removeCallbacks(cueVideoReadyRunnable);
            cueVideoReadyRunnable = null;
        }
        if (reloadReadyRunnable != null) {
            mainHandler.removeCallbacks(reloadReadyRunnable);
            reloadReadyRunnable = null;
        }
    }

    private void fetchVideoMetadataWithDimensions(final String videoId) {
        if (isReleased || metadataExecutor == null) return;

        if (metadataFuture != null) {
            metadataFuture.cancel(true);
        }

        final WeakReference<PlayerView> weakThis = new WeakReference<>(this);

        metadataFuture = metadataExecutor.submit(() -> {
            java.net.HttpURLConnection conn = null;
            try {
                String url = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v="
                        + videoId + "&format=json";

                java.net.URL apiUrl = new java.net.URL(url);
                conn = (java.net.HttpURLConnection) apiUrl.openConnection();
                conn.setRequestMethod("GET");
                conn.setConnectTimeout(5000);
                conn.setReadTimeout(5000);

                int responseCode = conn.getResponseCode();
                if (responseCode != 200) {
                    Log.w(TAG, "[WARN] oEmbed returned HTTP " + responseCode + " for " + videoId);
                    return;
                }

                StringBuilder response = new StringBuilder();
                try (java.io.BufferedReader reader = new java.io.BufferedReader(
                        new java.io.InputStreamReader(conn.getInputStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        response.append(line);
                    }
                }

                org.json.JSONObject json = new org.json.JSONObject(response.toString());

                final String title = json.optString("title", "");
                final String author = json.optString("author_name", "");
                final int width = json.optInt("width", 0);
                final int height = json.optInt("height", 0);

                PlayerView self = weakThis.get();
                if (self == null || self.isReleased || Thread.currentThread().isInterrupted()) return;

                if (width > 0 && height > 0) {
                    self.videoWidth = width;
                    self.videoHeight = height;
                    self.videoAspectRatio = (float) width / (float) height;

                    Log.d(TAG, "[DEBUG] Video dimensions: " + width + "x" + height +
                            " (aspect: " + self.videoAspectRatio + ")");
                }

                Handler handler = self.mainHandler;
                if (handler == null) return;

                handler.post(() -> {
                    PlayerView v = weakThis.get();
                    if (v == null || v.isReleased) return;

                    if (width > 0 && height > 0) {
                        v.scalingRetryCount = 0;
                        v.applyCalculatedScaling();
                    }

                    KrollDict event = new KrollDict();
                    event.put("videoId", videoId);
                    event.put("title", title);
                    event.put("author", author);
                    v.fireEvent("metadataReceived", event);
                });
            } catch (Exception e) {
                Log.e(TAG, "[ERROR] Failed to fetch metadata: " + e.getMessage());
            } finally {
                if (conn != null) {
                    conn.disconnect();
                }
            }
        });
    }

    // Public methods
    public void play() {
        if (isReleased) return;
        desiredPlayback = PLAYBACK_PLAY;
        // Not ready yet: onReady() replays this.
        if (youTubePlayer == null) return;
        youTubePlayer.play();
    }

    public void pause() {
        if (isReleased) return;
        desiredPlayback = PLAYBACK_PAUSE;
        if (youTubePlayer == null) return;
        youTubePlayer.pause();
    }

    public void stop() {
        if (isReleased) return;
        // Cancels a queued play instead of letting it start after teardown.
        desiredPlayback = PLAYBACK_NONE;
        if (youTubePlayer == null) return;
        youTubePlayer.pause();
        youTubePlayer.seekTo(0);
    }

    public void mute() {
        if (isReleased) return;
        // Recorded up front so onReady() can apply it even if this call is too early.
        isMuted = true;
        if (youTubePlayer == null) return;
        youTubePlayer.mute();
        fireEvent("muteChanged", createEventDict("muted", true));
    }

    public void unmute() {
        if (isReleased) return;
        isMuted = false;
        if (youTubePlayer == null) return;
        youTubePlayer.unMute();
        fireEvent("muteChanged", createEventDict("muted", false));
    }

    public boolean isMuted() {
        return isMuted;
    }

    public void seekTo(float seconds) {
        if (youTubePlayer != null && !isReleased) {
            Log.d(TAG, "[DEBUG] seekTo() called: " + seconds);
            youTubePlayer.seekTo(seconds);
        }
    }

    public void setPlaybackRate(float rate) {
        if (youTubePlayer != null && !isReleased) {
            PlayerConstants.PlaybackRate playbackRate = PlayerConstants.PlaybackRate.RATE_1;

            if (rate == 0.25f) playbackRate = PlayerConstants.PlaybackRate.RATE_0_25;
            else if (rate == 0.5f) playbackRate = PlayerConstants.PlaybackRate.RATE_0_5;
            else if (rate == 1.5f) playbackRate = PlayerConstants.PlaybackRate.RATE_1_5;
            else if (rate == 2.0f) playbackRate = PlayerConstants.PlaybackRate.RATE_2;

            Log.d(TAG, "[DEBUG] setPlaybackRate() called: " + rate);
            youTubePlayer.setPlaybackRate(playbackRate);
        }
    }

    public void setPlaybackQuality(String quality) {
        Log.d(TAG, "[DEBUG] setPlaybackQuality() called: " + quality + " (not supported by library)");
        preferredQuality = quality;
    }

    public void getAvailableQualityLevels(Object callback) {
        // The library exposes no quality API; always an empty list.
        answer(callback, "levels", new String[]{});
    }

    /** Always invokes the callback, so a caller is never left waiting. */
    private void answer(Object callback, String key, Object value) {
        if (!(callback instanceof KrollFunction) || proxy == null) return;
        KrollDict result = new KrollDict();
        result.put(key, value);
        ((KrollFunction) callback).callAsync(proxy.getKrollObject(), new Object[] { result });
    }

    public void loadVideo(String videoId, float startSeconds) {
        if (isReleased) return;

        currentVideoId = videoId;
        isPlayerReady = false;

        if (loadVideoReadyRunnable != null) {
            mainHandler.removeCallbacks(loadVideoReadyRunnable);
        }

        if (youTubePlayer != null) {
            Log.d(TAG, "[DEBUG] loadVideo() called: " + videoId + " at " + startSeconds);
            youTubePlayer.loadVideo(videoId, startSeconds);

            loadVideoReadyRunnable = () -> {
                if (!isReleased) {
                    isPlayerReady = true;
                    Log.d(TAG, "[DEBUG] Player ready after loadVideo");
                }
            };
            mainHandler.postDelayed(loadVideoReadyRunnable, 2000);
        }
    }

    public void cueVideo(String videoId, float startSeconds) {
        if (isReleased) return;

        currentVideoId = videoId;
        isPlayerReady = false;

        if (cueVideoReadyRunnable != null) {
            mainHandler.removeCallbacks(cueVideoReadyRunnable);
        }

        if (youTubePlayer != null) {
            Log.d(TAG, "[DEBUG] cueVideo() called: " + videoId + " at " + startSeconds);
            youTubePlayer.cueVideo(videoId, startSeconds);

            cueVideoReadyRunnable = () -> {
                if (!isReleased) {
                    isPlayerReady = true;
                    Log.d(TAG, "[DEBUG] Player ready after cueVideo");
                }
            };
            mainHandler.postDelayed(cueVideoReadyRunnable, 2000);
        }
    }

    public void reload() {
        if (youTubePlayer != null && currentVideoId != null && !isReleased) {
            Log.d(TAG, "[DEBUG] reload() called");
            isPlayerReady = false;

            if (reloadReadyRunnable != null) {
                mainHandler.removeCallbacks(reloadReadyRunnable);
            }

            youTubePlayer.loadVideo(currentVideoId, 0f);

            reloadReadyRunnable = () -> {
                if (!isReleased) {
                    isPlayerReady = true;
                    Log.d(TAG, "[DEBUG] Player ready after reload");
                }
            };
            mainHandler.postDelayed(reloadReadyRunnable, 2000);
        }
    }

    public void getDuration(Object callback) {
        answer(callback, "duration", currentDuration);
    }

    public void getCurrentTime(Object callback) {
        answer(callback, "currentTime", currentTime);
    }

    @Override
    public void release() {

        Log.d(TAG, "[DEBUG] Releasing player");

        isReleased = true;
        desiredPlayback = PLAYBACK_NONE;

        cancelPendingRunnables();

        if (metadataFuture != null) {
            metadataFuture.cancel(true);
            metadataFuture = null;
        }
        if (metadataExecutor != null) {
            metadataExecutor.shutdownNow();
            metadataExecutor = null;
        }

        if (mainHandler != null) {
            mainHandler.removeCallbacksAndMessages(null);
        }

        if (fullscreenView != null && containerView != null) {
            containerView.removeView(fullscreenView);
        }
        fullscreenView = null;
        exitFullscreen = null;

        // Unregister before releasing. YouTubePlayerView is its own lifecycle
        // observer and releases itself on ON_DESTROY, so leaving it registered
        // meant release() ran twice on an already destroyed WebView.
        if (youTubePlayerView != null) {
            if (lifecycleRegistry != null) {
                lifecycleRegistry.removeObserver(youTubePlayerView);
            }
            youTubePlayerView.release();
            youTubePlayerView = null;
        }

        if (lifecycleRegistry != null) {
            lifecycleRegistry.setCurrentState(Lifecycle.State.DESTROYED);
        }

        youTubePlayer = null;

        if (containerView != null) {
            containerView.removeAllViews();
            containerView = null;
        }

        // lifecycleRegistry is intentionally kept: getLifecycle() is declared
        // @NonNull and may still be queried during teardown.

        mainHandler = null;

        super.release();
    }
}

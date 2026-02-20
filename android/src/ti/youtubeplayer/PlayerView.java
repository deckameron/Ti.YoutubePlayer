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

public class PlayerView extends TiUIView implements LifecycleOwner {

    private static final String TAG = "PlayerView";

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
    private boolean isReleased = false;

    // NOVO - Runnables para poder cancelar
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

        // Get properties
        String videoId = TiConvert.toString(proxy.getProperty("videoId"));
        boolean autoplay = TiConvert.toBoolean(proxy.getProperty("autoplay"), true);
        boolean loop = TiConvert.toBoolean(proxy.getProperty("loop"), true);
        boolean controls = TiConvert.toBoolean(proxy.getProperty("controls"), false);
        isMuted = TiConvert.toBoolean(proxy.getProperty("muted"), true);
        boolean showCaptions = TiConvert.toBoolean(proxy.getProperty("showCaptions"), false);
        boolean showFullscreenButton = TiConvert.toBoolean(proxy.getProperty("showFullscreenButton"), false);

        // CORRIGIDO - shouldLoop é instância agora
        this.shouldLoop = loop;

        String quality = TiConvert.toString(proxy.getProperty("preferredQuality"));
        if (quality != null) {
            preferredQuality = quality;
        }

        if (videoId != null) {
            currentVideoId = videoId;
            initializePlayer(videoId, autoplay, controls, showCaptions, showFullscreenButton);
        }

        setNativeView(containerView);

        lifecycleRegistry.setCurrentState(Lifecycle.State.STARTED);
        lifecycleRegistry.setCurrentState(Lifecycle.State.RESUMED);
    }

    private void logDiagnostics() {
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
        youTubePlayerView.setLayoutParams(new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));

        youTubePlayerView.setEnableAutomaticInitialization(false);

        // Configure IFrame options
        IFramePlayerOptions.Builder optionsBuilder = new IFramePlayerOptions.Builder(proxy.getActivity())
                .controls(controls ? 1 : 0)
                .ccLoadPolicy(showCaptions ? 1 : 0)
                .ivLoadPolicy(3)
                .rel(0)
                .autoplay(autoplay ? 1 : 0)
                .fullscreen(showFullscreenButton ? 1 : 0);

        IFramePlayerOptions options = optionsBuilder.build();

        // Add lifecycle observer
        getLifecycle().addObserver(youTubePlayerView);

        final WeakReference<PlayerView> weakThis = new WeakReference<>(this);

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
                    player.loadVideo(videoId, 0f);
                } else {
                    player.cueVideo(videoId, 0f);
                }

                // Apply mute
                if (view.isMuted) {
                    player.mute();
                } else {
                    player.unMute();
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

                Log.d(TAG, "[DEBUG] Playback rate changed to: " + rate.toString());
                view.fireEvent("playbackRateChange", view.createEventDict("rate", rate.toString()));
            }

            @Override
            public void onError(@NonNull YouTubePlayer player, @NonNull PlayerConstants.PlayerError error) {
                PlayerView view = weakThis.get();
                if (view == null || view.isReleased) return;

                int errorCode = view.mapErrorToCode(error);
                Log.e(TAG, "[ERROR] Player error: " + error.toString() + " (code: " + errorCode + ")");

                KrollDict event = new KrollDict();
                event.put("message", error.toString());
                event.put("code", errorCode);
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

                KrollDict event = new KrollDict();
                event.put("videoId", videoId);
                view.fireEvent("metadataReceived", event);

                Log.d(TAG, "[DEBUG] Video ID: " + videoId);
            }
        }, options);

        containerView.addView(youTubePlayerView);
    }

    private void applyPreferredQuality() {
        if (youTubePlayer == null || isReleased) return;

        PlayerConstants.PlaybackQuality quality = mapStringToQuality(preferredQuality);
        Log.d(TAG, "[DEBUG] Preferred quality: " + preferredQuality + " (not directly supported by library)");
    }

    private int mapErrorToCode(PlayerConstants.PlayerError error) {
        return switch (error) {
            case INVALID_PARAMETER_IN_REQUEST -> 2;
            case HTML_5_PLAYER -> 5;
            case VIDEO_NOT_FOUND -> 100;
            case VIDEO_NOT_PLAYABLE_IN_EMBEDDED_PLAYER -> 101;
            default -> 5;
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

    // Public methods
    public void play() {
        if (youTubePlayer != null && !isReleased) {
            Log.d(TAG, "[DEBUG] play() called");
            youTubePlayer.play();
        }
    }

    public void pause() {
        if (youTubePlayer != null && !isReleased) {
            Log.d(TAG, "[DEBUG] pause() called");
            youTubePlayer.pause();
        }
    }

    public void stop() {
        if (youTubePlayer != null && !isReleased) {
            Log.d(TAG, "[DEBUG] stop() called");
            youTubePlayer.pause();
            youTubePlayer.seekTo(0);
        }
    }

    public void mute() {
        if (youTubePlayer != null && !isReleased) {
            Log.d(TAG, "[DEBUG] mute() called");
            youTubePlayer.mute();
            isMuted = true;
            fireEvent("muteChanged", createEventDict("muted", true));
        }
    }

    public void unmute() {
        if (youTubePlayer != null && !isReleased) {
            Log.d(TAG, "[DEBUG] unmute() called");
            youTubePlayer.unMute();
            isMuted = false;
            fireEvent("muteChanged", createEventDict("muted", false));
        }
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
        Log.d(TAG, "[DEBUG] getAvailableQualityLevels() called (not supported by library)");

        if (callback instanceof KrollFunction && !isReleased) {
            KrollDict result = new KrollDict();
            result.put("levels", new String[]{});
            ((KrollFunction) callback).callAsync(proxy.getKrollObject(), new Object[] { result });
        }
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
        if (callback instanceof KrollFunction && !isReleased) {
            KrollDict result = new KrollDict();
            result.put("duration", currentDuration);
            ((KrollFunction) callback).callAsync(proxy.getKrollObject(), new Object[] { result });
        }
    }

    public void getCurrentTime(Object callback) {
        if (callback instanceof KrollFunction && !isReleased) {
            KrollDict result = new KrollDict();
            result.put("currentTime", currentTime);
            ((KrollFunction) callback).callAsync(proxy.getKrollObject(), new Object[] { result });
        }
    }

    @Override
    public void release() {

        Log.d(TAG, "[DEBUG] Releasing player");

        isReleased = true;

        cancelPendingRunnables();

        if (mainHandler != null) {
            mainHandler.removeCallbacksAndMessages(null);
        }

        if (youTubePlayerView != null) {
            youTubePlayerView.release();
            youTubePlayerView = null;
        }

        youTubePlayer = null;

        if (containerView != null) {
            containerView.removeAllViews();
            containerView = null;
        }

        // Update lifecycle
        if (lifecycleRegistry != null) {
            lifecycleRegistry.setCurrentState(Lifecycle.State.DESTROYED);
            lifecycleRegistry = null;
        }

        mainHandler = null;

        super.release();
    }
}
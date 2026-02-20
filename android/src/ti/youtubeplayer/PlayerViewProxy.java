package ti.youtubeplayer;

import org.appcelerator.kroll.annotations.Kroll;
import org.appcelerator.titanium.proxy.TiViewProxy;
import org.appcelerator.titanium.view.TiUIView;
import android.app.Activity;

import java.util.HashMap;
import java.util.Objects;

@Kroll.proxy(creatableInModule = TiYoutubePlayerModule.class)
public class PlayerViewProxy extends TiViewProxy {

    private static final String TAG = "PlayerViewProxy";

    public PlayerViewProxy() {
        super();
    }

    @Override
    public TiUIView createView(Activity activity) {
        return new PlayerView(this);
    }

    // Play
    @Kroll.method
    public void play() {
        if (view != null) {
            ((PlayerView) view).play();
        }
    }

    // Pause
    @Kroll.method
    public void pause() {
        if (view != null) {
            ((PlayerView) view).pause();
        }
    }

    // Stop
    @Kroll.method
    public void stop() {
        if (view != null) {
            ((PlayerView) view).stop();
        }
    }

    // Mute
    @Kroll.method
    public void mute() {
        if (view != null) {
            ((PlayerView) view).mute();
        }
    }

    // Unmute
    @Kroll.method
    public void unmute() {
        if (view != null) {
            ((PlayerView) view).unmute();
        }
    }

    // Is Muted
    @Kroll.method
    public boolean isMuted() {
        if (view != null) {
            return ((PlayerView) view).isMuted();
        }
        return false;
    }

    // Seek
    @Kroll.method
    public void seek(float seconds) {
        if (view != null) {
            ((PlayerView) view).seekTo(seconds);
        }
    }

    // Set Playback Rate
    @Kroll.method
    public void setPlaybackRate(float rate) {
        if (view != null) {
            ((PlayerView) view).setPlaybackRate(rate);
        }
    }

    // Change Video
    @Kroll.method
    public void changeVideo(String videoId) {
        if (view != null) {
            ((PlayerView) view).loadVideo(videoId, 0);
        }
    }

    // Load Video
    @Kroll.method
    public void loadVideo(Object[] args) {
        if (view == null || args.length == 0) return;

        if (args[0] instanceof HashMap) {
            @SuppressWarnings("unchecked")
            HashMap<String, Object> params = (HashMap<String, Object>) args[0];
            String videoId = (String) params.get("videoId");
            float startSeconds = params.containsKey("startSeconds")
                    ? ((Number) Objects.requireNonNull(params.get("startSeconds"))).floatValue()
                    : 0f;

            ((PlayerView) view).loadVideo(videoId, startSeconds);
        }
    }

    // Cue Video
    @Kroll.method
    public void cueVideo(Object[] args) {
        if (view == null || args.length == 0) return;

        if (args[0] instanceof HashMap) {
            @SuppressWarnings("unchecked")
            HashMap<String, Object> params = (HashMap<String, Object>) args[0];
            String videoId = (String) params.get("videoId");
            float startSeconds = params.containsKey("startSeconds")
                    ? ((Number) Objects.requireNonNull(params.get("startSeconds"))).floatValue()
                    : 0f;

            ((PlayerView) view).cueVideo(videoId, startSeconds);
        }
    }

    @Kroll.method
    public void setPlaybackQuality(String quality) {
        if (view != null) {
            ((PlayerView) view).setPlaybackQuality(quality);
        }
    }

    @Kroll.method
    public void getAvailableQualityLevels(final @Kroll.argument(optional = true) Object callback) {
        if (view != null) {
            ((PlayerView) view).getAvailableQualityLevels(callback);
        }
    }

    // Reload
    @Kroll.method
    public void reload() {
        if (view != null) {
            ((PlayerView) view).reload();
        }
    }

    // Get Duration (with callback)
    @Kroll.method
    public void getDuration(final @Kroll.argument(optional = true) Object callback) {
        if (view != null) {
            ((PlayerView) view).getDuration(callback);
        }
    }

    // Get Current Time (with callback)
    @Kroll.method
    public void getCurrentTime(final @Kroll.argument(optional = true) Object callback) {
        if (view != null) {
            ((PlayerView) view).getCurrentTime(callback);
        }
    }
}
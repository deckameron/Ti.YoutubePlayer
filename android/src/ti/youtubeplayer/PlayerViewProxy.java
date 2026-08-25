package ti.youtubeplayer;

import org.appcelerator.kroll.annotations.Kroll;
import org.appcelerator.titanium.proxy.TiViewProxy;
import org.appcelerator.titanium.view.TiUIView;
import android.app.Activity;
import android.os.Looper;

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

    /**
     * Kroll methods run on the JS runtime thread. Anything that touches the view
     * hierarchy has to hop to the UI thread first, otherwise Android throws
     * CalledFromWrongThreadException.
     */
    private void onUiThread(Runnable block) {
        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block.run();
        } else {
            activity.runOnUiThread(block);
        }
    }

    private PlayerView player() {
        TiUIView v = this.view;
        return (v instanceof PlayerView) ? (PlayerView) v : null;
    }

    // Play
    @Kroll.method
    public void play() {
        PlayerView p = player();
        if (p != null) {
            p.play();
        }
    }

    // Pause
    @Kroll.method
    public void pause() {
        PlayerView p = player();
        if (p != null) {
            p.pause();
        }
    }

    // Stop
    @Kroll.method
    public void stop() {
        PlayerView p = player();
        if (p != null) {
            p.stop();
        }
    }

    // Mute
    @Kroll.method
    public void mute() {
        PlayerView p = player();
        if (p != null) {
            p.mute();
        }
    }

    // Unmute
    @Kroll.method
    public void unmute() {
        PlayerView p = player();
        if (p != null) {
            p.unmute();
        }
    }

    // Is Muted
    @Kroll.method
    public boolean isMuted() {
        PlayerView p = player();
        return p != null ? p.isMuted() : true;
    }

    // Seek
    @Kroll.method
    public void seek(float seconds) {
        PlayerView p = player();
        if (p != null) {
            p.seekTo(seconds);
        }
    }

    // Scaling Mode
    @Kroll.method
    public void setScalingMode(final int mode) {
        final PlayerView p = player();
        if (p != null) {
            onUiThread(() -> p.setScalingMode(mode));
        }
    }

    // Release
    @Kroll.method
    public void release() {
        final PlayerView p = player();
        if (p != null) {
            onUiThread(p::release);
        }
    }

    // Set Playback Rate
    @Kroll.method
    public void setPlaybackRate(float rate) {
        PlayerView p = player();
        if (p != null) {
            p.setPlaybackRate(rate);
        }
    }

    // Change Video
    @Kroll.method
    public void changeVideo(String videoId) {
        PlayerView p = player();
        if (p != null) {
            p.loadVideo(videoId, 0);
        }
    }

    // Load Video
    @Kroll.method
    public void loadVideo(Object[] args) {
        PlayerView p = player();
        if (p == null || args.length == 0) return;

        if (args[0] instanceof HashMap) {
            @SuppressWarnings("unchecked")
            HashMap<String, Object> params = (HashMap<String, Object>) args[0];
            String videoId = (String) params.get("videoId");
            float startSeconds = params.containsKey("startSeconds")
                    ? ((Number) Objects.requireNonNull(params.get("startSeconds"))).floatValue()
                    : 0f;

            p.loadVideo(videoId, startSeconds);
        }
    }

    // Cue Video
    @Kroll.method
    public void cueVideo(Object[] args) {
        PlayerView p = player();
        if (p == null || args.length == 0) return;

        if (args[0] instanceof HashMap) {
            @SuppressWarnings("unchecked")
            HashMap<String, Object> params = (HashMap<String, Object>) args[0];
            String videoId = (String) params.get("videoId");
            float startSeconds = params.containsKey("startSeconds")
                    ? ((Number) Objects.requireNonNull(params.get("startSeconds"))).floatValue()
                    : 0f;

            p.cueVideo(videoId, startSeconds);
        }
    }

    @Kroll.method
    public void setPlaybackQuality(String quality) {
        PlayerView p = player();
        if (p != null) {
            p.setPlaybackQuality(quality);
        }
    }

    @Kroll.method
    public void getAvailableQualityLevels(final @Kroll.argument(optional = true) Object callback) {
        PlayerView p = player();
        if (p != null) {
            p.getAvailableQualityLevels(callback);
        }
    }

    // Reload
    @Kroll.method
    public void reload() {
        PlayerView p = player();
        if (p != null) {
            p.reload();
        }
    }

    // Get Duration (with callback)
    @Kroll.method
    public void getDuration(final @Kroll.argument(optional = true) Object callback) {
        PlayerView p = player();
        if (p != null) {
            p.getDuration(callback);
        }
    }

    // Get Current Time (with callback)
    @Kroll.method
    public void getCurrentTime(final @Kroll.argument(optional = true) Object callback) {
        PlayerView p = player();
        if (p != null) {
            p.getCurrentTime(callback);
        }
    }
}
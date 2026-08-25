package ti.youtubeplayer;

import org.appcelerator.kroll.KrollDict;
import org.appcelerator.kroll.KrollFunction;
import org.appcelerator.kroll.annotations.Kroll;
import org.appcelerator.titanium.proxy.TiViewProxy;
import org.appcelerator.titanium.view.TiUIView;
import android.app.Activity;
import android.os.Looper;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Objects;

@Kroll.proxy(creatableInModule = TiYoutubePlayerModule.class)
public class PlayerViewProxy extends TiViewProxy {

    private static final String TAG = "PlayerViewProxy";

    public PlayerViewProxy() {
        super();
    }

    /** A command deferred until Titanium has actually built the view. */
    private interface PlayerCommand {
        void run(PlayerView player);
    }

    /**
     * Commands issued before createView() ran.
     *
     * createPlayerView(...) followed immediately by play() executes on the JS runtime
     * thread, while the view is only built later. Dropping those calls leaves the
     * player idle forever when autoplay is off, so they are held here and replayed.
     */
    private final List<PlayerCommand> pendingCommands = new ArrayList<>();
    private static final int MAX_PENDING_COMMANDS = 32;

    @Override
    public TiUIView createView(Activity activity) {
        PlayerView v = new PlayerView(this);
        drainPendingCommands(v);
        return v;
    }

    private void drainPendingCommands(final PlayerView v) {
        final List<PlayerCommand> commands;
        synchronized (pendingCommands) {
            if (pendingCommands.isEmpty()) return;
            commands = new ArrayList<>(pendingCommands);
            pendingCommands.clear();
        }
        onUiThread(() -> {
            for (PlayerCommand c : commands) {
                c.run(v);
            }
        });
    }

    private void discardPendingCommands() {
        synchronized (pendingCommands) {
            pendingCommands.clear();
        }
    }

    /**
     * Answers a query callback immediately with a default.
     *
     * Queries cannot be queued the way commands are — the caller wants a value now,
     * and delivering one much later would be worse than useless. Leaving the callback
     * uncalled is worse still: the caller waits forever.
     */
    private void answerNow(Object callback, String key, Object value) {
        if (!(callback instanceof KrollFunction)) return;
        KrollDict result = new KrollDict();
        result.put(key, value);
        ((KrollFunction) callback).callAsync(getKrollObject(), new Object[] { result });
    }

    /** Runs cmd against the view, queueing it if the view does not exist yet. */
    private void onPlayer(final PlayerCommand cmd) {
        final PlayerView p = player();
        if (p != null) {
            cmd.run(p);
            return;
        }
        synchronized (pendingCommands) {
            if (pendingCommands.size() < MAX_PENDING_COMMANDS) {
                pendingCommands.add(cmd);
            }
        }
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
        onPlayer(p -> p.play());
    }

    // Pause
    @Kroll.method
    public void pause() {
        onPlayer(p -> p.pause());
    }

    // Stop
    @Kroll.method
    public void stop() {
        onPlayer(p -> p.stop());
    }

    // Mute
    @Kroll.method
    public void mute() {
        onPlayer(p -> p.mute());
    }

    // Unmute
    @Kroll.method
    public void unmute() {
        onPlayer(p -> p.unmute());
    }

    // Is Muted
    @Kroll.method
    public boolean isMuted() {
        PlayerView p = player();
        return p != null ? p.isMuted() : true;
    }

    // Seek
    @Kroll.method
    public void seek(final float seconds) {
        onPlayer(p -> p.seekTo(seconds));
    }

    // Scaling Mode
    @Kroll.method
    public void setScalingMode(final int mode) {
        onPlayer(p -> onUiThread(() -> p.setScalingMode(mode)));
    }

    // Release
    @Kroll.method
    public void release() {
        // Anything still queued is for a player the caller is discarding.
        discardPendingCommands();
        final PlayerView p = player();
        if (p != null) {
            onUiThread(p::release);
        }
    }

    // Set Playback Rate
    @Kroll.method
    public void setPlaybackRate(final float rate) {
        onPlayer(p -> p.setPlaybackRate(rate));
    }

    // Change Video
    @Kroll.method
    public void changeVideo(final String videoId) {
        onPlayer(p -> p.loadVideo(videoId, 0));
    }

    // Load Video
    @Kroll.method
    public void loadVideo(Object[] args) {
        if (args.length == 0) return;

        if (args[0] instanceof HashMap) {
            @SuppressWarnings("unchecked")
            HashMap<String, Object> params = (HashMap<String, Object>) args[0];
            final String videoId = (String) params.get("videoId");
            final float startSeconds = params.containsKey("startSeconds")
                    ? ((Number) Objects.requireNonNull(params.get("startSeconds"))).floatValue()
                    : 0f;

            onPlayer(p -> p.loadVideo(videoId, startSeconds));
        }
    }

    // Cue Video
    @Kroll.method
    public void cueVideo(Object[] args) {
        if (args.length == 0) return;

        if (args[0] instanceof HashMap) {
            @SuppressWarnings("unchecked")
            HashMap<String, Object> params = (HashMap<String, Object>) args[0];
            final String videoId = (String) params.get("videoId");
            final float startSeconds = params.containsKey("startSeconds")
                    ? ((Number) Objects.requireNonNull(params.get("startSeconds"))).floatValue()
                    : 0f;

            onPlayer(p -> p.cueVideo(videoId, startSeconds));
        }
    }

    @Kroll.method
    public void setPlaybackQuality(final String quality) {
        onPlayer(p -> p.setPlaybackQuality(quality));
    }

    @Kroll.method
    public void getAvailableQualityLevels(final @Kroll.argument(optional = true) Object callback) {
        PlayerView p = player();
        if (p != null) {
            p.getAvailableQualityLevels(callback);
        } else {
            answerNow(callback, "levels", new String[] {});
        }
    }

    // Reload
    @Kroll.method
    public void reload() {
        onPlayer(p -> p.reload());
    }

    // Get Duration (with callback)
    @Kroll.method
    public void getDuration(final @Kroll.argument(optional = true) Object callback) {
        PlayerView p = player();
        if (p != null) {
            p.getDuration(callback);
        } else {
            answerNow(callback, "duration", 0f);
        }
    }

    // Get Current Time (with callback)
    @Kroll.method
    public void getCurrentTime(final @Kroll.argument(optional = true) Object callback) {
        PlayerView p = player();
        if (p != null) {
            p.getCurrentTime(callback);
        } else {
            answerNow(callback, "currentTime", 0f);
        }
    }
}
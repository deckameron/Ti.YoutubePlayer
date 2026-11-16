const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const android = fs.readFileSync(path.join(root, 'android/src/ti/youtubeplayer/PlayerView.java'), 'utf8').match(/CAPTIONS_SCRIPT = """\n([\s\S]*?)\n\s*""";/)[1];
const ios = fs.readFileSync(path.join(root, 'ios/TiYoutubeplayerView.swift'), 'utf8').match(/captionsScript = """\n([\s\S]*?)\n\s*"""/)[1];

test('both platforms execute the same captions policy', () => {
    const normalize = source => source.split('\n').map(line => line.trim()).join('\n');
    assert.equal(normalize(android), normalize(ios));
});

for (const [platform, source] of [['android', android], ['ios', ios]]) {
    test(platform + ': toggle preserves named tracks and follows video changes', () => {
        const english = { languageCode: 'en', name: 'English' };
        const spanish = { languageCode: 'es', name: 'Español' };
        let tracks = [english];
        let selected = english;
        let video = 'first';
        const listeners = {};
        const window = { player: {
            getVideoData: () => ({ video_id: video }),
            getOption: (module, option) => option === 'tracklist' ? tracks : selected,
            setOption: (module, option, track) => { selected = track; },
            loadModule() {},
            addEventListener: (event, listener) => { listeners[event] = listener; }
        } };
        const context = vm.createContext({ window });
        const set = enabled => vm.runInContext(source.replace('__ENABLED__', String(enabled)), context);
        set(false);
        assert.equal(selected.languageCode, undefined);
        set(true);
        assert.equal(selected, english);
        set(false);
        video = 'second';
        selected = english;
        window[listeners.onApiChange]({});
        assert.equal(selected.languageCode, undefined);
        tracks = [spanish];
        set(true);
        assert.equal(selected, spanish);
        video = 'no-captions';
        tracks = [];
        window[listeners.onStateChange]({ data: 1 });
        set(false);
        assert.equal(selected.languageCode, undefined);
        set(false);
        for (const restartState of [-1, 0, 5]) {
            window[listeners.onStateChange]({ data: restartState });
            selected = english;
            window[listeners.onStateChange]({ data: 1 });
            assert.equal(selected.languageCode, undefined, 'same video restart ' + restartState);
        }
        assert.equal(Object.keys(listeners).length, 2);
    });

    test(platform + ': repeated API events cannot cause an application loop', () => {
        let calls = 0;
        const listeners = {};
        const window = { player: {
            getVideoData: () => ({ video_id: 'first' }),
            getOption: () => null,
            setOption: () => {
                calls++;
                if (listeners.onApiChange) window[listeners.onApiChange]({});
            },
            addEventListener: (event, listener) => { listeners[event] = listener; }
        } };
        vm.runInNewContext(source.replace('__ENABLED__', 'false'), { window });
        assert.equal(calls, 2);
        window[listeners.onApiChange]({});
        window[listeners.onStateChange]({ data: 2 });
        assert.equal(calls, 2);
        window[listeners.onStateChange]({ data: 1 });
        assert.equal(calls, 3);
        window[listeners.onStateChange]({ data: 1 });
        assert.equal(calls, 3);
    });
}

import QtQuick
import org.kde.plasma.plasmoid
import "../../code/pear/ytm.js" as Ytm

// Pear Desktop api for auth, search, play and allat other stuff
Item {
    id: pearApi
    visible: false

    readonly property string apiUrl: (Plasmoid.configuration.apiUrl || "http://127.0.0.1:26538").replace(/\/+$/, "")
    property string apiToken: ""
    property var searchResults: []
    property bool searching: false
    property string searchError: ""

    readonly property bool configured: true

    signal searchAccepted()

    function reportUnconfigured() {}

    function clearSearch() {
        searchResults = [];
        searchError = "";
        searchQuery = "";
        searching = false;
        searchTries = 0;
        searchAutoLaunched = false;
        searchDeadline = 0;
        appWait.stop();
        searchRetry.stop();
        searchWatchdog.stop();
    }

    function apiRequest(method, path, body, cb, retried) {
        var xhr = new XMLHttpRequest();
        var done = false;
        xhr.timeout = 5000;
        xhr.ontimeout = function () {
            if (done) return;
            done = true;
            cb(false, 0, "");
        };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || done) return;
            done = true;
            if ((xhr.status === 401 || xhr.status === 403) && !retried) {
                apiAuth(function (ok) {
                    if (ok) apiRequest(method, path, body, cb, true);
                    else cb(false, xhr.status, "");
                });
                return;
            }
            cb(xhr.status >= 200 && xhr.status < 300, xhr.status, xhr.responseText);
        };
        xhr.open(method, apiUrl + path);
        xhr.setRequestHeader("Content-Type", "application/json");
        if (apiToken !== "") xhr.setRequestHeader("Authorization", "Bearer " + apiToken);
        xhr.send(body ? JSON.stringify(body) : null);
    }

    property var authWaiters: []
    function apiAuth(cb) {
        authWaiters.push(cb);
        if (authWaiters.length > 1) return;
        function finish(ok) {
            var ws = pearApi.authWaiters;
            pearApi.authWaiters = [];
            for (var i = 0; i < ws.length; i++) ws[i](ok);
        }
        var xhr = new XMLHttpRequest();
        var done = false;
        xhr.timeout = 10000;
        xhr.ontimeout = function () {
            if (done) return;
            done = true;
            finish(false);
        };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || done) return;
            done = true;
            var ok = false;
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    var j = JSON.parse(xhr.responseText);
                    if (j.accessToken) { pearApi.apiToken = j.accessToken; ok = true; }
                } catch (e) {}
            }
            finish(ok);
        };
        xhr.open("POST", apiUrl + "/auth/Chorus");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send("{}");
    }

    property string searchQuery: ""
    property int searchTries: 0
    property bool searchAutoLaunched: false
    property double searchDeadline: 0
    Timer {
        id: searchRetry
        interval: 1500
        repeat: false
        onTriggered: pearApi.performSearch()
    }

    Timer {
        id: searchWatchdog
        interval: 30000
        repeat: false
        onTriggered: {
            if (!pearApi.searching) return;
            pearApi.searching = false;
            pearApi.searchError = pearApi.searchAutoLaunched
                ? i18n("YouTube Music started but isn't responding. It may be unavailable in your region, or the \"API Server\" plugin is disabled")
                : i18n("Search timed out");
            appWait.stop();
            searchRetry.stop();
        }
    }
    Timer {
        id: appWait
        property int ticks: 0
        interval: 500
        repeat: true
        onTriggered: {
            if (pearApi.searchQuery === "") {
                stop();
                pearApi.searching = false;
                return;
            }
            if (root.searchAppRunning) {
                stop();
                pearApi.searchDeadline = Date.now() + 20000;
                searchWatchdog.restart();
                searchRetry.interval = 3000;
                searchRetry.restart();
            } else if (++ticks > 50) {
                stop();
                pearApi.searching = false;
                pearApi.searchError = i18n("YouTube Music didn't start. Check the Start command in the widget settings");
            }
        }
    }
    Timer {
        id: launchWatch
        property int ticks: 0
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.searchAppRunning) { stop(); return; }
            if (++ticks >= 25) {
                stop();
                if (pearApi.searchError === "" && !pearApi.searching)
                    pearApi.searchError = i18n("YouTube Music didn't start. Check the Start command in the widget settings");
            }
        }
    }

    function doSearch(query) {
        if (query.trim() === "") { searchResults = []; searchError = ""; return; }
        searchQuery = query;
        searchTries = 0;
        searchAutoLaunched = Date.now() < searchDeadline;
        searching = true;
        searchError = "";
        searchWatchdog.restart();
        if (!root.searchAppRunning) {
            searchAutoLaunched = true;
            launchApp();
            appWait.ticks = 0;
            appWait.restart();
            return;
        }
        performSearch();
    }

    function performSearch() {
        var query = searchQuery;
        apiRequest("POST", "/api/v1/search", { query: query }, function (ok, status, resp) {
            if (pearApi.searchQuery !== query) return;
            if (!ok) {
                if ((status === 0 || status === 401 || status === 403 || status === 503)
                        && pearApi.searchAutoLaunched && Date.now() < pearApi.searchDeadline) {
                    searchRetry.interval = 1500;
                    searchRetry.restart();
                    return;
                }
                pearApi.searching = false;
                pearApi.searchResults = [];
                if ((status === 0 || status === 503) && pearApi.searchAutoLaunched)
                    pearApi.searchError = i18n("YouTube Music started but isn't responding. It may be unavailable in your region, or the \"API Server\" plugin is disabled");
                else if (status === 0)
                    pearApi.searchError = i18n("Can't reach the API server. Enable the \"API Server\" plugin in YouTube Music");
                else
                    pearApi.searchError = i18n("Search failed (HTTP %1)", status);
                return;
            }
            var songs = Ytm.parseSearch(resp);
            if (songs.length === 0 && pearApi.searchAutoLaunched && pearApi.searchTries < 6
                    && Date.now() < pearApi.searchDeadline) {
                pearApi.searchTries++;
                searchRetry.interval = 1500;
                searchRetry.restart();
                return;
            }
            pearApi.searching = false;
            pearApi.searchError = "";
            if (Plasmoid.configuration.preferSongs)
                songs = pearApi.songsFirst(songs);
            pearApi.searchResults = songs;
            if (songs.length === 0)
                pearApi.searchError = pearApi.searchAutoLaunched
                    ? i18n("No results. If this keeps happening, YouTube Music may not be available in your region")
                    : i18n("No results");
        });
    }

    property string pendingPlayId: ""
    property int pendingTries: 0
    Timer {
        id: playDelay
        interval: 700
        repeat: false
        onTriggered: pearApi.jumpToPending()
    }

    // song > video setting
    function songsFirst(list) {
        var songs = [], vids = [];
        for (var i = 0; i < list.length; i++) {
            var sub = (list[i].subtitle || "").toLowerCase();
            var isVid = sub.indexOf("video") === 0 || sub.indexOf("views") !== -1;
            (isVid ? vids : songs).push(list[i]);
        }
        return songs.concat(vids);
    }

    function playSearchResult(item) {
        var videoId = item.videoId;
        var coldStart = !(root.currentPlayerIs("youtube") && root.isPlaying);
        var extras = [];
        var cfgExtras = Number(Plasmoid.configuration.extraQueue);
        var maxExtras = Math.max(0, Math.min(15, isNaN(cfgExtras) ? 5 : cfgExtras));
        if (coldStart) {
            var seen = false;
            for (var i = 0; i < searchResults.length && extras.length < maxExtras; i++) {
                if (searchResults[i].videoId === videoId) { seen = true; continue; }
                if (seen) extras.push(searchResults[i].videoId);
            }
            if (extras.length === 0)
                for (var j = 0; j < searchResults.length && extras.length < maxExtras; j++)
                    if (searchResults[j].videoId !== videoId) extras.push(searchResults[j].videoId);
        }
        // show song title and thumbnail before it loads  
        root.showOptimistic({
            title: item.title || "",
            artist: (item.subtitle || "").split("•")[0].split("•")[0].trim(),
            art: item.thumb || (videoId ? "https://i.ytimg.com/vi/" + encodeURIComponent(videoId) + "/hqdefault.jpg" : "")
        });
        searchQuery = "";
        appWait.stop();
        searchAccepted();
        apiRequest("POST", "/api/v1/queue", {
            videoId: videoId,
            insertPosition: coldStart ? "INSERT_AT_END" : "INSERT_AFTER_CURRENT_VIDEO"
        }, function (ok) {
            if (!ok) {
                pearApi.searchError = i18n("Couldn't queue the song");
                root.optimistic = null;
                return;
            }
            pearApi.pendingPlayId = videoId;
            pearApi.pendingTries = 0;
            playDelay.restart();
            if (extras.length > 0)
                pearApi.queueChain(extras);
        });
    }

    function queueChain(ids) {
        if (ids.length === 0) return;
        var id = ids.shift();
        apiRequest("POST", "/api/v1/queue", {
            videoId: id,
            insertPosition: "INSERT_AT_END"
        }, function () {
            pearApi.queueChain(ids);
        });
    }

    function jumpToPending() {
        var vid = pendingPlayId;
        if (vid === "") return;
        apiRequest("GET", "/api/v1/queue", null, function (ok, status, resp) {
            if (pearApi.pendingPlayId !== vid) return;
            var idx = -1;
            if (ok) {
                var q = Ytm.parseQueue(resp);
                console.log("[chorus] queue read:", q.items.length, "items, selected:", q.selectedIndex);
                var start = q.selectedIndex >= 0 ? q.selectedIndex + 1 : 0;
                for (var i = start; i < q.items.length; i++)
                    if (q.items[i].videoId === vid) { idx = i; break; }
                if (idx === -1)
                    for (var j = 0; j < q.items.length; j++)
                        if (q.items[j].videoId === vid) { idx = j; break; }
            }
            if (idx >= 0) {
                pearApi.pendingPlayId = "";
                console.log("[chorus] jumping to queue index", idx);
                pearApi.apiRequest("PATCH", "/api/v1/queue", { index: idx }, function (ok2, st2) {
                    if (!ok2) {
                        console.log("[chorus] setQueueIndex failed:", st2);
                        pearApi.searchError = i18n("Queued, but couldn't jump to it (HTTP %1)", st2);
                        return;
                    }
                    pearApi.apiRequest("POST", "/api/v1/play", null, function () {});
                    root.settleOptimistic();
                });
            } else if (pearApi.pendingTries < 5) {
                pearApi.pendingTries++;
                playDelay.restart();
            } else {
                pearApi.pendingPlayId = "";
                root.optimistic = null;
                pearApi.searchError = i18n("Song was queued but not found in the queue");
                console.log("[chorus] gave up finding", vid, "in queue");
            }
        });
    }

    property bool shuffleOn: false
    property string repeatMode: "NONE"
    function refreshModes() {
        if (!root.pearIsCurrent) return;
        apiRequest("GET", "/api/v1/shuffle", null, function (ok, status, resp) {
            if (!ok) return;
            try {
                var st = JSON.parse(resp).state === true;
                if (st !== pearApi.shuffleOn)
                    console.log("[chorus] shuffle state from api-server:", st);
                pearApi.shuffleOn = st;
            } catch (e) {}
        });
        apiRequest("GET", "/api/v1/repeat-mode", null, function (ok, status, resp) {
            if (!ok) return;
            try {
                var m = JSON.parse(resp).mode || "NONE";
                if (m !== pearApi.repeatMode)
                    console.log("[chorus] repeat mode from api-server:", m);
                pearApi.repeatMode = m;
            } catch (e) {}
        });
    }

    Timer {
        id: modeVerify
        property int ticks: 0
        interval: 400
        repeat: true
        onTriggered: {
            ticks++;
            pearApi.refreshModes();
            if (ticks >= 4) stop();
        }
    }
    function verifyModes() {
        modeVerify.ticks = 0;
        modeVerify.restart();
        refreshModes();
    }
    function doShuffle() {
        apiRequest("POST", "/api/v1/shuffle", null, function (ok) {
            if (ok) verifyModes();
            else root.mprisShuffle();
        });
    }
    function doLoop() {
        apiRequest("POST", "/api/v1/switch-repeat", { iteration: 1 }, function (ok) {
            if (ok) verifyModes();
            else root.mprisLoop();
        });
    }
    Connections {
        target: root
        function onExpandedChanged() { if (root.expanded) pearApi.refreshModes(); }
        function onPearIsCurrentChanged() { if (root.pearIsCurrent) pearApi.refreshModes(); }
    }

    function launchApp() {
        var cmd = (Plasmoid.configuration.launchCmd || "youtube-music").trim();
        if (cmd === "") return;
        root.runCmdWatch("sh -c '( " + cmd.split("'").join("") + " ) >/dev/null 2>&1 & p=$!; sleep 2; st=$(ps -o state= -p $p 2>/dev/null); if [ -n \"$st\" ] && [ \"$st\" != \"Z\" ]; then echo chorus-ok; elif wait $p; then echo chorus-ok; else echo chorus-fail; fi'",
            function (out) {
                if (out.indexOf("chorus-fail") === -1 || root.searchAppRunning) return;
                launchWatch.stop();
                appWait.stop();
                searchRetry.stop();
                pearApi.searching = false;
                pearApi.searchError = i18n("YouTube Music couldn't start. Check the Start command in the widget settings");
            });
        if (!root.searchAppRunning) { launchWatch.ticks = 0; launchWatch.restart(); }
    }

    function closeApp() {
        var kill = (Plasmoid.configuration.closeCmd || "pkill -9 -f youtube-music").trim().split("'").join("");
        if (kill === "") return;
        root.runCmd("sh -c '" + kill + " >/dev/null 2>&1'");
    }
}

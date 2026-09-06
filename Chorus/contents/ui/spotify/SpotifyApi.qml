import QtQuick
import org.kde.plasma.plasmoid

// Spotify Web API used for searching songs (it does need premium but it does work even if you use someone else's creds, not that i recommend it tho might even get either of the accounts banned (?))
Item {
    id: api

    readonly property string clientId: (Plasmoid.configuration.spotifyClientId || "").trim()
    readonly property string clientSecret: (Plasmoid.configuration.spotifyClientSecret || "").trim()
    readonly property bool configured: clientId !== "" && clientSecret !== ""

    property string token: ""
    property double tokenExpiresAt: 0

    property bool searching: false
    property string searchError: ""
    property var searchResults: []
    property int searchGen: 0

    signal searchAccepted()

    onClientIdChanged: { token = ""; tokenExpiresAt = 0; }
    onClientSecretChanged: { token = ""; tokenExpiresAt = 0; }

    function reportUnconfigured() {
        searchGen++;
        searching = false;
        searchResults = [];
        searchError = i18n("Add a Spotify client ID and secret in the widget settings to search");
    }

    function clearSearch() {
        searchGen++;
        searchResults = [];
        searchError = "";
        searching = false;
    }

    function authThen(cb) {
        if (token !== "" && Date.now() < tokenExpiresAt - 30000) { cb(true, 200); return; }
        var xhr = new XMLHttpRequest();
        var done = false;
        function finish(ok, status) { if (done) return; done = true; cb(ok, status); }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            var ok = false;
            if (xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText);
                    if (d && d.access_token) {
                        api.token = d.access_token;
                        api.tokenExpiresAt = Date.now() + (d.expires_in > 0 ? d.expires_in : 3600) * 1000;
                        ok = true;
                    }
                } catch (e) {}
            }
            finish(ok, xhr.status);
        };
        xhr.timeout = 15000;
        xhr.ontimeout = function () { finish(false, 0); };
        xhr.open("POST", "https://accounts.spotify.com/api/token");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(clientId + ":" + clientSecret));
        xhr.send("grant_type=client_credentials");
    }

    function doSearch(q) {
        q = (q || "").trim();
        if (q === "" || !configured) return;
        searchGen++;
        searching = true;
        searchError = "";
        searchResults = [];
        runSearch(q, searchGen, false);
    }

    function runSearch(q, gen, retried) {
        authThen(function (ok, status) {
            if (api.searchGen !== gen) return;
            if (!ok) {
                api.searching = false;
                api.searchError = (status === 400 || status === 401 || status === 403)
                    ? i18n("Spotify sign-in failed. Check the client ID and secret in the widget settings")
                    : i18n("Could not reach Spotify. Check your connection");
                return;
            }
            var xhr = new XMLHttpRequest();
            var done = false;
            function fail(msg) {
                if (done) return;
                done = true;
                if (api.searchGen !== gen) return;
                api.searching = false;
                api.searchError = msg;
            }
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE || done) return;
                if (api.searchGen !== gen) { done = true; return; }
                if ((xhr.status === 401 || xhr.status === 403) && !retried) {
                    done = true;
                    api.token = "";
                    api.runSearch(q, gen, true);
                    return;
                }
                if (xhr.status !== 200) { fail(i18n("Spotify search failed (HTTP %1)", xhr.status)); return; }
                done = true;
                var out = [];
                try {
                    var items = JSON.parse(xhr.responseText).tracks.items;
                    for (var i = 0; i < items.length && out.length < 10; i++) {
                        var t = items[i];
                        if (!t || !t.id || typeof t.name !== "string" || t.name === "") continue;
                        var names = [];
                        if (t.artists)
                            for (var j = 0; j < t.artists.length; j++)
                                if (t.artists[j] && typeof t.artists[j].name === "string") names.push(t.artists[j].name);
                        var art = "";
                        if (t.album && t.album.images && t.album.images.length > 0
                                && typeof t.album.images[0].url === "string")
                            art = t.album.images[0].url;
                        if (art.indexOf("https://") !== 0) art = "";
                        out.push({ id: String(t.id), title: t.name, subtitle: names.join(", "), art: art });
                    }
                } catch (e) {}
                api.searching = false;
                if (out.length === 0) api.searchError = i18n("No results");
                api.searchResults = out;
            };
            xhr.timeout = 10000;
            xhr.ontimeout = function () { fail(i18n("Spotify search timed out")); };
            xhr.open("GET", "https://api.spotify.com/v1/search?type=track&limit=10&q=" + encodeURIComponent(q));
            xhr.setRequestHeader("Authorization", "Bearer " + api.token);
            xhr.send();
        });
    }

    function playSearchResult(item) {
        if (!item || !/^[0-9A-Za-z]{10,40}$/.test(item.id || "")) return;
        var uri = "spotify:track:" + item.id;
        // preview song's title and thumbnail before the song actually plays
        root.showOptimistic({ title: item.title || "", artist: item.subtitle || "", art: item.art || "" });
        if (root.searchAppRunning) {
            if (!(root.currentPlayerIs("spotify") && root.safeCall(["openUri", "OpenUri"], uri)))
                root.runCmd("gdbus call --session --dest org.mpris.MediaPlayer2.spotify"
                            + " --object-path /org/mpris/MediaPlayer2"
                            + " --method org.mpris.MediaPlayer2.Player.OpenUri " + uri);
        } else {
            root.runCmd("sh -c 'xdg-open \"" + uri + "\" >/dev/null 2>&1"
                        + " || xdg-open \"https://open.spotify.com/track/" + item.id + "\" >/dev/null 2>&1'");
        }
        searchAccepted();
        clearSearch();
    }

    function launchApp() {
        var cmd = (Plasmoid.configuration.spotifyLaunchCmd
                   || "gtk-launch spotify || gtk-launch com.spotify.Client || spotify").trim();
        if (cmd === "") return;
        root.runCmd("sh -c '( " + cmd.split("'").join("") + " ) >/dev/null 2>&1 &'");
    }
    function closeApp() {
        var cmd = (Plasmoid.configuration.spotifyCloseCmd || "pkill -x spotify").trim().split("'").join("");
        if (cmd === "") return;
        root.runCmd("sh -c '" + cmd + " >/dev/null 2>&1'");
    }
}

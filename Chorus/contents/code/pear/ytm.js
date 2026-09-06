.pragma library

function _runsText(t) {
    try {
        if (!t) return "";
        if (t.runs) return t.runs.map(function (r) { return r.text; }).join("");
        if (t.simpleText) return t.simpleText;
    } catch (e) {}
    return "";
}

function _findVideoId(obj, depth) {
    if (!obj || depth > 8) return null;
    if (typeof obj !== "object") return null;
    if (obj.watchEndpoint && obj.watchEndpoint.videoId) return obj.watchEndpoint.videoId;
    if (obj.videoId && typeof obj.videoId === "string") return obj.videoId;
    for (var k in obj) {
        var v = obj[k];
        if (v && typeof v === "object") {
            var r = _findVideoId(v, depth + 1);
            if (r) return r;
        }
    }
    return null;
}

function _findThumb(obj, depth) {
    if (!obj || typeof obj !== "object" || depth > 8) return null;
    if (Array.isArray(obj.thumbnails) && obj.thumbnails.length > 0) {
        var best = obj.thumbnails[obj.thumbnails.length - 1];
        if (best && best.url) return best.url;
    }
    for (var k in obj) {
        var v = obj[k];
        if (v && typeof v === "object") {
            var r = _findThumb(v, depth + 1);
            if (r) return r;
        }
    }
    return null;
}

function _fromListItem(r) {
    try {
        var title = "", subtitle = "";
        if (r.flexColumns && r.flexColumns.length > 0) {
            title = _runsText(r.flexColumns[0].musicResponsiveListItemFlexColumnRenderer.text);
            if (r.flexColumns.length > 1)
                subtitle = _runsText(r.flexColumns[1].musicResponsiveListItemFlexColumnRenderer.text);
        }
        var vid = null;
        if (r.playlistItemData && r.playlistItemData.videoId) vid = r.playlistItemData.videoId;
        if (!vid && r.overlay) vid = _findVideoId(r.overlay, 0);
        if (!vid && r.flexColumns) vid = _findVideoId(r.flexColumns[0], 0);
        if (vid && title) return { videoId: vid, title: title, subtitle: subtitle,
                                   thumb: _findThumb(r.thumbnail, 0) || "" };
    } catch (e) {}
    return null;
}

function _fromCardShelf(r) {
    try {
        var title = _runsText(r.title);
        var subtitle = _runsText(r.subtitle);
        var vid = _findVideoId(r.title, 0) || _findVideoId(r.onTap, 0) || _findVideoId(r.thumbnailOverlay, 0);
        if (vid && title) return { videoId: vid, title: title, subtitle: subtitle,
                                   thumb: _findThumb(r.thumbnail, 0) || _findThumb(r, 0) || "" };
    } catch (e) {}
    return null;
}

function extractSongs(obj, out, depth, seen) {
    if (!obj || typeof obj !== "object" || depth > 24 || out.length >= 20) return;
    if (obj.musicResponsiveListItemRenderer) {
        var s = _fromListItem(obj.musicResponsiveListItemRenderer);
        if (s && !seen[s.videoId]) { seen[s.videoId] = true; out.push(s); }
    }
    if (obj.musicCardShelfRenderer) {
        var c = _fromCardShelf(obj.musicCardShelfRenderer);
        if (c && !seen[c.videoId]) { seen[c.videoId] = true; out.push(c); }
    }
    if (Array.isArray(obj)) {
        for (var i = 0; i < obj.length; i++) extractSongs(obj[i], out, depth + 1, seen);
        return;
    }
    for (var k in obj) {
        var v = obj[k];
        if (v && typeof v === "object") extractSongs(v, out, depth + 1, seen);
    }
}

function parseSearch(jsonText) {
    var out = [];
    try {
        var data = JSON.parse(jsonText);
        extractSongs(data, out, 0, {});
    } catch (e) {}
    return out;
}

function _extractQueue(obj, out, depth) {
    if (!obj || typeof obj !== "object" || depth > 24) return;
    if (obj.playlistPanelVideoRenderer) {
        var r = obj.playlistPanelVideoRenderer;
        if (r.videoId) out.push({ videoId: r.videoId, selected: r.selected === true });
        return; // don't recurse into counterpart/inner duplicates
    }
    if (Array.isArray(obj)) {
        for (var i = 0; i < obj.length; i++) _extractQueue(obj[i], out, depth + 1);
        return;
    }
    for (var k in obj) {
        var v = obj[k];
        if (v && typeof v === "object") _extractQueue(v, out, depth + 1);
    }
}

// -> { items: [{videoId, selected}], selectedIndex }
function parseQueue(jsonText) {
    var items = [];
    try {
        var data = JSON.parse(jsonText);
        _extractQueue(data, items, 0);
    } catch (e) {}
    var sel = -1;
    for (var i = 0; i < items.length; i++)
        if (items[i].selected) { sel = i; break; }
    return { items: items, selectedIndex: sel };
}

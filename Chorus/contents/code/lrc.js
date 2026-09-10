// LRC parsing + binary search helpers
.pragma library

// normalize typographic punctuation in CJK fonts. (basically i was testing the plugin with a zcool font and it had some weird artifacts and this was the fix to that, if youre not using a cjk font then dw bout it :v:)
function normalize(s) {
    if (!s) return s;
    return s
        .replace(/[\u2018\u2019\u02BC\u00B4\u0060]/g, "'")   // ‘ ’ ʼ ´ ` -> '
        .replace(/[\u201C\u201D\u201E]/g, '"')               // “ ” „ -> "
        .replace(/\u2026/g, "...")                            // … -> ...
        .replace(/[\u2013\u2014]/g, "-")                      // – — -> -
        .replace(/\u00A0/g, " ")                              // nbsp -> space
        .replace(/\u3000/g, " ");                             // fullwidth space
}

function parse(lrcText) {
    var lines = [];
    if (!lrcText) return lines;
    var re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
    var raw = lrcText.split(/\r?\n/);
    for (var i = 0; i < raw.length; i++) {
        var line = raw[i];
        var m, times = [], lastIdx = 0;
        re.lastIndex = 0;
        while ((m = re.exec(line)) !== null) {
            times.push((parseInt(m[1], 10) * 60 + parseFloat(m[2])) * 1000);
            lastIdx = re.lastIndex;
        }
        if (times.length === 0) continue;
        var text = normalize(line.slice(lastIdx).trim());
        for (var j = 0; j < times.length; j++)
            lines.push({ t: times[j], text: text });
    }
    lines.sort(function (a, b) { return a.t - b.t; });
    return lines;
}

function indexFor(lines, ms) {
    var lo = 0, hi = lines.length - 1, ans = -1;
    while (lo <= hi) {
        var mid = (lo + hi) >> 1;
        if (lines[mid].t <= ms) { ans = mid; lo = mid + 1; }
        else hi = mid - 1;
    }
    return ans;
}

function escapeHtml(s) {
    return String(s)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function fontSpan(s, css) {
    if (!css || css === "") return s;
    return '<span style="font-family: ' + css + '; white-space: pre">'
           + escapeHtml(s) + '</span>';
}

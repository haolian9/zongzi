// ref
// * https://github.com/brookhong/Surfingkeys/blob/master/docs/API.md

const {
    aceVimMap,
    mapkey,
    imap,
    imapkey,
    getClickableElements,
    vmapkey,
    map,
    unmap,
    cmap,
    addSearchAlias,
    removeSearchAlias,
    tabOpenLink,
    readText,
    Clipboard,
    Front,
    Hints,
    Visual,
    RUNTIME
} = api;


const rm_nmaps = [
    // proxy
    'cp',
    // o
    'ob', 'od', 'oa', 'og','oh', 'oi', 'om', 'on', 'ox', 'oy', 'O',
    // g
    'gr', 'gt', 'gT', 'go', 'gxx', 'gx$', 'gx0', 'gxT', 'gxt', 'gU', 'g#',
    'g?', 'gs', 'gn', 'ge', 'ge', 'gk', 'gh', 'gd', 'gc', 'gb', 'ga',
    // u
    'u',
    // semicolon
    ';cp', ';ap', ';pa', ';pb', ';pd', ';ps', ';pc', ';s', ';w', ';pf',
    ';i', ';pm', ';u', ';U', ';m', ';j', ';pp', ';t', ';dh',
    ';db', ';pj', ';di', ';gt', ';gw',
    // c
    'cf', 'C', 'cc', 'cp', 'cS', 'cq', 'cs',
    // z
    'zi', 'zo', 'zr', 'zv',
    // a
    'ab', 'af',
    // s
    'sb', 'sd', 'se', 'sg', 'sh', 'ss', 'sw', 'sy',
    // misc
    'H', 'Q', 'b', 'B', 'F', '<Ctrl-6>', 'S', 'D', '.', ';ql', 'p', ';fs', 'q',
    '[[', ']]', '0', 'e', 'd', '$', '%', 'w', 'W', 't',
    // y
    'yv', 'ymv', 'yi', 'ys', 'yj', 'yd', 'yt', 'yT', 'yh', 'yl', 'yQ', 'yf', 'yg',
    'yp', 'yma', 'yc', 'ymc', 'yq', 'yG', 'yS',
    // alt-
    '<Alt-i>', '<Alt-n>', '<Alt-p>', '<Alt-m>',
    // ctrl-
    '<Ctrl-h>', '<Ctrl-j>',
    // z
    'ZZ', 'ZR',
];
rm_nmaps.forEach(function(el, ix) {
    unmap(el);
});

const rm_vmaps = [
    // g
    'gr',
];
rm_vmaps.forEach(function(el, ix) {
    unmap(el);
});

const rm_searches = [
    'b', 'e', 'w', 's', 'h', 'y'
];
rm_searches.forEach(function(el, ix) {
    removeSearchAlias(el, 'g');
});

// ------------------- new born --------------------------------------

mapkey('u', '#8Open recently closed URL', function() {
    Front.openOmnibar({type: "URLs", extra: "getRecentlyClosed"});
});

mapkey('o', '#8Open a URL', function() {
    Front.openOmnibar({type: "URLs", extra: "getAllSites"});
});

map('g0', ':feedkeys 99E', 0, "#3Go to the first tab");
map('g$', ':feedkeys 99R', 0, "#3Go to the last tab");
mapkey('gf', '#1Open a link in non-active new tab', function() {
    Hints.create("", Hints.dispatchMouseClick, {tabbed: true, active: false});
});
mapkey('gi', '#1Go to the first edit box', function() {
    Hints.createInputLayer();
});

mapkey('go', '#4Edit current URL with vim editor, and reload', function() {
    Front.showEditor(window.location.href, function(data) {
        window.location.href = data;
    }, 'url');
});

mapkey('gu', '#4Go up one path in the URL', function() {
    var pathname = location.pathname;
    if (pathname.length > 1) {
        pathname = pathname.endsWith('/') ? pathname.substr(0, pathname.length - 1) : pathname;
        var last = pathname.lastIndexOf('/'), repeats = RUNTIME.repeats;
        RUNTIME.repeats = 1;
        while (repeats-- > 1) {
            var p = pathname.lastIndexOf('/', last - 1);
            if (p === -1) {
                break;
            } else {
                last = p;
            }
        }
        pathname = pathname.substr(0, last);
    }
    window.location.href = location.origin + pathname;
});

mapkey('p', '#3Duplicate current tab', function() {
    Clipboard.read(function(response) {
        url = response.data

        if (url.length > 256) {
            // too long
            return
        }

        try {
            new URL(response.data);
        } catch (err) {
            // not a valid url
            return
        }

        tabOpenLink(url);
    });
});

mapkey('ya', '#7Copy a link URL to the clipboard', function() {
    Hints.create('*[href]', function(element) {
        Clipboard.write(element.href);
    });
});

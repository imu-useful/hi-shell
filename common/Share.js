.pragma library

// How much of `total` a `part` is, as "34%"; "<1%" for a sliver, "" when there is nothing to tell.
function percent(part, total) {
    if (!(part > 0) || !(total > 0))
        return "";
    const p = Math.round(Math.min(part, total) / total * 100);
    return p < 1 ? "<1%" : `${p}%`;
}

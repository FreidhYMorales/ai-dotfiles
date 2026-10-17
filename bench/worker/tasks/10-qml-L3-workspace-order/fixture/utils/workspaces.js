.pragma library

// Workspace logic for the bar, kept out of QML so it can be tested with node.

// buildWorkspaces: the bar's workspace list. `workspaces` comes from Hyprland
// as [{ id, windows }]; ids 1..shown are always listed, plus any other normal
// workspace that exists and the active one. Special workspaces (id <= 0) are
// never listed. Returns [{ id, active, occupied }] in workspace order.
function buildWorkspaces(workspaces, activeId, shown) {
    const occupied = {}
    const ids = []
    for (let i = 1; i <= shown; i++)
        ids.push(i)
    for (const ws of workspaces) {
        if (ws.id <= 0)
            continue
        if (ws.windows > 0)
            occupied[ws.id] = true
        if (ids.indexOf(ws.id) === -1)
            ids.push(ws.id)
    }
    if (activeId > 0 && ids.indexOf(activeId) === -1)
        ids.push(activeId)
    ids.sort()
    return ids.map(id => ({ id: id, active: id === activeId, occupied: occupied[id] === true }))
}

// nextWorkspace: the id `step` places after `currentId` in `items` (as
// returned by buildWorkspaces), wrapping around at both ends.
function nextWorkspace(items, currentId, step) {
    if (items.length === 0)
        return currentId
    let i = items.findIndex(w => w.id === currentId)
    if (i === -1)
        i = 0
    const n = items.length
    return items[((i + step) % n + n) % n].id
}

// workspaceLabel: the text shown on the active dot (roman numerals 1-10).
function workspaceLabel(id) {
    const roman = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
    return id >= 1 && id <= roman.length ? roman[id - 1] : String(id)
}

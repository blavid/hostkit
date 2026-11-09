' Build 34 navigation (Blake-approved redesign).
'   Quick Fixes  = Roku Settings: rail -> fix list column -> steps (rail slides off).
'   Things to Do = Roku For You: rows of cards per category, rail collapses to icons.
'   Corner ad    = Roku lower-left ad under the expanded rail, rotating from ads.json.
' m.nav2 is "" (rail/other screens), "fxList", "fxSteps", "fyGrid" or "fyItem".
' Layout is a pure function of that state (Nav2Paint), so a slide that is cut
' short by a key press just lands on the painted end state.

function Nav2RailCollapsedW() as integer
    return 112
end function

function Nav2FyLeft(collapsed as boolean) as integer
    ' Build 41 variant A: the corner ad is hidden on Things to Do, so the
    ' collapsed grid starts beside the icon rail again: four cards per row.
    if collapsed then return RailX() + Nav2RailCollapsedW() + 40
    return ContentLeft()
end function

' Build 40: the next row peeks in above the down chevron (y 880).
function Nav2PeekClipY() as integer
    return 868
end function

' Gap between the focused card's zoomed bottom and the peeking row.
function Nav2PeekGap() as integer
    return 40
end function

function Nav2Right() as integer
    ' Build 35: action-safe right edge (FHD x 1822).
    return 1822
end function

' Build 37 (Blake: "Don't make users guess"): every card carries its own
' title and meta in a caption under the photo, so cards are wider: four fit
' inside action-safe on the collapsed grid (x 224-1796), three beside the rail.
function Nav2CardW() as integer
    ' Variant A: 9px narrower (363) so the fourth card ends at x 1784 and the
    ' right arrow fits inside action-safe at x 1798-1810.
    return 363
end function

' Photo height (16:9).
function Nav2CardH() as integer
    return 209
end function

function Nav2CapPad() as integer
    return 12
end function

function Nav2CapTextW() as integer
    return Nav2CardW() - 2 * Nav2CapPad()
end function

function Nav2MetaLine() as integer
    ' Build 37: measured line pitch of 24px type (37px); 30 clipped line 3 into an ellipsis.
    return 37
end function

function Nav2CardGap() as integer
    return 28
end function

function Nav2CountRight() as integer
    return 1726
end function

function Nav2NameLine() as integer
    ' Build 37: measured line pitch of 30px bold type.
    return 42
end function

function Nav2NameGap() as integer
    return 8
end function

function Nav2FxListX(deep as boolean) as integer
    if deep then return RailX()
    return RailX() + RailW() + 24
end function

function Nav2FxListW() as integer
    return 600
end function

function Nav2FxTop() as integer
    return 96
end function

function Nav2AdRect() as object
    ' Same width as the expanded rail, ~15% of 1080, equal left and bottom margins.
    ' Build 35 (pixel review): 438x214 at x 96-534, y 758-972, bottom on title-safe.
    return { x: RailX(), y: 758, w: 438, h: 214 }
end function

sub EnsureNav2()
    if m.nav2Built = true then return
    if m.shell = invalid then return
    m.nav2Built = true
    if m.nav2 = invalid then m.nav2 = ""
    m.fyRows = []
    m.fyRow = 0
    m.fyStamp = ""
    m.fxIndex = 0
    m.fxTop = 0
    BuildNav2Rail()
    BuildForYou(m.shell)
    BuildFixColumns(m.shell)
    BuildCornerAd(m.shell)
end sub

' ---------- rail ----------

sub BuildNav2Rail()
    if m.railTop = invalid then return
    m.railBg = m.railTop.getChild(0)
    if m.railBg <> invalid then m.railBg.id = "n2railBg"
    if m.railBrand <> invalid then m.railBrand.id = "n2brand"
    if m.railPlace <> invalid then m.railPlace.id = "n2place"
    if m.railDock <> invalid then m.railDock.id = "n2dock"
    index = 0
    for each row in m.railItems
        icon = CreateObject("roSGNode", "Poster")
        icon.width = 48
        icon.height = 48
        icon.translation = [20, (RailRowHeight() - 48) / 2]
        row.group.appendChild(icon)
        row.icon = icon
        row.label.id = "n2lab" + index.ToStr()
        row.mark.id = "n2mark" + index.ToStr()
        row.bg.id = "n2rowbg" + index.ToStr()
        index = index + 1
    end for
end sub

function Nav2Collapsed() as boolean
    return (m.nav2 = "fyGrid" or m.nav2 = "fyItem")
end function

sub PaintNav2Rail()
    if m.railDock = invalid then return
    collapsed = Nav2Collapsed()
    if m.railChild <> invalid then m.railChild.visible = false
    if m.railTop <> invalid
        m.railTop.visible = true
        m.railTop.translation = [0, 0]
    end if
    if m.nav2 = "fxSteps"
        m.railDock.translation = [0 - RailW() - 60, RailY()]
    else
        m.railDock.translation = [RailX(), RailY()]
    end if
    if m.railBg <> invalid
        m.railBg.width = RailW()
        if collapsed then m.railBg.width = Nav2RailCollapsedW()
    end if
    fade = 1.0
    if collapsed then fade = 0.0
    if m.railBrand <> invalid then m.railBrand.opacity = fade
    if m.railPlace <> invalid then m.railPlace.opacity = fade
    menu = TopMenu()
    last = m.railItems.Count() - 1
    for index = 0 to last
        row = m.railItems[index]
        section = ""
        if index < menu.Count() then section = menu[index]
        if row.icon <> invalid
            row.icon.uri = Nav2IconUri(section)
            row.icon.blendColor = "0xFFFFFFFF"
            if row.focused = true then row.icon.blendColor = InkOnAmber()
        end if
        row.label.translation = [84, 0]
        row.label.opacity = fade
        row.mark.opacity = fade
        row.mark.translation = [84 + RailLabelWidth() + 4, 0]
        row.bg.width = RailW() - 24
        if collapsed then row.bg.width = Nav2RailCollapsedW() - 24
        if section = "fixes" and (m.nav2 = "fxList" or m.nav2 = "fxSteps")
            ' Settings pattern: the parent row reads "< Quick Fixes".
            ' Build 38: it keeps the muted #3A4A66 pill other sections keep.
            row.label.text = "<  " + RailLabel("fixes")
            row.label.width = CheckoutLabelWidth()
            row.mark.text = ""
            row.bg.color = "0x3A4A66FF"
            row.label.color = InkColor()
            if row.icon <> invalid then row.icon.blendColor = "0xFFFFFFFF"
        end if
        if collapsed and section = "todo"
            row.bg.color = "0x3A4A66FF"
        end if
    end for
end sub

function Nav2IconUri(section as string) as string
    known = { home: 1, wifi: 1, todo: 1, rules: 1, fixes: 1, book: 1, checkout: 1 }
    if known.DoesExist(section) then return "pkg:/images/icon-" + section + ".png"
    item = invalid
    for each entry in MenuItems()
        if MenuSection(entry) = section then item = entry
    end for
    if item <> invalid
        kind = AsText(item.Lookup("type"))
        mapped = SectionForMenuType(kind)
        if known.DoesExist(mapped) then return "pkg:/images/icon-" + mapped + ".png"
    end if
    return ""
end function

' ---------- Things to Do (For You) ----------

sub BuildForYou(parent as object)
    pane = CreateObject("roSGNode", "Group")
    pane.id = "n2fy"
    pane.visible = false
    parent.appendChild(pane)
    m.fyPane = pane
    m.fyTitle = AddLabel(pane, RailLabel("todo"), "font:LargeBoldSystemFont", InkColor(), 0, 0, 900, 68)
    SetFontSize(m.fyTitle, PageH1Size())
    m.fyTitle.maxLines = 1
    m.fySub = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), 0, 72, 1100, 40)
    SetFontSize(m.fySub, 28)
    m.fySub.maxLines = 1
    m.fyCount = AddLabel(pane, "", "font:SmallBoldSystemFont", "0xF4EFE3FF", 0, 24, 240, 40)
    SetFontSize(m.fyCount, 26)
    m.fyCount.horizAlign = "right"
    m.fyCount.maxLines = 1
    m.fyBody = CreateObject("roSGNode", "Group")
    pane.appendChild(m.fyBody)
    ' Build 38: "OK Details" key hint, bottom-left of the content area.
    m.fyHint = AddKeyHint(pane, "OK", "Details")
    ' Build 39 (Pixel b38 P1): more rows exist. "▼ next row" and "▲ previous
    ' row" chips after OK Details, and a centered down chevron at y 880.
    m.fyNext = AddRowHint(pane, "down")
    m.fyPrev = AddRowHint(pane, "up")
    m.fyMore = CreateObject("roSGNode", "Poster")
    m.fyMore.uri = "pkg:/images/chevron-down-24.png"
    m.fyMore.width = 24
    m.fyMore.height = 12
    m.fyMore.visible = false
    pane.appendChild(m.fyMore)
    ' Focused-card details, drawn under the focused card.
    m.fyFocus = CreateObject("roSGNode", "Group")
    m.fyFocus.visible = false
    pane.appendChild(m.fyFocus)
    m.fyName = AddLabel(m.fyFocus, "", "font:SmallBoldSystemFont", "0xFFFFFFFF", 0, 0, 640, 86)
    SetFontSize(m.fyName, 30)
    m.fyName.vertAlign = "top"
    m.fyName.maxLines = 2
    m.fyMeta = AddLabel(m.fyFocus, "", "font:SmallSystemFont", "0xC9D1E0FF", 0, 0, 640, 76)
    SetFontSize(m.fyMeta, 24)
    m.fyMeta.vertAlign = "top"
    m.fyMeta.maxLines = 2
end sub

function FyStamp() as string
    token = 0
    if m.activitiesToken <> invalid then token = m.activitiesToken
    count = 0
    if IsList(m.activities) then count = m.activities.Count()
    return token.ToStr() + "|" + count.ToStr() + "|" + CurrentSeason()
end function

sub EnsureFyRows()
    stamp = FyStamp()
    if stamp = m.fyStamp and m.fyRows.Count() > 0 then return
    m.fyStamp = stamp
    clock = CreateObject("roTimespan")
    ' Clear the old row nodes.
    while m.fyBody.getChildCount() > 0
        m.fyBody.removeChildIndex(0)
    end while
    m.fyRows = []
    for each id in TodoMenu()
        items = FyRowPicks(m.activities, id, CurrentSeason())
        if items.Count() > 0
            group = CreateObject("roSGNode", "Group")
            m.fyBody.appendChild(group)
            label = AddLabel(group, RailLabel(id), "font:MediumBoldSystemFont", InkColor(), 0, 0, 800, 44)
            SetFontSize(label, 32)
            label.maxLines = 1
            cards = []
            ' Build 35 (dropped keys): one pooled slot per visible card, not
            ' one node set per activity. Building ~120 cards (480 nodes) on
            ' rail focus stalled the render thread past the next key press.
            for index = 0 to FyPoolSize() - 1
                cards.Push(MakeFyCard(group, index))
            end for
            caps = FyCaptions(items)
            ' Build 40: small side arrows when cards are off that side of the row.
            arrowL = MakeFyArrow(group, "left")
            arrowR = MakeFyArrow(group, "right")
            m.fyRows.Push({ id: id, items: items, group: group, label: label, cards: cards, col: 0, first: 0, caps: caps.list, capH: caps.h, nameMax: caps.nameMax, metaMax: caps.metaMax, arrowL: arrowL, arrowR: arrowR })
        end if
    end for
    if m.fyRow >= m.fyRows.Count() then m.fyRow = 0
    print "Eaglewood: fy rows built rows="; m.fyRows.Count(); " ms="; clock.TotalMilliseconds()
end sub

' Pre-broken caption text for every item in a row. The row's caption height
' fits its longest title and meta, so no card ever truncates or ellipsizes.
' Build 43 (Blake's TV, b42: cards drew as thin photo strips). Card and
' caption heights come only from these fixed numbers, clamped, never from
' font metrics, so a device that measures text differently still draws the
' whole card: a 209px photo and a caption body of 96-269px.
function Nav2CapMinH() as integer
    return Nav2CapPad() + Nav2NameLine() + Nav2NameGap() + Nav2MetaLine() - 3
end function

function Nav2CapMaxH() as integer
    return Nav2CapPad() + 3 * Nav2NameLine() + Nav2NameGap() + 3 * Nav2MetaLine() + Nav2CapPad()
end function

function FyCapHeight(nameLines as integer, metaLines as integer) as integer
    if nameLines < 1 then nameLines = 1
    if nameLines > 3 then nameLines = 3
    if metaLines < 0 then metaLines = 0
    if metaLines > 3 then metaLines = 3
    h = Nav2CapPad() + nameLines * Nav2NameLine() + Nav2NameGap() + metaLines * Nav2MetaLine() + Nav2CapPad()
    if h < Nav2CapMinH() then h = Nav2CapMinH()
    if h > Nav2CapMaxH() then h = Nav2CapMaxH()
    return h
end function

' Build 43: a full row always gets a real, non-empty clip that holds its label,
' arrows, the focus ring and the 1.08 focus scale. Rows never carry an empty
' [0,0,0,0] clip, whose meaning a device may not share with the emulator.
function FyRowClip(width as integer, capH as integer) as object
    return [-60, -12, width + 120, 52 + Nav2CardH() + capH + 48]
end function

function FyCaptions(items as object) as object
    list = []
    nameMax = 1
    metaMax = 0
    for each item in items
        nameLines = ClampLines(BreakLines(ItemText(item, "name"), Nav2CapTextW(), 30), 3)
        metaLines = ClampLines(BreakLines(FyMetaText(item), Nav2CapTextW(), 24), 3)
        if nameLines.Count() > nameMax then nameMax = nameLines.Count()
        if metaLines.Count() > metaMax then metaMax = metaLines.Count()
        ' Build 40 (Blake's TV photos): each card's caption panel hugs its own
        ' text, so no card shows an empty band under its meta line.
        own = FyCapHeight(nameLines.Count(), metaLines.Count())
        list.Push({ name: JoinLines(nameLines), meta: JoinLines(metaLines), nameLines: nameLines.Count(), metaLines: metaLines.Count(), h: own })
    end for
    h = FyCapHeight(nameMax, metaMax)
    return { list: list, h: h, nameMax: nameMax, metaMax: metaMax }
end function

function ClampLines(lines as object, most as integer) as object
    if lines.Count() <= most then return lines
    out = []
    for i = 0 to most - 1
        out.Push(lines[i])
    end for
    return out
end function

function MakeFyArrow(parent as object, dir as string) as object
    arrow = CreateObject("roSGNode", "Poster")
    arrow.uri = "pkg:/images/chevron-" + dir + "-24.png"
    arrow.width = 12
    arrow.height = 24
    arrow.visible = false
    parent.appendChild(arrow)
    return arrow
end function

function FyPoolSize() as integer
    return 6
end function

function MakeFyCard(parent as object, index as integer) as object
    group = CreateObject("roSGNode", "Group")
    group.id = "fyCard" + index.ToStr()
    group.scaleRotateCenter = [Nav2CardW() / 2, Nav2CardH() / 2]
    parent.appendChild(group)
    ring = AddRect(group, "0xFFFFFFFF", -6, -6, Nav2CardW() + 12, Nav2CardH() + 12)
    ring.visible = false
    AddRect(group, "0x243044FF", 0, 0, Nav2CardW(), Nav2CardH())
    ' Caption panel: opaque enough that text reads over any backdrop.
    cap = AddRect(group, "0x1A2336F2", 0, Nav2CardH(), Nav2CardW(), 0)
    photo = CreateObject("roSGNode", "Poster")
    photo.width = Nav2CardW()
    photo.height = Nav2CardH()
    photo.loadWidth = Nav2CardW()
    photo.loadHeight = Nav2CardH()
    photo.loadDisplayMode = "scaleToZoom"
    photo.failedBitmapUri = PlaceholderPoster()
    photo.loadingBitmapUri = PlaceholderPoster()
    group.appendChild(photo)
    name = AddLabel(group, "", "font:SmallBoldSystemFont", "0xFFFFFFFF", Nav2CapPad(), Nav2CardH() + Nav2CapPad(), Nav2CapTextW(), Nav2NameLine())
    SetFontSize(name, 30)
    name.vertAlign = "top"
    name.wrap = true
    name.id = "fyCardName"
    meta = AddLabel(group, "", "font:SmallSystemFont", "0xC9D1E0FF", Nav2CapPad(), 0, Nav2CapTextW(), Nav2MetaLine())
    SetFontSize(meta, 24)
    meta.vertAlign = "top"
    meta.wrap = true
    meta.id = "fyCardMeta"
    return { group: group, ring: ring, photo: photo, cap: cap, name: name, meta: meta }
end function

sub PaintForYou()
    EnsureFyRows()
    grid = (m.nav2 = "fyGrid")
    left = Nav2FyLeft(grid)
    width = Nav2Right() - left
    m.fyPane.translation = [left, 0]
    m.fyTitle.translation = [0, ContentTop()]
    m.fySub.translation = [0, ContentTop() + 72]
    m.fySub.text = FySubtitle()
    ' Build 35: right-aligned so the counter ends on title-safe x 1726.
    m.fyCount.translation = [Nav2CountRight() - left - 240, ContentTop() + 20]
    pitch = Nav2CardW() + Nav2CardGap()
    perRow = (width + Nav2CardGap()) \ pitch
    if perRow < 1 then perRow = 1
    y = ContentTop() + 136
    if grid then y = ContentTop() + 136
    m.fyFocus.visible = false
    m.fyCount.text = ""
    shift = 0
    if grid and m.fyRow > 0 then shift = -100
    m.fyShift = shift
    ' Set before the rows paint so their logged scene positions are current.
    if grid then m.fyBody.translation = [0, shift] else m.fyBody.translation = [0, 0]
    m.fyHint.visible = grid
    m.fyHint.translation = [Nav2HintX() - left, Nav2HintY()]
    PaintRowHints(grid, left, pitch, perRow)
    print "Eaglewood: fy paint"
    m.fyPeekState = "none"
    for r = 0 to m.fyRows.Count() - 1
        y = PaintFyRow(r, y, grid, width, pitch, perRow)
    end for
    if grid
        ' Title rows give way to the focused row once it moves down.
        m.fyTitle.visible = (m.fyRow = 0)
        m.fySub.visible = (m.fyRow = 0)
        m.fyBody.translation = [0, shift]
    else
        m.fyTitle.visible = true
        m.fySub.visible = true
        m.fyBody.translation = [0, 0]
    end if
end sub

function PaintFyRow(r as integer, y as integer, grid as boolean, width as integer, pitch as integer, perRow as integer) as integer
    row = m.fyRows[r]
    focusedRow = grid and r = m.fyRow
    ' Roku For You: the focused row rises to the top slot; rows above leave.
    above = grid and r < m.fyRow
    row.group.visible = not above
    row.arrowL.visible = false
    row.arrowR.visible = false
    if above then return y
    fitsRow = (y + m.fyShift + 52 + Nav2CardH() + row.capH <= 1023)
    ' Build 43: the first row on screen always draws whole, even if it runs long.
    if m.fyPeekState = "none" then fitsRow = true
    if not fitsRow
        if m.fyPeekState = "open" then return PaintFyPeek(r, width, pitch)
        m.fyPeekState = "done"
    end if
    row.group.clippingRect = FyRowClip(width, row.capH)
    row.group.translation = [0, y]
    ' Keep the focused card in view with one card of look-ahead.
    if row.col < row.first then row.first = row.col
    if row.col > row.first + perRow - 2 then row.first = row.col - perRow + 2
    if row.first < 0 then row.first = 0
    ' Build 35: a fixed pool of card slots per row, re-pointed at items.
    for slot = 0 to row.cards.Count() - 1
        card = row.cards[slot]
        c = row.first + slot
        card.group.translation = [slot * pitch, 52]
        ' Only whole cards, so the row ends inside action-safe, and only rows
        ' whose whole card (photo + caption) ends above action-safe y 1023.
        fits = fitsRow
        card.group.visible = (fits and c < row.items.Count() and slot * pitch + Nav2CardW() <= width)
        card.cap.height = row.capH
        if c < row.caps.Count() then card.cap.height = row.caps[c].h
        card.ring.height = Nav2CardH() + card.cap.height + 12
        focused = focusedRow and c = row.col
        card.ring.visible = focused
        if focused
            card.group.scale = [1.08, 1.08]
        else
            card.group.scale = [1.0, 1.0]
        end if
        uri = ""
        if card.group.visible
            uri = ItemText(row.items[c], "poster")
            if uri = "" then uri = PlaceholderPoster()
        end if
        if card.photo.uri <> uri then card.photo.uri = uri
        ' Build 37: every card shows its title (30px bold) and meta (24px),
        ' 8px apart, pre-broken to the caption width with no ellipsis.
        if card.group.visible
            caption = row.caps[c]
            card.name.text = caption.name
            ' Height 0 = no clip; maxLines matches the pre-broken lines.
            card.name.height = 0
            card.name.maxLines = caption.nameLines
            card.meta.text = caption.meta
            card.meta.translation = [Nav2CapPad(), Nav2CardH() + Nav2CapPad() + caption.nameLines * Nav2NameLine() + Nav2NameGap()]
            card.meta.height = 0
            card.meta.maxLines = caption.metaLines
            ' Build 37 caption test: node state for every shown card.
            at = NodeSceneXY(card.group)
            card.photo.height = Nav2CardH()
            card.photo.width = Nav2CardW()
            clip = RectList(row.group.clippingRect)
            print "Eaglewood: fy cardbox r=" + r.ToStr() + " c=" + c.ToStr() + " photoW=" + Int(card.photo.width).ToStr() + " photoH=" + Int(card.photo.height).ToStr() + " capY=" + Int(card.cap.translation[1]).ToStr() + " capH=" + Int(card.cap.height).ToStr() + " nameY=" + Int(card.name.translation[1]).ToStr() + " nameVis=" + BoolText(card.name.visible) + " metaY=" + Int(card.meta.translation[1]).ToStr() + " metaVis=" + BoolText(card.meta.visible) + " nameLines=" + caption.nameLines.ToStr() + " metaLines=" + caption.metaLines.ToStr() + " slotX=" + Int(card.group.translation[0]).ToStr() + " clip=" + Int(clip[0]).ToStr() + "," + Int(clip[1]).ToStr() + "," + Int(clip[2]).ToStr() + "," + Int(clip[3]).ToStr()
            print "Eaglewood: fy card r=" + r.ToStr() + " c=" + c.ToStr() + " x=" + at[0].ToStr() + " y=" + at[1].ToStr() + " capH=" + card.cap.height.ToStr() + " rowCapH=" + row.capH.ToStr() + " focused=" + BoolText(focused) + " nameLines=" + caption.nameLines.ToStr() + " metaLines=" + caption.metaLines.ToStr() + " name=" + caption.name.Replace(Chr(10), "|") + " meta=" + caption.meta.Replace(Chr(10), "|")
        else
            card.name.text = ""
            card.meta.text = ""
        end if
    end for
    ' A row too tall to fit keeps its heading as a peek of what is below.
    ' Build 38: no orphan heading. A label shows only with its row's cards.
    row.label.visible = fitsRow
    labelAt = NodeSceneXY(row.label)
    print "Eaglewood: fy row r=" + r.ToStr() + " id=" + row.id + " count=" + row.items.Count().ToStr() + " label=" + BoolText(row.label.visible) + " labelY=" + labelAt[1].ToStr() + " cardsY=" + (labelAt[1] + 52).ToStr()
    PaintFyArrows(r, width, pitch)
    if fitsRow and m.fyPeekState = "none"
        m.fyPeekState = "open"
        m.fyPeekFrom = y + 52 + Nav2CardH() + row.capH
    end if
    y = y + 52 + Nav2CardH() + row.capH + 36
    if focusedRow
        m.fyCount.text = (row.col + 1).ToStr() + " of " + row.items.Count().ToStr()
        print "Eaglewood: fy count text=" + m.fyCount.text + " row=" + row.id + " rowCount=" + row.items.Count().ToStr()
    end if
    return y
end function

' Build 40: arrows beside a fully shown row, one per side with cards off it.
sub PaintFyArrows(r as integer, width as integer, pitch as integer)
    row = m.fyRows[r]
    shown = 0
    for slot = 0 to row.cards.Count() - 1
        if row.cards[slot].group.visible then shown = shown + 1
    end for
    if shown < 1 then return
    hasLeft = (row.first > 0)
    hasRight = (row.first + shown < row.items.Count())
    perRow = (width + Nav2CardGap()) \ pitch
    arrowY = 52 + (Nav2CardH() - 24) \ 2
    leftX = -36
    rightX = perRow * pitch - Nav2CardGap() + 14
    row.arrowL.translation = [leftX, arrowY]
    row.arrowR.translation = [rightX, arrowY]
    row.arrowL.visible = hasLeft
    row.arrowR.visible = hasRight
    at = NodeSceneXY(row.arrowL)
    atR = NodeSceneXY(row.arrowR)
    print "Eaglewood: fy arrows r=" + r.ToStr() + " id=" + row.id + " col=" + row.col.ToStr() + " first=" + row.first.ToStr() + " shown=" + shown.ToStr() + " count=" + row.items.Count().ToStr() + " left=" + BoolText(hasLeft) + " right=" + BoolText(hasRight) + " leftX=" + at[0].ToStr() + " rightX=" + atR[0].ToStr() + " y=" + at[1].ToStr()
end sub

' Build 40: the first row that does not fit whole peeks in under the last
' whole row: its photos' top band shows down to y 868, above the chevron.
function PaintFyPeek(r as integer, width as integer, pitch as integer) as integer
    m.fyPeekState = "done"
    row = m.fyRows[r]
    cardTop = m.fyPeekFrom + Nav2PeekGap()
    groupY = cardTop - 52
    row.group.translation = [0, groupY]
    row.label.visible = false
    clipH = Nav2PeekClipY() - (cardTop + m.fyShift)
    if clipH < 0 then clipH = 0
    row.group.clippingRect = [-48, 52, width + 96, clipH]
    shown = 0
    for slot = 0 to row.cards.Count() - 1
        card = row.cards[slot]
        c = row.first + slot
        card.group.translation = [slot * pitch, 52]
        card.group.scale = [1.0, 1.0]
        card.ring.visible = false
        card.group.visible = (clipH > 0 and c < row.items.Count() and slot * pitch + Nav2CardW() <= width)
        uri = ""
        card.name.text = ""
        card.meta.text = ""
        if card.group.visible
            shown = shown + 1
            uri = ItemText(row.items[c], "poster")
            if uri = "" then uri = PlaceholderPoster()
        end if
        if card.photo.uri <> uri then card.photo.uri = uri
    end for
    print "Eaglewood: fy row r=" + r.ToStr() + " id=" + row.id + " count=" + row.items.Count().ToStr() + " label=no labelY=" + (groupY + m.fyShift).ToStr() + " cardsY=" + (cardTop + m.fyShift).ToStr()
    print "Eaglewood: fy peek r=" + r.ToStr() + " id=" + row.id + " top=" + (cardTop + m.fyShift).ToStr() + " clip=" + Nav2PeekClipY().ToStr() + " visible=" + clipH.ToStr() + " cards=" + shown.ToStr()
    return 4000
end function

function FySubtitle() as string
    return SeasonSubheadFor("todo", CurrentSeason())
end function

function FyMetaText(item as object) as string
    bits = []
    distance = ItemText(item, "distance")
    season = ItemText(item, "seasonLabel")
    if distance <> "" then bits.Push(distance)
    if season <> "" then bits.Push(season)
    return JoinBits(bits)
end function

function FyMoveRow(direction as integer) as boolean
    target = m.fyRow + direction
    if target < 0 or target >= m.fyRows.Count() then return true
    m.fyRow = target
    Nav2Paint()
    return true
end function

function FyMoveCol(direction as integer) as boolean
    if m.fyRows.Count() < 1 then return Nav2ToRail("todo")
    row = m.fyRows[m.fyRow]
    target = row.col + direction
    if target < 0 then return Nav2ToRail("todo")
    if target >= row.items.Count() then return true
    row.col = target
    Nav2Paint()
    return true
end function

function FyOpenItem() as boolean
    if m.fyRows.Count() < 1 then return true
    row = m.fyRows[m.fyRow]
    m.nav2 = "fyItem"
    m.section = row.id
    m.boundSection = row.id
    m.activityStamp = ""
    EnsureActivityGrid()
    m.cardIndex = row.col
    if CardCount() > row.col
        ' Same sort as the row, so the index matches; check the id anyway.
        if ItemText(m.sortedCards[row.col], "id") <> ItemText(row.items[row.col], "id")
            m.sortedCards = row.items
        end if
    else
        m.sortedCards = row.items
    end if
    print "Eaglewood: nav2 fy open row="; row.id; " col="; row.col
    return OpenActivityDetail()
end function

function FyCloseItem() as boolean
    m.nav2 = "fyGrid"
    m.zone = "fy"
    m.section = "todo"
    m.stepScroll = 0
    ShowSection(m.section)
    PaintAll()
    print "Eaglewood: screen=todo zone=fy"
    return true
end function

' ---------- Quick Fixes (Settings) ----------

sub BuildFixColumns(parent as object)
    pane = CreateObject("roSGNode", "Group")
    pane.id = "n2fx"
    pane.visible = false
    parent.appendChild(pane)
    m.fxPane = pane
    m.fxList = CreateObject("roSGNode", "Group")
    m.fxList.id = "n2fxList"
    pane.appendChild(m.fxList)
    m.fxListBg = AddRect(m.fxList, GlassColor(), 0, 0, Nav2FxListW(), 1080 - Nav2FxTop() - 64)
    m.fxHead = AddLabel(m.fxList, RailLabel("fixes"), "font:MediumBoldSystemFont", AmberColor(), 32, 16, Nav2FxListW() - 64, 48)
    SetFontSize(m.fxHead, 32)
    m.fxHead.maxLines = 1
    m.fxRows = []
    for index = 0 to 9
        group = CreateObject("roSGNode", "Group")
        m.fxList.appendChild(group)
        bg = AddRect(group, "0x00000000", 12, 0, Nav2FxListW() - 24, 60)
        crumb = AddLabel(group, "<", "font:SmallBoldSystemFont", InkColor(), 18, 0, 28, 60)
        SetFontSize(crumb, 28)
        label = AddLabel(group, "", "font:SmallSystemFont", InkColor(), 52, 0, FxLabelW(), 60)
        SetFontSize(label, 26)
        label.vertAlign = "center"
        label.maxLines = 4
        mark = AddLabel(group, ">", "font:SmallBoldSystemFont", AmberColor(), Nav2FxListW() - 56, 0, 28, 60)
        SetFontSize(mark, 28)
        m.fxRows.Push({ group: group, bg: bg, crumb: crumb, label: label, mark: mark })
    end for
    m.fxMore = CreateObject("roSGNode", "Poster")
    m.fxMore.uri = "pkg:/images/chevron-down.png"
    m.fxMore.width = 32
    m.fxMore.height = 20
    m.fxMore.visible = false
    m.fxList.appendChild(m.fxMore)
    m.fxScroll = CreateObject("roSGNode", "DetailScroll")
    m.fxScroll.id = "n2fxScroll"
    pane.appendChild(m.fxScroll)
end sub

function FxLabelW() as integer
    return Nav2FxListW() - 52 - 64
end function

function FxRowH(text as string) as integer
    lines = BreakLines(text, FxLabelW(), 26).Count()
    if lines < 1 then lines = 1
    if lines > 4 then lines = 4
    return lines * 36 + 26
end function

function FxTitle(index as integer) as string
    issues = FixIssues()
    if index < 0 or index >= issues.Count() then return ""
    return AsText(issues[index].Lookup("issue")).Trim()
end function

sub PaintFixColumns()
    deep = (m.nav2 = "fxSteps")
    listFocus = (m.nav2 = "fxList")
    m.fxList.translation = [Nav2FxListX(deep), Nav2FxTop()]
    count = IssueCount()
    if m.fxIndex >= count then m.fxIndex = 0
    m.issueIndex = m.fxIndex
    areaTop = 84
    ' Build 40: the corner ad shows on every page. Once the rail slides off,
    ' the list column takes its slot, so it ends at y 742 like the rail panel.
    listBottom = 1080 - 64
    if deep then listBottom = Nav2AdRect().y - 16
    m.fxListBg.height = listBottom - Nav2FxTop()
    areaH = listBottom - Nav2FxTop() - areaTop - 40
    ' Window: the least scroll that keeps the focused row fully visible.
    if m.fxIndex < m.fxTop then m.fxTop = m.fxIndex
    while m.fxTop < m.fxIndex and FxSpan(m.fxTop, m.fxIndex) > areaH
        m.fxTop = m.fxTop + 1
    end while
    y = areaTop
    slot = 0
    index = m.fxTop
    more = false
    while slot < m.fxRows.Count()
        row = m.fxRows[slot]
        if index >= count
            row.group.visible = false
        else
            text = FxTitle(index)
            h = FxRowH(text)
            if y + h > areaTop + areaH
                row.group.visible = false
                more = true
            else
                row.group.visible = true
                row.group.translation = [0, y]
                row.label.text = JoinLines(BreakLines(text, FxLabelW(), 26))
                row.label.height = h
                row.bg.height = h - 6
                row.mark.height = h
                row.crumb.height = h
                row.mark.visible = (StepCountFor(index) > 0)
                focused = (index = m.fxIndex)
                row.crumb.visible = deep and focused
                if listFocus and focused
                    row.bg.color = AmberColor()
                    row.label.color = InkOnAmber()
                    row.mark.color = InkOnAmber()
                else if deep and focused
                    row.bg.color = "0x3A4A66FF"
                    row.label.color = InkColor()
                    row.mark.color = InkColor()
                else
                    row.bg.color = "0x00000000"
                    row.label.color = InkColor()
                    row.mark.color = AmberColor()
                end if
                y = y + h
            end if
        end if
        index = index + 1
        slot = slot + 1
    end while
    if index < count then more = true
    m.fxMore.visible = more
    m.fxMore.translation = [(Nav2FxListW() - 32) / 2, areaTop + areaH + 8]
    ' Steps: a preview beside the list, or the whole right side once opened.
    showSteps = (listFocus or deep) and count > 0
    m.fxScroll.visible = showSteps
    if showSteps
        x = Nav2FxListX(false) + Nav2FxListW() + 24
        if deep then x = Nav2FxListX(true) + Nav2FxListW() + 24
        m.fxScroll.fontSize = 28
        m.fxScroll.pitch = 42
        m.fxScroll.padding = 32
        m.fxScroll.translation = [x, Nav2FxTop()]
        m.fxScroll.frameWidth = Nav2Right() - x
        m.fxScroll.frameHeight = 1080 - Nav2FxTop() - 64
        key = m.fxIndex.ToStr() + "|" + m.fxScroll.frameWidth.ToStr()
        if m.fxScrollKey <> key
            m.fxScrollKey = key
            m.fxScroll.heading = FxTitle(m.fxIndex)
            m.fxScroll.body = FixStepsText()
        end if
        if deep
            m.fxScroll.hint = "Up/Down|Scroll|Left|Fixes list"
        else
            m.fxScroll.hint = "Up/Down|Next fix|OK|Open steps"
        end if
        if m.stepScroll > m.fxScroll.maxOffset then m.stepScroll = m.fxScroll.maxOffset
        if m.stepScroll < 0 then m.stepScroll = 0
        m.fxScroll.offset = m.stepScroll
    end if
end sub

function FxSpan(first as integer, last as integer) as integer
    total = 0
    for index = first to last
        total = total + FxRowH(FxTitle(index))
    end for
    return total
end function

function StepCountFor(index as integer) as integer
    issues = FixIssues()
    if index < 0 or index >= issues.Count() then return 0
    steps = issues[index].Lookup("steps")
    if not IsList(steps) then return 0
    return steps.Count()
end function

' ---------- corner ad ----------

sub BuildCornerAd(parent as object)
    rect = Nav2AdRect()
    group = CreateObject("roSGNode", "Group")
    group.id = "n2ad"
    group.translation = [rect.x, rect.y]
    parent.appendChild(group)
    m.adGroup = group
    shadow = CreateObject("roSGNode", "Poster")
    shadow.uri = "pkg:/images/ad-shadow.png"
    shadow.translation = [-24, -24]
    shadow.width = rect.w + 48
    shadow.height = rect.h + 48
    group.appendChild(shadow)
    m.adA = MakeAdPoster(group, rect, "n2adA")
    m.adB = MakeAdPoster(group, rect, "n2adB")
    m.adB.opacity = 0.0
    m.ads = LoadAds()
    m.adIndex = 0
    m.adFront = m.adA
    m.adFrontB = false
    if m.ads.Count() > 0 then m.adA.uri = m.ads[0].image
    timer = CreateObject("roSGNode", "Timer")
    timer.repeat = true
    timer.duration = m.adSeconds
    timer.observeField("fire", "onAdTimer")
    m.top.appendChild(timer)
    m.adTimer = timer
    if m.ads.Count() > 1 then timer.control = "start"
    print "Eaglewood: ad list count="; m.ads.Count(); " rotate="; m.adSeconds
end sub

function MakeAdPoster(group as object, rect as object, id as string) as object
    poster = CreateObject("roSGNode", "Poster")
    poster.id = id
    poster.width = rect.w
    poster.height = rect.h
    poster.loadWidth = rect.w * 2
    poster.loadHeight = rect.h * 2
    poster.loadDisplayMode = "scaleToFit"
    group.appendChild(poster)
    return poster
end function

function LoadAds() as object
    m.adSeconds = 50
    m.adFade = 1.0
    out = []
    parsed = ParseJson(ReadAsciiFile("pkg:/data/ads.json"))
    if parsed = invalid or type(parsed) <> "roAssociativeArray" then return out
    seconds = parsed.Lookup("rotateSeconds")
    if seconds <> invalid and seconds >= 10 then m.adSeconds = seconds
    fade = parsed.Lookup("fadeSeconds")
    if fade <> invalid and fade > 0 then m.adFade = fade
    list = parsed.Lookup("ads")
    if not IsList(list) then return out
    for each entry in list
        if IsAssoc(entry)
            image = AsText(entry.Lookup("image"))
            if image <> "" then out.Push({ id: AsText(entry.Lookup("id")), image: image })
        end if
    end for
    return out
end function

sub onAdTimer()
    AdvanceAd()
end sub

sub AdvanceAd()
    if m.ads = invalid or m.ads.Count() < 2 then return
    m.adIndex = (m.adIndex + 1) mod m.ads.Count()
    ' SceneGraph nodes cannot be compared with "=", so track the front by flag.
    back = m.adB
    front = m.adA
    if m.adFrontB = true
        back = m.adA
        front = m.adB
    end if
    back.uri = m.ads[m.adIndex].image
    m.adFront = back
    m.adFrontB = not (m.adFrontB = true)
    print "Eaglewood: ad show id="; m.ads[m.adIndex].id; " index="; m.adIndex
    if SimulatorRun() or m.emuReplay = true
        back.opacity = 1.0
        front.opacity = 0.0
        return
    end if
    anim = CreateObject("roSGNode", "Animation")
    anim.duration = m.adFade
    anim.repeat = false
    anim.easeFunction = "linear"
    fadeIn = CreateObject("roSGNode", "FloatFieldInterpolator")
    fadeIn.key = [0.0, 1.0]
    fadeIn.keyValue = [0.0, 1.0]
    fadeIn.fieldToInterp = back.id + ".opacity"
    fadeOut = CreateObject("roSGNode", "FloatFieldInterpolator")
    fadeOut.key = [0.0, 1.0]
    fadeOut.keyValue = [1.0, 0.0]
    fadeOut.fieldToInterp = front.id + ".opacity"
    anim.appendChild(fadeIn)
    anim.appendChild(fadeOut)
    if m.adAnim <> invalid
        m.adAnim.control = "stop"
        m.adGroup.removeChild(m.adAnim)
    end if
    m.adAnim = anim
    m.adGroup.appendChild(anim)
    anim.control = "start"
end sub

sub PaintAd()
    if m.adGroup = invalid then return
    ' Build 42 (Blake via Captain): the corner ad shows on every page except
    ' Things to Do and Book Direct. Pages where it shows keep their content
    ' clear of its rect (x 96-534, y 758-972); see PaintFixColumns.
    show = true
    ' Build 42: hidden on Things to Do (rail on its row, the grid and every card
    ' detail; a detail sets m.section to the card's row, so key on nav2 too)
    ' and on Book Direct (the page has its own QR). Shown everywhere else.
    if m.section = "todo" or m.nav2 = "fyGrid" or m.nav2 = "fyItem" or m.section = "book" then show = false
    if m.ads = invalid or m.ads.Count() < 1 then show = false
    if m.adGroup.visible <> show then print "Eaglewood: ad visible="; show; " nav="; m.nav2; " section="; m.section
    m.adGroup.visible = show
    ' Last shell child, above every pane.
    if m.shell <> invalid
        m.shell.removeChild(m.adGroup)
        m.shell.appendChild(m.adGroup)
    end if
end sub

' ---------- paint + keys ----------

sub Nav2Paint()
    if m.shell = invalid then return
    EnsureNav2()
    if m.nav2Built <> true then return
    onTodo = (m.section = "todo")
    fyItem = (m.nav2 = "fyItem")
    onFix = (m.section = "fixes")
    if onTodo
        if m.activityPane <> invalid then m.activityPane.visible = false
        if m.detailPane <> invalid then m.detailPane.visible = false
        if m.detailScroll <> invalid then m.detailScroll.visible = false
        ReleaseCardImages()
    end if
    m.fyPane.visible = onTodo
    if onTodo then PaintForYou()
    if onFix
        if m.fixesPage <> invalid then m.fixesPage.visible = false
        if m.fixesPane <> invalid then m.fixesPane.visible = false
        if m.detailScroll <> invalid then m.detailScroll.visible = false
    end if
    m.fxPane.visible = onFix
    if onFix then PaintFixColumns()
    if m.footer <> invalid and (onTodo or onFix or fyItem) then m.footer.visible = false
    if m.offline <> invalid and Nav2Collapsed() then m.offline.visible = false
    PaintNav2Rail()
    PaintAd()
end sub

' Records the animated fields, repaints, then tweens from the old values.
sub Nav2Transition(target as string)
    before = Nav2Snapshot()
    m.nav2 = target
    Nav2Paint()
    after = Nav2Snapshot()
    Nav2Tween(before, after)
end sub

function Nav2Tracked() as object
    list = [
        { id: "n2dock", field: "translation" },
        { id: "n2railBg", field: "width" },
        { id: "n2brand", field: "opacity" },
        { id: "n2place", field: "opacity" },
        { id: "n2fy", field: "translation" },
        { id: "n2fxList", field: "translation" },
        { id: "n2fxScroll", field: "translation" }
    ]
    for index = 0 to m.railItems.Count() - 1
        list.Push({ id: "n2lab" + index.ToStr(), field: "opacity" })
        list.Push({ id: "n2mark" + index.ToStr(), field: "opacity" })
        list.Push({ id: "n2rowbg" + index.ToStr(), field: "width" })
    end for
    return list
end function

function Nav2Snapshot() as object
    out = {}
    if m.shell = invalid then return out
    for each entry in Nav2Tracked()
        node = m.top.findNode(entry.id)
        if node <> invalid then out[entry.id + "." + entry.field] = node.getField(entry.field)
    end for
    return out
end function

sub Nav2Tween(before as object, after as object)
    Nav2StopTween()
    if SimulatorRun() or m.emuReplay = true then return
    anim = CreateObject("roSGNode", "Animation")
    if anim = invalid then return
    anim.duration = 0.35
    anim.easeFunction = "outCubic"
    anim.repeat = false
    added = 0
    for each key in after
        old = before.Lookup(key)
        now = after.Lookup(key)
        if old <> invalid and now <> invalid
            kind = type(now)
            interp = invalid
            if kind = "roArray"
                if old[0] <> now[0] or old[1] <> now[1] then interp = CreateObject("roSGNode", "Vector2DFieldInterpolator")
            else
                if old <> now then interp = CreateObject("roSGNode", "FloatFieldInterpolator")
            end if
            if interp <> invalid
                interp.key = [0.0, 1.0]
                interp.keyValue = [old, now]
                interp.fieldToInterp = key
                anim.appendChild(interp)
                added = added + 1
            end if
        end if
    end for
    if added = 0 then return
    m.nav2Anim = anim
    m.top.appendChild(anim)
    anim.control = "start"
end sub

' A key during a slide ends it on the painted state (same rule as build 32).
sub Nav2StopTween()
    if m.nav2Anim = invalid then return
    m.nav2Anim.control = "stop"
    m.top.removeChild(m.nav2Anim)
    m.nav2Anim = invalid
    Nav2Paint()
end sub

function Nav2ToRail(section as string) as boolean
    m.zone = "rail"
    m.section = section
    m.menuDepth = "top"
    m.railIndex = MenuIndex(TopMenu(), section)
    print "Eaglewood: screen="; section; " zone=rail"
    ' Clear the nav state before the legacy paint so the rail row gets its
    ' expanded (gold) focus, then tween from the collapsed snapshot.
    before = Nav2Snapshot()
    m.nav2 = ""
    ShowSection(m.section)
    PaintAll()
    Nav2Tween(before, Nav2Snapshot())
    return true
end function

function Nav2EnterFy(rowId as string) as boolean
    EnsureNav2()
    m.menuDepth = "top"
    m.section = "todo"
    m.zone = "fy"
    m.railIndex = MenuIndex(TopMenu(), "todo")
    EnsureFyRows()
    if rowId <> ""
        for r = 0 to m.fyRows.Count() - 1
            if m.fyRows[r].id = rowId then m.fyRow = r
        end for
    end if
    print "Eaglewood: screen=todo zone=fy row="; m.fyRow
    ShowSection(m.section)
    PaintAll()
    Nav2Transition("fyGrid")
    return true
end function

function Nav2EnterFx() as boolean
    EnsureNav2()
    if IssueCount() < 1 then return true
    m.menuDepth = "top"
    m.section = "fixes"
    m.zone = "fxlist"
    m.railIndex = MenuIndex(TopMenu(), "fixes")
    m.stepScroll = 0
    print "Eaglewood: screen=fixes zone=fxlist"
    ShowSection(m.section)
    PaintAll()
    Nav2Transition("fxList")
    return true
end function

' Returns invalid when the old router should handle the key.
function Nav2Key(key as string) as object
    EnsureNav2()
    if m.nav2Built <> true then return invalid
    Nav2StopTween()
    nav = m.nav2
    if nav = ""
        if m.zone = "rail" and MenuDepth() = "top"
            if m.section = "todo" and (key = "right" or key = "OK") then return Nav2EnterFy("")
            if m.section = "fixes" and (key = "right" or key = "OK") then return Nav2EnterFx()
        end if
        return invalid
    end if
    if nav = "fyGrid"
        if key = "left" then return FyMoveCol(-1)
        if key = "right" then return FyMoveCol(1)
        if key = "up" then return FyMoveRow(-1)
        if key = "down" then return FyMoveRow(1)
        if key = "OK" then return FyOpenItem()
        if key = "back" then return Nav2ToRail("todo")
        return true
    end if
    if nav = "fyItem"
        if key = "back" or key = "left" then return FyCloseItem()
        if key = "up" then return MoveBodyScroll(-1)
        if key = "down" then return MoveBodyScroll(1)
        return true
    end if
    if nav = "fxList"
        if key = "up" or key = "down"
            delta = 1
            if key = "up" then delta = -1
            target = m.fxIndex + delta
            if target >= 0 and target < IssueCount()
                m.fxIndex = target
                m.stepScroll = 0
                Nav2Paint()
            end if
            return true
        end if
        if key = "right" or key = "OK"
            if StepCountFor(m.fxIndex) < 1 then return true
            m.zone = "fxsteps"
            m.stepScroll = 0
            print "Eaglewood: screen=fixes zone=fxsteps"
            Nav2Transition("fxSteps")
            return true
        end if
        if key = "left" or key = "back" then return Nav2ToRail("fixes")
        return true
    end if
    if nav = "fxSteps"
        if key = "up" or key = "down"
            delta = 1
            if key = "up" then delta = -1
            target = m.stepScroll + delta
            if m.fxScroll <> invalid and target >= 0 and target <= m.fxScroll.maxOffset
                m.stepScroll = target
                m.fxScroll.offset = target
            end if
            return true
        end if
        if key = "left" or key = "back"
            m.zone = "fxlist"
            print "Eaglewood: screen=fixes zone=fxlist"
            Nav2Transition("fxList")
            return true
        end if
        return true
    end if
    return invalid
end function

' Build 37 caption test: unscaled scene x,y of a node (sum of translations).
function NodeSceneXY(node as object) as object
    x = 0
    y = 0
    while node <> invalid
        t = node.translation
        if t <> invalid
            x = x + Int(t[0])
            y = y + Int(t[1])
        end if
        node = node.getParent()
    end while
    return [x, y]
end function

function BoolText(value as boolean) as string
    if value then return "yes"
    return "no"
end function

' ---------- Build 38 key hint chip ----------

function Nav2HintX() as integer
    return Nav2FyLeft(true)
end function

function Nav2HintY() as integer
    return 920
end function

' A #3A4A66 keycap with 24px #F4EFE3 text, then a 24px #C9D1E0 label.
function AddKeyHint(parent as object, key as string, text as string) as object
    group = CreateObject("roSGNode", "Group")
    group.visible = false
    parent.appendChild(group)
    capW = (Len(key) * 14) + 24
    AddRect(group, "0x3A4A66FF", 0, 2, capW, 36)
    cap = AddLabel(group, key, "font:SmallestBoldSystemFont", "0xF4EFE3FF", 0, 2, capW, 36)
    SetFontSize(cap, 24)
    cap.horizAlign = "center"
    cap.vertAlign = "center"
    label = AddLabel(group, text, "font:SmallestSystemFont", "0xC9D1E0FF", capW + 12, 0, HintLabelW(text), 40)
    SetFontSize(label, 24)
    label.vertAlign = "center"
    print "Eaglewood: hint chip key=" + key + " text=" + text
    m.fyHintLabel = label
    return group
end function

' ---------- Build 39 row hints ----------

function AddRowHint(parent as object, dir as string) as object
    group = CreateObject("roSGNode", "Group")
    group.visible = false
    parent.appendChild(group)
    AddRect(group, "0x3A4A66FF", 0, 2, Nav2RowCapW(), 36)
    arrow = CreateObject("roSGNode", "Poster")
    arrow.uri = "pkg:/images/chevron-" + dir + "-24.png"
    arrow.width = 24
    arrow.height = 12
    arrow.translation = [(Nav2RowCapW() - 24) \ 2, 14]
    group.appendChild(arrow)
    label = AddLabel(group, "", "font:SmallestSystemFont", "0xC9D1E0FF", Nav2RowCapW() + 12, 0, 300, 40)
    SetFontSize(label, 24)
    label.vertAlign = "center"
    label.maxLines = 1
    return { group: group, label: label, dir: dir }
end function

' Right edge of a hint label's text: its x in the chip group plus an
' estimated text width. Fonts can't be measured on the render thread
' (validate.py forbids the font registry there), so 24px text is estimated at
' a per-character class width (see HintTextW). The label node itself is
' 15px per character + 8 wide, so it never ellipsizes.
function HintLabelRight(label as object) as integer
    text = label.text
    if text = invalid then text = ""
    return Int(label.translation[0]) + HintTextW(text)
end function

function HintTextW(text as string) as integer
    ' Build 39: per-character classes, since one average misjudged "Summer"
    ' and "Winter". Wide m/w 21, other capitals 16, narrow i/l/j/t/f/r and
    ' space 7, everything else 13 (all at or above Metropolis 24px).
    w = 2
    for i = 1 to Len(text)
        c = Mid(text, i, 1)
        if Instr(1, "mwMW", c) > 0
            w = w + 21
        else if Instr(1, "iljtfrI ", c) > 0
            w = w + 7
        else if c >= "A" and c <= "Z"
            w = w + 16
        else
            w = w + 13
        end if
    end for
    return w
end function

function HintLabelW(text as string) as integer
    return HintTextW(text) + 16
end function

function Nav2RowCapW() as integer
    return 48
end function

' x after a hint's label: estimate 15px per character + 8 (wider than the
' 24px font draws, so labels never clip), then the 24px chip gap.
function Nav2HintEnd(x as integer, key as string, text as string) as integer
    return x + (Len(key) * 14) + 24 + 12 + (Len(text) * 15) + 8 + 24
end function

sub PaintRowHints(grid as boolean, left as integer, pitch as integer, perRow as integer)
    count = m.fyRows.Count()
    hasNext = grid and m.fyRow + 1 < count
    hasPrev = grid and m.fyRow > 0 and m.fyRow < count
    x = Nav2HintX() + HintLabelRight(m.fyHintLabel) + 24
    m.fyNext.group.visible = hasNext
    nextName = ""
    nextX = -1
    prevX = -1
    if hasNext
        nextName = RailLabel(m.fyRows[m.fyRow + 1].id)
        m.fyNext.label.text = nextName
        m.fyNext.label.width = HintLabelW(nextName)
        m.fyNext.group.translation = [x - left, Nav2HintY()]
        nextX = x
        x = x + HintLabelRight(m.fyNext.label) + 24
    end if
    m.fyPrev.group.visible = hasPrev
    prevName = ""
    if hasPrev
        prevName = RailLabel(m.fyRows[m.fyRow - 1].id)
        m.fyPrev.label.text = prevName
        m.fyPrev.label.width = HintLabelW(prevName)
        m.fyPrev.group.translation = [x - left, Nav2HintY()]
        prevX = x
    end if
    ' Centered under the visible card span; hidden on the last row.
    span = perRow * pitch - Nav2CardGap()
    moreX = left + (span - 24) \ 2
    m.fyMore.visible = hasNext
    m.fyMore.translation = [moreX - left, 880]
    if grid then print "Eaglewood: fy hints row=" + m.fyRow.ToStr() + " of=" + count.ToStr() + " next=" + nextName + " prev=" + prevName + " chevron=" + BoolText(hasNext) + " chevronX=" + moreX.ToStr() + " chevronY=880 nextX=" + nextX.ToStr() + " prevX=" + prevX.ToStr()
end sub

' The device returns a rect field as an array; brs-node returns an AA.
function RectList(v as dynamic) as object
    if type(v) = "roAssociativeArray" then return [v.x, v.y, v.width, v.height]
    if v = invalid or v.Count() < 4 then return [0, 0, 0, 0]
    return v
end function

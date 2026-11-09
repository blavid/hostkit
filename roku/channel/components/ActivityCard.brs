sub init()
    m.photo = m.top.findNode("photo")
    m.swatch = m.top.findNode("swatch")
    m.ring = m.top.findNode("ring")
    m.nameLabel = m.top.findNode("name")
    m.distanceLabel = m.top.findNode("distance")
    m.chip = m.top.findNode("chip")
    m.chipText = m.top.findNode("chipText")
    m.bound = invalid
    m.shown = ""
    m.triedFallback = false
    ' Build 30 (Pixel b29 ruling a): 30px title, 24px meta, 22px pill.
    CardFontSize(m.chipText, 22)
    CardFontSize(m.nameLabel, 30)
    CardFontSize(m.distanceLabel, 24)
    if m.photo <> invalid
        m.photo.loadWidth = 354
        m.photo.loadHeight = 200
        m.photo.observeField("loadStatus", "onPhotoStatus")
    end if
end sub

sub onItemContent()
    if m.bound <> invalid
        m.bound.unobserveField("imageUri")
        m.bound.unobserveField("cardFocused")
        m.bound.unobserveField("imageFallback")
    end if
    m.bound = m.top.itemContent
    m.triedFallback = false
    m.shown = ""
    if m.bound <> invalid
        m.bound.observeField("imageUri", "paintCard")
        m.bound.observeField("cardFocused", "paintCard")
        m.bound.observeField("imageFallback", "paintCard")
    end if
    paintCard()
end sub

sub paintCard()
    content = m.bound
    title = ""
    distance = ""
    season = ""
    swatch = "0x5C4033FF"
    focused = false
    uri = ""
    if content <> invalid
        if content.title <> invalid then title = content.title
        if content.distance <> invalid then distance = content.distance
        if content.seasonLabel <> invalid then season = content.seasonLabel
        if content.swatch <> invalid and content.swatch <> "" then swatch = content.swatch
        if content.cardFocused = true then focused = true
        if content.imageUri <> invalid then uri = content.imageUri
    end if
    if m.ring <> invalid then m.ring.visible = focused
    if m.swatch <> invalid then m.swatch.color = swatch
    layout = CardLayout(title, distance)
    if m.photo <> invalid then m.photo.height = layout.photoH
    if m.swatch <> invalid then m.swatch.height = layout.photoH
    if m.nameLabel <> invalid
        m.nameLabel.text = CardJoin(layout.name)
        m.nameLabel.translation = [16, layout.nameY]
        m.nameLabel.height = layout.nameH
    end if
    if m.distanceLabel <> invalid
        m.distanceLabel.text = CardJoin(layout.meta)
        m.distanceLabel.translation = [16, layout.metaY]
        m.distanceLabel.height = layout.metaH
    end if
    PaintChip(SeasonChipText(season))
    ShowPoster(uri)
end sub

' The pill carries the short season ("Year-round", "Seasonal"); the detail
' page shows the full line.
function SeasonChipText(season as string) as string
    if season = invalid then return ""
    range = MonthRange(season)
    if range <> "" then return range
    out = season
    for each mark in [" — ", " (", ", ", " are ", " for "]
        at = Instr(1, out, mark)
        if at > 1 then out = Left(out, at - 1)
    end for
    out = SeasonDash(out.Trim())
    if Len(out) <= 24 then return out
    ' Long ranges read as "Late Jun–Oct" (Pixel b28: one line, 24 characters).
    out = out.Replace(" through ", "–")
    months = [["January", "Jan"], ["February", "Feb"], ["March", "Mar"], ["April", "Apr"], ["June", "Jun"], ["July", "Jul"], ["August", "Aug"], ["September", "Sep"], ["October", "Oct"], ["November", "Nov"], ["December", "Dec"]]
    for each pair in months
        out = out.Replace(pair[0], pair[1])
    end for
    if Len(out) <= 24 then return out
    words = out.Split(" ")
    out = ""
    for each word in words
        if Len(out) + Len(word) + 1 > 24 then exit for
        if out <> "" then out = out + " "
        out = out + word
    end for
    return out
end function

' 14px per character at 24px plus 14px padding each side, at most the photo
' width less the 12px insets.
' One line: SeasonChipText caps the text at 24 characters.
function ChipLines(season as string) as object
    if season = invalid or season = "" then return []
    return [season]
end function

function ChipWidthFor(season as string) as integer
    if season = invalid or season = "" then return 0
    widest = 0
    for each line in ChipLines(season)
        if Len(line) > widest then widest = Len(line)
    end for
    width = (widest * 12) + 24
    if width > 330 then width = 330
    return width
end function

sub CardFontSize(label as object, size as integer)
    if label = invalid then return
    font = label.font
    if font = invalid or type(font) <> "roSGNode" then return
    font.size = size
end sub

' Breaks text at spaces for a per-character width, so no line starts with a
' space (the label's own wrap in brs-node keeps it).
function CardBreak(text as string, width as integer, charWidth as integer) as object
    lines = []
    if text = invalid or text = "" then return lines
    perLine = width \ charWidth
    if perLine < 4 then perLine = 4
    line = ""
    for each word in text.Split(" ")
        if word <> ""
            if line = ""
                line = word
            else if Len(line) + 1 + Len(word) <= perLine
                line = line + " " + word
            else
                lines.Push(line)
                line = word
            end if
        end if
    end for
    if line <> "" then lines.Push(line)
    return lines
end function

function CardJoin(lines as object) as string
    out = ""
    for each line in lines
        if out <> "" then out = out + Chr(10)
        out = out + line
    end for
    return out
end function

sub PaintChip(season as string)
    if m.chip = invalid or m.chipText = invalid then return
    if season = invalid or season = ""
        m.chip.visible = false
        m.chipText.visible = false
        m.chipText.text = ""
        return
    end if
    width = ChipWidthFor(season)
    lines = ChipLines(season)
    m.chip.width = width
    m.chip.height = 36 * lines.Count()
    m.chip.visible = true
    m.chipText.visible = true
    m.chipText.text = CardJoin(lines)
end sub

sub ShowPoster(uri as string)
    if m.photo = invalid then return
    if uri = invalid then uri = ""
    if uri = m.shown then return
    m.shown = uri
    m.triedFallback = false
    m.photo.loadWidth = 354
    m.photo.loadHeight = 200
    if uri = ""
        m.photo.uri = "pkg:/images/tv-placeholder.jpg"
        return
    end if
    m.photo.uri = uri
end sub

sub onPhotoStatus()
    if m.photo = invalid then return
    status = m.photo.loadStatus
    if status <> "failed" and status <> "error" then return
    if m.triedFallback = true
        UsePlaceholder()
        return
    end if
    m.triedFallback = true
    fallback = ""
    if m.bound <> invalid and m.bound.imageFallback <> invalid then fallback = m.bound.imageFallback
    if fallback <> "" and fallback <> m.shown
        m.shown = fallback
        m.photo.loadWidth = 354
        m.photo.loadHeight = 200
        m.photo.uri = fallback
        return
    end if
    UsePlaceholder()
end sub

sub UsePlaceholder()
    if m.photo = invalid then return
    held = "pkg:/images/tv-placeholder.jpg"
    if m.shown = held then return
    m.shown = held
    m.photo.loadWidth = 64
    m.photo.loadHeight = 64
    m.photo.uri = held
end sub

' Build 30: the photo gives up 38px per title line past 3, so a 30px title
' and 24px meta always fit the 420px card without ellipsis.
function CardLayout(title as string, distance as string) as object
    name = CardBreak(title, 332, 18)
    meta = CardBreak(distance, 332, 15)
    extra = name.Count() - 3
    if extra < 0 then extra = 0
    photoH = 200 - (extra * 38)
    nameY = 5 + photoH + 16
    nameH = name.Count() * 38
    if nameH < 38 then nameH = 38
    metaY = nameY + nameH + 12
    metaH = meta.Count() * 32
    return { name: name, meta: meta, photoH: photoH, nameY: nameY, nameH: nameH, metaY: metaY, metaH: metaH, bottom: metaY + metaH }
end function

' "April through October (full Rim Drive)" reads "Apr–Oct" (Pixel b29 b).
function MonthRange(season as string) as string
    text = season
    at = Instr(1, text, " (")
    if at > 1 then text = Left(text, at - 1)
    parts = text.Trim().Split(" through ")
    if parts.Count() <> 2 then return ""
    left = MonthShort(parts[0])
    right = MonthShort(parts[1])
    if left = "" or right = "" then return ""
    return left + "–" + right
end function

function MonthShort(word as string) as string
    prefix = ""
    text = word.Trim()
    if Left(text, 5) = "Late " or Left(text, 6) = "Early "
        at = Instr(1, text, " ")
        prefix = Left(text, at)
        text = Mid(text, at + 1)
    end if
    for each month in ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        if text = month then return prefix + Left(month, 3)
    end for
    return ""
end function

' "Spring through fall" reads "Spring–fall"; a multi-word side keeps spaces
' ("Late spring – early fall") so it can break between words.
function SeasonDash(text as string) as string
    parts = text.Split(" through ")
    if parts.Count() <> 2 then return text
    if Instr(1, parts[0], " ") > 0 or Instr(1, parts[1], " ") > 0 then return parts[0] + " – " + parts[1]
    return parts[0] + "–" + parts[1]
end function

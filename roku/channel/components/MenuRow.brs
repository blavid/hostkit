sub init()
    m.cursor = m.top.findNode("cursor")
    m.label = m.top.findNode("itemLabel")
    m.chevron = m.top.findNode("itemChevron")
end sub

sub showFrame()
    wide = m.top.width
    tall = m.top.height
    if wide = invalid or wide < 40 then return
    if tall = invalid or tall < 40 then return
    if m.cursor <> invalid
        m.cursor.width = wide
        m.cursor.height = tall - 4
    end if
    labelW = wide - 64
    if labelW < 40 then labelW = 40
    if m.label <> invalid
        m.label.width = labelW
        m.label.height = tall - 16
    end if
    if m.chevron <> invalid
        m.chevron.translation = [wide - 48, 8]
        m.chevron.height = tall - 16
    end if
end sub

sub showContent()
    content = m.top.itemContent
    title = ""
    mark = ""
    if content <> invalid
        if content.title <> invalid then title = content.title
        if content.shortDescriptionLine1 <> invalid then mark = content.shortDescriptionLine1
    end if
    if m.label <> invalid then m.label.text = title
    if m.chevron <> invalid then m.chevron.text = mark
    if content <> invalid and content.hasField("lit")
        content.observeField("lit", "showFocus")
    end if
    showFocus()
end sub

' MarkupListExample sets the focus graphic opacity from focusPercent.
sub showFocus()
    ' Build 32: the list never takes remote focus (the scene drives it), so
    ' the highlight comes from the row's "lit" field, not focusPercent.
    amount = 0
    content = m.top.itemContent
    if content <> invalid and content.hasField("lit")
        if content.lit = true then amount = 1
    end if
    if m.cursor <> invalid then m.cursor.opacity = amount
    if amount > 0.5
        if m.label <> invalid then m.label.color = "0x1C1408FF"
        if m.chevron <> invalid then m.chevron.color = "0x1C1408FF"
    else
        if m.label <> invalid then m.label.color = "0xFFFFFFFF"
        if m.chevron <> invalid then m.chevron.color = "0xF2A93BFF"
    end if
end sub

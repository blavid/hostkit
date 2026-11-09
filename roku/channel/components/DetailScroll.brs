sub init()
    m.frame = m.top.findNode("frame")
    m.lineGroup = m.top.findNode("lines")
    m.track = m.top.findNode("track")
    m.thumb = m.top.findNode("thumb")
    m.hintRow = m.top.findNode("hintRow")
    m.records = []
    m.pool = []
    m.top.scrollText = invalid
    onFrame()
end sub

function Pad() as integer
    value = m.top.padding
    if value = invalid or value < 0 then return 32
    return value
end function

function FontPx() as integer
    value = m.top.fontSize
    if value = invalid or value < 12 then return 30
    return value
end function

function PitchPx() as integer
    value = m.top.pitch
    if value = invalid or value < 16 then return 42
    return value
end function

function HintHeight() as integer
    return 40
end function

' Text area: frame less padding, less the hint row (24px above the bottom).
function AreaHeight() as integer
    return m.top.frameHeight - Pad() - 24 - HintHeight() - 16
end function

function AreaWidth() as integer
    return m.top.frameWidth - (Pad() * 2) - 16
end function

sub onFrame()
    if m.frame = invalid then return
    wide = m.top.frameWidth
    tall = m.top.frameHeight
    if wide = invalid or wide < 80 then wide = 1132
    if tall = invalid or tall < 80 then tall = 412
    m.frame.width = wide
    m.frame.height = tall
    m.hintRow.translation = [Pad(), tall - 24 - HintHeight()]
    m.track.translation = [wide - Pad() + 8, Pad()]
    m.track.height = AreaHeight()
    Layout()
end sub

sub onBody()
    m.top.offset = 0
    Layout()
end sub

sub onOffset()
    Render()
end sub

' Breaks at spaces for a per-character width (0.6 of the font size), so the
' Label never has to wrap again on its own.
function BreakAt(text as string, width as integer, size as integer) as object
    lines = []
    if text = invalid then return lines
    charW = Int((size * 6) / 10)
    if charW < 6 then charW = 6
    perLine = width \ charW
    if perLine < 8 then perLine = 8
    line = ""
    for each word in text.Split(" ")
        word = word.Trim()
        if word <> ""
            if line = ""
                line = word
            else if Len(line) + 1 + Len(word) <= perLine
                line = line + " " + word
            else
                lines.Push(line)
                line = word
            end if
            while Len(line) > perLine
                lines.Push(Left(line, perLine))
                line = Mid(line, perLine + 1)
            end while
        end if
    end for
    if line <> "" then lines.Push(line)
    return lines
end function

' "12. text" style paragraphs get a numeral and a hanging indent.
function StepNumber(paragraph as string) as string
    at = Instr(1, paragraph, ". ")
    if at < 2 or at > 4 then return ""
    head = Left(paragraph, at - 1)
    for index = 1 to Len(head)
        code = Asc(Mid(head, index, 1))
        if code < 48 or code > 57 then return ""
    end for
    return head + "."
end function

sub Layout()
    if m.lineGroup = invalid then return
    records = []
    y = 0
    width = AreaWidth()
    size = FontPx()
    pitch = PitchPx()
    heading = m.top.heading
    if heading <> invalid and heading.Trim() <> ""
        for each line in BreakAt(heading.Trim(), width, 36)
            records.Push({ text: line, x: 0, y: y, size: 36, bold: true, color: "0xFFFFFFFF" })
            y = y + 48
        end for
        y = y + 16
    end if
    body = m.top.body
    if body = invalid then body = ""
    indent = m.top.indent
    if indent = invalid then indent = 36
    for each paragraph in body.Split(Chr(10))
        paragraph = paragraph.Trim()
        if paragraph <> ""
            number = StepNumber(paragraph)
            textX = 0
            if number <> ""
                paragraph = Mid(paragraph, Len(number) + 1).Trim()
                textX = indent
                records.Push({ text: number, x: 0, y: y, size: size, bold: true, color: "0xF2A93BFF", lead: true })
            end if
            for each line in BreakAt(paragraph, width - textX, size)
                records.Push({ text: line, x: textX, y: y, size: size, bold: false, color: "0xFFFFFFF2" })
                y = y + pitch
            end for
        end if
    end for
    m.records = records
    m.contentHeight = y
    m.top.contentHeight = y
    ' Offsets are line starts, so a scroll step never cuts a line in half.
    starts = []
    for each record in records
        if record.lead <> true
            if starts.Count() = 0 or starts[starts.Count() - 1] <> record.y then starts.Push(record.y)
        end if
    end for
    m.starts = starts
    maxOffset = 0
    area = AreaHeight()
    if y > area
        last = starts.Count() - 1
        for index = 0 to last
            if y - starts[index] <= area
                maxOffset = index
                exit for
            end if
            maxOffset = index
        end for
    end if
    m.top.maxOffset = maxOffset
    m.top.lineCount = starts.Count()
    onHint()
    Render()
end sub

function LabelAt(index as integer) as object
    while m.pool.Count() <= index
        label = CreateObject("roSGNode", "Label")
        label.horizAlign = "left"
        label.vertAlign = "top"
        label.wrap = false
        m.lineGroup.appendChild(label)
        m.pool.Push(label)
    end while
    return m.pool[index]
end function

sub Render()
    if m.lineGroup = invalid or m.records = invalid then return
    offset = m.top.offset
    if offset = invalid or offset < 0 then offset = 0
    if offset > m.top.maxOffset then offset = m.top.maxOffset
    top = 0
    if m.starts <> invalid and m.starts.Count() > offset then top = m.starts[offset]
    area = AreaHeight()
    used = 0
    for each record in m.records
        rowY = record.y - top
        if rowY >= 0 and rowY + record.size <= area
            label = LabelAt(used)
            used = used + 1
            font = "font:SmallSystemFont"
            if record.bold = true then font = "font:SmallBoldSystemFont"
            label.font = font
            if label.font <> invalid and type(label.font) = "roSGNode" then label.font.size = record.size
            label.color = record.color
            label.translation = [Pad() + record.x, Pad() + rowY]
            label.width = AreaWidth() - record.x
            label.height = record.size + 12
            label.text = record.text
            label.visible = true
        end if
    end for
    last = m.pool.Count() - 1
    for index = used to last
        m.pool[index].visible = false
        m.pool[index].text = ""
    end for
    overflow = (m.top.maxOffset > 0)
    m.track.visible = overflow
    m.thumb.visible = overflow
    if overflow
        total = m.contentHeight
        if total < 1 then total = 1
        thumbH = Int(area * area / total)
        if thumbH < 40 then thumbH = 40
        m.thumb.height = thumbH
        travel = area - thumbH
        m.thumb.translation = [m.track.translation[0], Pad() + Int(travel * offset / m.top.maxOffset)]
    end if
end sub

' Hint text: "Key|label|Key|label". Keys render as keycaps, and the Up/Down
' pair is dropped when the copy fits.
sub onHint()
    if m.hintRow = invalid then return
    while m.hintRow.getChildCount() > 0
        m.hintRow.removeChildIndex(0)
    end while
    hint = m.top.hint
    if hint = invalid or hint = "" then return
    parts = hint.Split("|")
    x = 0
    index = 0
    while index + 1 < parts.Count()
        key = parts[index]
        text = parts[index + 1]
        index = index + 2
        show = true
        if m.top.maxOffset < 1
            if key = "Up/Down" and text = "Scroll" then show = false
            if key = "Right" then show = false
        end if
        if show
            capW = (Len(key) * 14) + 24
            ' Build 38: the OK chip uses the #3A4A66 / 24px #F4EFE3 style, 24px after the pair before it.
            okChip = (key = "OK")
            if okChip and x > 0 then x = x - 8
            cap = CreateObject("roSGNode", "Rectangle")
            cap.width = capW
            cap.height = 36
            cap.color = "0x2A3B5CFF"
            if okChip then cap.color = "0x3A4A66FF"
            cap.translation = [x, 2]
            m.hintRow.appendChild(cap)
            capText = CreateObject("roSGNode", "Label")
            capText.font = "font:SmallestBoldSystemFont"
            if capText.font <> invalid and type(capText.font) = "roSGNode" then capText.font.size = 22
            capText.color = "0xFFFFFFFF"
            if okChip
                capText.color = "0xF4EFE3FF"
                if capText.font <> invalid and type(capText.font) = "roSGNode" then capText.font.size = 24
            end if
            capText.horizAlign = "center"
            capText.vertAlign = "center"
            capText.width = capW
            capText.height = 36
            capText.translation = [x, 2]
            capText.text = key
            m.hintRow.appendChild(capText)
            x = x + capW + 12
            label = CreateObject("roSGNode", "Label")
            label.font = "font:SmallestSystemFont"
            if label.font <> invalid and type(label.font) = "roSGNode" then label.font.size = 24
            label.color = "0xC9D1E0FF"
            label.vertAlign = "center"
            label.height = 40
            label.width = (Len(text) * 15) + 8
            label.translation = [x, 0]
            label.text = text
            m.hintRow.appendChild(label)
            x = x + label.width + 32
        end if
    end while
end sub

sub focusBody()
end sub

' Book Direct, Wi-Fi, activity grids, and the corner badge.
' The scene keeps the remote. MarkupGrid is not focusable; it only virtualizes the cards.
' Card nodes are named from sourceIndex. Two activities may share an id.

function DisplayDomain() as string
    domain = "sunrivertownhome.com"
    return domain
end function

function ComingSoonWifi() as string
    return "Wi-Fi details coming soon"
end function

sub BuildPhase2(parent as object)
    BuildHomePrompt(m.homePane)
    BuildBadge(parent)
    m.bookPane = BuildBookPane(parent)
    m.wifiPane = BuildWifiPane(parent)
    m.activityPane = BuildActivityPane(parent)
    m.detailPane = BuildDetailPane(parent)
    m.activityStamp = ""
    m.boundSection = ""
    m.jumpedIndex = -1
    m.badgeReady = false
    m.bookPhotoTried = false
    m.bookQrTried = false
    m.detailPhotoTried = false
    m.detailQrFailed = false
    m.wifiJsonCode = 0
    m.wifiPngCode = 0
    m.wifiPngBit = 0
    m.wifiPngColor = -1
    m.wifiPngInterlace = 0
    m.wifiIndexed = "no"
    m.wifiRemoteSafe = ""
end sub

sub BuildHomePrompt(parent as object)
    if parent = invalid then return
    strip = HomeStripRect()
    w = strip.w
    h = strip.h
    group = CreateObject("roSGNode", "Group")
    group.translation = [strip.x, strip.y]
    group.scaleRotateCenter = [w / 2, h / 2]
    ' Focus (Pixel b28): 3px navy outer stroke, 6px amber ring, cream fill,
    ' 1.03x scale. No drop shadow, so the 24px gutter under the strip reads true.
    m.promptStroke = AddRect(group, PromptStrokeColor(), -3, -3, w + 6, h + 6)
    m.promptStroke.visible = false
    m.promptOuter = AddRect(group, AmberColor(), 0, 0, w, h)
    m.promptInner = AddRect(group, "0xF4EFE3FF", 0, 0, w, h)
    pine = CreateObject("roSGNode", "Poster")
    pine.uri = "pkg:/images/decor-pine.png"
    pine.width = 44
    pine.height = 32
    pine.loadWidth = 72
    pine.loadHeight = 48
    pine.translation = [24, 42]
    group.appendChild(pine)
    m.promptTitle = AddLabel(group, "Book your next stay direct and save!", "font:SmallBoldSystemFont", "0x1B4D38FF", 84, 16, w - 200, 88)
    m.promptTitle.horizAlign = "left"
    m.promptTitle.vertAlign = "center"
    m.promptTitle.maxLines = 2
    m.promptSub = AddLabel(group, "", "font:SmallestSystemFont", "0x3E5348FF", 84, 112, w - 200, 40)
    SetFontSize(m.promptSub, 28)
    m.promptSub.horizAlign = "left"
    m.promptSub.maxLines = 1
    arrowX = w - 72
    AddRect(group, AmberColor(), arrowX, (h - 40) / 2, 40, 40)
    arrowText = AddLabel(group, ">", "font:SmallBoldSystemFont", InkOnAmber(), arrowX, (h - 40) / 2, 40, 40)
    arrowText.horizAlign = "center"
    parent.appendChild(group)
    m.promptGroup = group
end sub

function PromptStrokeColor() as string
    return "0x1B2A44FF"
end function

function PromptFocusScale() as float
    return 1.03
end function

sub BuildBadge(parent as object)
    frame = BadgeFrame()
    group = CreateObject("roSGNode", "Group")
    group.translation = [frame.x, frame.y]
    group.visible = false
    card = AddRect(group, BadgeCardColor(), 0, 0, frame.w, frame.h)
    card.visible = false
    m.badgeCard = card
    m.badgeMark = AddRect(group, QrMarkColor(), frame.qrX, frame.qrY, frame.qr, frame.qr)
    m.badgeMark.visible = false
    m.badgePoster = CreateObject("roSGNode", "Poster")
    m.badgePoster.id = "badgeQr"
    m.badgePoster.focusable = false
    m.badgePoster.translation = [frame.qrX, frame.qrY]
    m.badgePoster.width = frame.qr
    m.badgePoster.height = frame.qr
    m.badgePoster.loadWidth = 256
    m.badgePoster.loadHeight = 256
    m.badgePoster.loadDisplayMode = "scaleToFit"
    m.badgePoster.visible = false
    m.badgePoster.observeField("loadStatus", "onBadgeStatus")
    m.badgeMissing = AddLabel(group, "", "font:SmallestSystemFont", "0x1C1408FF", 12, 78, 196, 64)
    m.badgeMissing.horizAlign = "center"
    m.badgeMissing.maxLines = 3
    group.appendChild(m.badgePoster)
    m.badgeDomain = AddLabel(group, DisplayDomain(), QrCaptionFont(), QrCaptionColor(), frame.captionX, frame.captionY, frame.captionW, frame.captionH)
    m.badgeDomain.color = BadgeCaptionColor()
    m.badgeDomain.horizAlign = "center"
    m.badgeDomain.vertAlign = "center"
    m.badgeDomain.maxLines = 1
    m.badgeDomain.visible = false
    parent.appendChild(group)
    m.badgeGroup = group
    m.badgeFrameKey = "corner"
    m.badgeHint = AddLabel(parent, "", "font:SmallSystemFont", MuteColor(), 980, 800, 500, 28)
    m.badgeHint.horizAlign = "right"
    m.badgeHint.visible = false
    m.badgeUri = ""
    m.badgeRemote = ""
    m.badgeFile = ""
    m.badgeFailed = false
end sub

function BuildBookPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    ' Pixel b28: the panel is the content box (x 588-1716, y 106-972), inside
    ' title-safe and clear of the rail, so the rail chevrons stay whole.
    panelBox = BookPanelRect()
    ' Build 30 (Captain #3): after OK the page holds focus, shown by a 4px
    ' gold frame (the chips are not focusable, so none of them lights up).
    m.bookFocusFrame = AddRect(pane, AmberColor(), panelBox.x - 4, panelBox.y - 4, panelBox.w + 8, panelBox.h + 8)
    m.bookFocusFrame.visible = false
    AddRect(pane, BookPanelColor(), panelBox.x, panelBox.y, panelBox.w, panelBox.h)
    ' One 52px H1 replaces the three questions and the gold bar.
    m.bookLines = []
    head = BookHeadRect()
    bannerText = AddLabel(pane, "", "font:LargeBoldSystemFont", BookInkColor(), head.x, head.y, head.w, head.h)
    SetFontSize(bannerText, 52)
    bannerText.horizAlign = "left"
    m.bookBanner = bannerText
    m.bookPhoto = CreateObject("roSGNode", "Poster")
    m.bookPhoto.translation = [BookPhotoRect().x, BookPhotoRect().y]
    m.bookPhoto.width = BookPhotoRect().w
    m.bookPhoto.height = BookPhotoRect().h
    m.bookPhoto.loadWidth = BookPhotoRect().w
    m.bookPhoto.loadHeight = BookPhotoRect().h
    m.bookPhoto.loadDisplayMode = "scaleToZoom"
    m.bookPhoto.failedBitmapUri = PlaceholderPoster()
    pane.appendChild(m.bookPhoto)
    m.bookPhoto.observeField("loadStatus", "onBookPhotoStatus")
    slot = BookQrSlot()
    qrCard = AddRect(pane, BookCardColor(), slot.cardX, slot.cardY, slot.cardW, slot.cardH)
    qrCard.visible = false
    m.bookQrCard = qrCard
    m.bookQrMark = AddRect(pane, QrMarkColor(), slot.cardX, slot.cardY, slot.cardW, slot.cardH)
    m.bookQrMark.visible = false
    m.bookQrPlate = AddRect(pane, "0xFFFFFFF2", slot.qrX, slot.qrY, slot.qrW, slot.qrH)
    m.bookQrPlate.visible = false
    m.bookQr = CreateObject("roSGNode", "Poster")
    m.bookQr.id = "bookQr"
    m.bookQr.focusable = false
    m.bookQr.translation = [slot.qrX, slot.qrY]
    m.bookQr.width = slot.qrW
    m.bookQr.height = slot.qrH
    m.bookQr.loadWidth = slot.qrW
    m.bookQr.loadHeight = slot.qrW
    m.bookQr.loadDisplayMode = "scaleToFit"
    m.bookQr.visible = false
    pane.appendChild(m.bookQr)
    m.bookQr.observeField("loadStatus", "onBookQrStatus")
    scan = AddLabel(pane, "Scan me!", "font:SmallBoldSystemFont", BookInkColor(), slot.labelX, slot.labelY, slot.labelW, slot.labelH)
    scan.horizAlign = "center"
    scan.visible = false
    m.bookScan = scan
    m.bookDomain = AddLabel(pane, DisplayDomain(), QrCaptionFont(), "0xF2A93BFF", slot.domainX, slot.domainY, slot.domainW, slot.domainH)
    SetFontSize(m.bookDomain, 28)
    m.bookDomain.horizAlign = "center"
    m.bookDomain.visible = false
    m.bookQrMissing = AddLabel(pane, "", "font:SmallestSystemFont", AmberColor(), slot.domainX, slot.domainY, slot.domainW, slot.domainH)
    m.bookQrMissing.horizAlign = "center"
    m.bookQrMissing.visible = false
    bodyRect = BookBodyRect()
    m.bookBody = AddLabel(pane, "", "font:SmallSystemFont", BookInkColor(), bodyRect.x, bodyRect.y, bodyRect.w, bodyRect.h)
    SetFontSize(m.bookBody, BookBodySize())
    m.bookBody.wrap = true
    m.bookBody.vertAlign = "top"
    m.bookBody.maxLines = BookTextLines()
    saveRect = BookSavingsRect()
    m.bookSavings = AddLabel(pane, "", "font:SmallSystemFont", BookInkColor(), saveRect.x, saveRect.y, saveRect.w, saveRect.h)
    SetFontSize(m.bookSavings, BookBodySize())
    m.bookSavings.wrap = true
    m.bookSavings.vertAlign = "top"
    m.bookSavings.maxLines = 2
    m.perkGroups = []
    perkRow = BookPerkRow()
    for index = 0 to 4
        chip = CreateObject("roSGNode", "Group")
        ' Pixel b30: plain tags, not buttons (they cannot take focus): 200x56,
        ' 2px #3A4A66 outline, no fill, 26px #C9D1E0 text, 24px gaps.
        chip.translation = [perkRow.x + (index * (PerkChipW() + PerkChipGap())), perkRow.y]
        AddRect(chip, PerkOutlineColor(), 0, 0, PerkChipW(), PerkChipH())
        bg = AddRect(chip, PerkChipColor(), 2, 2, PerkChipW() - 4, PerkChipH() - 4)
        text = AddLabel(chip, "", "font:SmallestSystemFont", PerkTextColor(), 4, 0, PerkChipW() - 8, PerkChipH())
        SetFontSize(text, PerkChipSize())
        text.horizAlign = "center"
        text.vertAlign = "center"
        text.maxLines = 2
        pane.appendChild(chip)
        m.perkGroups.Push({ group: chip, bg: bg, text: text })
    end for
    sign = BookSignRect()
    m.bookSign = AddLabel(pane, "", "font:SmallBoldSystemFont", BookInkColor(), sign.x, sign.y, sign.w, sign.h)
    m.bookSign.horizAlign = "center"
    m.bookPhotoUri = ""
    m.bookQrUri = ""
    m.bookFile = ""
    return pane
end function

function BuildWifiPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, "Join the Wi-Fi", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    top = WifiTop()
    m.wifiBacking = AddRect(pane, "0x1A2438FF", ContentLeft(), top, 400, 400)
    m.wifiPoster = CreateObject("roSGNode", "Poster")
    m.wifiPoster.id = "wifiQr"
    m.wifiPoster.focusable = false
    m.wifiPoster.translation = [ContentLeft() + 20, top + 20]
    m.wifiPoster.width = 360
    m.wifiPoster.height = 360
    m.wifiPoster.loadWidth = 480
    m.wifiPoster.loadHeight = 480
    m.wifiPoster.loadDisplayMode = "scaleToFit"
    m.wifiPoster.visible = false
    pane.appendChild(m.wifiPoster)
    m.wifiPoster.observeField("loadStatus", "onWifiPosterStatus")
    m.wifiMissing = AddLabel(pane, "", "font:SmallSystemFont", "0xFFFFFFF2", ContentLeft() + 16, top + 32, 368, 336)
    m.wifiMissing.horizAlign = "center"
    m.wifiMissing.vertAlign = "top"
    m.wifiMissing.maxLines = 8
    BuildWifiStatusPanel(pane)
    col = WifiColumn(false)
    ' Pixel b28: 24px #C9D1E0 labels, 8px to the value, 40px between pairs.
    m.wifiNetworkHeading = AddLabel(pane, "Network", "font:SmallSystemFont", TileSubColor(), col.x, top, col.w, 32)
    SetFontSize(m.wifiNetworkHeading, WifiLabelSize())
    m.wifiSsidLabel = AddLabel(pane, "", "font:SmallBoldSystemFont", InkColor(), col.x, top + 40, col.w, 104)
    SetFontSize(m.wifiSsidLabel, WifiSsidSize())
    m.wifiSsidLabel.vertAlign = "top"
    m.wifiSsidLabel.wrap = true
    m.wifiSsidLabel.maxLines = 2
    m.wifiPasswordHeading = AddLabel(pane, "Password", "font:SmallSystemFont", TileSubColor(), col.x, top + 184, col.w, 32)
    SetFontSize(m.wifiPasswordHeading, WifiLabelSize())
    m.wifiPasswordLabel = AddLabel(pane, "", "font:SmallBoldSystemFont", InkColor(), col.x, top + 224, col.w, 156)
    SetFontSize(m.wifiPasswordLabel, WifiValueSize())
    m.wifiPasswordLabel.vertAlign = "top"
    m.wifiPasswordLabel.wrap = true
    m.wifiPasswordLabel.maxLines = 3
    m.wifiHint = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), col.x, top + 364, WifiTextWidth(), 100)
    SetFontSize(m.wifiHint, WifiBodySize())
    m.wifiHint.vertAlign = "top"
    m.wifiHint.wrap = true
    m.wifiHint.maxLines = 4
    router = WifiRouterBox(false)
    ' Build 30 (Pixel b29 #2): navy 80% backing so the tip reads over the snow.
    m.wifiRouterScrim = AddRect(pane, "0x1B2A44CC", router.x - 24, router.y - 24, router.w + 48, 120)
    m.wifiRouterScrim.visible = false
    m.wifiRouter = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), router.x, router.y, router.w, router.h)
    SetFontSize(m.wifiRouter, router.size)
    m.wifiRouter.vertAlign = "top"
    m.wifiRouter.wrap = true
    m.wifiRouter.maxLines = router.maxLines
    m.wifiColumnKey = ""
    m.wifiShown = ""
    m.wifiPaintToken = ""
    return pane
end function

function WifiTop() as integer
    return ContentTop() + 80
end function

function WifiPanelWidth() as integer
    return 480
end function

' The text column moves right when the 480px status panel replaces the QR.
function WifiColumn(statusPanel as boolean) as object
    x = ContentLeft() + 430
    if statusPanel = true then x = ContentLeft() + WifiPanelWidth() + 40
    return { x: x, w: HomeRight() - x }
end function

function WifiLabelSize() as integer
    return 24
end function

function WifiSsidSize() as integer
    return 40
end function

' "Unavailable" and the password share the network-name weight at 34px.
function WifiValueSize() as integer
    return 34
end function

function WifiBodySize() as integer
    return 27
end function

' Pixel b28: hint and router tip are at most 620px wide.
function WifiTextWidth() as integer
    return 620
end function

function WifiHintText() as string
    return "Point your phone camera at the code and tap the banner to join."
end function

' Line pitch the column uses for a label at this size.
function WifiPitch(size as integer) as integer
    return size + 12
end function

' The right column, top to bottom, with the line counts the labels will get.
function WifiColumnLayout(statusPanel as boolean, ssid as string, password as string, hint as boolean) as object
    col = WifiColumn(statusPanel)
    y = WifiTop()
    out = { x: col.x, w: col.w, network: y }
    y = y + 32 + 8
    out.ssid = y
    ssidLines = BreakLines(ssid, col.w, WifiSsidSize()).Count()
    if ssidLines < 1 then ssidLines = 1
    if ssidLines > 2 then ssidLines = 2
    out.ssidH = ssidLines * WifiPitch(WifiSsidSize())
    y = y + out.ssidH + 40
    out.passwordHeading = y
    y = y + 32 + 8
    out.password = y
    pwLines = BreakLines(password, col.w, WifiValueSize()).Count()
    if pwLines < 1 then pwLines = 1
    if pwLines > 3 then pwLines = 3
    out.passwordH = pwLines * WifiPitch(WifiValueSize())
    y = y + out.passwordH + 40
    out.hint = y
    out.hintH = 0
    if hint = true
        out.hintH = BreakLines(WifiHintText(), WifiTextWidth(), WifiBodySize()).Count() * WifiPitch(WifiBodySize())
        y = y + out.hintH + 32
    end if
    out.router = y
    return out
end function

' Sized for the pessimistic wrap of the fallback copy at 28px.
function WifiStatusBodyBox() as object
    return { x: 32, y: 184, w: WifiPanelWidth() - 64, h: 376, maxLines: 9, size: 28 }
end function

function WifiStatusHeadingBox() as object
    return { x: 32, y: 80, w: WifiPanelWidth() - 64, h: 96, maxLines: 2, size: 34 }
end function

' Worst case (pessimistic) panel height; PaintWifi shrinks it to the content.
function WifiPanelHeight() as integer
    body = WifiStatusBodyBox()
    return body.y + body.h + 24
end function

' Pixel b28: content plus 32px padding.
function WifiPanelFitHeight(bodyLines as integer, headLines as integer) as object
    head = WifiStatusHeadingBox()
    headH = headLines * WifiPitch(head.size)
    bodyY = head.y + headH + 24
    bodyH = bodyLines * WifiPitch(WifiStatusBodyBox().size)
    return { bodyY: bodyY, bodyH: bodyH, h: bodyY + bodyH + 32 }
end function

' Router tip in the right column under the hint (QR) or the password (panel),
' at most 620px wide, ending inside title-safe (972). The y here is the one
' layout gives for a one-line network name and password.
function WifiRouterBox(statusPanel as boolean) as object
    layout = WifiColumnLayout(statusPanel, "Eaglewood Escape Guest", WifiUnavailableText(), statusPanel = false)
    w = WifiTextWidth()
    if layout.w < w then w = layout.w
    return { x: layout.x, y: layout.router, w: w, h: 972 - layout.router, maxLines: 9, size: WifiBodySize() }
end function

function WifiStatusHeading() as string
    return "Wi-Fi details didn't load"
end function

function WifiUnavailableText() as string
    return "Unavailable"
end function

' Pixel b27: a status panel, not a box where the QR would be. 4px amber left
' border, a 32px warning mark, a 34px heading, then the body left-aligned.
sub BuildWifiStatusPanel(pane as object)
    panel = CreateObject("roSGNode", "Group")
    panel.translation = [ContentLeft(), WifiTop()]
    panel.visible = false
    w = WifiPanelWidth()
    h = WifiPanelHeight()
    m.wifiPanelFill = AddRect(panel, "0x1A2438FF", 0, 0, w, h)
    m.wifiPanelBorder = AddRect(panel, AmberColor(), 0, 0, 4, h)
    AddRect(panel, AmberColor(), 32, 32, 32, 32)
    mark = AddLabel(panel, "!", "font:SmallBoldSystemFont", InkOnAmber(), 32, 28, 32, 40)
    mark.horizAlign = "center"
    mark.vertAlign = "center"
    headBox = WifiStatusHeadingBox()
    heading = AddLabel(panel, JoinLines(BreakLines(WifiStatusHeading(), headBox.w, headBox.size)), "font:SmallBoldSystemFont", "0xFFFFFFFF", headBox.x, headBox.y, headBox.w, headBox.h)
    SetFontSize(heading, headBox.size)
    heading.wrap = true
    heading.maxLines = headBox.maxLines
    heading.vertAlign = "top"
    body = WifiStatusBodyBox()
    m.wifiStatusBody = AddLabel(panel, "", "font:SmallSystemFont", "0xFFFFFFF2", body.x, body.y, body.w, body.h)
    SetFontSize(m.wifiStatusBody, body.size)
    m.wifiStatusBody.horizAlign = "left"
    m.wifiStatusBody.vertAlign = "top"
    m.wifiStatusBody.wrap = true
    m.wifiStatusBody.maxLines = body.maxLines
    pane.appendChild(panel)
    m.wifiStatusPanel = panel
end sub

sub PlaceWifiColumn(statusPanel as boolean, ssid as string, password as string, hint as boolean)
    layout = WifiColumnLayout(statusPanel, ssid, password, hint)
    key = layout.x.ToStr() + "/" + layout.ssidH.ToStr() + "/" + layout.passwordH.ToStr() + "/" + layout.hintH.ToStr()
    if m.wifiColumnKey = key then return
    m.wifiColumnKey = key
    nodes = [[m.wifiNetworkHeading, layout.network, 32, layout.w], [m.wifiSsidLabel, layout.ssid, layout.ssidH, layout.w], [m.wifiPasswordHeading, layout.passwordHeading, 32, layout.w], [m.wifiPasswordLabel, layout.password, layout.passwordH, layout.w], [m.wifiHint, layout.hint, layout.hintH + 8, WifiTextWidth()]]
    for each row in nodes
        node = row[0]
        if node <> invalid
            node.translation = [layout.x, row[1]]
            node.width = row[3]
            node.height = row[2]
        end if
    end for
    router = WifiRouterBox(statusPanel)
    if m.wifiRouter <> invalid
        m.wifiRouter.translation = [layout.x, layout.router]
        m.wifiRouter.width = router.w
        m.wifiRouter.height = 972 - layout.router
    end if
end sub

function BuildActivityPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    m.activityTitle = AddLabel(pane, "", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 68)
    SetFontSize(m.activityTitle, PageH1Size())
    m.activitySub = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 80, ContentWidth(), 36)
    ' Build 30 (Pixel b29 P3): 12px under the H1, grid 8px under the subhead.
    grid = CreateObject("roSGNode", "MarkupGrid")
    grid.translation = [ContentLeft(), ContentTop() + 124]
    grid.itemComponentName = "ActivityCard"
    grid.itemSize = [364, 420]
    grid.itemSpacing = [18, 16]
    grid.numColumns = 3
    grid.numRows = 1
    grid.drawFocusFeedback = false
    grid.focusable = false
    grid.vertFocusAnimationStyle = "floatingFocus"
    pane.appendChild(grid)
    m.activityGrid = grid
    ' Empty category: a 480px navy card at 588,260 with 32px padding (Pixel b28).
    m.activityEmptyCard = AddRect(pane, "0x1B2A44FF", ContentLeft(), 260, 480, 148)
    m.activityEmptyCard.visible = false
    m.activityEmpty = AddLabel(pane, ActivityEmptyText(""), "font:SmallSystemFont", InkColor(), ContentLeft() + 32, 292, 416, 84)
    SetFontSize(m.activityEmpty, 30)
    m.activityEmpty.vertAlign = "top"
    m.activityEmpty.wrap = true
    m.activityEmpty.maxLines = 2
    m.activityEmpty.visible = false
    BuildTodoPreview(pane)
    m.activityHint = AddLabel(pane, "Left menu    Arrows browse    OK open", "font:SmallSystemFont", MuteColor(), ContentLeft(), 776, 900, 32)
    return pane
end function

function BuildDetailPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    m.detailName = AddLabel(pane, "", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 136)
    SetFontSize(m.detailName, PageH1Size())
    m.detailName.vertAlign = "top"
    m.detailName.maxLines = 2
    m.detailPhoto = CreateObject("roSGNode", "Poster")
    photo = DetailPhotoRect()
    m.detailPhoto.translation = [photo.x, photo.y]
    m.detailPhoto.width = photo.w
    m.detailPhoto.height = photo.h
    m.detailPhoto.loadWidth = 640
    m.detailPhoto.loadHeight = 360
    m.detailPhoto.loadDisplayMode = "scaleToZoom"
    m.detailPhoto.failedBitmapUri = PlaceholderPoster()
    pane.appendChild(m.detailPhoto)
    m.detailPhoto.observeField("loadStatus", "onDetailPhotoStatus")
    card = DetailQrCardRect()
    cardX = card.x
    cardY = card.y
    qrCard = AddRect(pane, "0xFFFFFFF2", cardX, cardY, card.w, card.h)
    qrCard.visible = false
    m.detailQrCard = qrCard
    m.detailQrMark = AddRect(pane, QrMarkColor(), cardX, cardY, card.w, card.h)
    m.detailQrMark.visible = false
    m.detailPlace = invalid
    siteRect = DetailQrSiteRect()
    site = AddLabel(pane, "Website / menu", "font:SmallSystemFont", "0x1C1408FF", siteRect.x, siteRect.y, siteRect.w, siteRect.h)
    site.horizAlign = "center"
    site.visible = false
    m.detailSite = site
    posterRect = DetailQrPosterRect()
    m.detailQr = CreateObject("roSGNode", "Poster")
    m.detailQr.id = "detailQr"
    m.detailQr.focusable = false
    m.detailQr.translation = [posterRect.x, posterRect.y]
    m.detailQr.width = posterRect.w
    m.detailQr.height = posterRect.h
    m.detailQr.loadWidth = posterRect.w
    m.detailQr.loadHeight = posterRect.w
    m.detailQr.loadDisplayMode = "scaleToFit"
    m.detailQr.visible = false
    pane.appendChild(m.detailQr)
    m.detailQr.observeField("loadStatus", "onDetailQrStatus")
    captionRect = DetailQrCaptionRect()
    m.detailQrCaption = AddLabel(pane, "", QrCaptionFont(), QrCaptionColor(), captionRect.x, captionRect.y, captionRect.w, captionRect.h)
    SetFontSize(m.detailQrCaption, 28)
    m.detailQrCaption.horizAlign = "center"
    m.detailQrCaption.visible = false
    m.detailQrMissing = AddLabel(pane, "", "font:SmallestSystemFont", "0x1C1408FF", cardX, cardY + card.h - 32, card.w, 28)
    m.detailQrMissing.horizAlign = "center"
    m.detailQrMissing.visible = false
    ' Build 35 (pixel b34 TtD #4): the meta line sits on a scrim with 16px
    ' clearance above the body panel, not on the bright snow.
    metaY = DetailBodyRect().y - 16 - DetailMetaH()
    m.detailMetaScrim = AddRect(pane, "0x1A233699", ContentLeft(), metaY, DetailBodyRect().w, DetailMetaH())
    ' Label as tall as the scrim: a box shorter than the font draws nothing.
    m.detailMeta = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft() + 10, metaY, DetailBodyRect().w - 20, DetailMetaH())
    m.detailMeta.vertAlign = "center"
    body = DetailBodyRect()
    m.detailBody = AddLabel(pane, "", "font:SmallSystemFont", InkColor(), body.x, body.y, body.w, body.h)
    m.detailBody.vertAlign = "top"
    m.detailBody.maxLines = 6
    m.detailTip = AddLabel(pane, "", "font:SmallBoldSystemFont", AmberColor(), ContentLeft(), ContentTop() + 680, 700, 48)
    m.detailTip.vertAlign = "top"
    m.detailTip.maxLines = 2
    m.detailExtra = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 732, 700, 44)
    m.detailExtra.vertAlign = "top"
    m.detailExtra.maxLines = 2
    ' Photo credit sits under the QR card; the Back keycap in the scroll hint
    ' replaces the old "Back to ..." line.
    m.detailCredit = AddLabel(pane, "", "font:SmallestSystemFont", MuteColor(), card.x, card.y + card.h + 12, card.w, 28)
    m.detailCredit.horizAlign = "center"
    m.detailBack = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), 900, 400, 28)
    m.detailBack.visible = false
    m.detailPhotoUri = ""
    m.detailQrUri = ""
    m.detailFile = ""
    return pane
end function

sub PaintPhase2()
    PaintPrompt()
    PaintBook()
    PaintWifi()
    if ActivitySection(m.section) then PaintActivity()
    PaintBadge()
end sub

sub PaintPrompt()
    if m.promptTitle = invalid or m.book = invalid then return
    m.promptTitle.text = HomePromptTitle(m.book)
    m.promptSub.text = PromptSubline(BookText(m.book, "homePromptSub", "Up to about 10% less than Airbnb or Vrbo"))
    focused = (m.zone = "prompt" and m.section = "home")
    if m.promptInner = invalid then return
    strip = HomeStripRect()
    if focused
        m.promptInner.translation = [6, 6]
        m.promptInner.width = strip.w - 12
        m.promptInner.height = strip.h - 12
    else
        m.promptInner.translation = [0, 0]
        m.promptInner.width = strip.w
        m.promptInner.height = strip.h
    end if
    if m.promptStroke <> invalid then m.promptStroke.visible = focused
    if m.promptGroup <> invalid
        if focused
            m.promptGroup.scale = [PromptFocusScale(), PromptFocusScale()]
        else
            m.promptGroup.scale = [1.0, 1.0]
        end if
    end if
end sub

function HomePromptTitle(book as object) as string
    title = "Book your next stay direct and save!"
    text = BookText(book, "homePromptTitle", title)
    if text = "Book direct & save" then return title
    return text
end function

function PromptSubline(text as string) as string
    if text = invalid then text = ""
    if Instr(1, LCase(text), "ok for details") > 0 then return text
    if text = "" then return "OK for details"
    return text + "  ·  OK for details"
end function

function BookText(book as object, key as string, fallback as string) as string
    if not IsAssoc(book) then return fallback
    text = GuideLimitedText(book.Lookup(key), 180)
    if text = "" then return fallback
    return text
end function

sub PaintBadge()
    uri = ""
    if IsAssoc(m.book) then uri = GuideLimitedText(m.book.Lookup("bookingQrImageUrl"), 320)
    if not PosterKindOk(uri) then uri = ""
    uri = WithQrVersion(uri)
    if m.badgeDomain <> invalid then m.badgeDomain.text = DisplayDomain()
    EnsureQrSlot("badge", uri)
end sub

sub onBadgeStatus()
    NoteQrLoaded("badge")
    poster = PosterForSlot("badge")
    if poster = invalid then return
    status = poster.loadStatus
    if status = "ready"
        ' A drawn bitmap is enough; ShowBadgeFrame still drops it on Book Direct.
        ShowBadgeFrame(true)
        return
    end if
    if status <> "failed" and status <> "error" then return
    ' Build 33: the card stays drawn. The failure can fire synchronously
    ' inside the uri assignment (m.qrAssigning = true), which used to skip
    ' the retry and leave the card hidden, so the reload is always queued.
    ShowBadgeFrame(true)
    ScheduleQrReload("badge")
end sub

' Build 33 root cause (Home badge blank, Wi-Fi QR needing a relaunch): in
' brs-node, a cachefs PNG written by a task thread can read back on the render
' thread as another file's bytes (seen: wifi.png held the 57-byte qr-*.url
' note QrTask wrote at the same time), so the Poster decode failed. The texture
' loader also pins a failed URI (failedLocalUris), so retries of the same URI
' failed, the badge's one retry was skipped when the failure fired inside the
' uri assignment, and Wi-Fi had no retry. Tasks now send their PNG bytes as
' base64 in the result; on a failure the render thread writes its own copy to a
' fresh name and loads that (0.3 s, then 0.6, 1.2, 2.4 s), then the fallback.
function QrReloadGaps() as object
    return [0.3, 0.6, 1.2, 2.4]
end function

function FreshQrCopy(slot as string, path as string, attempt as integer) as string
    ' Render-thread write (roByteArray only; no roFileSystem here) from the
    ' task's own bytes, else from this thread's read of the file.
    target = "cachefs:/eaglewood/reload-" + slot + "-" + attempt.ToStr() + ".png"
    data = CreateObject("roByteArray")
    if data = invalid then return ""
    text = ""
    if m.qrPng64 <> invalid and m.qrPng64.Lookup(slot) <> invalid then text = m.qrPng64.Lookup(slot)
    if text <> ""
        data.FromBase64String(text)
    else if path = invalid or path = "" or data.ReadFile(path) <> true
        return ""
    end if
    if data.Count() < 8 or data[0] <> 137 or data[1] <> 80 then return ""
    if data.WriteFile(target) <> true then return ""
    return target
end function

sub RememberQrPng64(slot as string, text as dynamic)
    if m.qrPng64 = invalid then m.qrPng64 = {}
    if text = invalid then text = ""
    m.qrPng64[slot] = text
end sub

function QrReloadCount(slot as string) as integer
    if m.qrReloads = invalid then return 0
    value = m.qrReloads.Lookup(slot)
    if value = invalid then return 0
    return value
end function

sub ScheduleQrReload(slot as string)
    if m.top = invalid then return
    if m.qrReloads = invalid then m.qrReloads = {}
    if m.qrReloadTimers = invalid then m.qrReloadTimers = {}
    if m.qrReloadTimers.Lookup(slot) <> invalid then return
    count = QrReloadCount(slot)
    gaps = QrReloadGaps()
    if count >= gaps.Count()
        print "Eaglewood: qr "; slot; " reload gave up"
        QrGaveUp(slot)
        return
    end if
    m.qrReloads[slot] = count + 1
    timer = CreateObject("roSGNode", "Timer")
    timer.duration = gaps[count]
    timer.repeat = false
    if slot = "badge" then timer.observeField("fire", "onBadgeReload")
    if slot = "wifi" then timer.observeField("fire", "onWifiReload")
    m.top.appendChild(timer)
    m.qrReloadTimers[slot] = timer
    timer.control = "start"
end sub

sub onBadgeReload()
    RunQrReload("badge")
end sub

sub onWifiReload()
    RunQrReload("wifi")
end sub

sub RunQrReload(slot as string)
    timer = m.qrReloadTimers.Lookup(slot)
    if timer <> invalid
        timer.control = "stop"
        if m.top <> invalid then m.top.removeChild(timer)
    end if
    m.qrReloadTimers.Delete(slot)
    path = StoredQrPath(slot)
    if path = "" and m.qrMounted <> invalid
        value = m.qrMounted.Lookup(slot)
        if value <> invalid then path = value
    end if
    poster = PosterForSlot(slot)
    if poster = invalid or path = "" then return
    if poster.loadStatus = "ready" then return
    fresh = FreshQrCopy(slot, path, QrReloadCount(slot))
    if fresh = ""
        ' Not visible to this thread yet: wait for the next gap.
        print "Eaglewood: qr "; slot; " reload "; QrReloadCount(slot).ToStr(); " copy not ready"
        ScheduleQrReload(slot)
        return
    end if
    path = fresh
    print "Eaglewood: qr "; slot; " reload "; QrReloadCount(slot).ToStr(); " path="; path
    m.qrAssigning = true
    poster.uri = ""
    poster.uri = path
    m.qrAssigning = false
    LogQrState(slot, poster)
end sub

sub QrGaveUp(slot as string)
    if slot = "badge"
        m.badgeFallback = true
        ShowBadgeFrame(true)
    end if
    if slot = "wifi" and m.wifiMissing <> invalid then m.wifiMissing.text = "QR image could not be drawn"
end sub

' Build 33: the Home card always draws its cream frame and caption. If the
' QR is not drawn within 5 s, or every reload failed, it switches to the
' no-link layout (text in place of the code) and stays there.
sub ArmBadgeDeadline()
    if m.badgeDeadline <> invalid or m.top = invalid then return
    timer = CreateObject("roSGNode", "Timer")
    timer.duration = 5
    timer.repeat = false
    timer.observeField("fire", "onBadgeDeadline")
    m.top.appendChild(timer)
    m.badgeDeadline = timer
    timer.control = "start"
end sub

sub onBadgeDeadline()
    if BadgeBitmapReady() = true then return
    print "Eaglewood: qr badge deadline fallback"
    m.badgeFallback = true
    ShowBadgeFrame(true)
end sub

function BadgeFallbackText() as string
    return "Book direct online at"
end function

' The retry runs on a timer so it is outside the loadStatus observer.
sub ScheduleBadgeRetry()
    if m.badgeRetryArmed = true then return
    if m.top = invalid then return
    m.badgeRetryArmed = true
    timer = CreateObject("roSGNode", "Timer")
    timer.duration = 0.2
    timer.repeat = false
    timer.observeField("fire", "onBadgeRetry")
    m.top.appendChild(timer)
    m.badgeRetryTimer = timer
    timer.control = "start"
end sub

sub onBadgeRetry()
    if m.badgeRetryTimer <> invalid
        m.badgeRetryTimer.control = "stop"
        if m.top <> invalid then m.top.removeChild(m.badgeRetryTimer)
        m.badgeRetryTimer = invalid
    end if
    m.badgeRetryArmed = false
    if QrRemote("badge") = "" or m.section = "book" then return
    path = StoredQrPath("badge")
    poster = PosterForSlot("badge")
    if poster = invalid or path = "" then return
    MountQrPoster(poster, path, "badge")
end sub

sub UpdateBadgeVisible()
    ShowQrFrame("badge", QrRemote("badge") <> "")
end sub

sub ShowBadgeFrame(show as boolean)
    if BadgeShown(m.section) <> true then show = false
    ApplyBadgeFrame(m.section)
    ' Build 33 (Pixel b32 P2): the frame and caption always draw; only the
    ' QR inside waits for its bitmap, then falls back to text.
    if show = true then ArmBadgeDeadline()
    fallback = (m.badgeFallback = true and BadgeBitmapReady() <> true)
    LogBadgeCard(show)
    if m.badgeGroup <> invalid then m.badgeGroup.visible = show
    if m.badgeCard <> invalid then m.badgeCard.visible = show
    if m.badgeLabel <> invalid then m.badgeLabel.visible = show
    if m.badgeDomain <> invalid then m.badgeDomain.visible = show
    ready = BadgeBitmapReady()
    if m.badgePoster <> invalid then m.badgePoster.visible = (show and ready)
    if m.badgeMissing <> invalid
        m.badgeMissing.text = BadgeFallbackText()
        m.badgeMissing.visible = (show and fallback)
    end if
    ' The white plate marks the QR spot while it loads; the fallback has none.
    ShowQrMark("badge", show and not fallback)
    if m.badgeHint = invalid then return
    if show and m.zone = "item"
        m.badgeHint.text = "Always available"
        m.badgeHint.visible = true
    else
        m.badgeHint.visible = false
    end if
end sub

sub PaintBook()
    if m.bookPane = invalid or not IsAssoc(m.book) then return
    lines = BookHeadline(m.book)
    if m.bookLines <> invalid
        last = m.bookLines.Count() - 1
        for index = 0 to last
            text = ""
            if index < lines.Count() then text = lines[index]
            m.bookLines[index].text = text
            m.bookLines[index].visible = (text <> "")
        end for
    end if
    if m.bookBanner <> invalid then m.bookBanner.text = BookHeading(BookText(m.book, "banner", "Book direct and save"))
    bodyLines = BreakLines(BookText(m.book, "body", ""), BookBodyRect().w, BookBodySize())
    ' Build 41 (Pixel b40): the label wraps the body itself across the full
    ' 1097px, so lines run the whole width. BreakLines (18px/char, wider than
    ' the font) only gives an upper bound on the line count for placement.
    savingsText = BookText(m.book, "savingsText", DefaultSavingsText())
    savingsLines = BreakLines(savingsText, BookSavingsRect().w, BookBodySize())
    if m.bookBody <> invalid then m.bookBody.text = BookText(m.book, "body", "")
    if m.bookSavings <> invalid then m.bookSavings.text = savingsText
    if m.bookSavings <> invalid then m.bookSavings.translation = [BookSavingsRect().x, BookSavingsY(bodyLines.Count(), savingsLines.Count())]
    if m.section = "book" then LogBookBody()
    if m.bookSign <> invalid then m.bookSign.text = BookText(m.book, "signOff", "Thanks for staying!")
    if m.bookDomain <> invalid then m.bookDomain.text = DisplayDomain()
    PaintPerks()
    photo = GuideLimitedText(m.book.Lookup("photo"), 240)
    if photo = "" then photo = GuideLimitedText(m.book.Lookup("photoFallback"), 240)
    if photo <> m.bookPhotoUri and m.bookPhoto <> invalid
        m.bookPhotoUri = photo
        m.bookPhotoTried = false
        m.bookPhoto.loadWidth = BookPhotoRect().w
        m.bookPhoto.loadHeight = BookPhotoRect().h
        m.bookPhoto.uri = photo
    end if
    qr = WithQrVersion(GuideLimitedText(m.book.Lookup("qrImageUrl"), 320))
    if not PosterKindOk(qr) then qr = ""
    EnsureQrSlot("book", qr)
end sub

function BookHeadline(book as object) as object
    lines = []
    raw = invalid
    if IsAssoc(book) then raw = book.Lookup("headline")
    if IsList(raw)
        last = raw.Count() - 1
        if last > 2 then last = 2
        if last >= 0
            for index = 0 to last
                text = GuideLimitedText(raw[index], 80)
                if text <> "" then lines.Push(text)
            end for
        end if
    end if
    if lines.Count() = 0 then return ["Love our home?", "Want to come back?", "Like saving money?"]
    return lines
end function

sub PaintPerks()
    if m.perkGroups = invalid then return
    perks = []
    if IsAssoc(m.book)
        raw = m.book.Lookup("perks")
        if IsList(raw) then perks = raw
    end if
    ' The tags are not focusable, so they are all the same plain outline.
    last = m.perkGroups.Count() - 1
    for index = 0 to last
        chip = m.perkGroups[index]
        if index >= perks.Count()
            chip.group.visible = false
        else
            chip.group.visible = true
            label = ""
            entry = perks[index]
            if IsAssoc(entry) then label = GuideLimitedText(entry.Lookup("label"), 40)
            chip.text.text = PerkLabel(label)
            chip.bg.color = PerkChipColor()
            chip.text.color = PerkTextColor()
        end if
    end for
end sub

sub onBookPhotoStatus()
    if m.bookPhoto = invalid then return
    status = m.bookPhoto.loadStatus
    if status <> "failed" and status <> "error" then return
    if m.bookPhotoTried = true then return
    m.bookPhotoTried = true
    fallback = ""
    if IsAssoc(m.book) then fallback = GuideLimitedText(m.book.Lookup("photoFallback"), 240)
    if fallback <> "" and fallback <> m.bookPhotoUri
        m.bookPhotoUri = fallback
        m.bookPhoto.loadWidth = BookPhotoRect().w
        m.bookPhoto.loadHeight = BookPhotoRect().h
        m.bookPhoto.uri = fallback
    end if
end sub

sub ShowBookQr(show as boolean)
    if m.bookQrCard <> invalid then m.bookQrCard.visible = show
    if m.bookQrPlate <> invalid then m.bookQrPlate.visible = show
    if m.bookScan <> invalid then m.bookScan.visible = show
    if m.bookDomain <> invalid then m.bookDomain.visible = show
    if m.bookQr <> invalid then m.bookQr.visible = show
    if m.bookQrMissing <> invalid then m.bookQrMissing.visible = false
    ShowQrMark("book", show)
end sub

' Assign a path the task already finished. The scene does not read the file.
' A failed load clears uri, so the assigned path is retried once, and that
' retry never runs from inside the loadStatus observer.
sub MountQrPosterBody(poster as object, path as string, slot as string)
    if m.qrAssigning = true then return
    if poster = invalid or path = invalid or path = "" then return
    if Left(path, 8) <> "cachefs:" and Left(path, 4) <> "tmp:" then return
    poster.visible = true
    poster.focusable = false
    poster.loadDisplayMode = "scaleToFit"
    RememberPoster(slot, poster)
    status = poster.loadStatus
    if slot = "badge" then LogBadgeColdStart(path, NotedQrBytes(slot), status)
    plan = BadgeColdStartPlan(path, NotedQrBytes(slot), poster.uri, status)
    if plan.action = "keep" then return
    if poster.uri = path and plan.action = "assign"
        print "Eaglewood: qr "; slot; " retry"
        m.qrAssigning = true
        poster.uri = ""
        poster.uri = path
        m.qrAssigning = false
        LogQrState(slot, poster)
        return
    end if
    if AssignedQrPath(slot) = path
        if status = "ready" or status = "loading" then return
        if QrRetried(slot) then return
        MarkQrRetry(slot)
        print "Eaglewood: qr "; slot; " retry"
        m.qrAssigning = true
        poster.uri = ""
        poster.uri = path
        m.qrAssigning = false
        LogQrState(slot, poster)
        return
    end if
    noted = NotedQrBytes(slot)
    print "Eaglewood: qr "; slot; " file bytes="; noted; " read="; noted
    ClearQrRetry(slot)
    NoteAssigned(slot, path)
    if m.qrMounted = invalid then m.qrMounted = {}
    m.qrMounted[slot] = path
    m.qrAssigning = true
    poster.uri = path
    m.qrAssigning = false
    LogQrState(slot, poster)
end sub

sub onBookQrStatus()
    NoteQrLoaded("book")
end sub

sub PaintWifi()
    if m.wifiSsidLabel = invalid then return
    notice = ""
    if m.wifiNotice <> invalid then notice = m.wifiNotice
    ssid = ""
    if m.wifiSsid <> invalid then ssid = m.wifiSsid
    password = ""
    if m.wifiPassword <> invalid then password = m.wifiPassword
    lines = WifiLines(notice, ssid, password)
    colW = WifiColumn(lines.mode = "fallback").w
    m.wifiSsidLabel.text = JoinLines(BreakLines(lines.network, colW, WifiSsidSize()))
        if m.wifiPasswordLabel <> invalid
        if lines.mode = "show"
            m.wifiPasswordLabel.text = JoinLines(BreakLines(lines.password, colW, WifiValueSize()))
            m.wifiPasswordLabel.color = InkColor()
        else if lines.mode = "fallback"
            m.wifiPasswordLabel.text = WifiUnavailableText()
            m.wifiPasswordLabel.color = TileSubColor()
        else
            m.wifiPasswordLabel.text = ""
        end if
    end if
    statusPanel = (lines.mode = "fallback")
    shownPassword = ""
    if lines.mode = "show" then shownPassword = lines.password
    if statusPanel then shownPassword = WifiUnavailableText()
    PlaceWifiColumn(statusPanel, lines.network, shownPassword, lines.mode = "show")
    if m.wifiHint <> invalid then m.wifiHint.text = JoinLines(BreakLines(WifiHintText(), WifiTextWidth(), WifiBodySize()))
    if m.wifiPasswordHeading <> invalid then m.wifiPasswordHeading.visible = (lines.mode = "show" or statusPanel)
    if m.wifiHint <> invalid then m.wifiHint.visible = (lines.mode = "show")
    if m.wifiPaintToken <> lines.mode
        m.wifiPaintToken = lines.mode
        print "Eaglewood: wifi screen mode="; lines.mode
    end if
    if m.wifiRouter <> invalid
        routerLines = BreakLines(FlushText(RouterStep(m.issues)), WifiRouterBox(statusPanel).w, WifiBodySize())
        m.wifiRouter.text = JoinLines(routerLines)
        PlaceRouterScrim(routerLines.Count())
    end if
    pngReady = (m.wifiPng = "yes")
    poster = PosterForSlot("wifi")
    if poster = invalid then return
    path = "cachefs:/eaglewood/wifi.png"
    if m.wifiFile <> invalid and m.wifiFile <> "" then path = m.wifiFile
    plate = ""
    if pngReady
        poster.loadWidth = 480
        poster.loadHeight = 480
        GuardMountQrPoster(poster, path, "wifi")
    end if
    drawn = false
    if pngReady = true
        if poster.loadStatus = "ready" then drawn = true
    end if
    if drawn
        poster.visible = true
        if m.wifiBacking <> invalid
            m.wifiBacking.color = "0xFFFFFFFF"
            m.wifiBacking.visible = true
        end if
        if m.wifiMissing <> invalid
            m.wifiMissing.text = ""
            m.wifiMissing.visible = false
        end if
        if m.wifiStatusPanel <> invalid then m.wifiStatusPanel.visible = false
    else if lines.mode = "fallback" and notice <> "coming-soon"
        poster.visible = false
        if m.wifiBacking <> invalid then m.wifiBacking.visible = false
        if m.wifiMissing <> invalid
            m.wifiMissing.text = ""
            m.wifiMissing.visible = false
        end if
        FitWifiPanel()
        if m.wifiStatusPanel <> invalid then m.wifiStatusPanel.visible = true
    else
        if m.wifiStatusPanel <> invalid then m.wifiStatusPanel.visible = false
        poster.visible = false
        if m.wifiBacking <> invalid
            m.wifiBacking.color = "0x1A2438FF"
            m.wifiBacking.visible = true
        end if
        if notice = "coming-soon"
            plate = ComingSoonWifi()
        else if lines.mode = "fallback"
            plate = WifiFallbackMessage()
        else
            ' Build 30 (Captain #1): a working password never sits next to an
            ' "unavailable" box; the QR area stays empty until the code is drawn.
            plate = ""
            if m.wifiBacking <> invalid then m.wifiBacking.visible = false
        end if
        if m.wifiMissing <> invalid
            m.wifiMissing.color = "0xFFFFFFF2"
            m.wifiMissing.text = plate
            m.wifiMissing.visible = true
        end if
    end if
end sub

function WifiLines(notice as string, ssid as string, password as string) as object
    if notice = "coming-soon" and ssid = ""
        return { mode: "coming-soon", network: ComingSoonWifi(), password: "" }
    end if
    if ssid = ""
        return { mode: "fallback", network: NetworkValue(WifiFallbackText()), password: WifiFallbackMessage() }
    end if
    return { mode: "show", network: ssid, password: password }
end function

function NetworkValue(text as string) as string
    if text = invalid then return ""
    prefix = "network name:"
    if Len(text) < Len(prefix) then return text
    if LCase(Left(text, Len(prefix))) <> prefix then return text
    rest = Mid(text, Len(prefix) + 1)
    if rest = invalid then return ""
    rest = rest.Trim()
    if rest = "" then return text
    return rest
end function

'' Pixel b28: the panel is the content plus 32px padding, not a fixed 585px.
sub FitWifiPanel()
    if m.wifiStatusBody = invalid then return
    body = WifiStatusBodyBox()
    bodyLines = BreakLines(WifiFallbackMessage(), body.w, body.size)
    headLines = BreakLines(WifiStatusHeading(), WifiStatusHeadingBox().w, WifiStatusHeadingBox().size)
    fit = WifiPanelFitHeight(bodyLines.Count(), headLines.Count())
    m.wifiStatusBody.text = JoinLines(bodyLines)
    m.wifiStatusBody.translation = [body.x, fit.bodyY]
    m.wifiStatusBody.height = fit.bodyH + 8
    if m.wifiPanelFill <> invalid then m.wifiPanelFill.height = fit.h
    if m.wifiPanelBorder <> invalid then m.wifiPanelBorder.height = fit.h
end sub

' Collapses runs of spaces and trims, so wrapped lines start flush left.
function FlushText(text as string) as string
    if text = invalid then return ""
    out = text.Trim()
    while Instr(1, out, "  ") > 0
        out = out.Replace("  ", " ")
    end while
    return out
end function

'' Build 29: break text ourselves so no wrapped line starts with a space (the
' label wrap in brs-node keeps the space). The width per character is 0.6 of
' the size, wider than the Roku system font's average, so a broken line is
' never wider than the label and the label does not wrap it again.
function BreakCharWidth(size as integer) as integer
    width = (size * 3) \ 5
    if width < 1 then return 1
    return width
end function

function BreakLines(text as string, width as integer, size as integer) as object
    out = []
    if text = invalid then return out
    for each para in FlushParagraphs(text)
        for each line in WrapGreeting(para, width, invalid, BreakCharWidth(size))
            if line <> "overflow" then out.Push(line.Trim())
        end for
    end for
    return out
end function

function FlushParagraphs(text as string) as object
    out = []
    for each part in text.Split(Chr(10))
        clean = FlushText(part)
        if clean <> "" then out.Push(clean)
    end for
    return out
end function

function JoinLines(lines as object) as string
    out = ""
    for each line in lines
        if out <> "" then out = out + Chr(10)
        out = out + line
    end for
    return out
end function

function WifiFallbackMessage() as string
    return "Wi-Fi details couldn't load right now. Please check your booking welcome message or contact your host (see Quick Fixes)."
end function

sub onWifiPosterStatus()
    if m.wifiPoster = invalid then return
    LogQrState("wifi", m.wifiPoster)
    status = m.wifiPoster.loadStatus
    if status = "ready"
        m.wifiPoster.visible = true
        if m.wifiMissing <> invalid then m.wifiMissing.text = ""
        return
    end if
    if status <> "failed" and status <> "error" then return
    ' Build 33: reload on a timer first; the message shows only after the
    ' reloads give up (QrGaveUp).
    ScheduleQrReload("wifi")
end sub

function WifiFallbackText() as string
    if not IsList(m.issues) then return ComingSoonWifi()
    last = m.issues.Count() - 1
    if last < 0 then return ComingSoonWifi()
    for index = 0 to last
        issue = m.issues[index]
        if WifiIssueText(issue)
            steps = issue.Lookup("steps")
            if IsList(steps) and steps.Count() > 0
                return GuideLimitedText(steps[0], 180)
            end if
        end if
    end for
    return ComingSoonWifi()
end function

' Pixel b27: Things to Do shows its categories as 280x160 cards, 24px
' gutters, from y 260, in the Home tile style, the current season first.
function TodoPreviewCard() as object
    return { x: ContentLeft(), y: HomeSubheadY() + 64, w: 280, h: 160, gap: 24, columns: 3 }
end function

function TodoPreviewOrder(season as string) as object
    order = []
    menu = TodoMenu()
    for each section in menu
        if section = season then order.Push(section)
    end for
    for each section in menu
        if section <> season then order.Push(section)
    end for
    return order
end function

function TodoPreviewLine(section as string) as string
    if section = "dining" then return "Village & Bend"
    if section = "hiking" then return "Trails nearby"
    if section = "winter" then return "Winter picks"
    if section = "summer" then return "Summer picks"
    if section = "fishing" then return "On the water"
    if section = "biking" then return "Rides nearby"
    return ""
end function

sub BuildTodoPreview(pane as object)
    group = CreateObject("roSGNode", "Group")
    group.visible = false
    card = TodoPreviewCard()
    m.todoCards = []
    for index = 0 to 5
        col = index mod card.columns
        row = index \ card.columns
        cell = CreateObject("roSGNode", "Group")
        cell.translation = [card.x + (col * (card.w + card.gap)), card.y + (row * (card.h + card.gap))]
        AddRect(cell, "0x00000055", 8, 8, card.w, card.h)
        AddRect(cell, TileColor(), 0, 0, card.w, card.h)
        title = AddLabel(cell, "", "font:SmallBoldSystemFont", "0xFFFFFFFF", 24, 20, card.w - 48, 48)
        SetFontSize(title, 34)
        title.maxLines = 1
        line = AddLabel(cell, "", "font:SmallSystemFont", TileSubColor(), 24, 68, card.w - 48, 84)
        SetFontSize(line, 28)
        line.wrap = true
        line.vertAlign = "bottom"
        line.maxLines = 2
        group.appendChild(cell)
        m.todoCards.Push({ cell: cell, title: title, line: line })
    end for
    pane.appendChild(group)
    m.todoPreview = group
end sub

sub PaintTodoPreview(show as boolean)
    if m.todoPreview = invalid then return
    m.todoPreview.visible = show
    if show <> true then return
    order = TodoPreviewOrder(TodoSeason())
    last = m.todoCards.Count() - 1
    for index = 0 to last
        entry = m.todoCards[index]
        if index < order.Count()
            entry.title.text = RailLabel(order[index])
            entry.line.text = TodoPreviewLine(order[index])
            entry.cell.visible = true
        else
            entry.cell.visible = false
        end if
    end for
end sub

sub PaintActivity()
    if m.activityTitle = invalid then return
    m.activityTitle.text = RailLabel(m.section)
    if m.activitySub <> invalid then m.activitySub.text = ActivitySubtitle()
    EnsureActivityGrid()
    count = CardCount()
    preview = (m.section = "todo")
    if m.activityEmpty <> invalid
        if count = 0 then m.activityEmpty.text = JoinLines(BreakLines(ActivityEmptyText(m.section), 416, 30))
        ' The preview row replaces the OK hint on Things to Do.
        m.activityEmpty.visible = (count = 0 and not preview)
        if m.activityEmptyCard <> invalid then m.activityEmptyCard.visible = m.activityEmpty.visible
    end if
    PaintTodoPreview(preview)
    if m.activityGrid <> invalid then m.activityGrid.visible = (count > 0)
    if m.zone = "item"
        PaintDetail()
    else
        ShowCardFocus()
    end if
end sub

' The season the subhead names ("Sorted for winter"); the preview row leads with it.
function TodoSeason() as string
    ' Build 31 (Captain #1): never the last grid's season, which went stale.
    return CurrentSeason()
end function

function ActivitySubtitle() as string
    ' Build 31 (Captain #1): SeasonSubheadFor uses ScreenSortSeason, the same
    ' value EnsureActivityGrid sorts by.
    extra = "Seasonal picks"
    if m.section = "dining" then extra = "Village & Bend"
    if m.section = "hiking" then extra = "Trails nearby"
    if m.section = "winter" then extra = "Winter picks"
    if m.section = "summer" then extra = "Summer picks"
    if m.section = "fishing" then extra = "On the water"
    if m.section = "biking" then extra = "Rides nearby"
    if m.section = "todo" then return SeasonSubheadFor(m.section, CurrentSeason())
    return SeasonSubheadFor(m.section, CurrentSeason()) + "  ·  " + extra
end function

sub EnsureActivityGrid()
    if m.boundSection <> m.section
        m.boundSection = m.section
        m.cardIndex = 0
        m.jumpedIndex = -1
    end if
    ' Build 30 root cause: Summer and Winter sorted by the calendar season's
    ' rank (fall), so Hiking's high fall ranks led Summer. A season screen
    ' sorts by its own seasonRank key.
    season = ScreenSortSeason(m.section, CurrentSeason())
    token = 0
    if m.activitiesToken <> invalid then token = m.activitiesToken
    count = 0
    if IsList(m.activities) then count = m.activities.Count()
    stamp = m.section + "|" + token.ToStr() + "|" + count.ToStr() + "|" + season
    if stamp = m.activityStamp and m.activityContent <> invalid then return
    m.activityStamp = stamp
    picked = ActivitiesForScreen(m.activities, m.section)
    m.sortedCards = SortActivities(picked, season)
    if m.cardIndex < 0 or m.cardIndex >= CardCount() then m.cardIndex = 0
    RebuildActivityGrid()
end sub

function CardCount() as integer
    if not IsList(m.sortedCards) then return 0
    return m.sortedCards.Count()
end function

sub RebuildActivityGrid()
    if m.activityGrid = invalid then return
    root = CreateObject("roSGNode", "ContentNode")
    last = CardCount() - 1
    if last >= 0
        for index = 0 to last
            item = m.sortedCards[index]
            node = CreateObject("roSGNode", "ActivityContent")
            node.id = CardNodeId(item)
            node.title = ItemText(item, "name")
            node.distance = ItemText(item, "distance")
            node.seasonLabel = ItemText(item, "seasonLabel")
            node.swatch = SwatchFor(SourceIndexOf(item))
            node.sourceIndex = SourceIndexOf(item)
            node.imageUri = ""
            node.imageFallback = ""
            node.cardFocused = false
            root.appendChild(node)
        end for
    end if
    m.activityContent = root
    m.activityGrid.content = root
    m.jumpedIndex = -1
end sub

function CardNodeId(item as object) as string
    return "card" + SourceIndexOf(item).ToStr()
end function

function ItemText(item as object, key as string) as string
    if not IsAssoc(item) then return ""
    return GuideLimitedText(AaField(item, key), 420)
end function

function SwatchFor(index as integer) as string
    colors = ["0x6B4A32FF", "0x5C4033FF", "0x3E5C45FF", "0x4A5560FF", "0x6A5330FF", "0x2F4F45FF"]
    slot = index mod 6
    if slot < 0 then slot = 0
    return colors[slot]
end function

sub ShowCardFocus()
    if m.activityContent = invalid then return
    count = m.activityContent.getChildCount()
    if count < 1 then return
    start = ActivityWindowStart(m.cardIndex)
    finish = start + 9
    if finish > count then finish = count
    last = count - 1
    for index = 0 to last
        child = m.activityContent.getChild(index)
        child.cardFocused = (m.zone = "grid" and index = m.cardIndex)
        uri = ""
        fallback = ""
        if index >= start and index < finish
            item = invalid
            if index < CardCount() then item = m.sortedCards[index]
            if IsAssoc(item)
                uri = ItemText(item, "poster")
                fallback = ItemText(item, "posterFallback")
            end if
            if uri = "" then uri = PlaceholderPoster()
        end if
        if child.imageFallback <> fallback then child.imageFallback = fallback
        if child.imageUri <> uri then child.imageUri = uri
    end for
    if m.activityGrid <> invalid and m.zone = "grid" and m.jumpedIndex <> m.cardIndex
        m.activityGrid.jumpToItem = m.cardIndex
        m.jumpedIndex = m.cardIndex
    end if
end sub

function ActivityWindowStart(index as integer) as integer
    if index < 0 then return 0
    row = index \ 3
    if row > 0 then row = row - 1
    return row * 3
end function

sub ReleaseCardImages()
    if m.activityContent = invalid then return
    last = m.activityContent.getChildCount() - 1
    if last < 0 then return
    for index = 0 to last
        child = m.activityContent.getChild(index)
        child.cardFocused = false
        child.imageUri = ""
        child.imageFallback = ""
    end for
end sub

sub PaintDetail()
    LogDetailOpen()
    item = ActivityAt(m.sortedCards, m.cardIndex)
    if m.detailName <> invalid then m.detailName.text = JoinLines(BreakLines(ItemText(item, "name"), ContentWidth(), PageH1Size()))
    if m.detailMeta <> invalid then m.detailMeta.text = DetailMeta(item)
    if m.detailBody <> invalid
        m.detailBody.text = ""
        m.detailBody.visible = false
    end if
    if m.detailTip <> invalid
        m.detailTip.text = ""
        m.detailTip.visible = false
    end if
    if m.detailExtra <> invalid
        m.detailExtra.text = ""
        m.detailExtra.visible = false
    end if
    ArmDetailQrDeadline(DetailQrForItem(item))
    ' Build 31 (Captain #2): the no-link layout until the QR has a bitmap.
    LayoutDetailColumns(DetailQrShown())
    FillDetailBody()
    if m.detailCredit <> invalid then m.detailCredit.text = ItemText(item, "credit")
    if m.detailBack <> invalid then m.detailBack.text = "Back to " + RailLabel(m.section)
    photo = ItemText(item, "poster")
    if photo = "" then photo = PlaceholderPoster()
    if m.detailPhoto <> invalid and photo <> m.detailPhotoUri
        m.detailPhotoUri = photo
        m.detailPhotoTried = false
        m.detailPhoto.loadWidth = 640
        m.detailPhoto.loadHeight = 360
        m.detailPhoto.uri = photo
    end if
    qr = DetailQrForItem(item)
    if m.detailQrCaption <> invalid
        ' Fits the 280px card on one line at the pessimistic width (no ellipsis).
        m.detailQrCaption.text = "Scan for info"
    end if
    if qr = ""
        source = "none"
        if m.activitiesSource <> invalid and m.activitiesSource <> "" then source = m.activitiesSource
        print "Eaglewood: qr detail skip reason=no-url id="; ItemText(item, "id"); " index="; m.cardIndex; " source="; source
    else if qr <> QrRemote("detail")
        print "Eaglewood: qr detail open url="; SafeUri(qr)
    end if
    EnsureQrSlot("detail", qr)
    RevealDetailQr()
end sub

sub LogDetailOpen()
    item = ActivityAt(m.sortedCards, m.cardIndex)
    id = ItemText(item, "id")
    qr = DetailQrForItem(item)
    print "Eaglewood: detail open id="; id; " qrUrl="; qr
    print "Eaglewood: detail card rect="; ScreenRectText(DetailQrCardRect())
end sub

sub LogBookBody()
    text = ""
    if m.bookBody <> invalid then text = m.bookBody.text
    rect = BookBodyRect()
    lines = WrapGreeting(text, rect.w, invalid, FallbackCharWidth(BookBodyFontSize()))
    print "Eaglewood: book body lines="; lines.Count(); " rect="; ScreenRectText(rect)
    ' Build 40 geometry test: the page's blocks in scene coordinates.
    slot = BookQrSlot()
    save = BookSavingsRect()
    if m.bookSavings <> invalid then save.y = Int(m.bookSavings.translation[1])
    bodyCount = BreakLines(BookText(m.book, "body", ""), rect.w, BookBodySize()).Count()
    if bodyCount > BookTextLines() then bodyCount = BookTextLines()
    saveCount = BreakLines(BookText(m.book, "savingsText", DefaultSavingsText()), save.w, BookBodySize()).Count()
    if saveCount > 2 then saveCount = 2
    gapA = save.y - (rect.y + bodyCount * 42)
    gapB = BookPerkRow().y - (save.y + saveCount * 42)
    print "Eaglewood: book gaps photoToBody=" + (rect.y - BookPhotoRect().y - BookPhotoRect().h).ToStr() + " bodyToSavings=" + gapA.ToStr() + " savingsToChips=" + gapB.ToStr() + " bodyLines=" + bodyCount.ToStr() + " savingsLines=" + saveCount.ToStr()
    print "Eaglewood: book layout panel=" + ScreenRectText(BookPanelRect()) + " photo=" + ScreenRectText(BookPhotoRect()) + " card=" + ScreenRectText({ x: slot.cardX, y: slot.cardY, w: slot.cardW, h: slot.cardH }) + " qr=" + ScreenRectText({ x: slot.qrX, y: slot.qrY, w: slot.qrW, h: slot.qrH }) + " body=" + ScreenRectText(rect) + " savings=" + ScreenRectText(save) + " chips=" + ScreenRectText(BookPerkRow())
end sub

function BookBodyFontSize() as integer
    return 27
end function

function BookBodyLineHeight() as integer
    return 36
end function

function BookSavingsFontSize() as integer
    return 20
end function

function BookSavingsLineHeight() as integer
    return 26
end function

function BookPanelColor() as string
    return "0x1A2438FF"
end function

function BookCardColor() as string
    return "0x243044FF"
end function

function BookBannerColor() as string
    return "0xF2A93BFF"
end function

function BookInkColor() as string
    return "0xFFFFFFF2"
end function

sub LogBadgePlacement()
    group = m.badgeGroup
    if group = invalid then return
    visible = "false"
    if group.visible = true then visible = "true"
    parentId = "none"
    index = -1
    parent = group.getParent()
    if parent <> invalid
        parentId = "shell"
        if parent.id <> invalid and parent.id <> "" then parentId = parent.id
        count = parent.getChildCount()
        last = count - 1
        if last >= 0
            for at = 0 to last
                child = parent.getChild(at)
                same = false
                if child <> invalid
                    if child.isSameNode(group) = true then same = true
                end if
                if same = true then index = at
            end for
        end if
    end if
    opacity = 1
    if group.opacity <> invalid then opacity = group.opacity
    tx = 0
    ty = 0
    trans = group.translation
    if trans <> invalid
        tx = trans[0]
        ty = trans[1]
    end if
    scene = BadgeSceneRect(group)
    print "Eaglewood: badge visible="; visible; " parent="; parentId; " index="; index; " opacity="; opacity; " translation="; tx.ToStr(); ","; ty.ToStr(); " sceneRect="; ScreenRectText(scene)
end sub

function BadgeSceneRect(node as object) as object
    frame = BadgeFrame()
    x = frame.x
    y = frame.y
    wide = frame.w
    tall = frame.h
    if node = invalid then return { x: x, y: y, w: wide, h: tall }
    bounds = node.boundingRect()
    if bounds <> invalid
        if bounds.x <> invalid then x = bounds.x
        if bounds.y <> invalid then y = bounds.y
        if bounds.width <> invalid and bounds.width > 0 then wide = bounds.width
        if bounds.height <> invalid and bounds.height > 0 then tall = bounds.height
    end if
    parent = node.getParent()
    while parent <> invalid
        trans = parent.translation
        if trans <> invalid
            x = x + trans[0]
            y = y + trans[1]
        end if
        parent = parent.getParent()
    end while
    return { x: x, y: y, w: wide, h: tall }
end function

function BadgeShown(section as string) as boolean
    ' Build 34: the corner Book Direct ad (NavV2.brs) replaces the QR badge.
    return false
    if section = "book" then return false
    ' One QR per screen on Wi-Fi, so a guest cannot scan the booking code by mistake.
    if section = "wifi" then return false
    ' Things to Do grids and details: one QR per detail and a 32px gap under
    ' the cards (Pixel b28).
    if ActivitySection(section) then return false
    ' Quick Fixes: the steps panel grows to y 960, where the badge sat.
    if section = "fixes" then return false
    return true
end function

function BadgeNavigateReparents() as boolean
    return false
end function

function DetailQrForItem(item as object) as string
    qr = DetailQrUrl(item)
    if qr <> "" then return qr
    alt = ActivityById(m.activities, ItemText(item, "id"))
    if alt = invalid then return ""
    return DetailQrUrl(alt)
end function

sub ShowDetailQr(show as boolean)
    if show
        RevealDetailQr()
        return
    end if
    SetDetailQrVisible(false)
end sub

sub SetDetailQrVisible(show as boolean)
    if m.detailQrCard <> invalid then m.detailQrCard.visible = show
    if m.detailPlace <> invalid then m.detailPlace.visible = show
    if m.detailSite <> invalid then m.detailSite.visible = show
    if m.detailQrCaption <> invalid then m.detailQrCaption.visible = show
    if m.detailQr <> invalid then m.detailQr.visible = show
    if m.detailQrMissing <> invalid then m.detailQrMissing.visible = false
    ShowQrMark("detail", false)
end sub

function DetailPosterReady() as boolean
    poster = PosterForSlot("detail")
    if poster = invalid then return false
    if poster.loadStatus = "ready" then return true
    return false
end function

' Build 31 (Captain #2): the QR column exists only while this item's QR has a
' bitmap that arrived inside the 5s deadline. Otherwise the page keeps the
' no-link layout, so a guest never sees an empty white plate.
function DetailQrShown() as boolean
    if m.detailQrFor = invalid or m.detailQrFor = "" then return false
    if m.detailQrTimedOut = true then return false
    if QrRemote("detail") <> m.detailQrFor then return false
    return DetailPosterReady()
end function

function DetailQrDeadlineSeconds() as float
    return 5
end function

sub ArmDetailQrDeadline(qr as string)
    if m.detailQrFor = qr then return
    m.detailQrFor = qr
    m.detailQrTimedOut = false
    if m.detailQrTimer <> invalid then m.detailQrTimer.control = "stop"
    if qr = "" or m.top = invalid then return
    if m.detailQrTimer = invalid
        m.detailQrTimer = CreateObject("roSGNode", "Timer")
        m.detailQrTimer.repeat = false
        m.detailQrTimer.observeField("fire", "onDetailQrDeadline")
        m.top.appendChild(m.detailQrTimer)
    end if
    m.detailQrTimer.duration = DetailQrDeadlineSeconds()
    m.detailQrTimer.control = "start"
end sub

sub onDetailQrDeadline()
    if DetailQrShown() then return
    m.detailQrTimedOut = true
    print "Eaglewood: qr detail fallback reason=timeout url="; SafeUri(m.detailQrFor)
    RevealDetailQr()
end sub

sub RevealDetailQr()
    shown = DetailQrShown()
    if m.detailWide = shown
        LayoutDetailColumns(shown)
        if m.detailBody <> invalid then FillDetailBody()
    end if
    SetDetailQrVisible(shown)
end sub

function DetailMeta(item as object) as string
    bits = []
    season = ItemText(item, "seasonLabel")
    distance = ItemText(item, "distance")
    if season <> "" then bits.Push(season)
    if distance <> "" then bits.Push(distance)
    return JoinBits(bits)
end function

function ActivityScrollText() as string
    item = ActivityAt(m.sortedCards, m.cardIndex)
    text = ItemText(item, "description")
    tip = ItemText(item, "tip")
    extra = DetailExtra(item)
    if tip <> "" then text = text + Chr(10) + "Tip: " + tip
    if extra <> "" then text = text + Chr(10) + extra
    return text
end function

function DetailExtra(item as object) as string
    bits = []
    difficulty = ItemText(item, "difficulty")
    trail = ItemText(item, "trailDistance")
    getting = ItemText(item, "gettingThere")
    if difficulty <> "" then bits.Push(difficulty)
    if trail <> "" then bits.Push(trail)
    line = JoinBits(bits)
    if getting <> ""
        if line <> "" then line = line + " · "
        line = line + getting
    end if
    return line
end function

function JoinBits(bits as object) as string
    if not IsList(bits) or bits.Count() = 0 then return ""
    line = bits[0]
    last = bits.Count() - 1
    if last < 1 then return line
    for index = 1 to last
        line = line + " · " + bits[index]
    end for
    return line
end function

sub onDetailPhotoStatus()
    if m.detailPhoto = invalid then return
    status = m.detailPhoto.loadStatus
    if status <> "failed" and status <> "error" then return
    if m.detailPhotoTried = true
        if m.detailPhotoUri <> PlaceholderPoster()
            m.detailPhotoUri = PlaceholderPoster()
            m.detailPhoto.loadWidth = 64
            m.detailPhoto.loadHeight = 64
            m.detailPhoto.uri = PlaceholderPoster()
        end if
        return
    end if
    m.detailPhotoTried = true
    item = ActivityAt(m.sortedCards, m.cardIndex)
    fallback = ItemText(item, "posterFallback")
    if fallback <> "" and fallback <> m.detailPhotoUri
        m.detailPhotoUri = fallback
        m.detailPhoto.loadWidth = 640
        m.detailPhoto.loadHeight = 360
        m.detailPhoto.uri = fallback
        return
    end if
    m.detailPhotoUri = PlaceholderPoster()
    m.detailPhoto.uri = PlaceholderPoster()
end sub

sub onDetailQrStatus()
    NoteQrLoaded("detail")
    poster = PosterForSlot("detail")
    if poster <> invalid and poster.loadStatus = "failed"
        m.detailQrTimedOut = true
        print "Eaglewood: qr detail fallback reason=failed url="; SafeUri(m.detailQrFor)
    end if
    RevealDetailQr()
end sub

sub ApplyWifiResult(result as object)
    if result = invalid then return
    ' Build 34: never replace a real SSID with an empty one (Blake b33 TV log).
    incomingSsid = AsText(AaField(result, "ssid"))
    if incomingSsid = "" and m.wifiSsid <> "" and AsText(result.notice) <> "coming-soon"
        print "Eaglewood: wifi kept ssid len="; Len(m.wifiSsid); " reason=empty-result"
        return
    end if
    m.wifiSsid = AsText(AaField(result, "ssid"))
    m.wifiPassword = AsText(AaField(result, "password"))
    m.wifiPng = AsText(AaField(result, "png"))
    if m.wifiPng = "" then m.wifiPng = "no"
    m.wifiSource = AsText(result.source)
    m.wifiNotice = AsText(result.notice)
    m.wifiJsonCode = ResultNumber(result, "jsonCode")
    m.wifiPngCode = ResultNumber(result, "pngCode")
    m.wifiPngBit = ResultNumber(result, "pngBit")
    m.wifiPngColor = ResultNumber(result, "pngColor")
    m.wifiPngInterlace = ResultNumber(result, "pngInterlace")
    m.wifiIndexed = AsText(result.pngIndexed)
    if m.wifiIndexed = "" then m.wifiIndexed = "no"
    m.wifiRemoteSafe = AsText(result.remoteSafe)
    incoming = AsText(result.pngPath)
    if incoming <> "" then m.wifiFile = incoming
    NoteQrBytes("wifi", ResultNumber(result, "pngBytes"))
    RememberQrPng64("wifi", result.png64)
    PaintWifi()
end sub

function ResultNumber(result as object, key as string) as integer
    if result = invalid then return 0
    return GuideInt(result.Lookup(key))
end function

function QrDebugMarks() as boolean
    return false
end function

function QrMarkColor() as string
    if QrDebugMarks() then return "0xFF00FFFF"
    return "0xFFFFFFF2"
end function

function QrCaptionFont() as string
    return "font:SmallBoldSystemFont"
end function

' #8A5A00 on the cream card is about 5.9:1 (Pixel b28); gold was 1.7:1.
function QrCaptionColor() as string
    return "0x8A5A00FF"
end function

function PageH1Size() as integer
    return 52
end function

function CheckoutTileRect() as object
    grid = HomeGrid()
    return {
        x: grid.x + (2 * (grid.w + grid.gap)),
        y: grid.y + (grid.h + grid.gap),
        w: grid.w,
        h: grid.h
    }
end function

' Build 18 corner. The gold caption sits under the 128px QR, inside the card.
function BadgeCaptionColor() as string
    return "0x8A5A00FF"
end function

'' Build 28 (Pixel b27 P1). A cream card with 16px padding, right edge 1717,
' bottom 960 at most, inside title-safe. Home gets the 240px code beside the
' tile grid; every other page gets the 128px corner card.
function BadgeFrame() as object
    return BadgeFrameFor(128, 960)
end function

' Pixel b28: the Home card spans both tile rows (2 x 168 + 24), so its top
' and bottom line up with the grid. The code and caption are centered in it.
function HomeBadgeFrame() as object
    frame = BadgeFrameFor(240, 0)
    frame.y = HomeStripRect().y + HomeStripRect().h + 24
    tall = (2 * 168) + 24
    shift = (tall - frame.h) \ 2
    frame.h = tall
    frame.qrY = frame.qrY + shift
    frame.captionY = frame.captionY + shift
    frame.captionSize = 28
    return frame
end function

function BadgeFrameFor(qr as integer, bottom as integer) as object
    pad = 16
    w = 312
    ' The caption box is wider than the card so no font can ellipsize the
    ' domain; the text is centered, so the glyphs stay on the cream card.
    captionW = 520
    h = pad + qr + 8 + 40 + pad
    return {
        x: HomeRight() - w,
        y: bottom - h,
        w: w,
        h: h,
        qrX: (w - qr) \ 2,
        qrY: pad,
        qr: qr,
        captionX: (w - captionW) \ 2,
        captionY: pad + qr + 8,
        captionW: captionW,
        captionH: 40,
        captionSize: 20
    }
end function

function BadgeFrameForSection(section as string) as object
    if section = "home" then return HomeBadgeFrame()
    return BadgeFrame()
end function

function BadgeCardColor() as string
    return "0xF4EFE3FF"
end function

sub ApplyBadgeFrame(section as string)
    key = "corner"
    if section = "home" then key = "home"
    if m.badgeFrameKey = key then return
    m.badgeFrameKey = key
    frame = BadgeFrameForSection(section)
    if m.badgeGroup <> invalid then m.badgeGroup.translation = [frame.x, frame.y]
    if m.badgeCard <> invalid
        m.badgeCard.width = frame.w
        m.badgeCard.height = frame.h
    end if
    if m.badgeMark <> invalid
        m.badgeMark.translation = [frame.qrX, frame.qrY]
        m.badgeMark.width = frame.qr
        m.badgeMark.height = frame.qr
    end if
    if m.badgePoster <> invalid
        m.badgePoster.translation = [frame.qrX, frame.qrY]
        m.badgePoster.width = frame.qr
        m.badgePoster.height = frame.qr
    end if
    if m.badgeDomain <> invalid
        m.badgeDomain.translation = [frame.captionX, frame.captionY]
        SetFontSize(m.badgeDomain, frame.captionSize)
    end if
    ' No-link fallback text sits where the code would, above the caption.
    if m.badgeMissing <> invalid
        m.badgeMissing.translation = [16, frame.qrY]
        m.badgeMissing.width = frame.w - 32
        m.badgeMissing.height = frame.qr
        m.badgeMissing.horizAlign = "center"
        m.badgeMissing.vertAlign = "bottom"
        m.badgeMissing.wrap = true
        m.badgeMissing.maxLines = 2
        m.badgeMissing.color = "0x1B2A44FF"
        SetFontSize(m.badgeMissing, 30)
    end if
end sub

function BadgeCaptionRect() as object
    frame = BadgeFrame()
    return {
        x: frame.x + frame.captionX,
        y: frame.y + frame.captionY,
        w: frame.captionW,
        h: frame.captionH
    }
end function

sub LogBadgeCard(show as boolean)
    shown = "false"
    if show = true then shown = "true"
    if m.badgeCardLogged = shown + m.section then return
    m.badgeCardLogged = shown + m.section
    print "Eaglewood: badge card shown="; shown; " section="; m.section
end sub

function BadgeBitmapReady() as boolean
    poster = PosterForSlot("badge")
    if poster = invalid then return false
    return (poster.loadStatus = "ready")
end function

function BadgePosterFailed() as boolean
    poster = PosterForSlot("badge")
    if poster = invalid then return false
    status = poster.loadStatus
    if status = "failed" or status = "error" then return true
    return false
end function

function DetailPhotoRect() as object
    return { x: ContentLeft(), y: ContentTop() + 140, w: 700, h: 260 }
end function

function DetailQrCardRect() as object
    return { x: ContentLeft() + 740, y: ContentTop() + 140, w: 280, h: 280 }
end function

' Build 29: y 625-940 under the photo and QR card, as wide as photo + card,
' 5 lines at 30/42 before it scrolls.
function DetailMetaH() as integer
    return 38
end function

function DetailBodyRect() as object
    card = DetailQrCardRect()
    w = card.x + card.w - ContentLeft()
    if m.detailWide = true then w = DetailWideWidth()
    return { x: ContentLeft(), y: 625, w: w, h: 315 }
end function

' Build 30 (Captain #6, Pixel b29 TtD #3): with no link the QR column
' collapses; photo and body run 1128px wide (to x 1716, title-safe).
function DetailWideWidth() as integer
    return 1128
end function

sub LayoutDetailColumns(hasQr as boolean)
    m.detailWide = (hasQr <> true)
    photo = DetailPhotoRect()
    card = DetailQrCardRect()
    if m.detailPhoto <> invalid
        m.detailPhoto.width = photo.w
        if m.detailWide then m.detailPhoto.width = DetailWideWidth()
    end if
    if m.detailCredit <> invalid
        if m.detailWide
            m.detailCredit.translation = [ContentLeft() + DetailWideWidth() - 480, photo.y + photo.h + 12]
            m.detailCredit.width = 480
            m.detailCredit.horizAlign = "right"
        else
            m.detailCredit.translation = [card.x, card.y + card.h + 12]
            m.detailCredit.width = card.w
            m.detailCredit.horizAlign = "center"
        end if
    end if
    if m.detailWide then SetDetailQrVisible(false)
    ' Build 36 (Pixel b35 TtD #1): the meta strip spans the body panel,
    ' x 588-1716 with no QR, x 588-1608 with one.
    body = DetailBodyRect()
    if m.detailMetaScrim <> invalid then m.detailMetaScrim.width = body.w
    if m.detailMeta <> invalid then m.detailMeta.width = body.w - 20
    PlaceDetailScroll()
end sub

function DetailQrPosterRect() as object
    card = DetailQrCardRect()
    return { x: card.x + 30, y: card.y + 36, w: 220, h: 200 }
end function

function DetailQrSiteRect() as object
    card = DetailQrCardRect()
    return { x: card.x + 16, y: card.y + 4, w: 248, h: 28 }
end function

function DetailQrCaptionRect() as object
    card = DetailQrCardRect()
    return { x: card.x, y: card.y + card.h - 38, w: card.w, h: 34 }
end function

' Book Direct, build 29 (Pixel b28). Everything sits in the content box with
' 16px side padding: H1, photo, 24px gap, 30px body, then the chip row and a
' centered sign-off near the bottom.
function BookPanelRect() as object
    return { x: ContentLeft(), y: 106, w: HomeRight() - ContentLeft(), h: 972 - 106 }
end function

function BookInnerX() as integer
    return BookPanelRect().x + 16
end function

function BookHeadRect() as object
    return { x: BookInnerX(), y: BookPanelRect().y + 24, w: 1000, h: 64 }
end function

' Build 40 (Blake's TV photo: everything crammed left, right side empty).
' The page uses the whole box: a 16:9 photo on the left with the Scan me
' card (QR + site address) the same height beside it, then the body and the
' savings line across the full width, the chip row and the sign-off.
function BookInnerW() as integer
    return BookPanelRect().w - 32
end function

function BookColGap() as integer
    return 24
end function

function BookPhotoRect() as object
    ' 641 wide leaves an even-width Scan me card, so the QR centers exactly.
    return { x: BookInnerX(), y: BookHeadRect().y + 64 + 8, w: 641, h: 360 }
end function

function BookTextLines() as integer
    return 4
end function

function BookBodySize() as integer
    return 30
end function

function BookBodyRect() as object
    photo = BookPhotoRect()
    return { x: BookInnerX(), y: photo.y + photo.h + 24, w: BookInnerW(), h: BookTextLines() * 42 }
end function

' Build 41: the body starts 24px under the photo; the space left between the
' body's last line and the chip row is split evenly above and below the
' savings line.
function BookSavingsY(bodyCount as integer, savingsCount as integer) as integer
    if bodyCount > BookTextLines() then bodyCount = BookTextLines()
    if savingsCount > 2 then savingsCount = 2
    bodyEnd = BookBodyRect().y + bodyCount * 42
    free = BookPerkRow().y - bodyEnd - savingsCount * 42
    gap = free \ 2
    if gap < 12 then gap = 12
    return bodyEnd + gap
end function

function BookSavingsRect() as object
    body = BookBodyRect()
    ' PaintBook moves it up under the body's last drawn line.
    return { x: body.x, y: body.y + body.h + 8, w: body.w, h: 2 * 42 }
end function

function BookPerkRow() as object
    return { x: BookInnerX(), y: BookSignRect().y - 12 - PerkChipH(), w: (5 * PerkChipW()) + (4 * PerkChipGap()), h: PerkChipH() }
end function

' Build 40: five chips span the inner width (1096 = 5 x 200 + 4 x 24).
function PerkChipGap() as integer
    return (BookInnerW() - 5 * PerkChipW()) \ 4
end function

function BookSignRect() as object
    panelBox = BookPanelRect()
    return { x: panelBox.x, y: panelBox.y + panelBox.h - 16 - 40, w: panelBox.w, h: 40 }
end function

function PerkChipW() as integer
    return 200
end function

function PerkChipH() as integer
    return 56
end function

function PerkChipSize() as integer
    return 26
end function

' No fill: the inner rect is the panel color, leaving a 2px outline.
function PerkChipColor() as string
    return BookPanelColor()
end function

function PerkOutlineColor() as string
    return "0x3A4A66FF"
end function

function PerkTextColor() as string
    return "0xC9D1E0FF"
end function

' "Outdoor adventures" wraps in a 200px chip (Pixel b28), so it reads "Outdoors".
function PerkLabel(label as string) as string
    if LCase(label) = "outdoor adventures" then return "Outdoors"
    return label
end function

function BookHeading(text as string) as string
    out = FlushText(text)
    while Len(out) > 0 and Right(out, 1) = "!"
        out = Left(out, Len(out) - 1)
    end while
    if out = "" then return "Book direct and save"
    return out
end function

function RectOnScreen(rect as object) as boolean
    if rect = invalid then return false
    if rect.x < 0 or rect.y < 0 then return false
    if rect.w < 1 or rect.h < 1 then return false
    if rect.x + rect.w > 1920 then return false
    if rect.y + rect.h > 1080 then return false
    return true
end function

function ScreenRectText(rect as object) as string
    if rect = invalid then return "0,0 0x0"
    return rect.x.ToStr() + "," + rect.y.ToStr() + " " + rect.w.ToStr() + "x" + rect.h.ToStr()
end function

function RectsClear(a as object, b as object, gap as integer) as boolean
    if a = invalid or b = invalid then return false
    if a.x >= b.x + b.w + gap then return true
    if b.x >= a.x + a.w + gap then return true
    if a.y >= b.y + b.h + gap then return true
    if b.y >= a.y + a.h + gap then return true
    return false
end function

' Scan me card, poster, label, and domain. All of it sits inside the card
' and inside 1920x1080.
function BookQrSlot() as object
    photo = BookPhotoRect()
    cardX = photo.x + photo.w + BookColGap()
    cardY = photo.y
    cardW = BookInnerX() + BookInnerW() - cardX
    cardH = photo.h
    qrW = 240
    qrH = 240
    return {
        cardX: cardX,
        cardY: cardY,
        cardW: cardW,
        cardH: cardH,
        qrX: cardX + ((cardW - qrW) \ 2),
        qrY: cardY + ((cardH - qrH) \ 2),
        qrW: qrW,
        qrH: qrH,
        labelX: cardX,
        labelY: cardY + 4,
        labelW: cardW,
        labelH: 40,
        domainX: cardX,
        domainY: cardY + cardH - 48,
        domainW: cardW,
        domainH: 40
    }
end function

' True when the poster is centered in the Scan me card. Even sizes leave equal gaps.
function BookQrCentered(slot as object) as boolean
    if slot = invalid then return false
    leftGap = slot.qrX - slot.cardX
    rightGap = slot.cardX + slot.cardW - slot.qrX - slot.qrW
    if leftGap <> rightGap then return false
    topGap = slot.qrY - slot.cardY
    bottomGap = slot.cardY + slot.cardH - slot.qrY - slot.qrH
    if topGap <> bottomGap then return false
    if leftGap < 1 or topGap < 1 then return false
    return true
end function

function BookQrFits(slot as object) as boolean
    if slot = invalid then return false
    if slot.cardX < 0 or slot.cardY < 0 then return false
    if slot.cardX + slot.cardW > 1920 or slot.cardY + slot.cardH > 1080 then return false
    if InsideSlot(slot.qrX, slot.qrY, slot.qrW, slot.qrH, slot) <> true then return false
    if InsideSlot(slot.labelX, slot.labelY, slot.labelW, slot.labelH, slot) <> true then return false
    if InsideSlot(slot.domainX, slot.domainY, slot.domainW, slot.domainH, slot) <> true then return false
    return true
end function

function InsideSlot(x as integer, y as integer, width as integer, height as integer, slot as object) as boolean
    if x < slot.cardX or y < slot.cardY then return false
    if x + width > slot.cardX + slot.cardW then return false
    if y + height > slot.cardY + slot.cardH then return false
    return true
end function

function DetailQrUrl(item as object) as string
    qr = WithQrVersion(ItemText(item, "qrUrl"))
    if not PosterKindOk(qr) then qr = WithQrVersion(ItemText(item, "qrUri"))
    if not PosterKindOk(qr) then return ""
    return qr
end function

function PosterForSlot(slot as string) as object
    if slot = "badge" then return LivePoster("badgeQr", m.badgePoster)
    if slot = "book" then return LivePoster("bookQr", m.bookQr)
    if slot = "detail" then return LivePoster("detailQr", m.detailQr)
    if slot = "wifi" then return LivePoster("wifiQr", m.wifiPoster)
    return invalid
end function

function LivePoster(id as string, fallback as object) as object
    node = invalid
    if m.top <> invalid then node = m.top.findNode(id)
    if node <> invalid then return node
    return fallback
end function

sub RememberPoster(slot as string, node as object)
    if node = invalid then return
    if slot = "badge" then m.badgePoster = node
    if slot = "book" then m.bookQr = node
    if slot = "detail" then m.detailQr = node
    if slot = "wifi" then m.wifiPoster = node
end sub

function QrRetried(slot as string) as boolean
    if m.qrRetries = invalid then return false
    value = m.qrRetries.Lookup(slot)
    if value = invalid then return false
    return value = true
end function

sub MarkQrRetry(slot as string)
    if m.qrRetries = invalid then m.qrRetries = {}
    m.qrRetries[slot] = true
end sub

sub ClearQrRetry(slot as string)
    if m.qrRetries = invalid then m.qrRetries = {}
    m.qrRetries[slot] = false
end sub

function AssignedQrPath(slot as string) as string
    if m.qrAssigned = invalid then return ""
    value = m.qrAssigned.Lookup(slot)
    if value = invalid then return ""
    return value
end function

sub NoteAssigned(slot as string, path as string)
    if m.qrAssigned = invalid then m.qrAssigned = {}
    m.qrAssigned[slot] = path
end sub

sub ClearQrAssign(slot as string)
    ClearQrRetry(slot)
    NoteAssigned(slot, "")
end sub

function NotedQrBytes(slot as string) as integer
    if m.qrBytes = invalid then return 0
    value = m.qrBytes.Lookup(slot)
    if value = invalid then return 0
    return value
end function

sub NoteQrBytes(slot as string, bytes as integer)
    if m.qrBytes = invalid then m.qrBytes = {}
    m.qrBytes[slot] = bytes
end sub

sub ReassignStoredQrs()
    ApplyStoredQr("badge")
    ApplyStoredQr("book")
    ApplyStoredQr("detail")
end sub

function StoredQrPath(slot as string) as string
    if m.qrPaths = invalid then return ""
    value = m.qrPaths.Lookup(slot)
    if value = invalid then return ""
    return value
end function

sub ClearStoredQr(slot as string)
    if m.qrPaths = invalid then m.qrPaths = {}
    m.qrPaths[slot] = ""
end sub

sub EnsureQrSlot(slot as string, url as string)
    if url = invalid then url = ""
    if url <> QrRemote(slot)
        RememberQrRemote(slot, url)
        if slot = "badge"
            m.badgeFile = ""
            m.badgeReady = false
            m.badgeFailed = false
            if m.badgeMissing <> invalid then m.badgeMissing.text = ""
        end if
        if slot = "book"
            m.bookQrTried = false
            m.bookFile = ""
            if m.bookQrMissing <> invalid then m.bookQrMissing.text = ""
        end if
        if slot = "detail"
            m.detailQrFailed = false
            m.detailFile = ""
            if m.detailQrMissing <> invalid then m.detailQrMissing.text = ""
        end if
        ClearStoredQr(slot)
        ClearQrAssign(slot)
        if url <> "" then StartQrFetch(slot)
    end if
    ShowQrFrame(slot, url <> "")
    ApplyStoredQr(slot)
    if slot = "detail" then RevealDetailQr()
end sub

function QrRemote(slot as string) as string
    if slot = "badge"
        if m.badgeRemote = invalid then return ""
        return m.badgeRemote
    end if
    if slot = "book"
        if m.bookQrUri = invalid then return ""
        return m.bookQrUri
    end if
    if slot = "detail"
        if m.detailQrUri = invalid then return ""
        return m.detailQrUri
    end if
    return ""
end function

sub RememberQrRemote(slot as string, url as string)
    if slot = "badge"
        m.badgeRemote = url
        m.badgeUri = url
    end if
    if slot = "book" then m.bookQrUri = url
    if slot = "detail" then m.detailQrUri = url
end sub

sub ShowQrFrame(slot as string, show as boolean)
    if slot = "badge" then ShowBadgeFrame(show)
    if slot = "book" then ShowBookQr(show)
    if slot = "detail" then ShowDetailQr(show)
end sub

sub ShowQrMark(slot as string, show as boolean)
    mark = QrMarkForSlot(slot)
    if mark = invalid then return
    if show
        poster = PosterForSlot(slot)
        if poster <> invalid
            if poster.loadStatus = "ready" then show = false
        end if
    end if
    mark.visible = show
end sub

function QrMarkForSlot(slot as string) as object
    if slot = "badge" then return m.badgeMark
    if slot = "book" then return m.bookQrMark
    if slot = "detail" then return m.detailQrMark
    return invalid
end function

sub NoteQrLoaded(slot as string)
    poster = PosterForSlot(slot)
    if poster = invalid then return
    LogQrState(slot, poster)
    if poster.loadStatus <> "ready" then return
    if slot = "badge" then m.badgeReady = true
    poster.visible = true
    mark = QrMarkForSlot(slot)
    if mark <> invalid then mark.visible = false
end sub

sub RaiseBadge()
    if m.badgeGroup = invalid or m.shell = invalid then return
    m.shell.removeChild(m.badgeGroup)
    m.shell.appendChild(m.badgeGroup)
end sub

sub ApplyStoredQr(slot as string)
    path = StoredQrPath(slot)
    if path = "" then return
    ShowQrFrame(slot, true)
    AssignQrPoster(slot, path)
    if slot = "detail" then RevealDetailQr()
end sub

sub AssignQrPoster(slot as string, uri as string)
    if uri = invalid or uri = "" then return
    if m.qrPaths = invalid then m.qrPaths = {}
    m.qrPaths[slot] = uri
    if slot = "badge" then m.badgeFile = uri
    if slot = "book" then m.bookFile = uri
    if slot = "detail" then m.detailFile = uri
    poster = PosterForSlot(slot)
    nodeId = "none"
    found = "false"
    if poster <> invalid
        found = "true"
        if poster.id <> invalid and poster.id <> "" then nodeId = poster.id
    end if
    print "Eaglewood: qr "; slot; " deliver uri="; uri; " node="; nodeId; " found="; found
    if poster = invalid then return
    MountQrPoster(poster, uri, slot)
end sub

sub LogQrState(name as string, poster as object)
    status = "none"
    shown = "none"
    if poster <> invalid
        if poster.loadStatus <> invalid and poster.loadStatus <> "" then status = poster.loadStatus
        if poster.uri <> invalid and poster.uri <> "" then shown = SafeUri(poster.uri)
    end if
    print "Eaglewood: qr "; name; " uri="; shown; " status="; status; " rect="; QrRectText(poster)
end sub

function QrRectText(poster as object) as string
    if poster = invalid then return "0,0 0x0"
    bounds = poster.boundingRect()
    if bounds = invalid or bounds.width = invalid or bounds.height = invalid then return "0,0 0x0"
    x = 0
    y = 0
    if bounds.x <> invalid then x = bounds.x
    if bounds.y <> invalid then y = bounds.y
    return x.ToStr() + "," + y.ToStr() + " " + bounds.width.ToStr() + "x" + bounds.height.ToStr()
end function

sub LogQrScreen()
    if m.section = "wifi"
        print "Eaglewood: wifi response code="; m.wifiJsonCode
        print "Eaglewood: wifi png response code="; m.wifiPngCode
        print "Eaglewood: wifi png format bitdepth="; m.wifiPngBit; " colortype="; m.wifiPngColor; " interlace="; m.wifiPngInterlace; " indexed="; m.wifiIndexed
        LogQrState("wifi", m.wifiPoster)
    else if m.section = "book"
        LogQrState("book", PosterForSlot("book"))
        LogQrFormat("book")
    else if ActivitySection(m.section) and m.zone = "item"
        LogQrState("detail", PosterForSlot("detail"))
        LogQrFormat("detail")
    end if
    if m.section <> "book"
        LogQrState("badge", PosterForSlot("badge"))
        LogQrFormat("badge")
    end if
    LogCaptionLayout()
end sub

sub LogCaptionLayout()
    checkout = "0,0 0x0"
    if m.tiles <> invalid
        last = m.tiles.Count() - 1
        if last >= 0
            for index = 0 to last
                tile = m.tiles[index]
                if tile.section = "checkout" then checkout = QrRectText(tile.group)
            end for
        end if
    end if
    print "Eaglewood: caption badge rect="; QrRectText(m.badgeDomain); " book rect="; QrRectText(m.bookDomain); " checkout rect="; checkout
end sub

sub LogQrFormat(slot as string)
    text = ""
    if m.qrFormats <> invalid then text = AsText(m.qrFormats.Lookup(slot))
    if text <> "" then print "Eaglewood: qr "; slot; " format "; text
end sub

sub PlaceRouterScrim(count as integer)
    if m.wifiRouterScrim = invalid or m.wifiRouter = invalid then return
    if count < 1
        m.wifiRouterScrim.visible = false
        return
    end if
    at = m.wifiRouter.translation
    m.wifiRouterScrim.translation = [at[0] - 24, at[1] - 24]
    m.wifiRouterScrim.width = m.wifiRouter.width + 48
    m.wifiRouterScrim.height = (count * WifiPitch(WifiBodySize())) + 48
    m.wifiRouterScrim.visible = true
end sub

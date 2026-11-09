' Unconfigured HostKit screens: 3 intro / marketing pages, then pairing
' (6-character code, short URL, QR). Configured mode stays in MainScene.

function HostKitIntroPages() as object
    return [
        {
            title: "HostKit",
            body: "A guest guide on the TV in your short-term rental. House rules, things to do, Wi-Fi, and checkout — ready when guests walk in.",
            hint: "Press OK to continue"
        },
        {
            title: "Set up once",
            body: "Pair this TV with a short code. Guests see your place, not a generic app. You can update the guide any time from the web.",
            hint: "Press OK to continue"
        },
        {
            title: "Ready to pair",
            body: "Open the link on your phone, or scan the QR on the next screen. The code is already filled in.",
            hint: "Press OK to get your code"
        }
    ]
end function

sub HostKitEnsureUi()
    if m.hostKitRoot <> invalid then return
    root = CreateObject("roSGNode", "Group")
    root.id = "hostKitRoot"
    root.visible = false
    m.top.appendChild(root)
    m.hostKitRoot = root

    ' Navy scrim behind the left column so gold and cream text stay >= 4.5:1
    ' on Bachelor dusk. Ends before the QR so the mark is unchanged.
    scrim = CreateObject("roSGNode", "Rectangle")
    scrim.id = "hostKitScrim"
    scrim.translation = [96, 80]
    scrim.width = 1148
    scrim.height = 920
    scrim.color = "0x1A2336CC"
    root.appendChild(scrim)
    m.hostKitScrim = scrim

    intro = CreateObject("roSGNode", "Group")
    intro.id = "hostKitIntro"
    intro.visible = false
    root.appendChild(intro)
    m.hostKitIntro = intro

    m.hostKitTitle = HostKitAddLabel(intro, [192, 200], 1000, 110, "font:LargeBoldSystemFont", "0xFFFFFFFF", "")
    m.hostKitBody = HostKitAddLabel(intro, [192, 360], 1000, 280, "font:LargeSystemFont", "0xF4EFE3FF", "")
    m.hostKitBody.wrap = true
    m.hostKitBody.maxLines = 5
    HostKitSetLabelSize(m.hostKitBody, 42)
    m.hostKitHint = HostKitAddLabel(intro, [192, 900], 1000, 50, "font:SmallSystemFont", "0xF4EFE3FF", "")
    HostKitSetLabelSize(m.hostKitHint, 28)
    m.hostKitDotNodes = []
    dotIndex = 0
    while dotIndex < 3
        dot = CreateObject("roSGNode", "Rectangle")
        dot.width = 25
        dot.height = 25
        dot.translation = [192 + dotIndex * 47, 820]
        dot.color = "0xF2A93BFF"
        intro.appendChild(dot)
        m.hostKitDotNodes.Push(dot)
        dotIndex = dotIndex + 1
    end while

    pair = CreateObject("roSGNode", "Group")
    pair.id = "hostKitPair"
    pair.visible = false
    root.appendChild(pair)
    m.hostKitPair = pair

    m.hostKitPairKicker = HostKitAddLabel(pair, [192, 120], 1000, 50, "font:SmallSystemFont", "0xF2A93BFF", "Connect this TV")
    HostKitSetLabelSize(m.hostKitPairKicker, 28)
    m.hostKitPairTitle = HostKitAddLabel(pair, [192, 168], 1000, 80, "font:LargeBoldSystemFont", "0xFFFFFFFF", "Enter this code on the web")
    m.hostKitCodeChars = []
    cellW = 64
    groupGap = 60
    charIndex = 0
    while charIndex < 6
        charX = 192 + charIndex * cellW
        if charIndex >= 3 then charX = charX + groupGap
        ch = HostKitAddLabel(pair, [charX, 250], cellW, 130, "font:LargeBoldSystemFont", "0xF2A93BFF", "—")
        ch.horizAlign = "center"
        ch.vertAlign = "center"
        HostKitSetMonoSize(ch, 96)
        m.hostKitCodeChars.Push(ch)
        charIndex = charIndex + 1
    end while
    m.hostKitUrlLabel = HostKitAddLabel(pair, [192, 410], 1000, 40, "font:SmallSystemFont", "0xF4EFE3FF", "Or open this link")
    HostKitSetLabelSize(m.hostKitUrlLabel, 28)
    m.hostKitUrl = HostKitAddLabel(pair, [192, 452], 1000, 110, "font:MediumSystemFont", "0xFFFFFFFF", "")
    HostKitSetLabelSize(m.hostKitUrl, 42)
    m.hostKitUrl.wrap = true
    m.hostKitUrl.maxLines = 2
    m.hostKitStatus = HostKitAddLabel(pair, [192, 580], 1000, 90, "font:MediumSystemFont", "0xF4EFE3FF", "Getting a code…")
    HostKitSetLabelSize(m.hostKitStatus, 32)
    m.hostKitStatus.wrap = true
    m.hostKitStatus.maxLines = 2
    m.hostKitNote = HostKitAddLabel(pair, [192, 900], 1000, 50, "font:SmallSystemFont", "0xF4EFE3FF", "This code is valid for 15 minutes")
    HostKitSetLabelSize(m.hostKitNote, 26)

    frame = CreateObject("roSGNode", "Rectangle")
    frame.id = "hostKitQrFrame"
    frame.translation = [1270, 270]
    frame.width = 440
    frame.height = 440
    frame.color = "0x2A2622FF"
    frame.visible = false
    pair.appendChild(frame)
    m.hostKitQrFrame = frame

    ' 11px modules + 4-module quiet zone = 407px card, centered in the
    ' existing 420px plate so the QR is not restyled or shrunk.
    poster = CreateObject("roSGNode", "Poster")
    poster.id = "hostKitQr"
    poster.translation = [1286, 286]
    poster.width = 407
    poster.height = 407
    poster.loadDisplayMode = "scaleToFit"
    poster.uri = ""
    poster.visible = false
    pair.appendChild(poster)
    m.hostKitQr = poster

    m.hostKitQrLabel = HostKitAddLabel(pair, [1280, 230], 420, 40, "font:SmallSystemFont", "0xF4EFE3FF", "Scan to pair")
    m.hostKitQrLabel.horizAlign = "center"
    HostKitSetLabelSize(m.hostKitQrLabel, 28)
    m.hostKitQrLabel.visible = false
end sub

function HostKitAddLabel(parent as object, translation as object, width as integer, height as integer, font as string, color as string, text as string) as object
    label = CreateObject("roSGNode", "Label")
    label.translation = translation
    label.width = width
    label.height = height
    label.font = font
    label.color = color
    label.text = text
    label.horizAlign = "left"
    label.vertAlign = "top"
    parent.appendChild(label)
    return label
end function

sub HostKitHideSetup()
    if m.hostKitRoot <> invalid then m.hostKitRoot.visible = false
    if m.hostKitIntro <> invalid then m.hostKitIntro.visible = false
    if m.hostKitPair <> invalid then m.hostKitPair.visible = false
    HostKitStopPoll()
end sub

sub HostKitShowIntro(index as integer)
    HostKitEnsureUi()
    pages = HostKitIntroPages()
    last = pages.Count() - 1
    if index < 0 then index = 0
    if index > last then index = last
    m.hostKitIntroIndex = index
    m.hostKitMode = "intro"
    m.section = "intro-" + (index + 1).ToStr()
    m.zone = "hostkit"
    page = pages[index]
    m.hostKitTitle.text = page.title
    m.hostKitBody.text = page.body
    m.hostKitHint.text = page.hint
    HostKitPaintDots(index, pages.Count())
    m.hostKitRoot.visible = true
    m.hostKitIntro.visible = true
    m.hostKitPair.visible = false
    if m.greeting <> invalid then m.greeting.visible = false
    print "HostKit: screen="; m.section
    HoldFocus()
end sub

sub HostKitPaintDots(index as integer, count as integer)
    nodes = m.hostKitDotNodes
    if nodes = invalid then return
    i = 0
    while i < nodes.Count()
        node = nodes[i]
        if i < count
            node.visible = true
            if i = index
                node.color = "0xF2A93BFF"
            else
                node.color = "0xF2A93B66"
            end if
        else
            node.visible = false
        end if
        i = i + 1
    end while
end sub

sub HostKitShowPairing()
    HostKitEnsureUi()
    m.hostKitMode = "pairing"
    m.section = "pairing"
    m.zone = "hostkit"
    m.hostKitRoot.visible = true
    m.hostKitIntro.visible = false
    m.hostKitPair.visible = true
    if m.greeting <> invalid then m.greeting.visible = false
    HostKitPaintCode("")
    if m.hostKitUrl <> invalid then m.hostKitUrl.text = ""
    if m.hostKitQrLabel <> invalid then m.hostKitQrLabel.visible = false
    if m.hostKitStatus <> invalid then m.hostKitStatus.text = "Getting a code…"
    if m.hostKitQr <> invalid
        m.hostKitQr.uri = ""
        m.hostKitQr.visible = false
    end if
    if m.hostKitQrFrame <> invalid then m.hostKitQrFrame.visible = false
    m.hostKitRefreshed = false
    print "HostKit: screen=pairing"
    HoldFocus()
    startHostKitAction("start")
end sub

function HostKitFormatCode(code as string) as string
    ' Letter-spaced so the 6-character code stays readable from about 10 feet.
    if Len(code) <> 6 then return code
    out = ""
    i = 1
    while i <= 6
        if i > 1 then out = out + "  "
        if i = 4 then out = out + "  "
        out = out + Mid(code, i, 1)
        i = i + 1
    end while
    return out
end function

sub HostKitSetLabelSize(label as object, size as integer)
    if label = invalid then return
    font = CreateObject("roSGNode", "Font")
    if font = invalid then return
    current = label.font
    uri = "font:LargeBoldSystemFont"
    if current <> invalid
        kind = type(current)
        if kind = "String" or kind = "roString"
            if current <> "" then uri = current
        else if kind = "roSGNode" or kind = "SGNode"
            found = current.uri
            if found <> invalid and found <> "" then uri = found
        end if
    end if
    font.uri = uri
    font.size = size
    label.font = font
end sub

sub HostKitSetMonoSize(label as object, size as integer)
    if label = invalid then return
    font = CreateObject("roSGNode", "Font")
    if font = invalid then return
    font.uri = "pkg:/fonts/UbuntuMono-Regular.ttf"
    font.size = size
    label.font = font
end sub

sub HostKitPaintCode(code as string)
    chars = m.hostKitCodeChars
    if chars = invalid then return
    text = code
    if text = invalid then text = ""
    i = 0
    while i < chars.Count()
        glyph = "—"
        if Len(text) = 6 then glyph = Mid(text, i + 1, 1)
        chars[i].text = glyph
        i = i + 1
    end while
end sub

function HostKitRouteKey(key as string) as boolean
    HoldFocus()
    if m.hostKitMode = "intro"
        if key = "OK" or key = "right"
            pages = HostKitIntroPages()
            nextIndex = m.hostKitIntroIndex + 1
            if nextIndex >= pages.Count()
                HostKitShowPairing()
            else
                HostKitShowIntro(nextIndex)
            end if
            return true
        end if
        if key = "left" or key = "back"
            if m.hostKitIntroIndex <= 0
                if key = "back"
                    print "HostKit: back exit"
                    return false
                end if
                return true
            end if
            HostKitShowIntro(m.hostKitIntroIndex - 1)
            return true
        end if
        return true
    end if
    if m.hostKitMode = "pairing" or m.hostKitMode = "loading"
        if key = "back"
            HostKitStopPoll()
            HostKitShowIntro(HostKitIntroPages().Count() - 1)
            return true
        end if
        return true
    end if
    return true
end function

sub startHostKitAction(action as string)
    if m.hostKitTask <> invalid
        m.hostKitTask.unobserveField("result")
        m.hostKitTask.control = "STOP"
        m.hostKitTask = invalid
    end if
    if m.hostKitGeneration = invalid then m.hostKitGeneration = 0
    m.hostKitGeneration = m.hostKitGeneration + 1
    task = CreateObject("roSGNode", "HostKitTask")
    if task = invalid
        print "HostKit: task-create-failed"
        return
    end if
    task.action = action
    task.baseUrl = HostKitBaseUrl()
    task.deviceId = HostKitDeviceId()
    task.deviceToken = HostKitReadKey("deviceToken")
    task.etag = HostKitRememberedEtag()
    task.generation = m.hostKitGeneration
    task.observeField("result", "onHostKitTask")
    m.hostKitTask = task
    m.top.appendChild(task)
    task.control = "RUN"
end sub

sub onHostKitTask()
    task = m.hostKitTask
    if task = invalid then return
    result = task.result
    if result = invalid then return
    if result.generation <> invalid and result.generation <> m.hostKitGeneration then return
    action = result.action
    if action = "start"
        HostKitHandleStart(result)
    else if action = "status"
        HostKitHandleStatus(result)
    else if action = "config"
        HostKitHandleConfig(result)
    end if
end sub

sub HostKitHandleStart(result as object)
    if result.ok <> "yes"
        if m.hostKitStatus <> invalid then m.hostKitStatus.text = "Could not reach HostKit. Retrying…"
        waitSec = HostKitPollBackoff(HostKitCurrentPoll(), true)
        m.hostKitPollSeconds = waitSec
        HostKitArmPoll(waitSec)
        return
    end if
    m.hostKitPollSeconds = 5
    if result.pollAfterMs <> invalid and result.pollAfterMs > 0
        secs = Int(result.pollAfterMs / 1000)
        if secs >= 1 then m.hostKitPollSeconds = secs
    end if
    m.hostKitPairCode = result.code
    HostKitPaintCode(result.code)
    if m.hostKitUrl <> invalid then m.hostKitUrl.text = result.shortUrl
    status = "Waiting for the host to finish setup"
    if m.hostKitRefreshed = true then status = "This code expired. Use the new code or scan the QR again."
    if m.hostKitStatus <> invalid then m.hostKitStatus.text = status
    if result.qrPath <> invalid and result.qrPath <> ""
        if m.hostKitQr <> invalid
            m.hostKitQr.uri = result.qrPath
            m.hostKitQr.visible = true
        end if
        if m.hostKitQrFrame <> invalid then m.hostKitQrFrame.visible = true
        if m.hostKitQrLabel <> invalid then m.hostKitQrLabel.visible = true
    end if
    HostKitArmPoll(m.hostKitPollSeconds)
end sub

sub HostKitHandleStatus(result as object)
    if result.ok <> "yes"
        waitSec = HostKitPollBackoff(HostKitCurrentPoll(), true)
        m.hostKitPollSeconds = waitSec
        HostKitArmPoll(waitSec)
        return
    end if
    if result.status = "paired"
        HostKitStopPoll()
        token = result.deviceToken
        propertyId = result.propertyId
        if token = invalid or token = ""
            if m.hostKitStatus <> invalid then m.hostKitStatus.text = "Pairing failed. Getting a new code…"
            startHostKitAction("start")
            return
        end if
        HostKitSavePair(token, propertyId)
        print "HostKit: paired"
        m.hostKitMode = "loading"
        m.section = "loading"
        if m.hostKitStatus <> invalid then m.hostKitStatus.text = "Connected. Loading your guide…"
        startHostKitAction("config")
        return
    end if
    if result.status = "expired"
        m.hostKitRefreshed = true
        print "HostKit: code refreshed"
        startHostKitAction("start")
        return
    end if
    m.hostKitPollSeconds = HostKitPollBackoff(HostKitCurrentPoll(), false)
    HostKitArmPoll(m.hostKitPollSeconds)
end sub

sub HostKitHandleConfig(result as object)
    source = "none"
    cache = HostKitCachedConfig()
    cacheValid = false
    if cache <> invalid then cacheValid = true
    remoteOk = false
    reason = ""
    if result.reason <> invalid then reason = result.reason
    if result.ok = "yes" and reason <> "not-modified" and result.body <> invalid and result.body <> ""
        if HostKitWriteCacheText(result.body) = true
            if result.etag <> invalid and result.etag <> "" then HostKitRememberEtag(result.etag)
        end if
        remoteOk = true
    end if
    if result.ok = "yes" and reason = "not-modified"
        if result.etag <> invalid and result.etag <> "" then HostKitRememberEtag(result.etag)
    end if
    source = HostKitChooseSource(remoteOk, reason, cacheValid)
    ' not-modified still counts as a successful refresh from cache
    if reason = "not-modified" and cacheValid = true then source = "cachefs"
    if remoteOk = true then source = "network"
    print "HostKit: config source="; source
    if source <> "none" and m.hostKitMode = "configured"
        HostKitApplyCachedGuide()
    end if
    if reason = "unauthorized"
        print "HostKit: token revoked"
        HostKitClearPair()
        if m.hostKitMode = "configured"
            ' Stay on last-good guest screens if we already had them; next boot pairs again.
            return
        end if
        HostKitShowPairing()
        return
    end if
    if m.hostKitMode <> "configured"
        EnterConfiguredChannel()
    end if
end sub

function HostKitCurrentPoll() as integer
    if m.hostKitPollSeconds = invalid then return 5
    if m.hostKitPollSeconds < 1 then return 5
    return m.hostKitPollSeconds
end function

sub HostKitArmPoll(seconds as integer)
    if seconds < 1 then seconds = 5
    if m.hostKitPollTimer = invalid
        timer = CreateObject("roSGNode", "Timer")
        timer.id = "hostKitPollTimer"
        timer.repeat = false
        timer.observeField("fire", "onHostKitPoll")
        m.top.appendChild(timer)
        m.hostKitPollTimer = timer
    end if
    m.hostKitPollTimer.control = "stop"
    m.hostKitPollTimer.duration = seconds
    m.hostKitPollTimer.control = "start"
end sub

sub onHostKitPoll()
    if m.hostKitMode <> "pairing" then return
    startHostKitAction("status")
end sub

sub HostKitStopPoll()
    if m.hostKitPollTimer <> invalid
        m.hostKitPollTimer.control = "stop"
    end if
end sub

sub startHostKitConfigFetch()
    if HostKitHasDeviceToken() <> true then return
    startHostKitAction("config")
end sub

function HostKitApplyCachedGuide() as boolean
    cfg = HostKitCachedConfig()
    if cfg = invalid then return false
    docs = HostKitToLegacyDocuments(cfg)
    if docs = invalid then return false
    ' NormalizeGuide / NormalizeBookDirect / NormalizeActivities live on the
    ' scene. The GuideTask helpers that wrap them are not in this scope.
    guide = NormalizeGuide(docs.guide)
    if guide = invalid then return false
    guide.book = NormalizeBookDirect(docs.guide)
    guide.guideSource = "hostkit"
    guide.guideCode = "0"
    checkout = NormalizeCheckout(docs.checkout)
    if checkout = invalid then checkout = FallbackCheckout()
    checkout.checkoutSource = "hostkit"
    checkout.checkoutCode = "0"
    activities = NormalizeActivities(docs.activities)
    if activities = invalid
        activities = { activitiesVersion: 0, items: [] }
    end if
    activities.activitiesSource = "hostkit"
    activities.activitiesCode = "0"
    if guide.checkIn = "" then guide.checkIn = checkout.checkIn
    if guide.checkOut = "" then guide.checkOut = checkout.checkOut
    menuText = ""
    if docs.menu <> invalid then menuText = FormatJson(docs.menu)
    if menuText = invalid then menuText = ""
    book = guide.book
    if book = invalid then book = DefaultBookDirect()
    items = activities.items
    if items = invalid then items = []
    bundle = {
        brand: guide.brand,
        place: guide.place,
        domain: guide.domain,
        checkIn: guide.checkIn,
        checkOut: guide.checkOut,
        quietHours: guide.quietHours,
        hostName: guide.hostName,
        hostEmail: guide.hostEmail,
        hostPhone: guide.hostPhone,
        summary: checkout.summary,
        guideSource: "hostkit",
        guideCode: "0",
        guideVersion: VersionText(guide.guideVersion),
        checkoutSource: "hostkit",
        checkoutCode: "0",
        checkoutVersion: VersionText(checkout.checkoutVersion),
        rules: guide.rules,
        issues: guide.issues,
        checkoutSteps: checkout.checkoutSteps,
        activities: items,
        book: book,
        activitiesSource: "hostkit",
        activitiesCode: "0",
        activitiesVersion: VersionText(activities.activitiesVersion),
        menuSource: "hostkit",
        menuJson: menuText
    }
    ApplyBundle(bundle)
    print "Eaglewood: guide applied source=hostkit version="; m.guideVersion
    return true
end function


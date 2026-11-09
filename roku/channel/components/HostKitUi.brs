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

    intro = CreateObject("roSGNode", "Group")
    intro.id = "hostKitIntro"
    intro.visible = false
    root.appendChild(intro)
    m.hostKitIntro = intro

    m.hostKitTitle = HostKitAddLabel(intro, [160, 200], 1400, 110, "font:LargeBoldSystemFont", "0xFFFFFFFF", "")
    m.hostKitBody = HostKitAddLabel(intro, [160, 360], 1400, 280, "font:LargeSystemFont", "0xC9D1E0FF", "")
    m.hostKitBody.wrap = true
    m.hostKitBody.maxLines = 5
    m.hostKitHint = HostKitAddLabel(intro, [160, 900], 1400, 50, "font:SmallSystemFont", "0xD5DBE8FF", "")
    m.hostKitDots = HostKitAddLabel(intro, [160, 820], 800, 40, "font:SmallSystemFont", "0xE8C36AFF", "")

    pair = CreateObject("roSGNode", "Group")
    pair.id = "hostKitPair"
    pair.visible = false
    root.appendChild(pair)
    m.hostKitPair = pair

    m.hostKitPairKicker = HostKitAddLabel(pair, [160, 140], 1000, 50, "font:SmallSystemFont", "0xE8C36AFF", "Connect this TV")
    m.hostKitPairTitle = HostKitAddLabel(pair, [160, 200], 1000, 90, "font:LargeBoldSystemFont", "0xFFFFFFFF", "Enter this code on the web")
    m.hostKitCode = HostKitAddLabel(pair, [160, 340], 1000, 140, "font:LargeBoldSystemFont", "0xE8C36AFF", "——— ———")
    m.hostKitUrl = HostKitAddLabel(pair, [160, 520], 1000, 80, "font:MediumSystemFont", "0xFFFFFFFF", "")
    m.hostKitUrl.wrap = true
    m.hostKitUrl.maxLines = 2
    m.hostKitStatus = HostKitAddLabel(pair, [160, 640], 1000, 80, "font:MediumSystemFont", "0xC9D1E0FF", "Getting a code…")
    m.hostKitStatus.wrap = true
    m.hostKitStatus.maxLines = 2
    m.hostKitNote = HostKitAddLabel(pair, [160, 900], 1000, 50, "font:SmallSystemFont", "0xD5DBE8FF", "This code is valid for 15 minutes")

    poster = CreateObject("roSGNode", "Poster")
    poster.id = "hostKitQr"
    poster.translation = [1280, 280]
    poster.width = 420
    poster.height = 420
    poster.loadDisplayMode = "scaleToFit"
    poster.uri = ""
    poster.visible = false
    pair.appendChild(poster)
    m.hostKitQr = poster

    frame = CreateObject("roSGNode", "Rectangle")
    frame.id = "hostKitQrFrame"
    frame.translation = [1270, 270]
    frame.width = 440
    frame.height = 440
    frame.color = "0x2A2622FF"
    frame.visible = false
    pair.insertChild(frame, 0)
    m.hostKitQrFrame = frame
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
    m.hostKitDots.text = HostKitDotsText(index, pages.Count())
    m.hostKitRoot.visible = true
    m.hostKitIntro.visible = true
    m.hostKitPair.visible = false
    if m.greeting <> invalid then m.greeting.visible = false
    print "HostKit: screen="; m.section
    HoldFocus()
end sub

function HostKitDotsText(index as integer, count as integer) as string
    out = ""
    i = 0
    while i < count
        if i = index
            out = out + "●  "
        else
            out = out + "○  "
        end if
        i = i + 1
    end while
    return out
end function

sub HostKitShowPairing()
    HostKitEnsureUi()
    m.hostKitMode = "pairing"
    m.section = "pairing"
    m.zone = "hostkit"
    m.hostKitRoot.visible = true
    m.hostKitIntro.visible = false
    m.hostKitPair.visible = true
    if m.greeting <> invalid then m.greeting.visible = false
    if m.hostKitCode <> invalid then m.hostKitCode.text = "——— ———"
    if m.hostKitUrl <> invalid then m.hostKitUrl.text = ""
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
    if Len(code) <> 6 then return code
    return Left(code, 3) + "  " + Right(code, 3)
end function

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
    if m.hostKitCode <> invalid then m.hostKitCode.text = HostKitFormatCode(result.code)
    if m.hostKitUrl <> invalid then m.hostKitUrl.text = result.shortUrl
    status = "Waiting for the host to finish setup"
    if m.hostKitRefreshed = true then status = "Code refreshed"
    if m.hostKitStatus <> invalid then m.hostKitStatus.text = status
    if result.qrPath <> invalid and result.qrPath <> ""
        if m.hostKitQr <> invalid
            m.hostKitQr.uri = result.qrPath
            m.hostKitQr.visible = true
        end if
        if m.hostKitQrFrame <> invalid then m.hostKitQrFrame.visible = true
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

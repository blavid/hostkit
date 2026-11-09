sub init()
    print "Eaglewood: build 43 "; BuildCommit()
    m.top.id = "scene"
    m.greeting = m.top.findNode("greeting")
    m.backing = m.top.findNode("greetingBacking")
    m.idleTimer = m.top.findNode("idleTimer")
    m.refreshTimer = m.top.findNode("refreshTimer")
    m.heartbeatTimer = m.top.findNode("heartbeatTimer")
    m.guestTask = invalid
    m.guideTask = invalid
    m.wifiTask = invalid
    m.qrTask = invalid
    m.fetchGeneration = 0
    m.guideGeneration = 0
    m.wifiGeneration = 0
    m.qrGeneration = 0
    m.qrCleanupDone = false
    m.qrAssigning = false
    m.qrJobs = {}
    m.qrTasks = {}
    m.qrPaths = {}
    m.qrRetries = {}
    m.qrBytes = {}
    m.qrFormats = {}
    m.qrPending = {}
    m.wifiFile = ""
    m.shell = invalid
    home = HomePromptState()
    m.zone = home.zone
    m.section = home.section
    m.menuDepth = home.depth
    m.railIndex = home.index
    m.cardIndex = 0
    m.activities = []
    m.activitiesToken = 0
    m.fixIssues = []
    m.book = invalid
    m.wifiSsid = ""
    m.wifiPassword = ""
    m.wifiPng = "no"
    m.wifiNotice = ""
    m.wifiSource = "builtin"
    m.tileIndex = 0
    m.issueIndex = 0
    m.stepScroll = 0
    m.ruleScroll = 0
    m.checkoutScroll = 0
    m.guestCheckout = ""
    m.guestCheckoutPresent = "no"
    m.guestStay = "missing"
    m.brand = "Eaglewood"
    m.place = "Sunriver, Oregon"
    m.domain = "sunrivertownhome.com"
    m.checkIn = "4:00 PM"
    m.checkOut = "11:00 AM"
    m.quietHours = "Quiet hours after 10:00 PM"
    m.hostName = ""
    m.hostEmail = ""
    m.hostPhone = ""
    m.summary = ""
    m.guideSource = "builtin"
    m.guideCode = "0"
    m.guideVersion = "0"
    m.checkoutSource = "builtin"
    m.checkoutCode = "0"
    m.checkoutVersion = "0"
    m.rules = []
    m.issues = []
    m.checkoutSteps = []
    m.hostKitMode = "boot"
    m.hostKitIntroIndex = 0
    m.hostKitGeneration = 0
    m.hostKitPollSeconds = 5
    m.top.backgroundColor = "0x100E0CFF"
    m.top.setFocus(true)
    m.top.observeField("relaunchCount", "onRelaunch")
    ' Readable text before any layout. A layout failure must not leave this blank.
    ApplyPlainGreeting(FallbackGreeting())
    ShowGreeting(FallbackGreeting())
    if m.idleTimer <> invalid then m.idleTimer.observeField("fire", "onIdle")
    if m.refreshTimer <> invalid then m.refreshTimer.observeField("fire", "onRefresh")
    if m.heartbeatTimer <> invalid
        m.heartbeatTimer.observeField("fire", "onHeartbeat")
        m.heartbeatTimer.control = "start"
    end if
    HostKitPrepareCacheDir()
    HostKitMaybeSeedFromEmu()
    if HostKitHasDeviceToken()
        EnterConfiguredChannel()
        startHostKitConfigFetch()
    else
        StartUnconfiguredChannel()
    end if
    printUiResolution()
end sub

sub StartUnconfiguredChannel()
    if m.greeting <> invalid then m.greeting.visible = false
    HostKitShowIntro(0)
    BumpIdle()
    HoldFocus()
end sub

sub EnterConfiguredChannel()
    HostKitHideSetup()
    m.hostKitMode = "configured"
    if m.greeting <> invalid then m.greeting.visible = true
    try
        if m.shell = invalid
            BuildShell()
        end if
        if HostKitApplyCachedGuide() <> true
            ApplyBundle(BuiltinBundle())
        end if
        ShowSection("home")
        print "Eaglewood: screen=home zone="; m.zone
    catch err
        print "Eaglewood: layout error = "; LayoutErrorText(err)
    end try
    BumpIdle()
    HoldFocus()
    startGuestFetch()
    if HostKitHasDeviceToken() <> true then startGuideFetch()
    startWifiFetch()
    StartRefresh()
end sub

sub onRelaunch()
    print "Eaglewood: relaunch"
    if m.hostKitMode <> "configured" then return
    m.guestStay = "missing"
    m.guestCheckout = ""
    m.guestCheckoutPresent = "no"
    ShowGreeting(FallbackGreeting())
    home = HomePromptState()
    m.zone = home.zone
    m.section = home.section
    m.menuDepth = home.depth
    m.railIndex = home.index
    m.tileIndex = 0
    m.cardIndex = 0
    m.issueIndex = 0
    m.stepScroll = 0
    ShowSection("home")
    print "Eaglewood: screen=home zone="; m.zone
    PaintAll()
    HoldFocus()
    BumpIdle()
    startGuestFetch()
    if HostKitHasDeviceToken() <> true then startGuideFetch()
    startWifiFetch()
    StartRefresh()
    startHostKitConfigFetch()
end sub

sub startGuestFetch()
    if m.guestTask <> invalid
        m.guestTask.unobserveField("result")
        m.guestTask.control = "STOP"
        m.guestTask = invalid
    end if
    m.fetchGeneration = m.fetchGeneration + 1
    print "Eaglewood: task created generation="; m.fetchGeneration
    task = CreateObject("roSGNode", "GuestTask")
    if task = invalid
        print "Eaglewood: skip reason=task-create-failed"
        return
    end if
    task.functionName = "fetchGuest"
    task.generation = m.fetchGeneration
    task.observeField("result", "onGuestFetch")
    m.guestTask = task
    task.control = "RUN"
    print "Eaglewood: task started generation="; m.fetchGeneration
end sub

sub startGuideFetch()
    if HostKitHasDeviceToken() = true
        print "Eaglewood: guide skip reason=hostkit"
        HostKitApplyCachedGuide()
        return
    end if
    if m.guideTask <> invalid
        m.guideTask.unobserveField("result")
        m.guideTask.control = "STOP"
        m.guideTask = invalid
    end if
    m.guideGeneration = m.guideGeneration + 1
    print "Eaglewood: guide task created generation="; m.guideGeneration
    task = CreateObject("roSGNode", "GuideTask")
    if task = invalid
        print "Eaglewood: guide skip reason=task-create-failed"
        return
    end if
    task.functionName = "fetchGuideBundle"
    task.generation = m.guideGeneration
    task.observeField("result", "onGuideFetch")
    m.guideTask = task
    task.control = "RUN"
    print "Eaglewood: guide task started generation="; m.guideGeneration
end sub

sub onGuestFetch()
    task = m.guestTask
    if task = invalid
        print "Eaglewood: skip reason=no-task"
        return
    end if
    result = task.result
    if result = invalid
        print "Eaglewood: skip reason=no-result"
        return
    end if
    if not GenerationMatches(result)
        print "Eaglewood: skip reason=generation"
        return
    end if
    seen = result.generationText
    if seen = invalid or seen = "" or seen = "0"
        print "Eaglewood: generation missing; applying current result"
    end if
    reason = "no"
    if result.reason <> invalid and result.reason <> "" then reason = result.reason
    ok = "no"
    if result.ok <> invalid then ok = result.ok
    print "Eaglewood: fetch result ok="; ok; " reason="; reason
    if ok <> "yes"
        print "Eaglewood: skip reason="; reason
        m.guestStay = "missing"
        m.guestCheckout = ""
        m.guestCheckoutPresent = "no"
        RefreshHomeLine()
        ShowGreeting(FallbackGreeting())
        return
    end if
    present = false
    if result.checkoutPresent = "yes" then present = true
    decision = CheckoutDecision(result.checkout, present, NowSeconds())
    print "Eaglewood: checkout decision="; decision
    m.guestStay = decision
    m.guestCheckout = AsText(result.checkout)
    m.guestCheckoutPresent = "no"
    if result.checkoutPresent <> invalid then m.guestCheckoutPresent = result.checkoutPresent
    RefreshHomeLine()
    text = GreetingFromGuest(result.firstName, result.lastName, result.checkout, present)
    ShowGreeting(text)
end sub

sub onGuideFetch()
    task = m.guideTask
    if task = invalid
        print "Eaglewood: guide skip reason=no-task"
        return
    end if
    result = task.result
    if result = invalid
        print "Eaglewood: guide skip reason=no-result"
        return
    end if
    if not GuideGenerationMatches(result)
        print "Eaglewood: guide skip reason=generation"
        return
    end if
    try
        ApplyBundle(BundleFromResult(result))
    catch err
        print "Eaglewood: layout error = "; LayoutErrorText(err)
        HoldFocus()
        return
    end try
    rules = 0
    issues = 0
    steps = 0
    if m.rules <> invalid then rules = m.rules.Count()
    if m.issues <> invalid then issues = m.issues.Count()
    if m.checkoutSteps <> invalid then steps = m.checkoutSteps.Count()
    print "Eaglewood: guide applied source="; m.guideSource; " version="; m.guideVersion; " rules="; rules; " issues="; issues
    present = "no"
    if result.hostPhonePresent <> invalid and result.hostPhonePresent <> "" then present = result.hostPhonePresent
    print "Eaglewood: host phone present="; present
    print "Eaglewood: checkout applied source="; m.checkoutSource; " version="; m.checkoutVersion; " steps="; steps
    count = 0
    if m.activities <> invalid then count = m.activities.Count()
    print "Eaglewood: activities applied source="; m.activitiesSource; " version="; m.activitiesVersion; " count="; count
    HoldFocus()
end sub

' The observer is only attached to the current task. A result whose generation
' is still 0 was published before that field was visible; apply it.
function GenerationMatches(result as object) as boolean
    want = m.fetchGeneration.ToStr()
    text = result.generationText
    number = result.generation
    if text <> invalid
        if text = want then return true
    end if
    if number <> invalid
        if number.ToStr() = want then return true
    end if
    blank = false
    if text = invalid or text = "" or text = "0" then blank = true
    if blank
        if number = invalid or number = 0 then return true
    end if
    return false
end function

function GuideGenerationMatches(result as object) as boolean
    want = m.guideGeneration.ToStr()
    text = result.generationText
    number = result.generation
    if text <> invalid
        if text = want then return true
    end if
    if number <> invalid
        if number.ToStr() = want then return true
    end if
    blank = false
    if text = invalid or text = "" or text = "0" then blank = true
    if blank
        if number = invalid or number = 0 then return true
    end if
    return false
end function

sub ShowGreeting(text as string)
    if text = invalid or text = "" then text = FallbackGreeting()
    ApplyPlainGreeting(text)
    try
        ApplyGreetingLayout(text)
    catch err
        print "Eaglewood: layout error = "; LayoutErrorText(err)
    end try
    print "Eaglewood: greeting = "; text
end sub

' Built-in names only, on the Label font field. The label wraps; this does not
' measure glyphs. Text is assigned before ApplyGreetingLayout runs.
sub ApplyPlainGreeting(text as string)
    if m.backing <> invalid then m.backing.visible = false
    if m.greeting = invalid then return
    m.greeting.font = "font:LargeBoldSystemFont"
    m.greeting.color = "0xFFFFFFFF"
    m.greeting.width = GreetingLabelWidth()
    m.greeting.wrap = true
    m.greeting.maxLines = 2
    m.greeting.horizAlign = "left"
    m.greeting.vertAlign = "center"
    m.greeting.height = 64
    m.greeting.translation = [ContentLeft(), ContentTop()]
    m.greeting.text = text
end sub

sub ApplyGreetingLayout(text as string)
    if m.backing <> invalid then m.backing.visible = false
    if m.greeting = invalid then return
    m.greeting.font = GreetingFace(text)
end sub

function GreetingFontNames() as object
    return ["font:LargeBoldSystemFont", "font:MediumBoldSystemFont", "font:SmallBoldSystemFont", "font:SmallestBoldSystemFont"]
end function

function GreetingFace(text as string) as string
    names = GreetingFontNames()
    sizes = GreetingFontSizes()
    chosen = 0
    if names.Count() < 1 then return "font:LargeBoldSystemFont"
    chosen = names.Count() - 1
    limit = GreetingLabelWidth()
    if text = invalid then text = ""
    last = sizes.Count() - 1
    if last < 0 then return names[0]
    for index = 0 to last
        pixels = Len(text) * FallbackCharWidth(sizes[index])
        if pixels <= limit
            chosen = index
            exit for
        end if
    end for
    if chosen >= names.Count() then chosen = names.Count() - 1
    if chosen < 0 then chosen = 0
    return names[chosen]
end function

function CaughtText(value as object) as string
    kind = type(value)
    if kind = "String" or kind = "roString" then return value
    if kind = "Integer" or kind = "roInt" or kind = "LongInteger" or kind = "roLongInteger" then return value.ToStr()
    return "?"
end function

' Build 37: every catch handler logs through here with the fixed marker
' EAGLEWOOD-CAUGHT and the failing file:line, so the test suite can fail on
' any swallowed error.
function LayoutErrorText(err as object) as string
    text = "layout failed"
    where = ""
    kind = type(err)
    if kind = "String" or kind = "roString"
        text = err
    else if kind = "roAssociativeArray"
        message = err.Lookup("message")
        if type(message) = "String" or type(message) = "roString"
            if message <> "" then text = message
        end if
        trace = err.Lookup("backtrace")
        if type(trace) = "roArray" and trace.Count() > 0
            top = trace[trace.Count() - 1]
            if type(top) = "roAssociativeArray"
                where = " at " + CaughtText(top.Lookup("filename")) + ":" + CaughtText(top.Lookup("line_number"))
            end if
        end if
    end if
    print "Eaglewood: EAGLEWOOD-CAUGHT "; text; where
    return text + where
end function

function FocusedNodeId() as string
    if m.top = invalid then return "none"
    if m.top.hasFocus() = true
        if m.top.id <> invalid and m.top.id <> "" then return m.top.id
        return "scene"
    end if
    return "none"
end function

sub onHeartbeat()
    if m.heartbeatTimer = invalid then return
    if m.heartbeatTimer.fire <> true then return
    print "Eaglewood: heartbeat"
end sub

sub printUiResolution()
    deviceInfo = CreateObject("roDeviceInfo")
    if deviceInfo = invalid then return
    ui = deviceInfo.GetUIResolution()
    if ui = invalid then return
    print "Eaglewood: ui = "; ui.name; " "; ui.width; "x"; ui.height
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    flag = "false"
    if press = true then flag = "true"
    print "Eaglewood: key " + key + " press=" + flag + " focus=" + FocusedNodeId()
    if press <> true then return false
    handled = true
    try
        handled = RouteKey(key)
    catch err
        print "Eaglewood: key error = "; LayoutErrorText(err)
        HoldFocus()
        handled = true
        if key = "back"
            if m.section = "home" and m.zone = "rail" then handled = false
        end if
    end try
    ' Build 37: one state line after every press, so tests can assert where
    ' the rail highlight is (QA gate 3) without trusting the pixels alone.
    print "Eaglewood: state key=" + key + " section=" + CaughtText(m.section) + " zone=" + CaughtText(m.zone) + " nav2=" + CaughtText(m.nav2) + " lit=" + RailLitText()
    return handled
end function

' Sections whose rail row is drawn focused (amber), comma separated.
function RailLitText() as string
    out = ""
    if m.railItems = invalid then return "none"
    menu = TopMenu()
    for index = 0 to m.railItems.Count() - 1
        row = m.railItems[index]
        if row.focused = true and row.group.visible = true and index < menu.Count()
            if out <> "" then out = out + ","
            out = out + menu[index]
        end if
    end for
    if out = "" then return "none"
    return out
end function

function RouteKey(key as string) as boolean
    BumpIdle()
    HoldFocus()
    if m.hostKitMode = "intro" or m.hostKitMode = "pairing" or m.hostKitMode = "loading"
        return HostKitRouteKey(key)
    end if
    ' Build 32: a key during a slide snaps the slide to its end instead of
    ' being dropped, so a slide that never reports "stopped" cannot lock keys.
    if m.menuBusy = true then FinishMenuSlide()
    if m.shell = invalid
        if key = "back"
            print "Eaglewood: back exit"
            return false
        end if
        return true
    end if
    ' Build 34: Settings / For You navigation runs first.
    nav2 = Nav2Key(key)
    if nav2 <> invalid then return nav2
    if key = "back" then return HandleBack()
    if key = "up" then return HandleVertical(-1)
    if key = "down" then return HandleVertical(1)
    if key = "left" then return HandleLeft()
    if key = "right" then return HandleRight()
    if key = "OK" then return HandleOk()
    return false
end function

function HandleVertical(direction as integer) as boolean
    if m.zone = "prompt" then return MovePrompt(direction)
    if m.zone = "rail" then return MoveRail(direction)
    if m.zone = "tiles" then return MoveTiles(direction)
    if m.zone = "grid" then return MoveCards(0, direction)
    if m.zone = "list" then return MoveIssue(direction)
    if m.zone = "detail" then return MoveBodyScroll(direction)
    if m.zone = "item" then return MoveBodyScroll(direction)
    if m.zone = "panel" and m.section = "rules" then return MoveRuleScroll(direction)
    if m.zone = "panel" and m.section = "checkout" then return MoveCheckoutScroll(direction)
    return true
end function

function MovePrompt(direction as integer) as boolean
    if direction > 0
        m.zone = "tiles"
        if m.tileIndex < 0 then m.tileIndex = 0
        PaintPrompt()
        PaintTiles()
        HoldFocus()
    end if
    return true
end function

function MoveRail(direction as integer) as boolean
    key = "down"
    if direction < 0 then key = "up"
    state = NextNav(MenuDepth(), "rail", m.section, m.railIndex, key)
    if NavChanged(state) then return FinishNav(state)
    return true
end function

function MoveTiles(direction as integer) as boolean
    row = m.tileIndex \ 3
    if direction < 0
        if row > 0
            m.tileIndex = m.tileIndex - 3
        else
            m.zone = "prompt"
        end if
    else
        if row = 0 then m.tileIndex = m.tileIndex + 3
    end if
    PaintPrompt()
    PaintTiles()
    HoldFocus()
    return true
end function

function MoveCards(dx as integer, dy as integer) as boolean
    key = ""
    if dx < 0
        key = "left"
    else if dx > 0
        key = "right"
    else if dy < 0
        key = "up"
    else if dy > 0
        key = "down"
    end if
    moved = GridNav(CardCount(), m.cardIndex, key)
    if moved.zone = "rail" then return FocusRail()
    if moved.index = m.cardIndex then return true
    m.cardIndex = moved.index
    ShowCardFocus()
    HoldFocus()
    return true
end function

function MoveIssue(direction as integer) as boolean
    count = IssueCount()
    if count < 1 then return true
    nextIndex = m.issueIndex + direction
    if nextIndex < 0 or nextIndex >= count then return true
    m.issueIndex = nextIndex
    m.stepScroll = 0
    PaintFixes()
    HoldFocus()
    return true
end function

function MoveStepScroll(direction as integer) as boolean
    maxScroll = StepCount() - VisibleSteps()
    if maxScroll < 0 then maxScroll = 0
    nextScroll = m.stepScroll + direction
    if nextScroll < 0 or nextScroll > maxScroll then return true
    m.stepScroll = nextScroll
    PaintFixes()
    HoldFocus()
    return true
end function

function MoveRuleScroll(direction as integer) as boolean
    maxScroll = RuleCount() - VisibleRules()
    if maxScroll < 0 then maxScroll = 0
    nextScroll = m.ruleScroll + direction
    if nextScroll < 0 or nextScroll > maxScroll then return true
    m.ruleScroll = nextScroll
    PaintRules()
    HoldFocus()
    return true
end function

function MoveCheckoutScroll(direction as integer) as boolean
    maxScroll = CheckoutStepCount() - VisibleCheckoutSteps()
    if maxScroll < 0 then maxScroll = 0
    nextScroll = m.checkoutScroll + direction
    if nextScroll < 0 or nextScroll > maxScroll then return true
    m.checkoutScroll = nextScroll
    PaintCheckout()
    HoldFocus()
    return true
end function

function HandleLeft() as boolean
    tracked = false
    if m.zone = "item" then tracked = true
    if m.zone = "rail" then tracked = true
    if tracked = true
        state = NextNav(MenuDepth(), m.zone, m.section, m.railIndex, "left")
        if NavChanged(state) then return FinishNav(state)
        return true
    end if
    if m.zone = "prompt" then return FocusRail()
    if m.zone = "grid" then return MoveCards(-1, 0)
    if m.zone = "detail"
        m.zone = "list"
        print "Eaglewood: screen="; m.section; " zone=list"
        PaintFixes()
        HoldFocus()
        return true
    end if
    if m.zone = "tiles"
        col = m.tileIndex mod 3
        if col > 0
            m.tileIndex = m.tileIndex - 1
            PaintTiles()
            HoldFocus()
            return true
        end if
        return FocusRail()
    end if
    if m.zone = "list" or m.zone = "panel" then return FocusRail()
    return true
end function

function HandleRight() as boolean
    if m.zone = "rail"
        return FinishNav(NextNav(MenuDepth(), m.zone, m.section, m.railIndex, "right"))
    end if
    if m.zone = "grid" then return MoveCards(1, 0)
    if m.zone = "tiles"
        col = m.tileIndex mod 3
        if col < 2 then m.tileIndex = m.tileIndex + 1
        PaintTiles()
        HoldFocus()
        return true
    end if
    if m.zone = "list" then return OpenStepScroll()
    return true
end function

function HandleOk() as boolean
    if m.zone = "rail"
        return FinishNav(NextNav(MenuDepth(), m.zone, m.section, m.railIndex, "OK"))
    end if
    if m.zone = "prompt"
        OpenSection("book")
        return true
    end if
    if m.zone = "tiles"
        OpenSection(CurrentTileSection())
        return true
    end if
    if m.zone = "grid" then return OpenActivityDetail()
    if m.zone = "list" then return OpenStepScroll()
    return true
end function

function OpenActivityDetail() as boolean
    if CardCount() < 1 then return true
    LogDetailOpen()
    m.zone = "item"
    ReleaseCardImages()
    PaintDetail()
    ShowSection(m.section)
    print "Eaglewood: screen="; m.section; " zone=item"
    HoldFocus()
    return true
end function

function HandleBack() as boolean
    tracked = false
    if m.zone = "item" then tracked = true
    if m.zone = "grid" then tracked = true
    if m.zone = "rail" then tracked = true
    if tracked = true
        state = NextNav(MenuDepth(), m.zone, m.section, m.railIndex, "back")
        if state <> invalid
            if state.leave = true
                print "Eaglewood: back exit"
                return false
            end if
        end if
        if NavChanged(state) then return FinishNav(state)
    end if
    if m.zone <> "rail" then return FocusRail()
    print "Eaglewood: back exit"
    return false
end function

function FocusRail() as boolean
    m.zone = "rail"
    print "Eaglewood: screen="; m.section; " zone=rail"
    PaintAll()
    HoldFocus()
    return true
end function

function MenuDepth() as string
    if m.menuDepth = invalid or m.menuDepth = "" then return "top"
    return m.menuDepth
end function

function NavChanged(state as object) as boolean
    if state = invalid then return false
    if state.depth <> MenuDepth() then return true
    if state.zone <> m.zone then return true
    if state.section <> m.section then return true
    if state.index <> m.railIndex then return true
    return false
end function

function FinishNav(state as object) as boolean
    if state = invalid then return true
    m.nav2 = ""
    m.menuDepth = state.depth
    m.zone = state.zone
    m.section = state.section
    m.railIndex = state.index
    if state.depth = "fixes" then m.issueIndex = state.index
    if state.section = "home" then m.tileIndex = 0
    ShowSection(m.section)
    print "Eaglewood: screen="; m.section; " zone="; m.zone
    PaintAll()
    SyncMenuMotion()
    SyncChildList()
    HoldFocus()
    return true
end function

sub SyncChildList()
    if m.childMenu = invalid then return
    list = m.childMenu.list
    if list = invalid then return
    if MenuDepth() <> "todo" and MenuDepth() <> "fixes"
        m.childWindowKey = ""
        return
    end if
    content = list.content
    if content = invalid then return
    last = content.getChildCount() - 1
    if last < 0 then return
    for index = 0 to last
        row = content.getChild(index)
        if row <> invalid and row.hasField("lit") then row.lit = (index = m.railIndex)
    end for
    if m.railIndex >= 0 and m.railIndex <= last then list.jumpToItem = m.railIndex
    SyncMoreBelow(list, last + 1)
end sub

' Build 33 (Pixel b32 P3): track the visible window the way floatingFocus
' scrolls it (the least move that keeps the focused row on screen) and show
' the down-chevron only while rows remain below that window.
sub SyncMoreBelow(list as object, count as integer)
    rows = list.numRows
    if rows = invalid or rows < 1 then rows = 4
    if m.childWindow = invalid or m.childWindowKey <> MenuDepth() then m.childWindow = 0
    m.childWindowKey = MenuDepth()
    if m.railIndex < m.childWindow then m.childWindow = m.railIndex
    if m.railIndex > m.childWindow + rows - 1 then m.childWindow = m.railIndex - rows + 1
    if m.childWindow < 0 then m.childWindow = 0
    more = (m.childWindow + rows < count)
    pitch = 180
    size = list.itemSize
    if size <> invalid and size.Count() > 1 then pitch = size[1] + 4
    m.childMenu.moreY = 64 + (rows * pitch) - 2
    m.childMenu.moreBelow = more
    print "Eaglewood: submenu window="; m.childWindow; " rows="; rows; " count="; count; " more="; more
end sub

function CurrentTileSection() as string
    sections = TileSections()
    if m.tileIndex < 0 or m.tileIndex >= sections.Count() then return "wifi"
    return sections[m.tileIndex]
end function

sub OpenSection(section as string)
    ' Build 34: home tiles land in the new layouts.
    if section = "todo"
        Nav2EnterFy("")
        return
    end if
    if SubmenuSection(section)
        Nav2EnterFy(section)
        return
    end if
    if section = "fixes"
        Nav2EnterFx()
        return
    end if
    if section = "fixes" then m.stepScroll = 0
    FinishNav(OpenTarget(section))
end sub

' Build 30 (Captain #8): Right opens the steps only when they overflow, the
' same rule DetailScroll uses to show the "Right Scroll steps" keycap.
function OpenStepScroll() as boolean
    if m.detailScroll = invalid then return true
    if m.detailScroll.maxOffset < 1 then return true
    m.zone = "detail"
    if m.stepScroll < 0 then m.stepScroll = 0
    print "Eaglewood: screen="; m.section; " zone=detail"
    PaintFixes()
    HoldFocus()
    return true
end function

sub onIdle()
    if m.idleTimer = invalid then return
    if m.idleTimer.fire <> true then return
    print "Eaglewood: idle return home"
    try
        ResetMenuMotion()
        m.nav2 = ""
        Nav2StopTween()
        home = HomePromptState()
        m.section = home.section
        m.zone = home.zone
        m.menuDepth = home.depth
        m.railIndex = home.index
        m.tileIndex = 0
        m.cardIndex = 0
        m.issueIndex = 0
        m.stepScroll = 0
        m.ruleScroll = 0
        m.checkoutScroll = 0
        ShowSection("home")
        print "Eaglewood: screen=home zone="; m.zone
        PaintAll()
        HoldFocus()
    catch err
        print "Eaglewood: layout error = "; LayoutErrorText(err)
        HoldFocus()
    end try
    BumpIdle()
end sub

function PeekX() as integer
    return 48 - RailW()
end function

sub ResetMenuMotion()
    m.menuBusy = false
    m.slideOpen = false
    if m.menuAnim <> invalid
        m.menuAnim.control = "stop"
        if m.top <> invalid then m.top.removeChild(m.menuAnim)
        m.menuAnim = invalid
    end if
    if m.railTop <> invalid then m.railTop.translation = [0, 0]
    if m.railChild <> invalid
        m.railChild.translation = [RailW(), 0]
        m.railChild.visible = false
    end if
    if m.fixesPane <> invalid then m.fixesPane.translation = [0, 0]
end sub

sub SyncMenuMotion()
    ' Build 32: Quick Fixes slides in the same submenu as Things to Do.
    opening = false
    if MenuDepth() = "todo" or MenuDepth() = "fixes" then opening = true
    if m.slideOpen = invalid then m.slideOpen = false
    if opening <> m.slideOpen
        m.slideOpen = opening
        RunRailSlide(opening)
    end if
end sub

sub RunRailSlide(opening as boolean)
    if m.railTop = invalid or m.railChild = invalid then return
    wide = RailW()
    m.railTop.translation = [0, 0]
    if opening = true
        ' The parent used to peek in from the left and its labels were cut off.
        m.railTop.visible = false
        m.railChild.visible = true
        m.railChild.translation = [wide, 0]
        StartVectorSlide("railChild.translation", [wide, 0], [0, 0])
    else
        m.railChild.visible = true
        StartVectorSlide("railChild.translation", [0, 0], [wide, 0])
    end if
end sub

function SimulatorRun() as boolean
    info = CreateObject("roDeviceInfo")
    if info = invalid then return false
    return info.hasFeature("simulation_engine")
end function

sub StartVectorSlide(firstField as string, firstFrom as object, firstTo as object)
    if SimulatorRun() or m.emuReplay = true
        ApplySlideEnd(firstField, firstTo, "", [0, 0])
        return
    end if
    anim = CreateObject("roSGNode", "Animation")
    if anim = invalid
        ApplySlideEnd(firstField, firstTo, "", [0, 0])
        return
    end if
    anim.duration = 0.22
    anim.easeFunction = "outQuad"
    anim.repeat = false
    first = CreateObject("roSGNode", "Vector2DFieldInterpolator")
    if first = invalid
        ApplySlideEnd(firstField, firstTo, "", [0, 0])
        return
    end if
    first.key = [0.0, 1.0]
    first.keyValue = [firstFrom, firstTo]
    first.fieldToInterp = firstField
    anim.appendChild(first)
    if m.menuAnim <> invalid
        m.menuAnim.control = "stop"
        if m.top <> invalid then m.top.removeChild(m.menuAnim)
    end if
    m.menuBusy = true
    m.menuAnim = anim
    m.top.appendChild(anim)
    anim.observeField("state", "onMenuSlideState")
    anim.control = "start"
end sub

sub ApplySlideEnd(firstField as string, firstTo as object, secondField as string, secondTo as object)
    if firstField = "railChild.translation" and m.railChild <> invalid then m.railChild.translation = firstTo
    if secondField = "railChild.translation" and m.railChild <> invalid then m.railChild.translation = secondTo
    m.menuBusy = false
    if m.slideOpen = true
        if m.railTop <> invalid then m.railTop.visible = false
    else
        if m.railTop <> invalid
            m.railTop.visible = true
            m.railTop.translation = [0, 0]
        end if
        if m.railChild <> invalid then m.railChild.visible = false
    end if
end sub

sub FinishMenuSlide()
    anim = m.menuAnim
    m.menuAnim = invalid
    if anim <> invalid
        anim.unobserveField("state")
        anim.control = "stop"
        if m.top <> invalid then m.top.removeChild(anim)
    end if
    target = [RailW(), 0]
    if m.slideOpen = true then target = [0, 0]
    ApplySlideEnd("railChild.translation", target, "", [0, 0])
end sub

sub onMenuSlideState()
    if m.menuAnim = invalid then return
    if m.menuAnim.state <> "stopped" then return
    m.menuBusy = false
    if m.slideOpen = true
        if m.railTop <> invalid then m.railTop.visible = false
    else
        if m.railTop <> invalid
            m.railTop.visible = true
            m.railTop.translation = [0, 0]
        end if
        if m.railChild <> invalid then m.railChild.visible = false
    end if
    if m.top <> invalid then m.top.removeChild(m.menuAnim)
    m.menuAnim = invalid
end sub

sub BumpIdle()
    if m.idleTimer = invalid then return
    m.idleTimer.control = "stop"
    m.idleTimer.duration = 600
    m.idleTimer.control = "start"
end sub

sub startWifiFetch()
    if m.wifiTask <> invalid
        m.wifiTask.unobserveField("result")
        m.wifiTask.control = "STOP"
        m.wifiTask = invalid
    end if
    m.wifiGeneration = m.wifiGeneration + 1
    print "Eaglewood: wifi task created generation="; m.wifiGeneration
    task = CreateObject("roSGNode", "WifiTask")
    if task = invalid
        print "Eaglewood: wifi skip reason=task-create-failed"
        return
    end if
    task.functionName = "fetchWifi"
    task.generation = m.wifiGeneration
    task.busyPaths = LiveQrPathList()
    task.observeField("result", "onWifiFetch")
    m.wifiTask = task
    task.control = "RUN"
    print "Eaglewood: wifi task started generation="; m.wifiGeneration
end sub

sub onWifiFetch()
    task = m.wifiTask
    if task = invalid
        print "Eaglewood: wifi skip reason=no-task"
        return
    end if
    result = task.result
    if result = invalid
        print "Eaglewood: wifi skip reason=no-result"
        return
    end if
    if not WifiGenerationMatches(result)
        print "Eaglewood: wifi skip reason=generation"
        return
    end if
    try
        ApplyWifiResult(result)
    catch err
        print "Eaglewood: layout error = "; LayoutErrorText(err)
        HoldFocus()
        return
    end try
    source = AsText(result.source)
    png = AsText(result.png)
    if png = "" then png = "no"
    ssidLen = 0
    if result.ssidLen <> invalid then ssidLen = result.ssidLen
    print "Eaglewood: wifi applied source="; source; " ssid len="; ssidLen; " png="; png; " json code="; m.wifiJsonCode; " png code="; m.wifiPngCode
    HoldFocus()
end sub

function WifiGenerationMatches(result as object) as boolean
    want = m.wifiGeneration.ToStr()
    text = result.generationText
    number = result.generation
    if text <> invalid
        if text = want then return true
    end if
    if number <> invalid
        if number.ToStr() = want then return true
    end if
    blank = false
    if text = invalid or text = "" or text = "0" then blank = true
    if blank
        if number = invalid or number = 0 then return true
    end if
    return false
end function

sub StartRefresh()
    if m.refreshTimer = invalid then return
    m.refreshTimer.control = "stop"
    m.refreshTimer.repeat = true
    m.refreshTimer.duration = 21600
    m.refreshTimer.control = "start"
end sub

sub onRefresh()
    if m.refreshTimer = invalid then return
    if m.refreshTimer.fire <> true then return
    if HostKitHasDeviceToken() = true
        startHostKitConfigFetch()
    else
        startGuideFetch()
    end if
    startWifiFetch()
end sub

sub StartQrFetch(slot as string)
    url = ""
    if slot = "badge" and m.badgeRemote <> invalid then url = m.badgeRemote
    if slot = "book" and m.bookQrUri <> invalid then url = m.bookQrUri
    if slot = "detail" and m.detailQrUri <> invalid then url = m.detailQrUri
    if url = "" then return
    if m.qrJobs = invalid then m.qrJobs = {}
    if m.qrTasks = invalid then m.qrTasks = {}
    running = m.qrTasks.Lookup(slot)
    if m.qrJobs[slot] = url and running <> invalid
        DeliverQrPath(slot)
        return
    end if
    m.qrJobs[slot] = url
    if running <> invalid
        running.unobserveField("finalUri")
        running.control = "STOP"
        m.top.removeChild(running)
    end if
    m.qrGeneration = m.qrGeneration + 1
    task = CreateObject("roSGNode", "QrTask")
    if task = invalid
        print "Eaglewood: qr skip reason=task-create-failed"
        m.qrJobs[slot] = ""
        return
    end if
    task.id = "qrTask" + slot
    task.generation = m.qrGeneration
    task.badgeUrl = ""
    task.bookUrl = ""
    task.detailUrl = ""
    if slot = "badge" then task.badgeUrl = url
    if slot = "book" then task.bookUrl = url
    if slot = "detail" then task.detailUrl = url
    task.busyPaths = LiveQrPathList()
    task.doCleanup = false
    if m.qrCleanupDone <> true
        task.doCleanup = true
        m.qrCleanupDone = true
    end if
    m.qrTasks[slot] = task
    m.top.appendChild(task)
    if slot = "badge" then task.observeField("finalUri", "onBadgeQrUri")
    if slot = "book" then task.observeField("finalUri", "onBookQrUri")
    if slot = "detail" then task.observeField("finalUri", "onDetailQrUri")
    task.control = "RUN"
end sub

sub onBadgeQrUri()
    DeliverQrPath("badge")
end sub

sub onBookQrUri()
    DeliverQrPath("book")
end sub

sub onDetailQrUri()
    DeliverQrPath("detail")
end sub

' The callback is the one attached to this slot's task before RUN.
sub DeliverQrPath(slot as string)
    if m.qrTasks = invalid then return
    task = m.qrTasks.Lookup(slot)
    if task = invalid then return
    uri = task.finalUri
    if uri = invalid or uri = "" then return
    if Left(uri, 8) <> "cachefs:" and Left(uri, 4) <> "tmp:" then return
    if task.result <> invalid
        NoteQrBytes(slot, ResultNumber(task.result, "bytes"))
        RememberQrFormat(slot, task.result)
        RememberQrPng64(slot, task.result.png64)
    end if
    if slot = "badge" then m.badgeFailed = false
    if slot = "detail" then m.detailQrFailed = false
    ShowQrFrame(slot, true)
    AssignQrPoster(slot, uri)
    if slot = "detail" then RevealDetailQr()
end sub

sub RememberQrFormat(slot as string, result as object)
    if m.qrFormats = invalid then m.qrFormats = {}
    m.qrFormats[slot] = "bitdepth=" + NumberText(result.bit) + " colortype=" + NumberText(result.color) + " interlace=" + NumberText(result.interlace) + " indexed=" + AsText(result.indexed)
end sub

function NumberText(value as object) as string
    if value = invalid then return "0"
    return value.ToStr()
end function

' Build 32 (Blake's TV lockup): the scene owns remote focus in every zone.
' b31 handed focus to the submenu MarkupList; the list ate Up/Down itself
' and kept focus after the submenu slid away, so Down did nothing.
sub HoldFocus()
    focused = true
    try
        focused = m.top.hasFocus()
    catch err
        focused = false
        print "Eaglewood: layout error = "; LayoutErrorText(err)
    end try
    if focused = true then return
    m.top.setFocus(true)
    print "Eaglewood: focus restored"
end sub

' Replays a dash-separated key list (for example Left-Down-OK) once the scene
' is up. Only reachable through the harness-only emuKeys launch parameter.
' Debug-only (pkg:/emu/enabled, stripped by package.sh): replays a key list from
' the emuKeys deep link, one key every 0.6 s, so async loads land between keys
' the way they do for a person holding the remote.
sub onEmuKeys()
    keys = m.top.emuKeys
    if keys = invalid or keys = "" then return
    m.emuReplay = true
    names = {left: "left", right: "right", up: "up", down: "down", select: "OK", ok: "OK", back: "back", adnext: "adnext"}
    m.emuQueue = []
    for each part in keys.split("-")
        name = names.lookup(LCase(part))
        if name <> invalid then m.emuQueue.Push(name)
    end for
    timer = CreateObject("roSGNode", "Timer")
    timer.duration = 0.6
    timer.repeat = true
    timer.observeField("fire", "onEmuKeyTick")
    m.top.appendChild(timer)
    m.emuTimer = timer
    timer.control = "start"
end sub

sub onEmuKeyTick()
    if m.emuQueue <> invalid and m.emuQueue.Count() > 0
        name = m.emuQueue.Shift()
        print "Eaglewood: emu key " + name
        if name = "adnext"
            AdvanceAd()
            return
        end if
        RouteKey(name)
        return
    end if
    if m.emuTimer <> invalid
        m.emuTimer.control = "stop"
        m.top.removeChild(m.emuTimer)
        m.emuTimer = invalid
    end if
    print "Eaglewood: emu keys done section=" + m.section + " zone=" + m.zone
end sub

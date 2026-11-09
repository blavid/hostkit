sub init()
    m.top.functionName = "fetchGuideBundle"
end sub

' Network, then cachefs, then the packaged snapshot, then built-in strings.
' Response bodies are not printed: troubleshooting text can include access details.
sub fetchGuideBundle()
    generation = ReadGuideGeneration()
    DiscardActivitiesCacheGeneration()
    guide = LoadGuideLocal()
    checkout = LoadCheckoutLocal()
    activities = LoadActivitiesLocal()
    menu = LoadMenuLocal()
    FillTimes(guide, checkout)
    LogGuideChoice(guide)
    LogCheckoutChoice(checkout)
    LogActivitiesChoice(activities)
    LogMenuChoice(menu)
    PublishBundle(guide, checkout, activities, menu, generation)

    remoteGuide = FetchRemote("guide")
    remoteCheckout = FetchRemote("checkout")
    remoteActivities = FetchRemote("activities")
    remoteMenu = FetchRemote("menu")
    changed = false
    if remoteGuide <> invalid
        guide = remoteGuide
        changed = true
        LogGuideChoice(guide)
    end if
    if remoteCheckout <> invalid
        checkout = remoteCheckout
        changed = true
        LogCheckoutChoice(checkout)
    end if
    if remoteActivities <> invalid
        activities = remoteActivities
        changed = true
        LogActivitiesChoice(activities)
    end if
    if remoteMenu <> invalid
        menu = remoteMenu
        changed = true
        LogMenuChoice(menu)
    end if
    if changed
        FillTimes(guide, checkout)
        PublishBundle(guide, checkout, activities, menu, generation)
    end if
end sub

function GuideDataUrl() as string
    return "https://sunrivertownhome.com/data/guide.json"
end function

function CheckoutDataUrl() as string
    return "https://sunrivertownhome.com/data/checkout.json"
end function

function ActivitiesDataUrl() as string
    return "https://sunrivertownhome.com/data/activities.json"
end function

function LoadMenuLocal() as object
    cachedText = ReadText("cachefs:/eaglewood/menu.json")
    cached = AcceptMenuText(cachedText, "cachefs")
    if cached <> invalid then return cached
    if cachedText <> "" then print "Eaglewood: menu fallback reason=bad-cache"
    packaged = AcceptMenuText(ReadText("pkg:/data/menu.json"), "pkg")
    if packaged <> invalid then return packaged
    print "Eaglewood: menu fallback reason=bundle"
    return BuiltinMenu()
end function

sub LogMenuChoice(menu as object)
    source = "none"
    if menu <> invalid and menu.source <> invalid then source = menu.source
    print "Eaglewood: menu source="; source
end sub

function LoadGuideLocal() as object
    parsed = ParseObjectText(ReadText("cachefs:/eaglewood/guide.json"))
    guide = AttachGuideBook(parsed, "cachefs")
    if guide <> invalid then return guide
    parsed = ParseObjectText(ReadText("pkg:/data/guide.json"))
    guide = AttachGuideBook(parsed, "pkg")
    if guide <> invalid then return guide
    guide = FallbackGuide()
    guide.book = DefaultBookDirect()
    return guide
end function

function AttachGuideBook(parsed as object, source as string) as object
    guide = NormalizeGuide(parsed)
    if guide = invalid then return invalid
    guide.book = NormalizeBookDirect(parsed)
    guide.guideSource = source
    guide.guideCode = "0"
    return guide
end function

function LoadCheckoutLocal() as object
    parsed = ParseObjectText(ReadText("cachefs:/eaglewood/checkout.json"))
    checkout = NormalizeCheckout(parsed)
    if checkout <> invalid
        checkout.checkoutSource = "cachefs"
        checkout.checkoutCode = "0"
        return checkout
    end if
    parsed = ParseObjectText(ReadText("pkg:/data/checkout.json"))
    checkout = NormalizeCheckout(parsed)
    if checkout <> invalid
        checkout.checkoutSource = "pkg"
        checkout.checkoutCode = "0"
        return checkout
    end if
    return FallbackCheckout()
end function

sub FillTimes(guide as object, checkout as object)
    if guide = invalid or checkout = invalid then return
    if guide.checkIn = "" then guide.checkIn = checkout.checkIn
    if guide.checkOut = "" then guide.checkOut = checkout.checkOut
end sub

function FetchRemote(kind as string) as object
    url = GuideDataUrl()
    cachePath = "cachefs:/eaglewood/guide.json"
    prefix = "guide"
    if kind = "menu"
        url = MenuDataUrl()
        cachePath = "cachefs:/eaglewood/menu.json"
        prefix = "menu"
    else if kind = "checkout"
        url = CheckoutDataUrl()
        cachePath = "cachefs:/eaglewood/checkout.json"
        prefix = "checkout"
    else if kind = "activities"
        url = ActivitiesDataUrl()
        cachePath = "cachefs:/eaglewood/activities.json"
        prefix = "activities"
    end if
    etag = RememberedEtag(prefix)
    print "Eaglewood: "; kind; " request sent"
    response = HttpGet(url, etag)
    print "Eaglewood: "; kind; " response code="; response.code
    if kind = "activities" then response = ActivitiesResponse(url, cachePath, response)
    ' Build 34 (Blake b33 TV log, GuideTask.brs:327): 304 with no cache file.
    ' Forget the etag and fetch the full body once instead of failing.
    if response.reason = "not-modified" and ParseObjectText(ReadText(cachePath)) = invalid
        print "Eaglewood: "; kind; " cache-miss refetch"
        ForgetEtag(prefix)
        etag = ""
        response = HttpGet(url, "")
        print "Eaglewood: "; kind; " response code="; response.code
    end if
    if kind = "menu" and response.code = 404
        ' No menu.json on the site yet: the packaged menu is the menu. Not a failure.
        print "Eaglewood: menu remote absent code=404 using="; "local"
        ForgetEtag(prefix)
        return invalid
    end if
    if response.reason = "not-modified"
        cachedText = ReadText(cachePath)
        parsed = ParseObjectText(cachedText)
        if parsed = invalid
            print "Eaglewood: "; kind; " failure reason=cache-miss"
            return invalid
        end if
        print "Eaglewood: "; kind; " etag match"
        RememberFetch(prefix, etag, GuideInt(parsed.Lookup("version")))
        if kind = "activities" then return ActivitiesFromText(cachedText, "not-modified", "304")
        return FinishRemote(kind, parsed, "not-modified", "304")
    end if
    if response.reason <> "ok"
        print "Eaglewood: "; kind; " failure reason="; response.reason
        return invalid
    end if
    parsed = ParseObjectText(response.body)
    if parsed = invalid
        print "Eaglewood: "; kind; " failure reason=bad-json"
        return invalid
    end if
    if kind = "menu"
        if MenuRejectReason(parsed) <> "ok"
            print "Eaglewood: menu fallback reason="; MenuRejectReason(parsed)
            return invalid
        end if
    end if
    wrote = WriteText(cachePath, response.body)
    stored = response.etag
    if stored = "" then stored = etag
    ' Build 34 root cause: the etag was kept even when the cache write failed,
    ' so the next launch got a 304 for a file that was never written.
    if wrote <> true
        print "Eaglewood: "; kind; " cache-write failed, etag not kept"
        stored = ""
        ForgetEtag(prefix)
    end if
    if response.etag <> ""
        print "Eaglewood: "; kind; " etag stored"
    else
        print "Eaglewood: "; kind; " etag missing"
    end if
    RememberFetch(prefix, stored, GuideInt(parsed.Lookup("version")))
    if kind = "activities" then return ActivitiesFromText(response.body, "network", "200")
    return FinishRemote(kind, parsed, "network", "200")
end function

' The 304 cache file is the same raw JSON body a 200 wrote. Both go through
' ActivitiesFromFetch. A cache with no qrUrl falls back to the pkg snapshot.
function ActivitiesFromText(text as string, source as string, code as string) as object
    bundled = FinishActivities(ParseObjectText(ReadText("pkg:/data/activities.json")), "pkg", "0")
    chosen = ActivitiesFromFetch(ParseObjectText(text), source, code, bundled)
    if source = "not-modified" and chosen <> invalid and chosen.activitiesSource = "pkg"
        print "Eaglewood: activities cache missing qrUrl"
    end if
    return chosen
end function

function FinishRemote(kind as string, parsed as object, source as string, code as string) as object
    if kind = "menu"
        menu = NormalizeMenu(parsed)
        if menu = invalid then return invalid
        menu.source = source
        return menu
    end if
    if kind = "checkout"
        checkout = NormalizeCheckout(parsed)
        if checkout = invalid then return invalid
        checkout.checkoutSource = source
        checkout.checkoutCode = code
        return checkout
    end if
    if kind = "activities" then return FinishActivities(parsed, source, code)
    guide = NormalizeGuide(parsed)
    if guide = invalid then return invalid
    guide.book = NormalizeBookDirect(parsed)
    guide.guideSource = source
    guide.guideCode = code
    return guide
end function

function LoadActivitiesLocal() as object
    bundled = FinishActivities(ParseObjectText(ReadText("pkg:/data/activities.json")), "pkg", "0")
    cachedText = ReadText("cachefs:/eaglewood/activities.json")
    cachedParsed = ParseObjectText(cachedText)
    if cachedParsed <> invalid and ActivitiesCacheDropsQr(cachedParsed)
        print "Eaglewood: activities cache missing qrUrl"
        DeleteActivitiesCache()
        cachedParsed = invalid
    end if
    chosen = ActivitiesFromFetch(cachedParsed, "cachefs", "0", bundled)
    if cachedParsed <> invalid and chosen <> invalid and chosen.activitiesSource = "pkg"
        print "Eaglewood: activities cache missing qrUrl"
    end if
    if chosen <> invalid then return chosen
    return EmptyActivities()
end function

function FinishActivities(parsed as object, source as string, code as string) as object
    norm = NormalizeActivities(parsed)
    if norm = invalid then return invalid
    norm.activitiesSource = source
    norm.activitiesCode = code
    return norm
end function

function EmptyActivities() as object
    return {
        activitiesVersion: 0,
        items: [],
        activitiesSource: "builtin",
        activitiesCode: "0"
    }
end function

sub LogActivitiesChoice(activities as object)
    if activities = invalid then return
    print "Eaglewood: activities version="; VersionText(activities.activitiesVersion); " source="; activities.activitiesSource; " code="; activities.activitiesCode; " qr="; ActivitiesQrCount(activities.items)
end sub

function HttpGet(url as string, etag as string) as object
    result = { code: 0, body: "", etag: "", reason: "no-transfer" }
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    if transfer = invalid or port = invalid then return result
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.RetainBodyOnError(true)
    transfer.SetUrl(url)
    if etag <> "" then transfer.AddHeader("If-None-Match", etag)
    transfer.AddHeader("Accept", "application/json")
    started = transfer.AsyncGetToString()
    if started = false or started = invalid
        result.reason = "async-failed"
        return result
    end if
    event = wait(8000, port)
    if type(event) <> "roUrlEvent"
        transfer.AsyncCancel()
        result.reason = "timeout"
        return result
    end if
    result.code = event.GetResponseCode()
    result.etag = HeaderValue(event.GetResponseHeaders(), "ETag")
    if Len(result.etag) > 180 then result.etag = Left(result.etag, 180)
    body = event.GetString()
    if body = invalid then body = ""
    if result.code = 304
        result.reason = "not-modified"
        return result
    end if
    if result.code <> 200
        result.reason = "http"
        return result
    end if
    if body = ""
        result.reason = "empty-body"
        return result
    end if
    if ParseObjectText(body) = invalid
        result.reason = "bad-json"
        return result
    end if
    result.body = body
    result.reason = "ok"
    return result
end function

function HeaderValue(headers as object, name as string) as string
    if headers = invalid then return ""
    if type(headers) <> "roAssociativeArray" then return ""
    wanted = LCase(name)
    found = ""
    for each key in headers
        if LCase(key) = wanted
            value = headers.Lookup(key)
            found = GuideLimitedText(value, 180)
            exit for
        end if
    end for
    return found
end function

function ReadText(path as string) as string
    return ReadIfPresent(path)
end function

function WriteText(path as string, body as string) as boolean
    if body = invalid or body = "" then return false
    fs = CreateObject("roFileSystem")
    if fs <> invalid then fs.CreateDirectory("cachefs:/eaglewood")
    wrote = WriteAsciiFile(path, body)
    if wrote = true then return true
    return false
end function

function ActivitiesResponse(url as string, cachePath as string, response as object) as object
    if response <> invalid and response.reason = "ok" then return response
    cached = ParseObjectText(ReadText(cachePath))
    reason = ""
    if response <> invalid and response.reason <> invalid then reason = response.reason
    if ActivitiesCacheShouldDiscard(reason, cached) <> true then return response
    print "Eaglewood: activities cache discarded"
    DeleteActivitiesCache()
    return HttpGet(url, "")
end function

sub DiscardActivitiesCacheGeneration()
    section = CreateObject("roRegistrySection", "EaglewoodGuide")
    current = ""
    if section <> invalid then current = GuideLimitedText(section.Read("activitiesCacheKey"), 40)
    if current = ActivitiesCacheGeneration() then return
    print "Eaglewood: activities cache generation "; ActivitiesCacheGeneration()
    DeleteActivitiesCache()
    if section = invalid then return
    section.Write("activitiesCacheKey", ActivitiesCacheGeneration())
    section.Flush()
end sub

sub DeleteActivitiesCache()
    fs = CreateObject("roFileSystem")
    path = "cachefs:/eaglewood/activities.json"
    if fs <> invalid
        if fs.Exists(path) = true then fs.Delete(path)
    end if
    section = CreateObject("roRegistrySection", "EaglewoodGuide")
    if section = invalid then return
    section.Delete("activitiesEtag")
    section.Write("activitiesEtag", "")
    section.Flush()
end sub

sub ForgetEtag(prefix as string)
    section = CreateObject("roRegistrySection", "EaglewoodGuide")
    if section = invalid then return
    section.Delete(prefix + "Etag")
    section.Flush()
end sub

function RememberedEtag(prefix as string) as string
    section = CreateObject("roRegistrySection", "EaglewoodGuide")
    if section = invalid then return ""
    value = section.Read(prefix + "Etag")
    return GuideLimitedText(value, 180)
end function

sub RememberFetch(prefix as string, etag as string, version as integer)
    section = CreateObject("roRegistrySection", "EaglewoodGuide")
    if section = invalid then return
    section.Write(prefix + "Etag", etag)
    section.Write(prefix + "Version", version.ToStr())
    section.Write(prefix + "FetchedAt", NowStamp())
    section.Flush()
end sub

function NowStamp() as string
    clock = CreateObject("roDateTime")
    if clock = invalid then return "0"
    return clock.AsSeconds().ToStr()
end function

sub LogGuideChoice(guide as object)
    if guide = invalid then return
    print "Eaglewood: guide version="; VersionText(guide.guideVersion); " source="; guide.guideSource; " code="; guide.guideCode
end sub

sub LogCheckoutChoice(checkout as object)
    if checkout = invalid then return
    print "Eaglewood: checkout decision="; checkout.checkoutSource; " version="; VersionText(checkout.checkoutVersion); " code="; checkout.checkoutCode
end sub

sub PublishBundle(guide as object, checkout as object, activities as object, menu as object, generation as integer)
    if guide = invalid then guide = FallbackGuide()
    if checkout = invalid then checkout = FallbackCheckout()
    if activities = invalid then activities = EmptyActivities()
    book = guide.book
    if book = invalid then book = DefaultBookDirect()
    items = activities.items
    if items = invalid then items = []
    phone = GuideLimitedText(guide.hostPhone, 40)
    present = "no"
    if phone <> "" then present = "yes"
    m.top.result = {
        generation: generation,
        generationText: generation.ToStr(),
        guideSource: guide.guideSource,
        guideCode: guide.guideCode,
        guideVersion: VersionText(guide.guideVersion),
        checkoutSource: checkout.checkoutSource,
        checkoutCode: checkout.checkoutCode,
        checkoutVersion: VersionText(checkout.checkoutVersion),
        hostPhonePresent: present,
        activitiesSource: activities.activitiesSource,
        activitiesCode: activities.activitiesCode,
        activitiesVersion: VersionText(activities.activitiesVersion),
        activitiesJson: EncodeJson(items),
        bookJson: EncodeJson(book),
        brand: guide.brand,
        place: guide.place,
        domain: guide.domain,
        checkIn: guide.checkIn,
        checkOut: guide.checkOut,
        quietHours: guide.quietHours,
        hostName: guide.hostName,
        hostEmail: guide.hostEmail,
        hostPhone: phone,
        summary: checkout.summary,
        rulesJson: EncodeJson(guide.rules),
        issuesJson: EncodeJson(guide.issues),
        stepsJson: EncodeJson(checkout.checkoutSteps),
        menuSource: MenuSourceText(menu),
        menuJson: MenuBodyText(menu)
    }
end sub

function ReadGuideGeneration() as integer
    generation = m.top.generation
    if generation <> invalid and generation <> 0 then return generation
    spins = 0
    while spins < 30
        Sleep(10)
        generation = m.top.generation
        if generation <> invalid and generation <> 0 then return generation
        spins = spins + 1
    end while
    if generation = invalid then return 0
    return generation
end function

' Build 32: Roku logs "ReadAsciiFile: file open for read failed" for every
' missing file, so check first. A missing cache is normal on a cold start.
function ReadIfPresent(path as string) as string
    if path = invalid or path = "" then return ""
    fs = CreateObject("roFileSystem")
    if fs = invalid then return ""
    if fs.Exists(path) <> true then return ""
    text = ReadAsciiFile(path)
    if text = invalid then return ""
    return text
end function

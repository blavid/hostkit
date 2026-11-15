' HostKit v1 helpers: pairing alphabet, FAQ flatten, activity dedupe, cache
' choice, registry token metadata, and the build-time base URL. Network I/O
' lives in HostKitTask.brs. Do not put secrets, PINs, phones, or card digits here.

function HostKitAlphabet() as string
    return "ABCDEFGH" + "JKMNPQRS" + "TUVWXYZ" + "23456789" ' pairing alphabet (no 0 O 1 I L)
end function

function HostKitCodeOk(code as object) as boolean
    if code = invalid then return false
    kind = type(code)
    if kind <> "String" and kind <> "roString" then return false
    if Len(code) <> 6 then return false
    alphabet = HostKitAlphabet()
    upper = UCase(code)
    index = 1
    while index <= 6
        ch = Mid(upper, index, 1)
        if InStr(1, alphabet, ch) = 0 then return false
        index = index + 1
    end while
    return true
end function

function HostKitMakeCode(seed as integer) as string
    ' Deterministic helper for unit tests. Production codes come from the Worker.
    alphabet = HostKitAlphabet()
    count = Len(alphabet)
    value = seed
    if value < 0 then value = -value
    if value = 0 then value = 17
    out = ""
    i = 0
    while i < 6
        value = value * 17 + i + 31
        if value < 0 then value = -value
        index = value MOD count
        out = out + Mid(alphabet, index + 1, 1)
        i = i + 1
    end while
    return out
end function

function HostKitDedupeActivities(items as object) as object
    out = []
    if items = invalid then return out
    if HostKitIsArray(items) <> true then return out
    seen = []
    for each item in items
        if item <> invalid
            id = HostKitFieldText(item, "id")
            if id = "" or HostKitListHas(seen, id) <> true
                if id <> "" then seen.Push(id)
                out.Push(item)
            end if
        end if
    end for
    return out
end function

function HostKitFlattenFaqs(faqs as object) as object
    return HostKitFlattenFaqLevel(faqs, 1)
end function

function HostKitFlattenFaqLevel(faqs as object, depth as integer) as object
    out = []
    if faqs = invalid then return out
    if HostKitIsArray(faqs) <> true then return out
    for each cat in faqs
        if cat <> invalid then out.Push(HostKitFlattenOneCategory(cat, depth))
    end for
    return out
end function

function HostKitFlattenOneCategory(cat as object, depth as integer) as object
    copy = {}
    HostKitSetText(copy, "id", HostKitFieldText(cat, "id"))
    HostKitSetText(copy, "title", HostKitFieldText(cat, "title"))
    copy.items = HostKitCopyFaqItems(HostKitLookup(cat, "items"), "")
    kids = HostKitLookup(cat, "categories")
    if depth >= 2
        HostKitMergeFaqChildren(copy, kids)
        copy.categories = []
    else
        copy.categories = HostKitFlattenFaqLevel(kids, depth + 1)
    end if
    return copy
end function

sub HostKitMergeFaqChildren(parent as object, cats as object)
    if cats = invalid then return
    if HostKitIsArray(cats) <> true then return
    for each cat in cats
        if cat <> invalid
            title = HostKitFieldText(cat, "title")
            items = HostKitLookup(cat, "items")
            copied = HostKitCopyFaqItems(items, title)
            for each item in copied
                parent.items.Push(item)
            end for
            HostKitMergeFaqChildren(parent, HostKitLookup(cat, "categories"))
        end if
    end for
end sub

function HostKitCopyFaqItems(items as object, prefix as string) as object
    out = []
    if items = invalid then return out
    if HostKitIsArray(items) <> true then return out
    for each item in items
        if item <> invalid then out.Push(HostKitCopyFaqItem(item, prefix))
    end for
    return out
end function

function HostKitCopyFaqItem(item as object, prefix as string) as object
    copy = {}
    q = HostKitFieldText(item, "q")
    if prefix <> "" and q <> ""
        HostKitSetText(copy, "q", prefix + " - " + q)
    else
        HostKitSetText(copy, "q", q)
    end if
    HostKitSetText(copy, "a", HostKitFieldText(item, "a"))
    imageUrl = HostKitFieldText(item, "imageUrl")
    qrUrl = HostKitFieldText(item, "qrUrl")
    if imageUrl <> "" then HostKitSetText(copy, "imageUrl", imageUrl)
    if qrUrl <> "" then HostKitSetText(copy, "qrUrl", qrUrl)
    steps = HostKitListText(HostKitLookup(item, "steps"))
    if steps.Count() > 0 then copy.steps = steps
    return copy
end function

function HostKitNormalizeConfig(parsed as object) as object
    if parsed = invalid then return invalid
    if HostKitIsAa(parsed) <> true then return invalid
    version = HostKitLookup(parsed, "schemaVersion")
    if HostKitIsVersionOne(version) <> true then return invalid
    prop = HostKitLookup(parsed, "property")
    if HostKitIsAa(prop) <> true then return invalid
    if HostKitFieldText(prop, "id") = "" then return invalid
    out = {}
    out.schemaVersion = 1
    out.property = prop
    out.links = HostKitLookup(parsed, "links")
    out.faqs = HostKitFlattenFaqs(HostKitLookup(parsed, "faqs"))
    out.activities = HostKitDedupeActivities(HostKitLookup(parsed, "activities"))
    out.checkout = HostKitLookup(parsed, "checkout")
    out.wifi = HostKitLookup(parsed, "wifi")
    out.branding = HostKitLookup(parsed, "branding")
    out.subscription = HostKitLookup(parsed, "subscription")
    out.menu = HostKitLookup(parsed, "menu")
    out.quickReference = HostKitLookup(parsed, "quickReference")
    ' `web` is intentionally omitted. The TV ignores it.
    return out
end function

function HostKitAcceptConfigText(text as object) as object
    if text = invalid then return invalid
    kind = type(text)
    if kind <> "String" and kind <> "roString" then return invalid
    if text = "" then return invalid
    parsed = ParseJson(text)
    return HostKitNormalizeConfig(parsed)
end function

function HostKitChooseSource(remoteOk as boolean, remoteReason as string, cacheValid as boolean) as string
    if remoteOk = true then return "network"
    if remoteReason = "not-modified" and cacheValid = true then return "cachefs"
    if cacheValid = true then return "cachefs"
    return "none"
end function

function HostKitCachePath() as string
    return "cachefs:/hostkit/config.json"
end function

function HostKitQrCachePath(code as string) as string
    ' Unique file per code so the Poster reloads after a refresh.
    if code = invalid or code = "" then return "cachefs:/hostkit/pair-qr.png"
    return "cachefs:/hostkit/pair-qr-" + code + ".png"
end function

sub HostKitPrepareCacheDir()
    fs = CreateObject("roFileSystem")
    if fs = invalid then return
    if fs.Exists("cachefs:/hostkit") <> true then fs.CreateDirectory("cachefs:/hostkit")
end sub

function HostKitBaseUrl() as string
    text = ReadAsciiFile("pkg:/config/hostkit.json")
    if text = invalid or text = "" then return ""
    parsed = ParseJson(text)
    if parsed = invalid then return ""
    url = HostKitFieldText(parsed, "baseUrl")
    if url = "" then return ""
    if Right(url, 1) = "/" then url = Left(url, Len(url) - 1)
    return url
end function

function HostKitRegistry() as object
    return CreateObject("roRegistrySection", "HostKit")
end function

function HostKitReadKey(name as string) as string
    section = HostKitRegistry()
    if section = invalid then return ""
    value = section.Read(name)
    if value = invalid then return ""
    text = ""
    text = text + value
    return text
end function

sub HostKitWriteKey(name as string, value as string)
    section = HostKitRegistry()
    if section = invalid then return
    section.Write(name, value)
    section.Flush()
end sub

sub HostKitClearKey(name as string)
    section = HostKitRegistry()
    if section = invalid then return
    section.Delete(name)
    section.Flush()
end sub

function HostKitHasDeviceToken() as boolean
    if HostKitReadKey("deviceToken") = "" then return false
    return true
end function

sub HostKitSavePair(token as string, propertyId as string)
    section = HostKitRegistry()
    if section = invalid then return
    section.Write("deviceToken", token)
    section.Write("propertyId", propertyId)
    section.Write("pairedAt", HostKitNowStamp())
    section.Flush()
end sub

sub HostKitClearPair()
    section = HostKitRegistry()
    if section = invalid then return
    section.Delete("deviceToken")
    section.Delete("propertyId")
    section.Delete("pairedAt")
    section.Delete("configEtag")
    section.Delete("configFetchedAt")
    section.Flush()
end sub

sub HostKitRememberEtag(etag as string)
    section = HostKitRegistry()
    if section = invalid then return
    section.Write("configEtag", etag)
    section.Write("configFetchedAt", HostKitNowStamp())
    section.Flush()
end sub

function HostKitRememberedEtag() as string
    return HostKitReadKey("configEtag")
end function

function HostKitDeviceId() as string
    existing = HostKitReadKey("deviceId")
    if existing <> "" then return existing
    id = HostKitFreshDeviceId()
    if id = "" then id = "hk-" + HostKitNowStamp()
    HostKitWriteKey("deviceId", id)
    return id
end function

function HostKitFreshDeviceId() as string
    info = CreateObject("roDeviceInfo")
    if info = invalid then return ""
    id = info.GetChannelClientId()
    if id <> invalid and id <> "" then return id
    id = info.GetClientTrackingId()
    if id <> invalid and id <> "" then return id
    return ""
end function

function HostKitReadCacheText() as string
    text = ReadAsciiFile(HostKitCachePath())
    if text = invalid then return ""
    return text
end function

function HostKitWriteCacheText(body as string) as boolean
    if body = invalid or body = "" then return false
    HostKitPrepareCacheDir()
    wrote = WriteAsciiFile(HostKitCachePath(), body)
    if wrote = true then return true
    return false
end function

function HostKitCachedConfig() as object
    return HostKitAcceptConfigText(HostKitReadCacheText())
end function

sub HostKitMaybeSeedFromEmu()
    fs = CreateObject("roFileSystem")
    if fs = invalid then return
    if fs.Exists("pkg:/emu/enabled") <> true then return
    if fs.Exists("pkg:/emu/hostkit-seed.json") <> true then return
    text = ReadAsciiFile("pkg:/emu/hostkit-seed.json")
    parsed = ParseJson(text)
    if parsed = invalid then return
    token = HostKitFieldText(parsed, "deviceToken")
    propertyId = HostKitFieldText(parsed, "propertyId")
    if token <> "" then HostKitSavePair(token, propertyId)
    configText = HostKitFieldText(parsed, "configText")
    if configText = ""
        raw = HostKitLookup(parsed, "config")
        if raw <> invalid then configText = FormatJson(raw)
    end if
    if configText <> ""
        HostKitWriteCacheText(configText)
        print "HostKit: emu seeded cache"
    end if
end sub

function HostKitNowStamp() as string
    now = CreateObject("roDateTime")
    if now = invalid then return "0"
    return now.AsSeconds().ToStr()
end function

function HostKitLookup(obj as object, name as string) as object
    if obj = invalid then return invalid
    if HostKitIsAa(obj) <> true then return invalid
    return obj.Lookup(name)
end function

function HostKitFieldText(obj as object, name as string) as string
    if HostKitIsAa(obj) <> true then return ""
    value = invalid
    if obj.DoesExist(name) = true then value = obj.Lookup(name)
    if value = invalid then value = obj[name]
    if value = invalid then return ""
    kind = type(value)
    if kind = "String" or kind = "roString"
        text = ""
        text = text + value
        return text
    end if
    return ""
end function

function HostKitListHas(list as object, wanted as string) as boolean
    if HostKitIsArray(list) <> true then return false
    for each item in list
        if item = wanted then return true
    end for
    return false
end function

sub HostKitSetText(obj as object, name as string, value as string)
    if HostKitIsAa(obj) <> true then return
    obj.AddReplace(name, value)
end sub

function HostKitIsAa(obj as object) as boolean
    if obj = invalid then return false
    kind = type(obj)
    if kind = "roAssociativeArray" then return true
    if kind = "AssociativeArray" then return true
    return false
end function

function HostKitIsArray(obj as object) as boolean
    if obj = invalid then return false
    kind = type(obj)
    if kind = "roArray" then return true
    if kind = "Array" then return true
    return false
end function

function HostKitIsVersionOne(value as object) as boolean
    if HostKitInt(value) = 1 then return true
    return false
end function

function HostKitInt(value as object) as integer
    if value = invalid then return 0
    kind = type(value)
    ' Parentheses matter: otherwise `or` can swallow the comparisons.
    if (kind = "Integer") or (kind = "roInteger") or (kind = "roInt") or (kind = "LongInteger") or (kind = "roLongInteger") then return Int(value)
    if (kind = "Float") or (kind = "roFloat") or (kind = "Double") or (kind = "roDouble") then return Int(value)
    return 0
end function

function HostKitPollBackoff(currentSeconds as integer, failed as boolean) as integer
    if failed <> true then return 5
    nextWait = currentSeconds * 2
    if nextWait < 10 then nextWait = 10
    if nextWait > 30 then nextWait = 30
    return nextWait
end function

' ---------------------------------------------------------------------------
' HostKit v1 → today's guide / activities / checkout / menu documents.
' The scene then runs the existing normalizers (NormalizeGuide, SlimActivity,
' NormalizeBookDirect, etc.) so configured screens stay on one code path.
' ---------------------------------------------------------------------------

function HostKitIsPlaceholder(value as string) as boolean
    if value = "" then return true
    if Left(value, 2) <> "{{" then return false
    if Right(value, 2) <> "}}" then return false
    ' A bare {{TOKEN}} is unpublished. Mixed copy keeps its text.
    if Instr(3, value, "{{") > 0 then return false
    return true
end function

function HostKitDisplayField(obj as object, name as string) as string
    text = HostKitFieldText(obj, name)
    if HostKitIsPlaceholder(text) = true then return ""
    return text
end function

function HostKitListText(values as object) as object
    out = []
    if HostKitIsArray(values) <> true then return out
    for each entry in values
        if entry <> invalid
            holder = {}
            holder.AddReplace("v", entry)
            text = HostKitDisplayField(holder, "v")
            if text <> "" then out.Push(text)
        end if
    end for
    return out
end function

function HostKitCategoryTitle(id as string) as string
    if id = "guided-tours-and-activities" then return "Guided tours and activities"
    if id = "dining" then return "Dining"
    if id = "hiking" then return "Hiking"
    if id = "swimming" then return "Swimming"
    if id = "river-floats" then return "River Floats & Rafting"
    if id = "skiing-snowboarding" then return "Skiing & Snowboarding"
    if id = "mountain-biking" then return "Mountain Biking"
    if id = "scenic-adventures" then return "Scenic & Day Trips"
    if id = "golf-family" then return "Golf & Family Fun"
    if id = "" then return "Things to Do"
    return id
end function

function HostKitActivityLink(item as object) as string
    signup = HostKitDisplayField(item, "signupUrl")
    if signup <> "" then return signup
    return HostKitDisplayField(item, "url")
end function

function HostKitSeasonList(item as object) as object
    seasons = HostKitLookup(item, "seasons")
    if HostKitIsArray(seasons) = true then return seasons
    seasons = HostKitLookup(item, "season")
    if HostKitIsArray(seasons) = true then return seasons
    return []
end function

function HostKitActivityToLegacy(item as object) as object
    out = {}
    if HostKitIsAa(item) <> true then return out
    title = HostKitDisplayField(item, "title")
    if title = "" then title = HostKitDisplayField(item, "name")
    out["id"] = HostKitFieldText(item, "id")
    out["name"] = title
    out["description"] = HostKitFieldText(item, "description")
    out["image"] = HostKitFieldText(item, "image")
    out["imageUrl"] = HostKitFieldText(item, "imageUrl")
    out["imageTvUrl"] = HostKitFieldText(item, "imageTvUrl")
    out["imageAlt"] = HostKitFieldText(item, "imageAlt")
    out["distance"] = HostKitFieldText(item, "distance")
    out["trailDistance"] = HostKitFieldText(item, "trailDistance")
    out["difficulty"] = HostKitFieldText(item, "difficulty")
    out["gettingThere"] = HostKitFieldText(item, "gettingThere")
    out["seasonLabel"] = HostKitFieldText(item, "seasonLabel")
    out["tip"] = HostKitFieldText(item, "tip")
    out["url"] = HostKitActivityLink(item)
    out["qrUrl"] = HostKitFieldText(item, "qrUrl")
    out["season"] = HostKitSeasonList(item)
    ranks = HostKitLookup(item, "seasonRank")
    if HostKitIsAa(ranks) = true then out["seasonRank"] = ranks
    credit = HostKitLookup(item, "imageCredit")
    if HostKitIsAa(credit) = true then out["imageCredit"] = credit
    specified = HostKitLookup(item, "seasonSpecified")
    if specified <> invalid then out["seasonSpecified"] = specified
    return out
end function

function HostKitGroupActivities(items as object) as object
    sections = []
    indexById = {}
    if HostKitIsArray(items) <> true then return sections
    for each item in items
        if item <> invalid
            category = HostKitFieldText(item, "category")
            if category = "" then category = "things"
            slot = indexById.Lookup(category)
            if slot = invalid
                title = HostKitDisplayField(item, "categoryTitle")
                if title = "" then title = HostKitCategoryTitle(category)
                section = {}
                section["id"] = category
                section["title"] = title
                section["activities"] = []
                indexById.AddReplace(category, sections.Count())
                sections.Push(section)
                slot = sections.Count() - 1
            end if
            sections[slot]["activities"].Push(HostKitActivityToLegacy(item))
        end if
    end for
    return sections
end function

function HostKitFaqById(faqs as object, wanted as string) as object
    if HostKitIsArray(faqs) <> true then return invalid
    for each cat in faqs
        if cat <> invalid
            id = LCase(HostKitFieldText(cat, "id"))
            if id = wanted then return cat
        end if
    end for
    return invalid
end function

function HostKitRulesFromFaqs(faqs as object) as object
    out = []
    cat = HostKitFaqById(faqs, "house-rules")
    if cat = invalid then cat = HostKitFaqById(faqs, "rules")
    if cat = invalid then return out
    items = HostKitLookup(cat, "items")
    if HostKitIsArray(items) <> true then return out
    for each item in items
        text = HostKitDisplayField(item, "q")
        if text = "" then text = HostKitDisplayField(item, "a")
        if text <> "" then out.Push(text)
    end for
    return out
end function

function HostKitStepsFromItem(item as object) as object
    out = []
    raw = HostKitLookup(item, "steps")
    out = HostKitListText(raw)
    if out.Count() > 0 then return out
    answer = HostKitDisplayField(item, "a")
    if answer = "" then return out
    ' Split on newlines when the wizard stored steps in the answer body.
    chunk = ""
    i = 1
    limit = Len(answer)
    while i <= limit
        ch = Mid(answer, i, 1)
        if ch = Chr(10)
            text = chunk.Trim()
            if text <> "" then out.Push(text)
            chunk = ""
        else if ch <> Chr(13)
            chunk = chunk + ch
        end if
        i = i + 1
    end while
    text = chunk.Trim()
    if text <> "" then out.Push(text)
    return out
end function

function HostKitIssuesFromFaqs(faqs as object) as object
    out = []
    cat = HostKitFaqById(faqs, "quick-fixes")
    if cat = invalid then cat = HostKitFaqById(faqs, "troubleshooting")
    if cat = invalid then return out
    HostKitCollectIssues(out, HostKitLookup(cat, "items"))
    kids = HostKitLookup(cat, "categories")
    if HostKitIsArray(kids) = true
        for each child in kids
            if child <> invalid then HostKitCollectIssues(out, HostKitLookup(child, "items"))
        end for
    end if
    return out
end function

sub HostKitCollectIssues(out as object, items as object)
    if HostKitIsArray(items) <> true then return
    for each item in items
        if item <> invalid
            issue = HostKitDisplayField(item, "q")
            steps = HostKitStepsFromItem(item)
            if issue <> "" then out.Push({ issue: issue, steps: steps })
        end if
    end for
end sub

function HostKitGuideSectionsFromFaqs(faqs as object) as object
    out = []
    cat = HostKitFaqById(faqs, "guest-guide")
    if cat = invalid then return out
    kids = HostKitLookup(cat, "categories")
    if HostKitIsArray(kids) <> true then kids = []
    if kids.Count() = 0
        section = HostKitGuideSectionFromCat(cat)
        if section <> invalid then out.Push(section)
        return out
    end if
    for each child in kids
        section = HostKitGuideSectionFromCat(child)
        if section <> invalid then out.Push(section)
    end for
    return out
end function

function HostKitGuideSectionFromCat(cat as object) as object
    if HostKitIsAa(cat) <> true then return invalid
    title = HostKitDisplayField(cat, "title")
    items = []
    raw = HostKitLookup(cat, "items")
    if HostKitIsArray(raw) = true
        for each item in raw
            text = HostKitDisplayField(item, "q")
            if text = "" then text = HostKitDisplayField(item, "a")
            if text <> "" then items.Push(text)
        end for
    end if
    if title = "" and items.Count() = 0 then return invalid
    return { title: title, items: items }
end function

function HostKitSiteFromConfig(cfg as object) as object
    prop = HostKitLookup(cfg, "property")
    links = HostKitLookup(cfg, "links")
    if HostKitIsAa(prop) <> true then prop = {}
    if HostKitIsAa(links) <> true then links = {}
    hostIn = HostKitLookup(prop, "host")
    if HostKitIsAa(hostIn) <> true then hostIn = {}
    host = {}
    HostKitSetText(host, "name", HostKitDisplayField(hostIn, "name"))
    HostKitSetText(host, "email", HostKitDisplayField(hostIn, "email"))
    HostKitSetText(host, "phone", HostKitDisplayField(hostIn, "phone"))
    site = {}
    HostKitSetText(site, "name", HostKitFieldText(prop, "name"))
    HostKitSetText(site, "tagline", HostKitFieldText(prop, "tagline"))
    domain = HostKitDisplayField(links, "domain")
    if domain = "" then domain = HostKitDisplayField(prop, "domain")
    HostKitSetText(site, "domain", domain)
    HostKitSetText(site, "bookUrl", HostKitDisplayField(links, "hostToolsDirect"))
    HostKitSetText(site, "airbnbUrl", HostKitDisplayField(links, "airbnb"))
    HostKitSetText(site, "vrboUrl", HostKitDisplayField(links, "vrbo"))
    HostKitSetText(site, "checkIn", HostKitFieldText(prop, "checkIn"))
    HostKitSetText(site, "checkOut", HostKitFieldText(prop, "checkOut"))
    stats = HostKitLookup(prop, "stats")
    if HostKitIsAa(stats) = true then site["stats"] = stats
    site["host"] = host
    return site
end function

function HostKitBookFromConfig(cfg as object) as object
    branding = HostKitLookup(cfg, "branding")
    if HostKitIsAa(branding) <> true then branding = {}
    block = HostKitLookup(branding, "ad")
    book = HostKitLookup(branding, "bookDirect")
    if HostKitIsAa(book) <> true then book = {}
    links = HostKitLookup(cfg, "links")
    if HostKitIsAa(links) <> true then links = {}
    out = {}
    headlines = HostKitLookup(book, "headline")
    if HostKitIsArray(headlines) = true then out["headline"] = headlines
    HostKitSetText(out, "banner", HostKitFieldText(book, "banner"))
    HostKitSetText(out, "body", HostKitDisplayField(book, "body"))
    savings = HostKitDisplayField(book, "savingsText")
    if savings = "" and HostKitIsAa(block) = true then savings = HostKitDisplayField(block, "text")
    HostKitSetText(out, "savingsText", savings)
    HostKitSetText(out, "signOff", HostKitFieldText(book, "signOff"))
    perks = HostKitLookup(book, "perks")
    if HostKitIsArray(perks) = true then out["perks"] = perks
    siteUrl = HostKitDisplayField(book, "siteUrl")
    if siteUrl = "" then siteUrl = HostKitDisplayField(links, "website")
    HostKitSetText(out, "siteUrl", siteUrl)
    booking = HostKitDisplayField(book, "bookingUrl")
    if booking = "" then booking = HostKitDisplayField(links, "hostToolsDirect")
    HostKitSetText(out, "bookingUrl", booking)
    HostKitSetText(out, "qrImageUrl", HostKitFieldText(book, "qrImageUrl"))
    HostKitSetText(out, "bookingQrImageUrl", HostKitFieldText(book, "bookingQrImageUrl"))
    HostKitSetText(out, "photoUrl", HostKitFieldText(book, "photoUrl"))
    HostKitSetText(out, "photoTvUrl", HostKitFieldText(book, "photoTvUrl"))
    HostKitSetText(out, "homePromptTitle", HostKitFieldText(book, "homePromptTitle"))
    HostKitSetText(out, "homePromptSub", HostKitFieldText(book, "homePromptSub"))
    return out
end function

function HostKitToLegacyDocuments(cfg as object) as object
    if HostKitIsAa(cfg) <> true then return invalid
    prop = HostKitLookup(cfg, "property")
    if HostKitIsAa(prop) <> true then return invalid
    faqs = HostKitLookup(cfg, "faqs")
    checkoutIn = HostKitLookup(cfg, "checkout")
    if HostKitIsAa(checkoutIn) <> true then checkoutIn = {}
    rawMenu = HostKitLookup(cfg, "menu")
    menu = {}
    menu["version"] = 1
    if HostKitIsArray(rawMenu) = true
        menu["items"] = rawMenu
    else if HostKitIsAa(rawMenu) = true
        menu = rawMenu
    end if
    guide = {}
    guide["version"] = 1
    guide["siteConfig"] = HostKitSiteFromConfig(cfg)
    guide["houseRules"] = HostKitRulesFromFaqs(faqs)
    guide["troubleshooting"] = HostKitIssuesFromFaqs(faqs)
    guide["guestGuideSections"] = HostKitGuideSectionsFromFaqs(faqs)
    guide["quickReference"] = HostKitLookup(cfg, "quickReference")
    guide["bookDirect"] = HostKitBookFromConfig(cfg)
    checkout = {}
    checkout["version"] = 1
    HostKitSetText(checkout, "summary", HostKitDisplayField(checkoutIn, "summary"))
    HostKitSetText(checkout, "checkIn", HostKitFieldText(checkoutIn, "checkIn"))
    HostKitSetText(checkout, "checkOut", HostKitFieldText(checkoutIn, "checkOut"))
    checkout["steps"] = HostKitListText(HostKitLookup(checkoutIn, "steps"))
    activities = {}
    activities["version"] = 1
    activities["activitySections"] = HostKitGroupActivities(HostKitLookup(cfg, "activities"))
    out = {}
    out["guide"] = guide
    out["checkout"] = checkout
    out["activities"] = activities
    out["menu"] = menu
    return out
end function

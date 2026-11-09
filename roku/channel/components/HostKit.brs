' HostKit v1 helpers: pairing alphabet, FAQ flatten, activity dedupe, cache
' choice, registry token metadata, and the build-time base URL. Network I/O
' lives in HostKitTask.brs. Do not put secrets, PINs, phones, or card digits here.

function HostKitAlphabet() as string
    return "ABCDEFGH" + "JKLMNPQR" + "STUVWXYZ" + "23456789" ' pairing alphabet (no 0 O 1 I)
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

function HostKitQrCachePath() as string
    return "cachefs:/hostkit/pair-qr.png"
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

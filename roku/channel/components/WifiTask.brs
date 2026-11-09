sub init()
    m.top.functionName = "fetchWifi"
end sub

' Worker /tv/<key>/wifi.json and wifi.png. The path key and the password are never printed.
' A 503 with an empty body means the worker secrets are unset.
sub fetchWifi()
    generation = ReadWifiGeneration()
    cached = ReadWifiCache()
    if WifiCacheOk(cached)
        if cached.png = "yes" then NoteWifiPng(cached)
        PublishWifi(cached, generation)
    else
        PublishWifi(EmptyWifi("builtin", ""), generation)
    end if
    jsonUrl = WifiJsonUrl()
    pngUrl = WifiPngUrl()
    if jsonUrl = "" or pngUrl = ""
        print "Eaglewood: wifi skip reason=no-key"
        return
    end if
    print "Eaglewood: wifi request sent"
    remote = WifiHttp(jsonUrl, RememberedWifiEtag("wifiJson"), WifiJsonPath(), true)
    print "Eaglewood: wifi response code="; remote.code
    ' Build 34 (Blake b33 TV log): a 304 means "your copy is current", but the
    ' copy can be gone (cachefs is evicted). Drop the etag and fetch the body.
    if remote.reason = "not-modified" and not WifiCacheOk(ReadWifiCache())
        print "Eaglewood: wifi cache-miss refetch"
        ForgetWifiEtag("wifiJson")
        ForgetWifiEtag("wifiPng")
        remote = WifiHttp(jsonUrl, "", WifiJsonPath(), true)
        print "Eaglewood: wifi response code="; remote.code
    end if
    mode = WifiScreenMode(remote.code, WifiCacheOk(cached))
    if mode = "show" and remote.reason = "ok"
        cached = { ssid: remote.ssid, password: remote.password, png: "no", pngBytes: 0, source: "network", notice: "", jsonCode: remote.code }
        if remote.etag <> "" then print "Eaglewood: wifi etag stored"
        RememberWifiFetch("wifiJson", remote.etag)
    else if mode = "show" and remote.reason = "not-modified"
        print "Eaglewood: wifi etag match"
        if not WifiCacheOk(cached) then cached = ReadWifiCache()
        if WifiCacheOk(cached) then cached.source = "network"
    else if remote.code = 503
        print "Eaglewood: wifi kept cache="; YesNo(WifiCacheOk(cached))
    end if
    if WifiCacheOk(cached) and mode <> "coming-soon"
        print "Eaglewood: wifi png request sent"
        png = WifiHttp(pngUrl, RememberedWifiEtag("wifiPng"), WifiPngPath(), false)
        if png.reason = "not-modified" and PngFileBytes(WifiPngPath()) < 1
            print "Eaglewood: wifi png cache-miss refetch"
            ForgetWifiEtag("wifiPng")
            png = WifiHttp(pngUrl, "", WifiPngPath(), false)
        end if
        print "Eaglewood: wifi png response code="; png.code; " reason="; png.reason
        cached.pngCode = png.code
        if png.reason = "ok" or png.reason = "not-modified"
            shown = WifiPngPath()
            if png.reason = "ok" and png.stored <> invalid and png.stored <> "" then shown = png.stored
            size = PngFileBytes(shown)
            if size > 0
                cached.png = "yes"
                cached.pngBytes = size
                if png.reason = "ok" then cached.pngPath = shown
                if png.etag <> "" and png.reason = "ok" then print "Eaglewood: wifi etag stored"
                if png.reason = "not-modified" then print "Eaglewood: wifi etag match"
                RememberWifiFetch("wifiPng", png.etag)
            end if
        else
            size = PngFileBytes(WifiPngPath())
            if size > 0
                cached.png = "yes"
                cached.pngBytes = size
                cached.pngPath = WifiPngPath()
            end if
        end if
        cached.notice = ""
        if cached.source <> "network" then cached.source = "cachefs"
        if cached.png = "yes" then NoteWifiPng(cached)
        if cached.jsonCode = invalid then cached.jsonCode = remote.code
        PublishWifi(cached, generation)
    else if mode = "coming-soon"
        soon = EmptyWifi("unavailable", "coming-soon")
        soon.jsonCode = remote.code
        soon.remoteSafe = SafeUri(WifiPngUrl())
        PublishWifi(soon, generation)
        cached = soon
    else if not WifiCacheOk(cached)
        failed = EmptyWifi("builtin", "")
        failed.jsonCode = remote.code
        failed.remoteSafe = SafeUri(WifiPngUrl())
        PublishWifi(failed, generation)
        cached = failed
    end if
    shown = cached
    if not WifiCacheOk(shown) then shown = EmptyWifi("builtin", "")
    print "Eaglewood: wifi ssid len="; Len(shown.ssid)
    print "Eaglewood: wifi png bytes="; shown.pngBytes
end sub

function EmptyWifi(source as string, notice as string) as object
    return {
        ssid: "",
        password: "",
        png: "no",
        pngBytes: 0,
        source: source,
        notice: notice,
        jsonCode: 0,
        pngCode: 0,
        pngBit: 0,
        pngColor: -1,
        pngInterlace: 0,
        pngIndexed: "no",
        remoteSafe: ""
    }
end function

sub NoteWifiPng(info as object)
    if info = invalid then return
    path = WifiPngPath()
    if info.pngPath <> invalid and info.pngPath <> "" then path = info.pngPath
    prepared = ExpandPngFile(path, path)
    info.pngBit = prepared.bit
    info.pngColor = prepared.color
    info.pngInterlace = prepared.interlace
    indexed = "no"
    if prepared.converted = true or prepared.color = 3 then indexed = "yes"
    info.pngIndexed = indexed
    info.remoteSafe = SafeUri(WifiPngUrl())
    print "Eaglewood: wifi png format bitdepth="; prepared.bit; " colortype="; prepared.color; " interlace="; prepared.interlace; " indexed="; indexed
    if prepared.ok <> true
        print "Eaglewood: wifi png failure reason="; prepared.reason
        info.png = "no"
        info.pngBytes = 0
    end if
end sub

function WifiCacheOk(cached as object) as boolean
    if cached = invalid then return false
    if cached.ssid = invalid or cached.ssid = "" then return false
    return true
end function

function YesNo(flag as boolean) as string
    if flag then return "yes"
    return "no"
end function

function WifiJsonPath() as string
    return "cachefs:/eaglewood/wifi.json"
end function

function WifiPngPath() as string
    return "cachefs:/eaglewood/wifi.png"
end function

function WifiPngTempPath() as string
    return "cachefs:/eaglewood/wifi-next.png"
end function

function ReadWifiCache() as object
    EnsureWifiDir()
    text = ReadIfPresent(WifiJsonPath())
    parsed = ParseWifiDocument(text)
    if parsed = invalid then return invalid
    png = "no"
    size = PngFileBytes(WifiPngPath())
    if size > 0 then png = "yes"
    return {
        ssid: parsed.ssid,
        password: parsed.password,
        png: png,
        pngBytes: size,
        source: "cachefs",
        notice: ""
    }
end function

function ParseWifiDocument(body as object) as object
    if body = invalid then return invalid
    kind = type(body)
    if kind <> "String" and kind <> "roString" then return invalid
    if body = "" or Len(body) > 2048 then return invalid
    parsed = ParseJson(body)
    if parsed = invalid or type(parsed) <> "roAssociativeArray" then return invalid
    ssid = GuideLimitedText(AaField(parsed, "ssid"), 64)
    password = GuideLimitedText(AaField(parsed, "password"), 64)
    if ssid = "" or password = "" then return invalid
    return { ssid: ssid, password: password }
end function

function WifiHttp(url as string, etag as string, dest as string, wantJson as boolean) as object
    result = { code: 0, etag: "", reason: "no-transfer", ssid: "", password: "", bytes: 0 }
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    if transfer = invalid or port = invalid then return result
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.RetainBodyOnError(true)
    transfer.SetUrl(url)
    if etag <> "" then transfer.AddHeader("If-None-Match", etag)
    if wantJson
        transfer.AddHeader("Accept", "application/json")
        started = transfer.AsyncGetToString()
    else
        EnsureWifiDir()
        transfer.AddHeader("Accept", "image/png")
        started = transfer.AsyncGetToFile(WifiPngTempPath())
    end if
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
    result.etag = WifiHeader(event.GetResponseHeaders(), "ETag")
    if Len(result.etag) > 180 then result.etag = Left(result.etag, 180)
    if result.code = 304
        result.reason = "not-modified"
        return result
    end if
    if result.code = 503
        result.reason = "unavailable"
        return result
    end if
    if result.code = 404
        result.reason = "missing"
        return result
    end if
    if result.code <> 200
        result.reason = "http"
        print "Eaglewood: wifi failure reason="; MaskWifiSecret(OneLineWifi(event.GetFailureReason()))
        return result
    end if
    if wantJson
        body = event.GetString()
        parsed = ParseWifiDocument(body)
        if parsed = invalid
            result.reason = "bad-json"
            return result
        end if
        ' The guide task may not have made cachefs:/eaglewood yet on a cold start.
        EnsureWifiDir()
        ' Build 34: a failed cache write still shows the SSID, but keeps no
        ' etag, so the next launch cannot get a 304 for a file that is not there.
        if WriteAsciiFile(dest, body) <> true
            print "Eaglewood: wifi cache-write failed, etag not kept"
            result.etag = ""
        end if
        result.ssid = parsed.ssid
        result.password = parsed.password
        result.reason = "ok"
        return result
    end if
    size = PngFileBytes(WifiPngTempPath())
    if size < 1
        DeleteWifiFile(WifiPngTempPath())
        result.reason = "bad-png"
        return result
    end if
    stored = PromoteWifiPng()
    if stored = ""
        result.reason = "cache-write"
        return result
    end if
    result.stored = stored
    result.bytes = PngFileBytes(stored)
    result.reason = "ok"
    return result
end function

' A 200 saves a new file. wifi.png is not rewritten while a Poster points at it.
function PromoteWifiPng() as string
    try
        return CommitWifiPng()
    catch err
        print "Eaglewood: wifi png error="; WifiErrorText(err)
        return ""
    end try
end function

function WifiErrorText(err as object) as string
    print "Eaglewood: EAGLEWOOD-CAUGHT WifiErrorText"
    if err = invalid then return "failed"
    kind = type(err)
    if kind = "String" or kind = "roString" then return err
    if kind = "roAssociativeArray"
        message = err.Lookup("message")
        if message <> invalid and message <> "" then return message
    end if
    return "failed"
end function

function CommitWifiPng() as string
    data = CreateObject("roByteArray")
    if data = invalid then return ""
    if data.ReadFile(WifiPngTempPath()) <> true then return ""
    count = data.Count()
    if count = invalid or count < 8 then return ""
    m.lastPng64 = data.ToBase64String()
    busy = ""
    if m.top.busyPaths <> invalid then busy = m.top.busyPaths
    existing = QrReadLength(WifiPngPath())
    if existing = count
        DeleteWifiFile(WifiPngTempPath())
        return WifiPngPath()
    end if
    stored = CommitQrBytes("wifi", data, busy)
    if stored = invalid or stored = ""
        if data.WriteFile(WifiPngPath()) = true then stored = WifiPngPath()
    end if
    DeleteWifiFile(WifiPngTempPath())
    return stored
end function

function PngFileBytes(path as string) as integer
    fs = CreateObject("roFileSystem")
    if fs = invalid then return 0
    stat = fs.Stat(path)
    if stat = invalid then return 0
    size = stat.size
    if size = invalid then return 0
    if size < 24 or size > 500000 then return 0
    data = CreateObject("roByteArray")
    if data = invalid then return 0
    if data.ReadFile(path) <> true then return 0
    if data.Count() < 8 then return 0
    if data[0] <> 137 or data[1] <> 80 or data[2] <> 78 or data[3] <> 71 then return 0
    return data.Count()
end function

sub EnsureWifiDir()
    fs = CreateObject("roFileSystem")
    if fs <> invalid then fs.CreateDirectory("cachefs:/eaglewood")
end sub

sub DeleteWifiFile(path as string)
    if ProtectedCacheFile(path) then return
    fs = CreateObject("roFileSystem")
    if fs <> invalid then fs.Delete(path)
end sub

function WifiHeader(headers as object, name as string) as string
    if headers = invalid or type(headers) <> "roAssociativeArray" then return ""
    wanted = LCase(name)
    for each key in headers
        if LCase(key) = wanted
            return GuideLimitedText(headers.Lookup(key), 180)
        end if
    end for
    return ""
end function

function RememberedWifiEtag(prefix as string) as string
    section = CreateObject("roRegistrySection", "EaglewoodGuide")
    if section = invalid then return ""
    return GuideLimitedText(section.Read(prefix + "Etag"), 180)
end function

sub ForgetWifiEtag(prefix as string)
    section = CreateObject("roRegistrySection", "EaglewoodGuide")
    if section = invalid then return
    section.Delete(prefix + "Etag")
    section.Flush()
end sub

sub RememberWifiFetch(prefix as string, etag as string)
    if etag = invalid or etag = "" then return
    section = CreateObject("roRegistrySection", "EaglewoodGuide")
    if section = invalid then return
    section.Write(prefix + "Etag", etag)
    clock = CreateObject("roDateTime")
    stamp = "0"
    if clock <> invalid then stamp = clock.AsSeconds().ToStr()
    section.Write(prefix + "FetchedAt", stamp)
    section.Flush()
end sub

function MaskWifiSecret(text as string) as string
    if text = invalid or text = "" then return "none"
    key = GuestPathKey()
    if key = invalid or key = "" then return text
    return WifiReplace(text, key, "***")
end function

function WifiReplace(text as string, find as string, replacement as string) as string
    if find = invalid or find = "" then return text
    out = ""
    remaining = text
    guard = 0
    while guard < 8
        guard = guard + 1
        at = Instr(1, remaining, find)
        if at = 0 then return out + remaining
        if at > 1 then out = out + Left(remaining, at - 1)
        out = out + replacement
        if at + Len(find) - 1 >= Len(remaining) then return out
        remaining = Right(remaining, Len(remaining) - (at + Len(find) - 1))
    end while
    return out + remaining
end function

function OneLineWifi(text as object) as string
    if text = invalid or text = "" then return "none"
    kind = type(text)
    if kind <> "String" and kind <> "roString" then return "none"
    out = ""
    index = 1
    while index <= Len(text)
        ch = Mid(text, index, 1)
        code = Asc(ch)
        if code = 10 or code = 13
            out = out + " "
        else
            out = out + ch
        end if
        index = index + 1
    end while
    return out
end function

sub PublishWifi(info as object, generation as integer)
    if info = invalid then info = EmptyWifi("builtin", "")
    ssid = info.ssid
    if ssid = invalid then ssid = ""
    password = info.password
    if password = invalid then password = ""
    notice = info.notice
    if notice = invalid then notice = ""
    png = info.png
    if png = invalid or png = "" then png = "no"
    pngBytes = 0
    if info.pngBytes <> invalid then pngBytes = info.pngBytes
    source = info.source
    if source = invalid or source = "" then source = "builtin"
    jsonCode = 0
    if info.jsonCode <> invalid then jsonCode = info.jsonCode
    pngCode = 0
    if info.pngCode <> invalid then pngCode = info.pngCode
    pngBit = 0
    if info.pngBit <> invalid then pngBit = info.pngBit
    pngColor = -1
    if info.pngColor <> invalid then pngColor = info.pngColor
    pngInterlace = 0
    if info.pngInterlace <> invalid then pngInterlace = info.pngInterlace
    pngIndexed = info.pngIndexed
    if pngIndexed = invalid or pngIndexed = "" then pngIndexed = "no"
    remoteSafe = info.remoteSafe
    if remoteSafe = invalid or remoteSafe = "" then remoteSafe = SafeUri(WifiPngUrl())
    pngPath = ""
    if info.pngPath <> invalid then pngPath = info.pngPath
    m.top.result = {
        generation: generation,
        generationText: generation.ToStr(),
        source: source,
        ssid: ssid,
        password: password,
        png: png,
        pngBytes: pngBytes,
        png64: TaskPng64(pngPath),
        ssidLen: Len(ssid),
        notice: notice,
        jsonCode: jsonCode,
        pngCode: pngCode,
        pngBit: pngBit,
        pngColor: pngColor,
        pngInterlace: pngInterlace,
        pngIndexed: pngIndexed,
        remoteSafe: remoteSafe,
        pngPath: pngPath
    }
end sub

function ReadWifiGeneration() as integer
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

' Build 33: the task thread's view of the file, as base64, so the render
' thread can write its own copy (see FreshQrCopy).
function TaskPng64(path as string) as string
    if path = invalid or path = "" then return ""
    if m.lastPng64 <> invalid and m.lastPng64 <> "" then return m.lastPng64
    data = CreateObject("roByteArray")
    if data = invalid then return ""
    if data.ReadFile(path) <> true then return ""
    if data.Count() < 8 then return ""
    return data.ToBase64String()
end function

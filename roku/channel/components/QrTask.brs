sub init()
    m.top.functionName = "fetchQrs"
end sub

' Public QR PNGs. Same download as wifi.png: AsyncGetToFile, then a local file for Poster.
sub fetchQrs()
    if m.top.doCleanup = true
        busy = ""
        if m.top.busyPaths <> invalid then busy = m.top.busyPaths
        try
            ClearStaleQrCache(busy)
        catch err
            print "Eaglewood: qr cache error="; TaskErrorText(err)
        end try
    end if
    generation = ReadQrGeneration()
    FetchQr("badge", m.top.badgeUrl, generation)
    FetchQr("book", m.top.bookUrl, generation)
    FetchQr("detail", m.top.detailUrl, generation)
end sub

sub FetchQr(slot as string, url as string, generation as integer)
    try
        FetchQrBody(slot, url, generation)
    catch err
        print "Eaglewood: qr "; slot; " error="; TaskErrorText(err)
        PublishQr(slot, generation, url, 0, FailQr("commit"), "", 0)
        print "Eaglewood: qr "; slot; " final uri=none"
    end try
end sub

function TaskErrorText(err as object) as string
    print "Eaglewood: EAGLEWOOD-CAUGHT TaskErrorText"
    if err = invalid then return "failed"
    kind = type(err)
    if kind = "String" or kind = "roString" then return err
    if kind = "roAssociativeArray"
        message = err.Lookup("message")
        if message <> invalid and message <> "" then return message
    end if
    return "failed"
end function

sub FetchQrBody(slot as string, url as string, generation as integer)
    if url = invalid then url = ""
    if slot = invalid or slot = "" or url = "" then return
    print "Eaglewood: qr "; slot; " url="; QrExactUrl(url)
    code = 0
    prepared = invalid
    finalUri = ""
    busy = ""
    if m.top.busyPaths <> invalid then busy = m.top.busyPaths
    cached = CachedContentPath(slot, url)
    cachedBytes = 0
    if cached <> "" then cachedBytes = QrReadLength(cached)
    if slot = "badge" then LogBadgeColdStart(cached, cachedBytes, "cache")
    if QrCacheHit(cached, cachedBytes)
        print "Eaglewood: qr "; slot; " response code=cache"
        prepared = ExpandPngBytes(ReadFileBytes(cached))
        readAgain = QrReadLength(cached)
        if prepared <> invalid and prepared.ok = true and QrCacheHit(cached, readAgain)
            prepared.path = cached
            finalUri = cached
            LogQrFile(slot, "cached", FsExists(cached), readAgain)
        else
            print "Eaglewood: qr "; slot; " cache unreadable bytes="; readAgain
            prepared = invalid
            finalUri = ""
        end if
    end if
    if finalUri = ""
        print "Eaglewood: qr "; slot; " request sent"
        fetched = DownloadQrBytes(slot, url)
        code = fetched.code
        print "Eaglewood: qr "; slot; " response code="; code
        if code <> 200 or fetched.bytes = invalid
            if fetched.reason <> invalid and fetched.reason <> "" and fetched.reason <> "ok"
                print "Eaglewood: qr "; slot; " failure reason="; fetched.reason
            end if
            PublishQr(slot, generation, url, code, FailQr("http"), "", 0)
            print "Eaglewood: qr "; slot; " final uri=none"
            return
        end if
        raw = fetched.bytes
        prepared = ExpandPngBytes(AsBuf(raw))
        bytes = raw
        if prepared <> invalid and prepared.converted = true
            bytes = CopyToByteArray(prepared.bytes)
        end if
        if prepared = invalid or prepared.ok <> true or bytes = invalid
            PublishQr(slot, generation, url, code, prepared, "", 0)
            print "Eaglewood: qr "; slot; " final uri=none"
            return
        end if
        m.lastPng64 = ""
        if bytes <> invalid and bytes.Count() > 8 then m.lastPng64 = bytes.ToBase64String()
        finalUri = SaveQrBytes(slot, bytes, busy)
        if prepared <> invalid then prepared.path = finalUri
    end if
    LogQrFormat(slot, prepared)
    if LocalPosterPath(finalUri) <> true then finalUri = ""
    byteCount = 0
    if finalUri <> "" then byteCount = QrReadLength(finalUri)
    if QrCacheHit(finalUri, byteCount) <> true and code = 0
        print "Eaglewood: qr "; slot; " cache unreadable bytes="; byteCount
        prepared = invalid
        finalUri = ""
        byteCount = 0
        print "Eaglewood: qr "; slot; " request sent"
        fetched = DownloadQrBytes(slot, url)
        code = fetched.code
        print "Eaglewood: qr "; slot; " response code="; code
        if code <> 200 or fetched.bytes = invalid
            if fetched.reason <> invalid and fetched.reason <> "" and fetched.reason <> "ok"
                print "Eaglewood: qr "; slot; " failure reason="; fetched.reason
            end if
            PublishQr(slot, generation, url, code, FailQr("http"), "", 0)
            print "Eaglewood: qr "; slot; " final uri=none"
            return
        end if
        raw = fetched.bytes
        prepared = ExpandPngBytes(AsBuf(raw))
        bytes = raw
        if prepared <> invalid and prepared.converted = true
            bytes = CopyToByteArray(prepared.bytes)
        end if
        if prepared = invalid or prepared.ok <> true or bytes = invalid
            PublishQr(slot, generation, url, code, prepared, "", 0)
            print "Eaglewood: qr "; slot; " final uri=none"
            return
        end if
        m.lastPng64 = ""
        if bytes <> invalid and bytes.Count() > 8 then m.lastPng64 = bytes.ToBase64String()
        finalUri = SaveQrBytes(slot, bytes, busy)
        if prepared <> invalid then prepared.path = finalUri
        LogQrFormat(slot, prepared)
        if LocalPosterPath(finalUri) <> true then finalUri = ""
        byteCount = 0
        if finalUri <> "" then byteCount = QrReadLength(finalUri)
    end if
    if finalUri <> "" and prepared <> invalid and prepared.ok = true and QrCacheHit(finalUri, byteCount)
        WriteAsciiFile(QrNotePath(slot), url)
        WriteAsciiFile(QrPathNote(slot), finalUri)
    else if finalUri <> "" and QrCacheHit(finalUri, byteCount) <> true
        finalUri = ""
        byteCount = 0
    end if
    ' Build 33: a failed task-side write still hands its bytes to the render
    ' thread, which writes its own copy (FreshQrCopy) after the first load fails.
    if finalUri = "" and m.lastPng64 <> invalid and m.lastPng64 <> "" and prepared <> invalid and prepared.ok = true
        finalUri = "cachefs:/eaglewood/qr-" + slot + "-pending.png"
        print "Eaglewood: qr "; slot; " task write failed, render copy"
    end if
    if finalUri = ""
        print "Eaglewood: qr "; slot; " final uri=none"
    else
        print "Eaglewood: qr "; slot; " final uri="; finalUri
    end if
    PublishQr(slot, generation, url, code, prepared, finalUri, byteCount)
end sub

function LocalPosterPath(path as string) as boolean
    if path = invalid or path = "" then return false
    if Left(path, 8) = "cachefs:" then return true
    if Left(path, 4) = "tmp:" then return true
    return false
end function

function CachedContentPath(slot as string, url as string) as string
    notePath = QrNotePath(slot)
    pathNote = QrPathNote(slot)
    if FsExists(notePath) <> true or FsExists(pathNote) <> true then return ""
    note = ReadAsciiFile(notePath)
    if note = invalid or note <> url then return ""
    path = ReadAsciiFile(pathNote)
    if path = invalid or LocalPosterPath(path) <> true then return ""
    if QrCacheHit(path, QrReadLength(path)) <> true then return ""
    return path
end function

function FsExists(path as string) as boolean
    if path = invalid or path = "" then return false
    fs = CreateObject("roFileSystem")
    if fs = invalid then return false
    found = fs.Exists(path)
    if found = true then return true
    return false
end function

' Same transfer setup as WifiHttp. The body is read into memory, then WriteFile
' goes straight to the md5 name. Nothing is renamed and the dest does not end in .tmp.
function DownloadQrBytesOnce(slot as string, url as string) as object
    result = { code: 0, reason: "no-transfer", bytes: invalid }
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    if transfer = invalid or port = invalid then return result
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.RetainBodyOnError(true)
    transfer.SetUrl(url)
    EnsureQrDir()
    dest = QrFetchPath(slot)
    DeleteQrFile(dest)
    DeleteQrFile(dest + ".tmp")
    transfer.AddHeader("Accept", "image/png")
    started = transfer.AsyncGetToFile(dest)
    if started = false or started = invalid
        result.reason = "async-failed"
        return result
    end if
    event = wait(8000, port)
    if type(event) <> "roUrlEvent"
        transfer.AsyncCancel()
        DeleteQrFile(dest)
        DeleteQrFile(dest + ".tmp")
        result.reason = "timeout"
        return result
    end if
    result.code = event.GetResponseCode()
    if result.code <> 200
        reason = event.GetFailureReason()
        if reason = invalid or reason = "" then reason = "http"
        if Len(reason) > 180 then reason = Left(reason, 180)
        result.reason = reason
        DeleteQrFile(dest)
        DeleteQrFile(dest + ".tmp")
        return result
    end if
    data = CreateObject("roByteArray")
    if data = invalid or data.ReadFile(dest) <> true or data.Count() < 8
        result.reason = "bad-png"
        DeleteQrFile(dest)
        DeleteQrFile(dest + ".tmp")
        return result
    end if
    DeleteQrFile(dest)
    DeleteQrFile(dest + ".tmp")
    result.bytes = data
    result.reason = "ok"
    return result
end function

function QrFetchPath(slot as string) as string
    return "cachefs:/eaglewood/qr-fetch-" + slot + ".png"
end function

function SaveQrBytes(slot as string, raw as object, busy as string) as string
    count = 0
    if raw <> invalid and raw.Count() <> invalid then count = raw.Count()
    tag = ""
    try
        tag = PngDigestTag(raw)
    catch err
        print "Eaglewood: qr "; slot; " digest error="; TaskErrorText(err)
        tag = ""
    end try
    if tag = "" then tag = Md5Tag(raw)
    print "Eaglewood: qr "; slot; " digest="; tag
    name = QrContentFileName(slot, tag)
    if name = ""
        print "Eaglewood: qr "; slot; " WriteFile=skipped"
        print "Eaglewood: qr "; slot; " Exists=false bytes="; count
        return ""
    end if
    path = "cachefs:/eaglewood/" + name
    if EnsureParentDir(path) <> true
        print "Eaglewood: qr "; slot; " WriteFile=no-dir"
        print "Eaglewood: qr "; slot; " Exists=false bytes="; count
        return ""
    end if
    fs = CreateObject("roFileSystem")
    if fs = invalid
        print "Eaglewood: qr "; slot; " WriteFile=no-fs"
        print "Eaglewood: qr "; slot; " Exists=false bytes="; count
        return ""
    end if
    existing = QrReadLength(path)
    if existing = count and count > 0 and fs.Exists(path) = true
        LogQrFile(slot, "unchanged", true, existing)
        return path
    end if
    if PathIsBusy(path, busy) = true and existing > 0
        LogQrFile(slot, "busy", true, existing)
        return path
    end if
    if ProtectedCacheFile(path) <> true and fs.Exists(path) = true and PathIsBusy(path, busy) <> true
        fs.Delete(path)
    end if
    wrote = raw.WriteFile(path)
    found = fs.Exists(path)
    readBack = QrReadLength(path)
    LogQrFile(slot, WriteResultText(wrote), found, readBack)
    if wrote <> true or found <> true or readBack < 8 then return ""
    return path
end function

sub LogQrFile(slot as string, wrote as object, found as object, bytes as integer)
    print "Eaglewood: qr "; slot; " WriteFile="; wrote
    print "Eaglewood: qr "; slot; " Exists="; WriteResultText(found); " bytes="; bytes
end sub

function QrExactUrl(url as string) as string
    if url = invalid or url = "" then return "none"
    if Instr(1, url, "/tv/") > 0 then return SafeUri(url)
    return url
end function

sub LogQrFormat(slot as string, prepared as object)
    bit = 0
    color = -1
    interlace = 0
    indexed = "no"
    reason = "bad-png"
    if prepared <> invalid
        if prepared.bit <> invalid then bit = prepared.bit
        if prepared.color <> invalid then color = prepared.color
        if prepared.interlace <> invalid then interlace = prepared.interlace
        if prepared.converted = true or prepared.color = 3 then indexed = "yes"
        if prepared.reason <> invalid and prepared.reason <> "" then reason = prepared.reason
    end if
    print "Eaglewood: qr "; slot; " format bitdepth="; bit; " colortype="; color; " interlace="; interlace; " indexed="; indexed
    if prepared = invalid or prepared.ok <> true then print "Eaglewood: qr "; slot; " failure reason="; reason
end sub

sub PublishQr(slot as string, generation as integer, url as string, code as integer, prepared as object, path as string, bytes as integer)
    ok = "no"
    reason = "bad-png"
    bit = 0
    color = -1
    interlace = 0
    indexed = "no"
    if prepared <> invalid
        if prepared.ok = true then ok = "yes"
        if prepared.reason <> invalid and prepared.reason <> "" then reason = prepared.reason
        if prepared.bit <> invalid then bit = prepared.bit
        if prepared.color <> invalid then color = prepared.color
        if prepared.interlace <> invalid then interlace = prepared.interlace
        if prepared.converted = true or color = 3 then indexed = "yes"
    end if
    uri = path
    if uri = invalid then uri = ""
    if uri <> "" then ok = "yes"
    m.top.result = {
        generation: generation,
        generationText: generation.ToStr(),
        slot: slot,
        ok: ok,
        reason: reason,
        uri: uri,
        remote: url,
        code: code,
        bit: bit,
        color: color,
        interlace: interlace,
        indexed: indexed,
        bytes: bytes,
        png64: TaskPng64(uri)
    }
    if uri <> "" then m.top.finalUri = uri
end sub

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

function FailQr(reason as string) as object
    return { ok: false, reason: reason, bit: 0, color: -1, interlace: 0, converted: false }
end function

function QrNotePath(slot as string) as string
    if slot = "badge" or slot = "book" or slot = "detail" or slot = "wifi" then return "cachefs:/eaglewood/qr-" + slot + ".url"
    return ""
end function

function QrPathNote(slot as string) as string
    if slot = "badge" or slot = "book" or slot = "detail" or slot = "wifi" then return "cachefs:/eaglewood/qr-" + slot + ".path"
    return ""
end function

sub EnsureQrDir()
    fs = CreateObject("roFileSystem")
    if fs <> invalid then fs.CreateDirectory("cachefs:/eaglewood")
end sub

sub DeleteQrFile(path as string)
    if ProtectedCacheFile(path) then return
    fs = CreateObject("roFileSystem")
    if fs <> invalid then fs.Delete(path)
end sub

function ReadQrGeneration() as integer
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

' Build 33: the downloaded temp file can read back as other bytes in the
' emulator (same cross-thread cachefs race as the Poster load), so a body that
' is not a PNG is fetched again, up to 3 tries.
function DownloadQrBytes(slot as string, url as string) as object
    fetched = invalid
    for attempt = 1 to 3
        fetched = DownloadQrBytesOnce(slot, url)
        good = (fetched.code = 200 and fetched.bytes <> invalid)
        if good then good = (fetched.bytes.Count() >= 8 and fetched.bytes[0] = 137 and fetched.bytes[1] = 80)
        if good then return fetched
        if fetched.code <> 200 and fetched.reason <> "bad-png" then return fetched
        print "Eaglewood: qr "; slot; " download retry "; attempt; " reason="; fetched.reason
        fetched.bytes = invalid
        if fetched.reason = invalid or fetched.reason = "" or fetched.reason = "ok" then fetched.reason = "bad-png"
        sleep(200 * attempt)
    end for
    return fetched
end function

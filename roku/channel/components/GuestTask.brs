sub init()
    m.top.functionName = "fetchGuest"
end sub

' generation is set on this node before control=RUN. That write is often still
' the default 0 when this function starts, and the scene then drops the result
' for a generation mismatch. Read the field again before publishing.
sub fetchGuest()
    LogKey()
    url = GuestJsonUrl()
    if url = invalid or url = ""
        print "Eaglewood: skip reason=no-key"
        result = BlankGuestResult(0)
        result.reason = "no-key"
        m.top.result = PublishResult(result)
        return
    end if
    m.top.result = FetchGuestDocument(url)
end sub

function FetchGuestDocument(url as string) as object
    result = BlankGuestResult(0)
    target = WithCacheBuster(url)
    print "Eaglewood: url = "; RedactSecret(target)
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    if transfer = invalid or port = invalid
        print "Eaglewood: skip reason=no-transfer"
        result.reason = "no-transfer"
        return PublishResult(result)
    end if
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.RetainBodyOnError(true)
    transfer.SetUrl(target)
    print "Eaglewood: request sent"
    started = transfer.AsyncGetToString()
    if started = false or started = invalid
        print "Eaglewood: response code=0"
        print "Eaglewood: failure reason=async-start-failed"
        print "Eaglewood: skip reason=async-failed"
        result.reason = "async-failed"
        return PublishResult(result)
    end if
    event = wait(3000, port)
    if type(event) <> "roUrlEvent"
        transfer.AsyncCancel()
        print "Eaglewood: response code=0"
        print "Eaglewood: failure reason=timeout"
        print "Eaglewood: skip reason=timeout"
        result.reason = "timeout"
        return PublishResult(result)
    end if
    code = event.GetResponseCode()
    print "Eaglewood: response code="; code
    LogFailureReason(event)
    body = event.GetString()
    if body = invalid
        print "Eaglewood: body len=0 snippet="
        print "Eaglewood: skip reason=empty-body"
        result.reason = "empty-body"
        return PublishResult(result)
    end if
    print "Eaglewood: body len="; Len(body); " snippet="; BodySnippet(body)
    if Len(body) = 0
        print "Eaglewood: skip reason=empty-body"
        result.reason = "empty-body"
        return PublishResult(result)
    end if
    if Len(body) > 4096
        print "Eaglewood: skip reason=huge-body"
        result.reason = "huge-body"
        return PublishResult(result)
    end if
    if code <> 200
        print "Eaglewood: skip reason=http"
        result.reason = "http"
        return PublishResult(result)
    end if
    parsed = ParseJson(body)
    if parsed = invalid or type(parsed) <> "roAssociativeArray"
        print "Eaglewood: parse ok=no first= checkoutPresent=no"
        print "Eaglewood: checkout decision=unreadable now="; NowSeconds().ToStr()
        print "Eaglewood: skip reason=bad-json"
        result.reason = "bad-json"
        return PublishResult(result)
    end if
    result = GuestFields(parsed, 0)
    result.reason = "ok"
    LogParse(result)
    return PublishResult(result)
end function

function PublishResult(result as object) as object
    generation = ReadGeneration()
    result.generation = generation
    result.generationText = generation.ToStr()
    print "Eaglewood: generation="; result.generationText
    return result
end function

function ReadGeneration() as integer
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

sub LogKey()
    key = GuestPathKey()
    if key = invalid or key = ""
        print "Eaglewood: key loaded no"
        return
    end if
    print "Eaglewood: key loaded yes len="; Len(key)
end sub

sub LogFailureReason(event as object)
    raw = ""
    if event <> invalid
        raw = event.GetFailureReason()
    end if
    if raw = invalid or raw = "" then raw = "none"
    print "Eaglewood: failure reason="; RedactSecret(OneLine(raw))
end sub

sub LogParse(result as object)
    first = ""
    ok = "no"
    present = "no"
    checkout = ""
    if result <> invalid
        if result.firstName <> invalid then first = result.firstName
        if result.ok <> invalid then ok = result.ok
        if result.checkoutPresent <> invalid then present = result.checkoutPresent
        if result.checkout <> invalid then checkout = result.checkout
    end if
    print "Eaglewood: parse ok="; ok; " first="; first; " checkoutPresent="; present
    clockSeconds = NowSeconds()
    decision = "unreadable"
    if ok = "yes"
        presentFlag = false
        if present = "yes" then presentFlag = true
        decision = CheckoutDecision(checkout, presentFlag, clockSeconds)
    end if
    print "Eaglewood: checkout decision="; decision; " now="; clockSeconds.ToStr()
end sub

function BodySnippet(body as string) as string
    if body = invalid or body = "" then return ""
    snippet = body
    if Len(snippet) > 160 then snippet = Left(snippet, 160)
    return RedactSecret(OneLine(snippet))
end function

function OneLine(text as string) as string
    if text = invalid or text = "" then return ""
    out = ""
    index = 1
    while index <= Len(text)
        ch = CharAt(text, index)
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

function RedactSecret(text as string) as string
    if text = invalid then return ""
    key = GuestPathKey()
    if key = invalid or key = "" then return text
    return ReplaceAll(text, key, "***")
end function

function ReplaceAll(text as string, find as string, replacement as string) as string
    if text = invalid then return ""
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

function WithCacheBuster(url as string) as string
    stamp = "0"
    clock = CreateObject("roDateTime")
    if clock <> invalid then stamp = clock.AsSeconds().ToStr()
    if Instr(1, url, "?") > 0 then return url + "&t=" + stamp
    return url + "?t=" + stamp
end function

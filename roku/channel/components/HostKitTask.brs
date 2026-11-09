sub init()
    m.top.functionName = "runHostKit"
end sub

sub runHostKit()
    action = m.top.action
    result = HostKitEmptyResult(action)
    if action = "start"
        result = HostKitDoStart()
    else if action = "status"
        result = HostKitDoStatus()
    else if action = "config"
        result = HostKitDoConfig()
    else
        result.reason = "unknown-action"
    end if
    result.generation = m.top.generation
    result.action = action
    m.top.result = result
end sub

function HostKitEmptyResult(action as string) as object
    return {
        ok: "no",
        action: action,
        reason: "none",
        httpCode: 0,
        body: "",
        etag: "",
        code: "",
        shortUrl: "",
        qrUrl: "",
        qrPath: "",
        expiresAt: "",
        pollAfterMs: 5000,
        status: "",
        deviceToken: "",
        propertyId: "",
        generation: 0
    }
end function

function HostKitDoStart() as object
    result = HostKitEmptyResult("start")
    base = m.top.baseUrl
    deviceId = m.top.deviceId
    if base = invalid or base = ""
        result.reason = "no-base-url"
        return result
    end if
    if deviceId = invalid or deviceId = ""
        result.reason = "no-device-id"
        return result
    end if
    payload = FormatJson({ deviceId: deviceId })
    print "HostKit: pair start request"
    response = HostKitHttp("POST", base + "/v1/pair/start", payload, "", "")
    result.httpCode = response.code
    result.reason = response.reason
    if response.reason <> "ok"
        print "HostKit: pair start failure reason="; response.reason; " code="; response.code
        return result
    end if
    parsed = ParseJson(response.body)
    if parsed = invalid
        result.reason = "bad-json"
        return result
    end if
    result.code = HostKitFieldText(parsed, "code")
    result.shortUrl = HostKitFieldText(parsed, "shortUrl")
    result.qrUrl = HostKitFieldText(parsed, "qrUrl")
    result.expiresAt = HostKitFieldText(parsed, "expiresAt")
    result.pollAfterMs = HostKitJsonInt(parsed, "pollAfterMs", 5000)
    if HostKitCodeOk(result.code) <> true
        result.reason = "bad-code"
        print "HostKit: pair start failure reason=bad-code"
        return result
    end if
    result.ok = "yes"
    print "HostKit: pair start code="; result.code
    print "HostKit: pair url="; result.shortUrl
    qrUrl = result.qrUrl
    if qrUrl = "" and result.code <> ""
        qrUrl = base + "/v1/pair/qr?code=" + result.code
        result.qrUrl = qrUrl
    end if
    if qrUrl <> ""
        result.qrPath = HostKitDownloadQr(qrUrl, result.code)
    end if
    return result
end function

function HostKitDoStatus() as object
    result = HostKitEmptyResult("status")
    base = m.top.baseUrl
    deviceId = m.top.deviceId
    if base = invalid or base = ""
        result.reason = "no-base-url"
        return result
    end if
    if deviceId = invalid or deviceId = ""
        result.reason = "no-device-id"
        return result
    end if
    url = base + "/v1/pair/status?deviceId=" + deviceId
    response = HostKitHttp("GET", url, "", "", "")
    result.httpCode = response.code
    result.reason = response.reason
    if response.reason <> "ok"
        print "HostKit: pair status failure reason="; response.reason
        return result
    end if
    parsed = ParseJson(response.body)
    if parsed = invalid
        result.reason = "bad-json"
        return result
    end if
    result.status = HostKitFieldText(parsed, "status")
    result.deviceToken = HostKitFieldText(parsed, "deviceToken")
    result.propertyId = HostKitFieldText(parsed, "propertyId")
    result.expiresAt = HostKitFieldText(parsed, "expiresAt")
    result.pollAfterMs = HostKitJsonInt(parsed, "pollAfterMs", 5000)
    result.ok = "yes"
    print "HostKit: pair status="; result.status
    return result
end function

function HostKitDoConfig() as object
    result = HostKitEmptyResult("config")
    base = m.top.baseUrl
    token = m.top.deviceToken
    if base = invalid or base = ""
        result.reason = "no-base-url"
        return result
    end if
    if token = invalid or token = ""
        result.reason = "no-token"
        return result
    end if
    etag = m.top.etag
    if etag = invalid then etag = ""
    print "HostKit: config request sent"
    response = HostKitHttp("GET", base + "/v1/config", "", "Bearer " + token, etag)
    result.httpCode = response.code
    result.etag = response.etag
    result.reason = response.reason
    print "HostKit: config response code="; response.code
    if response.reason = "unauthorized"
        result.reason = "unauthorized"
        return result
    end if
    if response.reason = "not-modified"
        result.ok = "yes"
        result.reason = "not-modified"
        return result
    end if
    if response.reason <> "ok"
        return result
    end if
    parsed = HostKitAcceptConfigText(response.body)
    if parsed = invalid
        result.reason = "bad-config"
        return result
    end if
    result.ok = "yes"
    result.body = response.body
    result.propertyId = HostKitFieldText(parsed.property, "id")
    return result
end function

function HostKitDownloadQr(url as string, code as string) as string
    if url = invalid or url = "" then return ""
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    if transfer = invalid or port = invalid then return ""
    HostKitPrepareCacheDir()
    path = HostKitQrCachePath(code)
    fetchUrl = url
    ' Cache-bust the GET by code even if the server URL was a stable path.
    if code <> invalid and code <> "" and InStr(fetchUrl, "code=") = 0
        sep = "?"
        if InStr(fetchUrl, "?") > 0 then sep = "&"
        fetchUrl = fetchUrl + sep + "code=" + code
    end if
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.AddHeader("Cache-Control", "no-cache")
    transfer.SetUrl(fetchUrl)
    started = transfer.AsyncGetToFile(path)
    if started = false or started = invalid then return ""
    event = wait(8000, port)
    if type(event) <> "roUrlEvent" then return ""
    if event.GetResponseCode() <> 200 then return ""
    print "HostKit: pair qr saved code="; code
    return path
end function

function HostKitHttp(method as string, url as string, body as string, authorization as string, etag as string) as object
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
    transfer.AddHeader("Accept", "application/json")
    if authorization <> "" then transfer.AddHeader("Authorization", authorization)
    if etag <> "" then transfer.AddHeader("If-None-Match", etag)
    started = false
    if method = "POST"
        transfer.AddHeader("Content-Type", "application/json")
        started = transfer.AsyncPostFromString(body)
    else
        started = transfer.AsyncGetToString()
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
    result.etag = HostKitHeaderValue(event.GetResponseHeaders(), "ETag")
    bodyText = event.GetString()
    if bodyText = invalid then bodyText = ""
    if result.code = 304
        result.reason = "not-modified"
        return result
    end if
    if result.code = 401
        result.reason = "unauthorized"
        result.body = bodyText
        return result
    end if
    if result.code <> 200
        result.reason = "http"
        result.body = bodyText
        return result
    end if
    result.body = bodyText
    result.reason = "ok"
    return result
end function

function HostKitHeaderValue(headers as object, name as string) as string
    if headers = invalid then return ""
    if HostKitIsAa(headers) <> true then return ""
    wanted = LCase(name)
    found = ""
    for each key in headers
        if LCase(key) = wanted
            value = headers.Lookup(key)
            if value <> invalid then found = value
            exit for
        end if
    end for
    if Len(found) > 180 then found = Left(found, 180)
    return found
end function

function HostKitJsonInt(obj as object, name as string, fallback as integer) as integer
    value = HostKitLookup(obj, name)
    if value = invalid then return fallback
    kind = type(value)
    if kind = "Integer" or kind = "roInt" or kind = "roInteger" or kind = "Float" or kind = "roFloat" or kind = "Double" then return value
    return fallback
end function

' The live guest document is
'   <origin><path key>/guest.json
' The origin is the only copy of that address in the channel. The path key
' is not in this file. Package scripts write it into components/secrets.brs,
' which is gitignored. An empty key skips the request.
function GuestServiceOrigin() as string
    return "https://sunrivertownhome.com/tv/"
end function

function GuestJsonUrl() as string
    stub = GuestStubUrl()
    if stub <> invalid and stub <> "" then return stub
    key = GuestPathKey()
    if key = invalid or key = "" then return ""
    return GuestServiceOrigin() + key + "/guest.json"
end function

function WifiJsonUrl() as string
    return WifiAssetUrl("wifi.json")
end function

function WifiPngUrl() as string
    return WifiAssetUrl("wifi.png")
end function

function WifiAssetUrl(name as string) as string
    key = GuestPathKey()
    if key = invalid or key = "" then return ""
    return GuestServiceOrigin() + key + "/" + name
end function

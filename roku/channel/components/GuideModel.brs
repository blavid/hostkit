' Pure guide/checkout shaping. Included by the scene and by GuideTask.
' No component objects are created here. Do not print guide bodies from callers.

function ParseObjectText(text as string) as object
    if text = invalid or text = "" then return invalid
    if Len(text) > 400000 then return invalid
    parsed = ParseJson(text)
    if parsed = invalid then return invalid
    if type(parsed) <> "roAssociativeArray" then return invalid
    return parsed
end function

function GuideString(parsed as object, key as string, limit as integer) as string
    if parsed = invalid then return ""
    if type(parsed) <> "roAssociativeArray" then return ""
    value = parsed.Lookup(key)
    return GuideLimitedText(value, limit)
end function

' ParseJson keeps the key it was given. An AA literal stores qrUrl as qrurl,
' so a detail read has to accept the original name and the lowercased one.
function AaField(item as object, key as string) as object
    if item = invalid or key = invalid or key = "" then return invalid
    if type(item) <> "roAssociativeArray" then return invalid
    value = item.Lookup(key)
    if value <> invalid then return value
    lower = LCase(key)
    if lower = key then return invalid
    return item.Lookup(lower)
end function

function GuideLimitedText(value as object, limit as integer) as string
    if value = invalid then return ""
    kind = type(value)
    ' Build 37: a JSON number where text is expected (an id like 3) becomes
    ' "3" here, at the boundary, so no later = ever sees roInt vs String.
    if kind = "roInt" or kind = "Integer" or kind = "roLongInteger" or kind = "LongInteger" then return value.ToStr()
    if kind <> "String" and kind <> "roString" then return ""
    text = value.Trim()
    if text = "" then return ""
    if limit > 0 and Len(text) > limit then return Left(text, limit)
    return text
end function

function GuideInt(value as object) as integer
    if value = invalid then return 0
    kind = type(value)
    ' Parentheses matter: otherwise `or` can swallow the comparisons.
    ' roInt is the boxed integer type the brs interpreter reports.
    if (kind = "Integer") or (kind = "roInteger") or (kind = "roInt") or (kind = "LongInteger") or (kind = "roLongInteger") then return Int(value)
    if (kind = "Float") or (kind = "roFloat") or (kind = "Double") or (kind = "roDouble") then return Int(value)
    if (kind = "String") or (kind = "roString") then return Int(Val(value))
    return 0
end function

function VersionText(value as object) as string
    number = GuideInt(value)
    return number.ToStr()
end function

function StringList(value as object, maxCount as integer, maxLen as integer) as object
    items = []
    if value = invalid then return items
    kind = type(value)
    if kind <> "roArray" and kind <> "Array" then return items
    last = value.Count() - 1
    if last < 0 then return items
    for index = 0 to last
        if items.Count() >= maxCount then exit for
        text = GuideLimitedText(value[index], maxLen)
        if text <> "" then items.Push(text)
    end for
    return items
end function

function IssueList(value as object) as object
    items = []
    if value = invalid then return items
    kind = type(value)
    if kind <> "roArray" and kind <> "Array" then return items
    last = value.Count() - 1
    if last < 0 then return items
    for index = 0 to last
        if items.Count() >= 24 then exit for
        entry = value[index]
        if type(entry) = "roAssociativeArray"
            issue = GuideString(entry, "issue", 140)
            steps = StringList(entry.Lookup("steps"), 8, 420)
            if issue <> "" then items.Push({ issue: issue, steps: steps })
        end if
    end for
    return items
end function

function QuietFromRules(rules as object) as string
    if rules = invalid then return ""
    last = rules.Count() - 1
    if last < 0 then return ""
    for index = 0 to last
        text = GuideLimitedText(rules[index], 180)
        if text <> ""
            if Instr(1, LCase(text), "quiet") > 0 then return text
        end if
    end for
    return ""
end function

function CompactQuiet(text as string) as string
    if text = invalid or text = "" then return ""
    if Instr(1, LCase(text), "quiet") < 1 then return ""
    return DropMarker(text, ":00")
end function

function DropMarker(text as string, marker as string) as string
    if text = invalid or text = "" then return ""
    if marker = invalid or marker = "" then return text
    width = Len(marker)
    out = ""
    index = 1
    limit = Len(text)
    while index <= limit
        if index + width - 1 <= limit
            if Mid(text, index, width) = marker
                index = index + width
            else
                out = out + Mid(text, index, 1)
                index = index + 1
            end if
        else
            out = out + Mid(text, index, 1)
            index = index + 1
        end if
    end while
    return out
end function

function SplitTagline(tagline as string) as object
    brand = "Eaglewood"
    place = "Sunriver, Oregon"
    if tagline = invalid or tagline = "" then return { brand: brand, place: place }
    at = Instr(1, tagline, "·")
    if at < 2 then return { brand: brand, place: tagline }
    lead = Left(tagline, at - 1).Trim()
    tail = ""
    if at < Len(tagline) then tail = Right(tagline, Len(tagline) - at).Trim()
    if lead <> "" then brand = lead
    if tail <> "" then place = tail
    return { brand: brand, place: place }
end function

function NormalizeGuide(parsed as object) as object
    if parsed = invalid or type(parsed) <> "roAssociativeArray" then return invalid
    rules = StringList(parsed.Lookup("houseRules"), 16, 280)
    issues = IssueList(parsed.Lookup("troubleshooting"))
    if rules.Count() = 0 and issues.Count() = 0 then return invalid
    site = parsed.Lookup("siteConfig")
    if type(site) <> "roAssociativeArray" then site = {}
    host = site.Lookup("host")
    if type(host) <> "roAssociativeArray" then host = {}
    brandPlace = SplitTagline(GuideString(site, "tagline", 80))
    return {
        brand: brandPlace.brand,
        place: brandPlace.place,
        domain: GuideString(site, "domain", 80),
        checkIn: GuideString(site, "checkIn", 40),
        checkOut: GuideString(site, "checkOut", 40),
        quietHours: QuietFromRules(rules),
        hostName: GuideString(host, "name", 80),
        hostEmail: GuideString(host, "email", 120),
        hostPhone: GuideString(host, "phone", 40),
        rules: rules,
        issues: issues,
        guideVersion: GuideInt(parsed.Lookup("version")),
        guideSource: "builtin",
        guideCode: "0"
    }
end function

function NormalizeCheckout(parsed as object) as object
    if parsed = invalid or type(parsed) <> "roAssociativeArray" then return invalid
    steps = StringList(parsed.Lookup("steps"), 8, 220)
    summary = GuideString(parsed, "summary", 320)
    if steps.Count() = 0 and summary = "" then return invalid
    return {
        summary: summary,
        checkoutSteps: steps,
        checkIn: GuideString(parsed, "checkIn", 40),
        checkOut: GuideString(parsed, "checkOut", 40),
        checkoutVersion: GuideInt(parsed.Lookup("version")),
        checkoutSource: "builtin",
        checkoutCode: "0"
    }
end function

function FallbackGuide() as object
    rules = ["Check-in after 4:00 PM", "Check-out before 11:00 AM", "Quiet hours after 10:00 PM"]
    issues = [{
        issue: "Guide unavailable",
        steps: ["The house guide did not load. Message your host in the booking app."]
    }]
    return {
        brand: "Eaglewood",
        place: "Sunriver, Oregon",
        domain: "sunrivertownhome.com",
        checkIn: "4:00 PM",
        checkOut: "11:00 AM",
        quietHours: "Quiet hours after 10:00 PM",
        hostName: "",
        hostEmail: "",
        hostPhone: "",
        rules: rules,
        issues: issues,
        guideVersion: 0,
        guideSource: "builtin",
        guideCode: "0"
    }
end function

function FallbackCheckout() as object
    return {
        summary: "Checkout is 11:00 AM.",
        checkoutSteps: ["Start the dishwasher", "Leave used towels in the laundry room"],
        checkIn: "4:00 PM",
        checkOut: "11:00 AM",
        checkoutVersion: 0,
        checkoutSource: "builtin",
        checkoutCode: "0"
    }
end function

function BuiltinBundle() as object
    guide = FallbackGuide()
    checkout = FallbackCheckout()
    return {
        brand: guide.brand,
        place: guide.place,
        domain: guide.domain,
        checkIn: guide.checkIn,
        checkOut: guide.checkOut,
        quietHours: guide.quietHours,
        hostName: "",
        hostEmail: "",
        hostPhone: "",
        summary: checkout.summary,
        rules: guide.rules,
        issues: guide.issues,
        checkoutSteps: checkout.checkoutSteps,
        guideVersion: "0",
        guideSource: "builtin",
        guideCode: "0",
        checkoutVersion: "0",
        checkoutSource: "builtin",
        checkoutCode: "0"
    }
end function

function EncodeJson(value as object) as string
    if value = invalid then return "[]"
    text = FormatJson(value)
    if text = invalid or text = "" then return "[]"
    return text
end function

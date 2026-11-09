' Home-line and footer copy. Scene scope only (uses the guest clock helpers).

function MonthNameList() as object
    return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
end function

function WeekdayNameList() as object
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
end function

function FormatStayDate(raw as object) as string
    if raw = invalid then return ""
    kind = type(raw)
    if kind <> "String" and kind <> "roString" then return ""
    text = raw.Trim()
    if Len(text) < 10 then return ""
    if Mid(text, 5, 1) <> "-" or Mid(text, 8, 1) <> "-" then return ""
    yearText = Mid(text, 1, 4)
    monthText = Mid(text, 6, 2)
    dayText = Mid(text, 9, 2)
    if not IsDigits(yearText) or not IsDigits(monthText) or not IsDigits(dayText) then return ""
    year = Int(Val(yearText))
    month = Int(Val(monthText))
    day = Int(Val(dayText))
    if year < 2000 or year > 2037 then return ""
    if month < 1 or month > 12 then return ""
    if day < 1 or day > DaysInMonth(year, month) then return ""
    dow = WeekdayOf(year, month, day)
    if dow < 0 or dow > 6 then return ""
    months = MonthNameList()
    days = WeekdayNameList()
    return days[dow] + " " + months[month - 1] + " " + day.ToStr()
end function

function JoinDots(bits as object) as string
    if bits = invalid or bits.Count() = 0 then return ""
    line = bits[0]
    last = bits.Count() - 1
    if last < 1 then return line
    for index = 1 to last
        line = line + " · " + bits[index]
    end for
    return line
end function

function HomeStatusLine() as string
    bits = []
    dateLabel = ""
    if m.guestStay = "current" then dateLabel = FormatStayDate(m.guestCheckout)
    if dateLabel <> ""
        bits.Push("Checkout " + dateLabel)
    else
        bits.Push("Checkout")
    end if
    if m.checkOut <> invalid and m.checkOut <> "" then bits.Push(m.checkOut)
    quiet = CompactQuiet(m.quietHours)
    if quiet <> "" then bits.Push(quiet)
    return JoinDots(bits)
end function

function FooterLine() as string
    domain = "sunrivertownhome.com"
    if m.domain <> invalid and m.domain <> "" then domain = m.domain
    return domain + " · Book your next stay direct"
end function

function HostLine() as string
    bits = []
    if m.hostName <> invalid and m.hostName <> "" then bits.Push(m.hostName)
    if m.hostEmail <> invalid and m.hostEmail <> "" then bits.Push(m.hostEmail)
    if m.hostPhone <> invalid and m.hostPhone <> "" then bits.Push(m.hostPhone)
    if bits.Count() = 0 then return "Message us in your booking app."
    return JoinDots(bits)
end function

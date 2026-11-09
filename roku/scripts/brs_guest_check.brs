sub Main()
    failed = 0
    failed = failed + ExpectPart("", "")
    failed = failed + ExpectPart("   ", "")
    failed = failed + ExpectPart("Alex", "Alex")
    failed = failed + ExpectPart("Alex Rivera", "Alex Rivera")
    failed = failed + ExpectPart("Mary-Jane", "Mary-Jane")
    failed = failed + ExpectPart("O'Brien", "O'Brien")
    failed = failed + ExpectPart("O’Brien", "O'Brien")
    failed = failed + ExpectPart("A", "A")
    failed = failed + ExpectPart("A.", "A.")
    failed = failed + ExpectPart("St. James", "St. James")
    failed = failed + ExpectPart("Alex-", "Alex-")
    failed = failed + ExpectPart("O'", "O'")
    failed = failed + ExpectPart("-Alex", "-Alex")
    failed = failed + ExpectPart("Alex123", "")
    failed = failed + ExpectPart("José", "José")
    failed = failed + ExpectPart("Søren", "Søren")
    failed = failed + ExpectPart("Łukasz", "Łukasz")
    failed = failed + ExpectPart("A×B", "")
    failed = failed + ExpectPart("---", "")
    failed = failed + ExpectPart("Ann  Marie", "Ann Marie")
    letters = ""
    n = 0
    while n < 32
        letters = letters + "A"
        n = n + 1
    end while
    failed = failed + ExpectPart(letters, letters)
    failed = failed + ExpectPart(letters + "-X", letters)
    failed = failed + ExpectPart(Left(letters, 31) + "-YZ", Left(letters, 31))

    now = CheckoutSeconds("2026-10-26T15:00:00Z")
    if now = invalid
        print "FAIL could not parse the fixture instant"
        failed = failed + 1
        now = 0
    end if

    failed = failed + ExpectGreeting("Alex", "Rivera", "", false, now, "Welcome, Alex Rivera")
    failed = failed + ExpectGreeting("Alex", "", "", false, now, "Welcome, Alex")
    failed = failed + ExpectGreeting("Alex", "R2", "", false, now, "Welcome, Alex")
    failed = failed + ExpectGreeting("R2", "Rivera", "", false, now, "Welcome to Eaglewood 19")
    failed = failed + ExpectGreeting("José", "García", "2026-10-28T11:00:00-07:00", true, now, "Welcome, José García")
    failed = failed + ExpectGreeting("Mary Jane", "van Horn", "", false, now, "Welcome, Mary Jane van Horn")
    failed = failed + ExpectGreeting("Alex", "Lee", "nope", true, now, "Welcome, Alex Lee")
    failed = failed + ExpectGreeting("Alex", "Lee", "2001-01-01T00:00:00Z", true, now, "Welcome to Eaglewood 19")
    failed = failed + ExpectGreeting("Alex", "Lee", "2038-01-01T00:00:00Z", true, now, "Welcome, Alex Lee")
    failed = failed + ExpectGreeting("Alex", "Lee", "2026-02-29T00:00:00Z", true, now, "Welcome, Alex Lee")

    if CheckoutSeconds("2028-02-29T00:00:00Z") = invalid
        print "FAIL leap day rejected"
        failed = failed + 1
    end if
    ' 2026-10-28 is during Pacific Daylight Time. The plain date ends at
    ' midnight PDT, which is 07:00 UTC the next morning.
    if CheckoutSeconds("2026-10-28") <> CheckoutSeconds("2026-10-29T07:00:00Z")
        print "FAIL date-only daylight checkout"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-01-15") <> CheckoutSeconds("2026-01-16T08:00:00Z")
        print "FAIL date-only standard checkout"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-03-07") <> CheckoutSeconds("2026-03-08T08:00:00Z")
        print "FAIL day before daylight time starts"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-03-08") <> CheckoutSeconds("2026-03-09T07:00:00Z")
        print "FAIL daylight-time start day"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-31") <> CheckoutSeconds("2026-11-01T07:00:00Z")
        print "FAIL day before standard time returns"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-11-01") <> CheckoutSeconds("2026-11-02T08:00:00Z")
        print "FAIL standard-time return day"
        failed = failed + 1
    end if
    if CheckoutSeconds("2028-02-29") <> CheckoutSeconds("2028-03-01T08:00:00Z")
        print "FAIL leap-day date-only checkout"
        failed = failed + 1
    end if
    eveningBefore = CheckoutSeconds("2026-10-28T03:00:00Z")
    if StayIsCurrent("2026-10-28", true, eveningBefore) <> true
        print "FAIL evening before the Pacific checkout day"
        failed = failed + 1
    end if
    checkoutAfternoon = CheckoutSeconds("2026-10-28T22:00:00Z")
    if StayIsCurrent("2026-10-28", true, checkoutAfternoon) <> true
        print "FAIL afternoon of the Pacific checkout day"
        failed = failed + 1
    end if
    if StayIsCurrent("2026-10-28", true, CheckoutSeconds("2026-10-29T06:00:00Z")) <> true
        print "FAIL late evening of the Pacific checkout day"
        failed = failed + 1
    end if
    if StayIsCurrent("2026-10-28", true, CheckoutSeconds("2026-10-29T07:30:00Z")) <> false
        print "FAIL after Pacific midnight"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-28T11:00:00") <> CheckoutSeconds("2026-10-28T11:00:00Z")
        print "FAIL naive datetime"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-28 11:00:00") <> CheckoutSeconds("2026-10-28T11:00:00Z")
        print "FAIL space datetime"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-28t11:00:00.999z") <> CheckoutSeconds("2026-10-28T11:00:00Z")
        print "FAIL fractional or lowercase datetime"
        failed = failed + 1
    end if
    zulu = CheckoutSeconds("2026-10-28T18:00:00Z")
    if zulu <> CheckoutSeconds("2026-10-28T11:00:00-07:00")
        print "FAIL offset -07:00"
        failed = failed + 1
    end if
    if zulu <> CheckoutSeconds("2026-10-28T11:00:00-0700")
        print "FAIL offset -0700"
        failed = failed + 1
    end if
    if zulu <> CheckoutSeconds("2026-10-28T11:00:00.5-07:00")
        print "FAIL fractional offset"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-28T18:00:00+05:30") <> CheckoutSeconds("2026-10-28T12:30:00Z")
        print "FAIL offset +05:30"
        failed = failed + 1
    end if
    instant = CheckoutSeconds("2026-10-28T11:00:00Z")
    if StayIsCurrent("2026-10-28T11:00:00Z", true, instant) <> false
        print "FAIL equal instant should be past"
        failed = failed + 1
    end if
    if StayIsCurrent("2026-10-28T11:00:01Z", true, instant) <> true
        print "FAIL one second before checkout"
        failed = failed + 1
    end if
    if StayIsCurrent("", false, instant) <> true
        print "FAIL missing checkout"
        failed = failed + 1
    end if
    if StayIsCurrent("tomorrow", true, instant) <> true
        print "FAIL unreadable checkout should show the name"
        failed = failed + 1
    end if
    if CheckoutDecision("", false, instant) <> "missing"
        print "FAIL missing checkout decision"
        failed = failed + 1
    end if
    if CheckoutDecision("tomorrow", true, instant) <> "unreadable"
        print "FAIL unreadable checkout decision"
        failed = failed + 1
    end if

    ' Blake's live guest.json body. 2026-10-27 is a Pacific daylight day, so
    ' the stay ends at 2026-10-28T07:00:00Z. The evening of 2026-10-26 is current.
    liveBody = "{""firstName"":""Test"",""lastName"":""Guest"",""checkout"":""2026-10-27""}"
    live = GuestFields(ParseJson(liveBody), 5)
    if live.ok <> "yes" or live.firstName <> "Test" or live.lastName <> "Guest"
        print "FAIL live body names"
        failed = failed + 1
    end if
    if live.checkout <> "2026-10-27" or live.checkoutPresent <> "yes"
        print "FAIL live body checkout"
        failed = failed + 1
    end if
    if DaysFromCivil(1970, 1, 1) <> 0
        print "FAIL civil epoch"
        failed = failed + 1
    end if
    if CheckoutSeconds("2000-01-01T00:00:00Z") <> 946684800
        print "FAIL year 2000 epoch"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-26T22:02:58Z") <> 1793052178
        print "FAIL device clock instant"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-27") <> 1793170800
        print "FAIL live checkout instant"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-27") <> CheckoutSeconds("2026-10-28T07:00:00Z")
        print "FAIL live checkout does not match the next Pacific midnight"
        failed = failed + 1
    end if
    ' The TV's clock when build 5 logged the unreadable date.
    deviceNow = 1793052178
    liveText = GreetingFromGuestAt(live.firstName, live.lastName, live.checkout, true, deviceNow)
    if liveText <> "Welcome, Test Guest"
        print "FAIL live body at the device clock"
        failed = failed + 1
    end if
    if CheckoutDecision(live.checkout, true, deviceNow) <> "current"
        print "FAIL live body decision at the device clock"
        failed = failed + 1
    end if
    if GreetingFromGuestAt("Test", "Guest", "2026-10-27", true, 1793170800) <> "Welcome to Eaglewood 19"
        print "FAIL hide at Pacific midnight"
        failed = failed + 1
    end if
    if CheckoutDecision("2026-10-27", true, 1793170800) <> "past"
        print "FAIL midnight decision"
        failed = failed + 1
    end if
    if GreetingFromGuestAt("Test", "Guest", "2026-10-27", true, 1793174400) <> "Welcome to Eaglewood 19"
        print "FAIL hide after Pacific midnight"
        failed = failed + 1
    end if
    if GreetingFromGuestAt("Test", "Guest", "not-a-date", true, deviceNow) <> "Welcome, Test Guest"
        print "FAIL malformed checkout should show the name"
        failed = failed + 1
    end if
    if CheckoutDecision("not-a-date", true, deviceNow) <> "unreadable"
        print "FAIL malformed checkout decision"
        failed = failed + 1
    end if
    if StayIsCurrent("2026-10-27", true, CheckoutSeconds("2026-10-27T22:00:00Z")) <> true
        print "FAIL live checkout afternoon"
        failed = failed + 1
    end if
    if StayIsCurrent("2026-10-27", true, CheckoutSeconds("2026-10-28T06:30:00Z")) <> true
        print "FAIL live checkout late evening"
        failed = failed + 1
    end if
    if StayIsCurrent("2026-10-27", true, CheckoutSeconds("2026-10-28T07:00:00Z")) <> false
        print "FAIL live checkout at pacific midnight"
        failed = failed + 1
    end if

    parsed = ParseJson("{""firstName"":""Mary"",""lastName"":""O'Brien"",""checkout"":"""",""phone"":""5550000000"",""note"":""secret""}")
    fields = GuestFields(parsed, 7)
    if fields.ok <> "yes" or fields.firstName <> "Mary" or fields.lastName <> "O'Brien"
        print "FAIL json names"
        failed = failed + 1
    end if
    if fields.checkoutPresent <> "no" or fields.generation <> 7
        print "FAIL blank checkout field"
        failed = failed + 1
    end if
    if fields.DoesExist("phone") or fields.DoesExist("note")
        print "FAIL extra json fields were kept"
        failed = failed + 1
    end if
    bad = GuestFields(ParseJson("{""checkout"":12}"), 1)
    if bad.checkoutPresent <> "yes"
        print "FAIL numeric checkout"
        failed = failed + 1
    end if
    empty = GuestFields(ParseJson("{}"), 1)
    if empty.ok <> "yes" or empty.firstName <> "" or empty.checkoutPresent <> "no"
        print "FAIL empty object"
        failed = failed + 1
    end if
    if GuestFields(invalid, 1).ok <> "no"
        print "FAIL invalid json"
        failed = failed + 1
    end if

    wide = WrapGreeting("hello world", 50, invalid, 10)
    if wide.Count() <> 2 or wide[0] <> "hello" or wide[1] <> "world"
        print "FAIL wrap on space"
        failed = failed + 1
    end if
    hyphenated = WrapGreeting("hello-world", 60, invalid, 10)
    if hyphenated.Count() <> 2 or hyphenated[0] <> "hello-" or hyphenated[1] <> "world"
        print "FAIL wrap on hyphen"
        failed = failed + 1
    end if
    one = WrapGreeting("Welcome to Eaglewood 19", 1760, invalid, FallbackCharWidth(64))
    if one.Count() <> 1
        print "FAIL fallback should be one line"
        failed = failed + 1
    end if
    crowded = ""
    i = 0
    while i < 40
        crowded = crowded + "M"
        i = i + 1
    end while
    huge = WrapGreeting("Welcome, " + crowded + " " + crowded, 1760, invalid, FallbackCharWidth(64))
    smaller = WrapGreeting("Welcome, " + crowded + " " + crowded, 1760, invalid, FallbackCharWidth(34))
    if huge.Count() <= 2
        print "FAIL long name should not fit at the large fallback width"
        failed = failed + 1
    end if
    if smaller.Count() > 2
        print "FAIL long name should fit within two lines at the smallest size"
        failed = failed + 1
    end if
    single = GreetingBarBox(1, 64)
    if single.barTop <> 800 or single.barHeight <> 160
        print "FAIL single-line bar"
        failed = failed + 1
    end if
    grown = GreetingBarBox(2, 80)
    if grown.barHeight <= 160 or grown.barTop <> 960 - grown.barHeight
        print "FAIL two-line bar"
        failed = failed + 1
    end if

    if failed = 0
        print "brs guest checks passed"
    else
        print "brs guest checks failed"
    end if
end sub

function ExpectPart(input as string, expect as string) as integer
    actual = SanitizeNamePart(input)
    if actual <> expect
        print "FAIL part [" ; input ; "] got [" ; actual ; "] want [" ; expect ; "]"
        return 1
    end if
    return 0
end function

function ExpectGreeting(firstName as string, lastName as string, checkout as string, present as boolean, nowSeconds as integer, expect as string) as integer
    actual = GreetingFromGuestAt(firstName, lastName, checkout, present, nowSeconds)
    if actual <> expect
        print "FAIL greeting got [" ; actual ; "] want [" ; expect ; "]"
        return 1
    end if
    return 0
end function

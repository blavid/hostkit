sub Main()
    failed = 0
    key = GuestPathKey()
    if key = invalid or key = ""
        print "FAIL packaged key empty"
        failed = failed + 1
    end if
    url = GuestJsonUrl()
    expect = ""
    if key <> invalid then expect = GuestServiceOrigin() + key + "/guest.json"
    if url <> expect
        print "FAIL packaged url"
        failed = failed + 1
    end if
    masked = RedactSecret(url + "?t=99")
    if key <> invalid and key <> ""
        if Instr(1, masked, key) > 0
            print "FAIL redact left the key in place"
            failed = failed + 1
        end if
    end if
    if Instr(1, masked, "***") < 1 or Instr(1, masked, "/guest.json?t=99") < 1
        print "FAIL redact shape"
        failed = failed + 1
    end if
    if Instr(1, masked, GuestServiceOrigin()) < 1
        print "FAIL redact origin"
        failed = failed + 1
    end if

    body = "{""firstName"":""Test"",""lastName"":""Guest"",""checkout"":""2026-10-27""}"
    fields = GuestFields(ParseJson(body), 5)
    if fields.ok <> "yes" or fields.firstName <> "Test" or fields.lastName <> "Guest"
        print "FAIL packaged names"
        failed = failed + 1
    end if
    if fields.checkout <> "2026-10-27" or fields.checkoutPresent <> "yes"
        print "FAIL packaged checkout field"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-27") <> CheckoutSeconds("2026-10-28T07:00:00Z")
        print "FAIL packaged pacific end"
        failed = failed + 1
    end if
    if CheckoutSeconds("2026-10-27") <> 1793170800
        print "FAIL packaged checkout instant"
        failed = failed + 1
    end if
    deviceNow = 1793052178
    text = GreetingFromGuestAt(fields.firstName, fields.lastName, fields.checkout, true, deviceNow)
    if text <> "Welcome, Test Guest"
        print "FAIL packaged greeting"
        failed = failed + 1
    end if
    if CheckoutDecision(fields.checkout, true, deviceNow) <> "current"
        print "FAIL packaged decision"
        failed = failed + 1
    end if
    if GreetingFromGuestAt("Test", "Guest", "2026-10-27", true, 1793174400) <> "Welcome to Eaglewood 19"
        print "FAIL packaged after midnight"
        failed = failed + 1
    end if
    if GreetingFromGuestAt("Test", "Guest", "not-a-date", true, deviceNow) <> "Welcome, Test Guest"
        print "FAIL packaged malformed checkout"
        failed = failed + 1
    end if
    afternoon = CheckoutSeconds("2026-10-27T22:00:00Z")
    if GreetingFromGuestAt("Test", "Guest", "2026-10-27", true, afternoon) <> "Welcome, Test Guest"
        print "FAIL packaged afternoon"
        failed = failed + 1
    end if

    if failed = 0
        print "packaged live guest ok"
    else
        print "packaged live guest failed"
    end if
end sub

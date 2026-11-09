' Unit checks for HostKit loader helpers. Run with test_hostkit.sh (brs 0.45).

sub main()
    failed = 0
    failed = failed + CheckCodes()
    failed = failed + CheckDedupe()
    failed = failed + CheckFlatten()
    failed = failed + CheckCacheChoice()
    failed = failed + CheckNormalize()
    failed = failed + CheckLegacyMap()
    if failed = 0
        print "brs hostkit checks passed"
    else
        print "brs hostkit checks failed count="; failed
    end if
end sub

function CheckCodes() as integer
    failed = 0
    if HostKitCodeOk("ABC234") <> true then failed = failed + Fail("valid ABC234")
    if HostKitCodeOk("abc234") <> true then failed = failed + Fail("valid lowercase")
    if HostKitCodeOk("AB0CDE") <> false then failed = failed + Fail("reject 0")
    if HostKitCodeOk("ABOCDE") <> false then failed = failed + Fail("reject O")
    if HostKitCodeOk("AB1CDE") <> false then failed = failed + Fail("reject 1")
    if HostKitCodeOk("ABICDE") <> false then failed = failed + Fail("reject I")
    if HostKitCodeOk("ABC23") <> false then failed = failed + Fail("reject short")
    if HostKitCodeOk("ABC2345") <> false then failed = failed + Fail("reject long")
    if HostKitCodeOk("") <> false then failed = failed + Fail("reject empty")
    if HostKitCodeOk(invalid) <> false then failed = failed + Fail("reject invalid")
    alphabet = HostKitAlphabet()
    if InStr(1, alphabet, "0") <> 0 then failed = failed + Fail("alphabet 0")
    if InStr(1, alphabet, "O") <> 0 then failed = failed + Fail("alphabet O")
    if InStr(1, alphabet, "1") <> 0 then failed = failed + Fail("alphabet 1")
    if InStr(1, alphabet, "I") <> 0 then failed = failed + Fail("alphabet I")
    if InStr(1, alphabet, "L") <> 0 then failed = failed + Fail("alphabet L")
    if HostKitCodeOk("ABL234") <> false then failed = failed + Fail("reject L")
    seed = 1
    while seed <= 80
        code = HostKitMakeCode(seed)
        if HostKitCodeOk(code) <> true
            failed = failed + Fail("generated " + code)
        end if
        seed = seed + 1
    end while
    return failed
end function

function CheckDedupe() as integer
    failed = 0
    items = []
    items.Push({ id: "trail-a", title: "First" })
    items.Push({ id: "trail-b", title: "Second" })
    items.Push({ id: "trail-a", title: "Duplicate should drop" })
    items.Push({ id: "trail-c", title: "Third" })
    items.Push({ id: "trail-b", title: "Another dup" })
    out = HostKitDedupeActivities(items)
    if out.Count() <> 3 then failed = failed + Fail("dedupe count")
    if out[0].title <> "First" then failed = failed + Fail("dedupe first wins")
    if out[1].id <> "trail-b" then failed = failed + Fail("dedupe second id")
    if out[2].id <> "trail-c" then failed = failed + Fail("dedupe third id")
    empty = HostKitDedupeActivities(invalid)
    if empty.Count() <> 0 then failed = failed + Fail("dedupe invalid")
    return failed
end function

function CheckFlatten() as integer
    failed = 0
    faqs = []
    faqs.Push({
        id: "house-rules",
        title: "House Rules",
        items: [{ q: "Pets?", a: "No." }],
        categories: []
    })
    faqs.Push({
        id: "quick-fixes",
        title: "Quick Fixes",
        items: [{ q: "Wi-Fi?", a: "See the card." }],
        categories: [{
            id: "nested-demo",
            title: "Nested",
            items: [{ q: "Depth 2", a: "Keep as a child category." }],
            categories: [{
                id: "too-deep",
                title: "Depth 3",
                items: [{ q: "Too deep", a: "Flatten into parent." }],
                categories: []
            }]
        }]
    })
    out = HostKitFlattenFaqs(faqs)
    if out.Count() <> 2 then failed = failed + Fail("flatten top count")
    if out[0].categories.Count() <> 0 then failed = failed + Fail("house-rules stays flat")
    kids = out[1].categories
    if kids.Count() <> 1 then failed = failed + Fail("quick-fixes keeps one child")
    if kids[0].id <> "nested-demo" then failed = failed + Fail("child id")
    if kids[0].categories.Count() <> 0 then failed = failed + Fail("depth 3 categories removed")
    if kids[0].items.Count() <> 2 then failed = failed + Fail("depth 3 items merged")
    merged = kids[0].items[1]
    if InStr(1, merged.q, "Too deep") = 0 then failed = failed + Fail("merged question")
    if InStr(1, merged.q, "Depth 3") = 0 then failed = failed + Fail("merged prefix")
    return failed
end function

function CheckCacheChoice() as integer
    failed = 0
    if HostKitChooseSource(true, "ok", false) <> "network" then failed = failed + Fail("choose network")
    if HostKitChooseSource(false, "not-modified", true) <> "cachefs" then failed = failed + Fail("choose 304 cache")
    if HostKitChooseSource(false, "timeout", true) <> "cachefs" then failed = failed + Fail("choose offline cache")
    if HostKitChooseSource(false, "timeout", false) <> "none" then failed = failed + Fail("choose none")
    if HostKitChooseSource(true, "ok", true) <> "network" then failed = failed + Fail("choose network over cache")
    return failed
end function

function CheckNormalize() as integer
    failed = 0
    text = "{""schemaVersion"":1,""property"":{""id"":""eaglewood"",""name"":""Sample""},""faqs"":[{""id"":""root"",""title"":""Root"",""items"":[],""categories"":[{""id"":""mid"",""title"":""Mid"",""items"":[{""q"":""M"",""a"":""1""}],""categories"":[{""id"":""deep"",""title"":""Deep"",""items"":[{""q"":""D"",""a"":""2""}]}]}]}],""activities"":[{""id"":""a"",""title"":""One""},{""id"":""a"",""title"":""Two""}],""web"":{""theme"":""should-ignore""}}"
    cfg = HostKitAcceptConfigText(text)
    if cfg = invalid then return Fail("normalize parse")
    if cfg.schemaVersion <> 1 then failed = failed + Fail("normalize version")
    if cfg.property.id <> "eaglewood" then failed = failed + Fail("normalize property")
    if cfg.activities.Count() <> 1 then failed = failed + Fail("normalize dedupe")
    if cfg.activities[0].title <> "One" then failed = failed + Fail("normalize first wins")
    if cfg.Lookup("web") <> invalid then failed = failed + Fail("normalize drops web")
    mid = cfg.faqs[0].categories[0]
    if mid.categories.Count() <> 0 then failed = failed + Fail("normalize flatten")
    if mid.items.Count() <> 2 then failed = failed + Fail("normalize merged items")
    bad = HostKitAcceptConfigText("{""schemaVersion"":2,""property"":{""id"":""x""}}")
    if bad <> invalid then failed = failed + Fail("reject major version")
    return failed
end function

function CheckLegacyMap() as integer
    failed = 0
    text = "{""schemaVersion"":1,""property"":{""id"":""eaglewood"",""name"":""Sunriver Townhome"",""tagline"":""Eaglewood · Sunriver, Oregon"",""checkIn"":""4:00 PM"",""checkOut"":""11:00 AM"",""host"":{""name"":""Blake Clough"",""email"":""{{HOST_EMAIL}}"",""phone"":""{{HOST_PHONE}}""}},""links"":{""hostToolsDirect"":""https://book.sunrivertownhome.com"",""website"":""https://sunrivertownhome.com"",""domain"":""sunrivertownhome.com""},""faqs"":[{""id"":""house-rules"",""title"":""House Rules"",""items"":[{""q"":""Check-in after 4:00 PM"",""a"":""Check-in after 4:00 PM""},{""q"":""Dogs only, limited to one dog"",""a"":""Dogs only, limited to one dog""}]},{""id"":""quick-fixes"",""title"":""Quick Fixes"",""items"":[{""q"":""Circuit breaker tripped"",""a"":""Find the panel."",""steps"":[""Locate the panel."",""Reset the breaker.""]}]}],""activities"":[{""id"":""viator-ebike-tour"",""title"":""Electric Bike Tour"",""category"":""guided-tours-and-activities"",""categoryTitle"":""Guided tours and activities"",""signupUrl"":""https://www.viator.com/tours/example"",""qrUrl"":""https://sunrivertownhome.com/data/qr/viator-ebike-tour.png"",""seasons"":[""year-round""]},{""id"":""hot-lava-bakery"",""title"":""Hot Lava Bakery"",""category"":""dining"",""url"":""https://www.hotlavabakery.com/""},{""id"":""viator-ebike-tour"",""title"":""Duplicate should already be gone"",""category"":""golf-family""}],""checkout"":{""summary"":""Checkout is 11:00 AM."",""checkIn"":""4:00 PM"",""checkOut"":""11:00 AM"",""steps"":[""Start the dishwasher"",""{{CHECKOUT_SECRET}}""]},""branding"":{""colors"":{},""bookDirect"":{""body"":""Our website has lots of great information about the house, local activities, dining, outdoor adventures and more!"",""homePromptTitle"":""Book direct & save"",""bookingUrl"":""https://book.sunrivertownhome.com""}},""menu"":[{""id"":""home"",""label"":""Home"",""type"":""home""},{""id"":""todo"",""label"":""Things to Do"",""type"":""things"",""children"":[{""id"":""dining"",""label"":""Dining""}]}]}"
    cfg = HostKitAcceptConfigText(text)
    if cfg = invalid then return Fail("legacy parse")
    docs = HostKitToLegacyDocuments(cfg)
    if docs = invalid then return Fail("legacy docs")
    rules = docs.guide.houseRules
    if rules.Count() <> 2 then failed = failed + Fail("legacy rules count")
    if rules[1] <> "Dogs only, limited to one dog" then failed = failed + Fail("legacy rule text")
    issues = docs.guide.troubleshooting
    if issues.Count() <> 1 then failed = failed + Fail("legacy issues count")
    if issues[0].issue <> "Circuit breaker tripped" then failed = failed + Fail("legacy issue title")
    if issues[0].steps.Count() <> 2 then failed = failed + Fail("legacy issue steps")
    sections = docs.activities.activitySections
    if sections.Count() <> 2 then failed = failed + Fail("legacy section count")
    if sections[0].id <> "guided-tours-and-activities" then failed = failed + Fail("legacy first section")
    if sections[0].title <> "Guided tours and activities" then failed = failed + Fail("legacy section title")
    tour = sections[0].activities[0]
    if tour.name <> "Electric Bike Tour" then failed = failed + Fail("legacy activity title")
    if tour.url <> "https://www.viator.com/tours/example" then failed = failed + Fail("legacy signupUrl becomes url")
    if sections[1].id <> "dining" then failed = failed + Fail("legacy dining section")
    if sections[1].activities[0].url <> "https://www.hotlavabakery.com/" then failed = failed + Fail("legacy info url")
    if docs.checkout.steps.Count() <> 1 then failed = failed + Fail("legacy placeholder step dropped")
    if docs.checkout.steps[0] <> "Start the dishwasher" then failed = failed + Fail("legacy checkout step")
    host = docs.guide.siteConfig.host
    if host.name <> "Blake Clough" then failed = failed + Fail("legacy host name")
    if host.email <> "" then failed = failed + Fail("legacy host email placeholder dropped")
    if host.phone <> "" then failed = failed + Fail("legacy host phone placeholder dropped")
    if docs.guide.bookDirect.body <> "Our website has lots of great information about the house, local activities, dining, outdoor adventures and more!" then failed = failed + Fail("legacy book body")
    if docs.guide.bookDirect.homePromptTitle <> "Book direct & save" then failed = failed + Fail("legacy prompt title")
    if docs.menu.items.Count() <> 2 then failed = failed + Fail("legacy menu count")
    if HostKitIsPlaceholder("{{HOST_EMAIL}}") <> true then failed = failed + Fail("placeholder token")
    if HostKitIsPlaceholder("Blake Clough") <> false then failed = failed + Fail("real name not placeholder")
    return failed
end function

function Fail(name as string) as integer
    print "FAIL "; name
    return 1
end function

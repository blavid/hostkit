' Unit checks for HostKit loader helpers. Run with test_hostkit.sh (brs 0.45).

sub main()
    failed = 0
    failed = failed + CheckCodes()
    failed = failed + CheckDedupe()
    failed = failed + CheckFlatten()
    failed = failed + CheckCacheChoice()
    failed = failed + CheckNormalize()
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

function Fail(name as string) as integer
    print "FAIL "; name
    return 1
end function

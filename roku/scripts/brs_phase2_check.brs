sub Main()
    failed = 0
    failed = failed + ExpectSeason(1772348400, 2, 23, "winter")
    failed = failed + ExpectSeason(1772353800, 3, 0, "spring")
    failed = failed + ExpectHour(1772962200, 3, 8, 1, 8)
    failed = failed + ExpectHour(1772965800, 3, 8, 3, 7)
    failed = failed + ExpectSeason(1780293600, 5, 23, "spring")
    failed = failed + ExpectSeason(1780299000, 6, 0, "summer")
    failed = failed + ExpectSeason(1793138400, 10, 15, "fall")
    failed = failed + ExpectSeason(1796113800, 12, 0, "winter")
    failed = failed + ExpectDay(1798788600, 2026, 12, 31, 23)

    early = { sourceIndex: 1, seasonRank: { fall: 2 } }
    later = { sourceIndex: 2, seasonRank: { fall: 1 } }
    missing = { sourceIndex: 0, seasonRank: { fall: 0 } }
    if CompareSeasonRank("fall", early, later, 1, 2) <= 0
        print "FAIL a higher seasonRank sorted first"
        failed = failed + 1
    end if
    if CompareSeasonRank("fall", later, early, 2, 1) >= 0
        print "FAIL a lower seasonRank did not sort first"
        failed = failed + 1
    end if
    if CompareSeasonRank("fall", missing, later, 0, 2) <= 0
        print "FAIL a missing rank sorted ahead of a ranked activity"
        failed = failed + 1
    end if
    tiedA = { sourceIndex: 4, seasonRank: { fall: 3 } }
    tiedB = { sourceIndex: 9, seasonRank: { fall: 3 } }
    if CompareSeasonRank("fall", tiedB, tiedA, 9, 4) <= 0
        print "FAIL equal ranks did not keep the earlier source index first"
        failed = failed + 1
    end if

    sorted = SortActivities([early, missing, later], "fall")
    if sorted.Count() <> 3 or SourceIndexOf(sorted[0]) <> 2 or SourceIndexOf(sorted[1]) <> 1 or SourceIndexOf(sorted[2]) <> 0
        print "FAIL sort order was not rank, then source index"
        failed = failed + 1
    end if

    dupes = NormalizeActivities({
        version: 4,
        activitySections: [
            { id: "guided-tours-and-activities", activities: [Sample("viator-ebike-tour", "https://example.com/a")] },
            { id: "golf-family", activities: [Sample("viator-ebike-tour", "https://example.com/a")] }
        ]
    })
    if dupes = invalid or dupes.items.Count() <> 2
        print "FAIL duplicate activity ids were collapsed"
        failed = failed + 1
    else
        if dupes.items[0].id <> dupes.items[1].id
            print "FAIL duplicate ids were rewritten"
            failed = failed + 1
        end if
        if SourceIndexOf(dupes.items[0]) = SourceIndexOf(dupes.items[1])
            print "FAIL duplicate ids share a source index"
            failed = failed + 1
        end if
        if CardNodeId(dupes.items[0]) = CardNodeId(dupes.items[1])
            print "FAIL card nodes would share an id"
            failed = failed + 1
        end if
    end if

    if ResolveContentUrl("/images/tv/a.jpg") <> "https://sunrivertownhome.com/images/tv/a.jpg"
        print "FAIL a root-relative URL did not resolve"
        failed = failed + 1
    end if
    if ResolveContentUrl("images/tv/a.jpg") <> "https://sunrivertownhome.com/images/tv/a.jpg"
        print "FAIL a relative URL did not resolve"
        failed = failed + 1
    end if
    absolute = "https://sunrivertownhome.com/images/tv/a.jpg"
    if ResolveContentUrl(absolute) <> absolute
        print "FAIL an absolute URL was rewritten"
        failed = failed + 1
    end if

    tv = ActivityPoster({ imageTvUrl: "/images/tv/place.jpg", imageUrl: "https://cdn.example/place.webp" })
    if tv.poster <> "https://sunrivertownhome.com/images/tv/place.jpg"
        print "FAIL imageTvUrl did not win"
        failed = failed + 1
    end if
    webp = ActivityPoster({ imageUrl: "https://cdn.example/place.webp" })
    if webp.poster <> ""
        print "FAIL a webp imageUrl was accepted"
        failed = failed + 1
    end if
    gif = ActivityPoster({ imageTvUrl: "https://cdn.example/place.gif", imageUrl: "https://cdn.example/place.avif" })
    if gif.poster <> ""
        print "FAIL a gif or avif poster was accepted"
        failed = failed + 1
    end if
    png = ActivityPoster({ imageUrl: "https://cdn.example/place.png" })
    if png.poster <> "https://cdn.example/place.png"
        print "FAIL a png imageUrl was rejected"
        failed = failed + 1
    end if

    if ActivityQr({ id: "cafe", qrUrl: "/data/qr/cafe.png", affiliateUrl: "https://affiliate.example/cafe" }) <> ""
        print "FAIL a QR was built without url"
        failed = failed + 1
    end if
    linked = ActivityQr({ id: "cafe", url: "https://cafe.example", qrUrl: "/data/qr/cafe.png", affiliateUrl: "https://affiliate.example/cafe" })
    if linked <> "https://sunrivertownhome.com/data/qr/cafe.png?v=rgb2"
        print "FAIL qrUrl was not resolved from url"
        failed = failed + 1
    end if
    joined = WithQrVersion("https://sunrivertownhome.com/data/qr/cafe.png?x=1")
    if joined <> "https://sunrivertownhome.com/data/qr/cafe.png?x=1&v=rgb2"
        print "FAIL a QR query was not joined with &"
        failed = failed + 1
    end if
    kept = WithQrVersion("https://sunrivertownhome.com/data/qr/cafe.png?v=rgb2")
    if kept <> "https://sunrivertownhome.com/data/qr/cafe.png?v=rgb2"
        print "FAIL the QR version was added twice"
        failed = failed + 1
    end if
    other = WithQrVersion("https://cdn.example/place.png")
    if other <> "https://cdn.example/place.png"
        print "FAIL a non-QR image gained a version"
        failed = failed + 1
    end if
    wifiUrl = WithQrVersion("https://cdn.example/tv/wifi.png")
    if wifiUrl <> "https://cdn.example/tv/wifi.png"
        print "FAIL a Wi-Fi URL gained a version"
        failed = failed + 1
    end if
    derived = ActivityQr({ id: "cafe", url: "https://cafe.example" })
    if derived <> ""
        print "FAIL a missing qrUrl still built a QR"
        failed = failed + 1
    end if
    norm = NormalizeActivities({
        version: 4,
        activitySections: [{
            id: "guided-tours-and-activities",
            activities: [{
                id: "viator-ebike-tour",
                name: "Electric Bike Tour",
                url: "https://www.viator.com/tours/Bend/example",
                qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png"
            }]
        }]
    })
    if norm = invalid or norm.items.Count() <> 1
        print "FAIL the detail activity did not normalize"
        failed = failed + 1
    else
        item = norm.items[0]
        wanted = "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png?v=rgb2"
        if item.qrUrl <> wanted or item.qrUri <> wanted or DetailQrUrl(item) <> wanted
            print "FAIL qrUrl was not passed to the detail item"
            failed = failed + 1
        end if
    end if
    stale = { items: [{ id: "viator-ebike-tour", qrUri: "" }] }
    fresh = { items: [{ id: "viator-ebike-tour", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png?v=rgb2" }] }
    picked = ChooseActivities(stale, fresh)
    if picked = invalid or picked.items[0].qrUrl = ""
        print "FAIL a cache without qrUrl beat the bundled snapshot"
        failed = failed + 1
    end if
    kept = ChooseActivities(fresh, stale)
    if kept = invalid or kept.items[0].qrUrl <> fresh.items[0].qrUrl
        print "FAIL a cache with qrUrl was discarded"
        failed = failed + 1
    end if
    raw304 = {
        version: 4,
        activitySections: [{
            id: "guided-tours-and-activities",
            activities: [
                { id: "viator-ebike-tour", name: "First tour", url: "https://example.com/a", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png" },
                { id: "viator-ebike-tour", name: "Second tour", url: "https://example.com/b", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour-b.png" }
            ]
        }]
    }
    stale304 = {
        version: 4,
        activitySections: [{
            id: "guided-tours-and-activities",
            activities: [
                { id: "viator-ebike-tour", name: "First tour", url: "https://example.com/a" },
                { id: "viator-ebike-tour", name: "Second tour", url: "https://example.com/b" }
            ]
        }]
    }
    bundled304 = ActivitiesFromFetch(raw304, "pkg", "0", invalid)
    from304 = ActivitiesFromFetch(stale304, "not-modified", "304", bundled304)
    first304 = ActivityAt(from304.items, 0)
    second304 = ActivityAt(from304.items, 1)
    firstQr = "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png?v=rgb2"
    secondQr = "https://sunrivertownhome.com/data/qr/viator-ebike-tour-b.png?v=rgb2"
    if first304 = invalid or second304 = invalid or first304.qrUrl <> firstQr or second304.qrUrl <> secondQr
        print "FAIL a 304 cache without qrUrl dropped the packaged QR links"
        failed = failed + 1
    else if first304.id <> "viator-ebike-tour" or second304.id <> "viator-ebike-tour" or first304.qrUrl = second304.qrUrl
        print "FAIL duplicate activity ids were collapsed"
        failed = failed + 1
    else
        kept304 = ActivitiesFromFetch(raw304, "not-modified", "304", { items: [{ id: "other", qrUrl: "https://sunrivertownhome.com/data/qr/other.png?v=rgb2" }] })
        round304 = ParseJson(EncodeJson(kept304.items))
        if ActivityAt(kept304.items, 0).qrUrl <> firstQr or ActivityAt(round304, 1).qrUrl <> secondQr
            print "FAIL a 304 document with qrUrl did not keep both cards"
            failed = failed + 1
        end if
    end if
    if BookQrFits(BookQrSlot()) <> true or BookQrCentered(BookQrSlot()) <> true
        print "FAIL the Scan me slot falls outside its card or is off center"
        failed = failed + 1
    end if
    if QrDebugMarks() <> false or QrMarkColor() <> "0xFFFFFFF2"
        print "FAIL QR debug marks are on"
        failed = failed + 1
    end if
    if ActivitiesCacheGeneration() <> "qr3"
        print "FAIL the activities cache generation was not bumped"
        failed = failed + 1
    end if
    if ActivitiesCacheDropsQr({ activitySections: [{ activities: [{ id: "viator-ebike-tour", url: "https://example.com/a" }] }] }) <> true
        print "FAIL a cached activity without qrUrl was kept"
        failed = failed + 1
    end if
    if ActivitiesCacheDropsQr({ activitySections: [{ activities: [{ id: "viator-ebike-tour", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png" }] }] }) <> false
        print "FAIL a cached activity with qrUrl was discarded"
        failed = failed + 1
    end if
    byId = ActivityById({
        activitySections: [{
            activities: [
                { id: "viator-ebike-tour", name: "First" },
                { id: "viator-ebike-tour", name: "Second", qrUrl: "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png" }
            ]
        }]
    }, "viator-ebike-tour")
    if byId = invalid or byId.qrUrl <> "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png"
        print "FAIL detail did not resolve qrUrl by id"
        failed = failed + 1
    end if
    slot = BookQrSlot()
    if slot.domainW <> slot.cardW or slot.domainX <> slot.cardX
        print "FAIL the Book Direct domain caption is narrower than its card"
        failed = failed + 1
    end if
    ' Build 29: "Scan for info" is #8A5A00 semibold (about 5.9:1 on cream).
    if QrCaptionColor() <> "0x8A5A00FF" or QrCaptionFont() <> "font:SmallBoldSystemFont"
        print "FAIL the QR captions do not use the high-contrast caption style"
        failed = failed + 1
    end if
    frame = BadgeFrame()
    ' Build 28 (Pixel b27 P1): cream card, 16px padding, right edge 1717,
    ' bottom 960 at most, inside FHD title-safe (x 192-1726, y 106-972).
    if frame.x + frame.w <> 1717 or frame.y + frame.h > 960 or frame.qr <> 128 or frame.qrY <> 16
        print "FAIL the corner badge is not the title-safe cream card"
        failed = failed + 1
    end if
    if frame.qrX <> (frame.w - frame.qr) \ 2
        print "FAIL the corner QR is not centered in the card"
        failed = failed + 1
    end if
    home = HomeBadgeFrame()
    grid = HomeGrid()
    if home.qr <> 240 or home.x + home.w <> 1717 or home.y + home.h > 960 or home.captionH <> 40
        print "FAIL the Home QR card is not 240 plus a 40px caption inside the grid column"
        failed = failed + 1
    end if
    ' Build 35: the QR card is gone; 354px tiles end on the strip edge x 1699.
    if grid.w <> 354 or grid.x + (3 * grid.w) + (2 * grid.gap) < 1697 or grid.gap <> 24 or grid.h <> 168
        print "FAIL the Home tile grid is not 3 x 354px ending at x ~1699 with 24px gutters"
        failed = failed + 1
    end if
    if HomeGridBottom() + 32 > 972
        print "FAIL the Home grid does not keep 32px inside title-safe"
        failed = failed + 1
    end if
    for each section in TileSections()
        if TileTitleFits(section) <> true
            print "FAIL tile title does not fit: "; section
            failed = failed + 1
        end if
        if LabelFitsBox(TileSubtitle(section), TileSubBox()) <> true
            print "FAIL tile subtitle does not fit: "; section
            failed = failed + 1
        end if
    end for
    preview = TodoPreviewCard()
    if preview.y <> HomeSubheadY() + 64 or preview.w <> 280 or preview.h <> 160 or preview.gap <> 24
        print "FAIL the Things to Do preview cards are not 280x160 with 24px gutters 24px under the subhead"
        failed = failed + 1
    end if
    if TodoPreviewOrder("winter")[0] <> "winter" or TodoPreviewOrder("winter").Count() <> TodoMenu().Count()
        print "FAIL the Things to Do preview does not lead with the current season"
        failed = failed + 1
    end if
    for each section in TodoMenu()
        if LabelFitsBox(RailLabel(section), { w: 232, h: 48, maxLines: 1, size: 34 }) <> true or LabelFitsBox(TodoPreviewLine(section), { w: 232, h: 84, maxLines: 2, size: 28 }) <> true
            print "FAIL a Things to Do preview card does not fit: "; section
            failed = failed + 1
        end if
    end for
    if BadgeCardColor() <> "0xF4EFE3FF"
        print "FAIL the badge card is not cream"
        failed = failed + 1
    end if
    if frame.captionH <> 40 or frame.captionY < frame.qrY + frame.qr
        print "FAIL the domain caption is not directly under the corner QR"
        failed = failed + 1
    end if
    if frame.captionY + frame.captionH > frame.h
        print "FAIL the domain caption is clipped by the badge card"
        failed = failed + 1
    end if
    if BadgeCaptionColor() <> "0x8A5A00FF"
        print "FAIL the badge caption is not the dark gold"
        failed = failed + 1
    end if
    domainWide = PessimisticCharWidth(20) * Len(DisplayDomain())
    if domainWide < 1 or frame.captionW < domainWide
        print "FAIL the domain caption is narrower than the pessimistic text"
        failed = failed + 1
    else
        captionMargin = ((frame.captionW - domainWide) * 100) \ domainWide
        print "Eaglewood: badge caption margin="; captionMargin; "% width="; frame.captionW; " text="; domainWide
        if captionMargin < 20 then failed = failed + 1
    end if
    if RectsClear(BadgeCaptionRect(), CheckoutTileRect(), 24) <> true
        print "FAIL the badge caption overlaps the Checkout tile"
        failed = failed + 1
    end if
    if ActivitiesCacheShouldDiscard("not-modified", raw304) <> true
        print "FAIL a 304 activities response was kept"
        failed = failed + 1
    end if
    if ActivitiesCacheShouldDiscard("ok", raw304) <> false
        print "FAIL a 200 activities document was discarded"
        failed = failed + 1
    end if
    if ActivitiesCacheShouldDiscard("http", stale304) <> true
        print "FAIL a 304 cache missing qrUrl was kept"
        failed = failed + 1
    end if
    if ActivitiesCacheShouldDiscard("timeout", invalid) <> false
        print "FAIL a failed fetch with no cache was treated as a wipe"
        failed = failed + 1
    end if

    book = NormalizeBookDirect({
        bookDirect: {
            photoTvUrl: "/images/tv/book-direct-living.jpg",
            photoUrl: "living-room-1.jpg",
            qrImageUrl: "/data/qr/book-direct-site.png",
            bookingQrImageUrl: "/data/qr/book-direct-booking.png"
        }
    })
    if book.photo <> "https://sunrivertownhome.com/images/tv/book-direct-living.jpg"
        print "FAIL book photoTvUrl stayed relative"
        failed = failed + 1
    end if
    if book.qrImageUrl <> "https://sunrivertownhome.com/data/qr/book-direct-site.png?v=rgb2"
        print "FAIL site QR stayed relative"
        failed = failed + 1
    end if
    if book.bookingQrImageUrl <> "https://sunrivertownhome.com/data/qr/book-direct-booking.png?v=rgb2"
        print "FAIL booking QR stayed relative"
        failed = failed + 1
    end if
    if Instr(1, book.savingsText, "booking" + Chr(8209) + "site") < 1 or Instr(1, book.savingsText, "booking-site") > 0
        print "FAIL savings line must use a non-breaking hyphen (U+2011) in booking-site"
        failed = failed + 1
    end if
    if Instr(1, book.savingsText, "up to about 10% less") < 1
        print "FAIL default savings text changed"
        failed = failed + 1
    end if
    if book.bookingUrl <> "https://book.sunrivertownhome.com"
        print "FAIL booking URL changed"
        failed = failed + 1
    end if
    if HomePromptTitle({ homePromptTitle: "Book direct & save" }) <> "Book your next stay direct and save!"
        print "FAIL the home strip kept the short title"
        failed = failed + 1
    end if
    if HomePromptTitle({ homePromptTitle: "Come back in the fall" }) <> "Come back in the fall"
        print "FAIL a custom home title was replaced"
        failed = failed + 1
    end if
    if WifiLines("coming-soon", "", "").mode <> "coming-soon"
        print "FAIL Wi-Fi lines ignored coming-soon"
        failed = failed + 1
    end if
    if WifiLines("", "Cabin", "secret").password <> "secret"
        print "FAIL Wi-Fi lines dropped the password"
        failed = failed + 1
    end if
    if NetworkValue("Network name: Cabin") <> "Cabin" or NetworkValue("Cabin") <> "Cabin"
        print "FAIL the network label prefix stayed on the value"
        failed = failed + 1
    end if
    if WifiFallbackMessage() <> "Wi-Fi details couldn't load right now. Please check your booking welcome message or contact your host (see Quick Fixes)."
        print "FAIL the Wi-Fi fallback message changed"
        failed = failed + 1
    end if

    if DisplayDomain() <> "sunrivertownhome.com"
        print "FAIL QR caption is not the marketing host"
        failed = failed + 1
    end if

    if WifiScreenMode(200, false) <> "show" or WifiScreenMode(304, true) <> "show"
        print "FAIL a fresh Wi-Fi response did not show"
        failed = failed + 1
    end if
    if WifiScreenMode(503, true) <> "cache"
        print "FAIL a 503 dropped a cached Wi-Fi copy"
        failed = failed + 1
    end if
    if WifiScreenMode(503, false) <> "coming-soon"
        print "FAIL a 503 without cache was not coming-soon"
        failed = failed + 1
    end if
    if WifiScreenMode(404, false) <> "fallback" or WifiScreenMode(404, true) <> "cache"
        print "FAIL a 404 Wi-Fi mode was wrong"
        failed = failed + 1
    end if
    if ComingSoonWifi() <> "Wi-Fi details coming soon"
        print "FAIL coming-soon copy changed"
        failed = failed + 1
    end if

    fixes = IssuesForFixes([{ issue: "WiFi not connecting" }, { issue: "Hot tub" }])
    if fixes.Count() <> 1 or fixes[0].issue <> "Hot tub"
        print "FAIL the Wi-Fi how-to was still in Quick Fixes"
        failed = failed + 1
    end if

    wanted = "https://sunrivertownhome.com/data/qr/viator-ebike-tour.png?v=rgb2"
    if norm = invalid
        print "FAIL the detail activity did not stay normalized"
        failed = failed + 1
    else if not IsList(norm.items)
        print "FAIL the detail activity did not stay normalized"
        failed = failed + 1
    else if norm.items.Count() <> 1
        print "FAIL the detail activity did not stay normalized"
        failed = failed + 1
    else
        copied = DecodeList(EncodeJson(norm.items))
        if copied.Count() <> 1 or DetailQrUrl(copied[0]) <> wanted
            print "FAIL the scene activity copy dropped qrUrl"
            failed = failed + 1
        end if
    end if
    folded = ParseJson("{""id"":""viator-ebike-tour"",""qrurl"":""https://sunrivertownhome.com/data/qr/viator-ebike-tour.png?v=rgb2""}")
    if DetailQrUrl(folded) <> wanted
        print "FAIL a lowercase qrurl did not reach the detail screen"
        failed = failed + 1
    end if
    card = DetailQrCardRect()
    photo = DetailPhotoRect()
    body = DetailBodyRect()
    if RectOnScreen(card) <> true or RectOnScreen(BadgeFrame()) <> true
        print "FAIL the detail QR card or corner badge is off the FHD screen"
        failed = failed + 1
    end if
    if RectsClear(card, photo, 0) <> true or RectsClear(card, body, 0) <> true
        print "FAIL the detail QR card overlaps the photo or description"
        failed = failed + 1
    end if
    if BadgeShown("dining") = true and (RectsClear(BadgeFrame(), card, 0) <> true or RectsClear(BadgeFrame(), photo, 0) <> true or RectsClear(BadgeFrame(), body, 0) <> true)
        print "FAIL the corner badge overlaps the detail photo, description, or QR card"
        failed = failed + 1
    end if
    poster = DetailQrPosterRect()
    site = DetailQrSiteRect()
    caption = DetailQrCaptionRect()
    print "Eaglewood: detail poster rect="; ScreenRectText(poster)
    if poster.w <> 220 or poster.h <> 200
        print "FAIL the detail QR poster did not grow into the label space"
        failed = failed + 1
    end if
    if poster.x < card.x or poster.y < card.y or poster.x + poster.w > card.x + card.w or poster.y + poster.h > card.y + card.h
        print "FAIL the detail QR poster leaves its card"
        failed = failed + 1
    end if
    if RectsClear(poster, photo, 0) <> true or RectsClear(poster, body, 0) <> true
        print "FAIL the larger detail QR overlaps the photo or description"
        failed = failed + 1
    end if
    if site.y + site.h > poster.y or poster.y + poster.h > caption.y
        print "FAIL the detail QR covers its website label or gold caption"
        failed = failed + 1
    end if
    ' Build 34: the corner Book Direct ad replaces the badge on every screen.
    if BadgeShown("home") <> false or BadgeShown("dining") <> false or BadgeShown("hiking") <> false or BadgeShown("book") <> false
        print "FAIL the corner badge visibility does not match build 34"
        failed = failed + 1
    end if
    if BadgeNavigateReparents() <> false
        print "FAIL navigation still reparents the corner badge"
        failed = failed + 1
    end if
    if frame.x + frame.w <> 1717 or frame.y + frame.h > 960
        print "FAIL the corner badge translation left the title-safe card"
        failed = failed + 1
    end if

    bookBody = BookBodyRect()
    savings = BookSavingsRect()
    perks = BookPerkRow()
    slot = BookQrSlot()
    qrCard = { x: slot.cardX, y: slot.cardY, w: slot.cardW, h: slot.cardH }
    gold = { x: slot.domainX, y: slot.domainY, w: slot.domainW, h: slot.domainH }
    liveBody = DefaultBookDirect().body
    bodyLines = WrapGreeting(liveBody, bookBody.w, invalid, FallbackCharWidth(BookBodyFontSize()))
    print "Eaglewood: book body lines="; bodyLines.Count(); " rect="; ScreenRectText(bookBody)
    if bodyLines.Count() < 1 or bodyLines.Count() > 6
        print "FAIL the Book Direct body does not fit its line budget"
        failed = failed + 1
    end if
    if bodyLines.Count() * BookBodyLineHeight() > bookBody.h
        print "FAIL the Book Direct body lines exceed the label height"
        failed = failed + 1
    end if
    joined = ""
    lineLast = bodyLines.Count() - 1
    if lineLast >= 0
        for lineAt = 0 to lineLast
            if lineAt > 0 then joined = joined + " "
            joined = joined + bodyLines[lineAt]
        end for
    end if
    if joined <> liveBody
        print "FAIL the Book Direct body was truncated"
        failed = failed + 1
    end if
    if RectsClear(bookBody, perks, 0) <> true or RectsClear(savings, perks, 0) <> true
        print "FAIL the Book Direct copy overlaps the buttons"
        failed = failed + 1
    end if
    if RectsClear(bookBody, qrCard, 0) <> true or RectsClear(bookBody, gold, 0) <> true
        print "FAIL the Book Direct body overlaps the QR card or gold caption"
        failed = failed + 1
    end if
    if RectsClear(savings, qrCard, 0) <> true or RectsClear(savings, gold, 0) <> true
        print "FAIL the Book Direct savings overlap the QR card or gold caption"
        failed = failed + 1
    end if
    saveLines = WrapGreeting(DefaultSavingsText(), savings.w, invalid, FallbackCharWidth(BookSavingsFontSize()))
    print "Eaglewood: book savings lines="; saveLines.Count(); " rect="; ScreenRectText(savings)
    if saveLines.Count() < 1 or saveLines.Count() > 5
        print "FAIL the Book Direct savings do not fit their line budget"
        failed = failed + 1
    end if
    if saveLines.Count() * BookSavingsLineHeight() > savings.h
        print "FAIL the Book Direct savings lines exceed the label height"
        failed = failed + 1
    end if
    saveJoined = ""
    saveLast = saveLines.Count() - 1
    if saveLast >= 0
        for saveAt = 0 to saveLast
            if saveAt > 0 then saveJoined = saveJoined + " "
            saveJoined = saveJoined + saveLines[saveAt]
        end for
    end if
    if saveJoined <> DefaultSavingsText()
        print "FAIL the Book Direct savings text was truncated"
        failed = failed + 1
    end if
    centered = BookQrSlot()
    print "Eaglewood: book qr origin="; centered.qrX; ","; centered.qrY; " card="; centered.cardX; ","; centered.cardY; " "; centered.cardW; "x"; centered.cardH; " poster="; centered.qrW; "x"; centered.qrH

    if CheckoutNavFits() <> true
        print "FAIL Checkout Instructions does not fit the nav label"
        failed = failed + 1
    end if
    if CheckoutTileFits() <> true
        print "FAIL Checkout Instructions does not fit the home tile"
        failed = failed + 1
    end if
    if CheckoutHeadingFits() <> true
        print "FAIL Checkout Instructions does not fit the page heading"
        failed = failed + 1
    end if
    if RailClearsContent() <> true
        print "FAIL the nav overlaps the content column"
        failed = failed + 1
    end if
    titleBox = TileTitleBox()
    tile = CheckoutTileRect()
    if titleBox.x < 0 or titleBox.y < 0 or titleBox.x + titleBox.w > tile.w or titleBox.y + titleBox.h > tile.h
        print "FAIL the checkout tile title leaves the tile"
        failed = failed + 1
    end if
    navLines = WrapGreeting(RailLabel("checkout"), CheckoutLabelWidth(), invalid, PessimisticCharWidth(NavFontSize()))
    navWord = LongestWordWidth(RailLabel("checkout"), PessimisticCharWidth(NavFontSize()))
    navMargin = 0
    if navWord > 0 then navMargin = ((CheckoutLabelWidth() - navWord) * 100) \ navWord
    print "Eaglewood: checkout nav lines="; navLines.Count(); " width="; CheckoutLabelWidth(); " height="; RailRowHeight(); " margin="; navMargin; "%"
    tileLines = WrapGreeting(TileTitle("checkout"), titleBox.w, invalid, PessimisticCharWidth(NavFontSize()))
    print "Eaglewood: checkout tile lines="; tileLines.Count(); " rect="; titleBox.x; ","; titleBox.y; " "; titleBox.w; "x"; titleBox.h; " tile="; ScreenRectText(tile)

    if ShownBrand("") <> "Eaglewood 19" or ShownBrand("Eaglewood") <> "Eaglewood 19"
        print "FAIL the rail header still says Eaglewood"
        failed = failed + 1
    end if
    if HomeMenuIndex() <> 0 or TopMenu()[0] <> "home" or TopMenu()[1] <> "wifi" or TopMenu()[2] <> "todo" or TodoMenu().Count() <> 6
        print "FAIL the top menu is not Home, Wi-Fi, Things to Do"
        failed = failed + 1
    end if
    failed = failed + ExpectMenuFile()
    if RailLabel("checkout") <> "Checkout" or PageTitle("checkout") <> "Checkout Instructions" or TileTitle("checkout") <> "Checkout" or TileTitle("todo") <> "To Do"
        print "FAIL Checkout was not renamed"
        failed = failed + 1
    end if
    failed = failed + ExpectNav()
    failed = failed + ExpectActivityMenus()
    failed = failed + ExpectBrandCopy()
    failed = failed + ExpectTextFit()
    failed = failed + ExpectSummerOrder()
    failed = failed + ExpectSeasonSubhead()
    failed = failed + ExpectScroll()
    failed = failed + PrintNavTrace()

    if failed = 0 then print "brs phase2 checks passed"
end sub

function ExpectNav() as integer
    missed = 0
    ' Build 41 (TV checklist step 4): Right on the Book Direct rail row opens the page.
    book = NextNav("top", "rail", "book", 5, "right")
    if book.section <> "book" or book.zone <> "panel"
        print "FAIL right on the Book Direct rail row did not open the page (zone="; book.zone; ")"
        missed = missed + 1
    end if
    wifi = NextNav("top", "rail", "home", HomeMenuIndex(), "down")
    if wifi.section <> "wifi" or wifi.index <> 1 or wifi.depth <> "top"
        print "FAIL down from Home did not reach Wi-Fi"
        missed = missed + 1
    end if
    home = NextNav(wifi.depth, wifi.zone, wifi.section, wifi.index, "down")
    if home.section <> "todo" or home.index <> 2 or home.depth <> "top"
        print "FAIL down from Wi-Fi did not reach Things to Do"
        missed = missed + 1
    end if
    opened = NextNav(home.depth, home.zone, home.section, home.index, "OK")
    if opened.depth <> "todo" or opened.zone <> "rail" or opened.section <> "dining" or opened.index <> 0
        print "FAIL OK on Things to Do did not open the submenu"
        missed = missed + 1
    end if
    down = NextNav(opened.depth, opened.zone, opened.section, opened.index, "down")
    if down.section <> "hiking" or down.index <> 1 or down.depth <> "todo"
        print "FAIL down in the submenu did not reach Hiking"
        missed = missed + 1
    end if
    cards = NextNav(down.depth, down.zone, down.section, down.index, "right")
    if cards.zone <> "grid" or cards.section <> "hiking" or cards.depth <> "todo"
        print "FAIL right on a submenu did not open its cards"
        missed = missed + 1
    end if
    detail = { depth: cards.depth, zone: "item", section: cards.section, index: cards.index }
    backDetail = NextNav(detail.depth, detail.zone, detail.section, detail.index, "back")
    if backDetail.zone <> "grid" or backDetail.section <> "hiking" or backDetail.depth <> "todo"
        print "FAIL back from detail left the submenu list"
        missed = missed + 1
    end if
    leftDetail = NextNav(detail.depth, detail.zone, detail.section, detail.index, "left")
    if leftDetail.zone <> "grid" or leftDetail.section <> "hiking"
        print "FAIL left from detail left the submenu list"
        missed = missed + 1
    end if
    backCards = NextNav(backDetail.depth, backDetail.zone, backDetail.section, backDetail.index, "back")
    if backCards.zone <> "rail" or backCards.section <> "hiking" or backCards.depth <> "todo"
        print "FAIL back from cards left the submenu"
        missed = missed + 1
    end if
    backMenu = NextNav(backCards.depth, backCards.zone, backCards.section, backCards.index, "left")
    if backMenu.depth <> "top" or backMenu.section <> "todo" or backMenu.index <> MenuIndex(TopMenu(), "todo") or backMenu.zone <> "rail"
        print "FAIL left from the submenu did not focus Things to Do"
        missed = missed + 1
    end if
    idle = HomePromptState()
    if idle.section <> "home" or idle.index <> HomeMenuIndex() or idle.zone <> "rail" or idle.depth <> "top"
        print "FAIL idle home is not Home on the top menu"
        missed = missed + 1
    end if
    dining = OpenTarget("dining")
    if dining.depth <> "todo" or dining.section <> "dining" or dining.zone <> "grid"
        print "FAIL the Dining tile did not enter that submenu"
        missed = missed + 1
    end if
    todoTile = OpenTarget("todo")
    if todoTile.depth <> "todo" or todoTile.zone <> "rail" or todoTile.section <> "dining"
        print "FAIL the Things to Do tile did not enter the submenu"
        missed = missed + 1
    end if
    return missed
end function

function ExpectActivityMenus() as integer
    missed = 0
    mapped = NormalizeActivities({
        version: 1,
        activitySections: [
            { id: "dining", title: "Dining", activities: [{ id: "cafe", name: "Cafe", season: ["year-round"] }] },
            { id: "hiking", title: "Hiking", activities: [{ id: "trail", name: "Trail", season: ["summer"] }] },
            { id: "mountain-biking", title: "Mountain biking", activities: [{ id: "mtb", name: "Phil's Trail", season: ["summer", "fall"] }] },
            { id: "scenic-adventures", title: "Scenic", activities: [{ id: "fall-color", name: "Fall color drive", season: ["fall"] }] },
            { id: "guided-tours-and-activities", title: "Guided tours", activities: [{ id: "ride", name: "River E-bike", season: ["spring"] }] }
        ]
    })
    if mapped = invalid or mapped.items.Count() <> 5
        print "FAIL submenu fixtures did not normalize"
        return 1
    end if
    cafe = mapped.items[0]
    trail = mapped.items[1]
    mtb = mapped.items[2]
    fallColor = mapped.items[3]
    ride = mapped.items[4]
    if ItemOnScreen(cafe, "dining") <> true or ItemOnScreen(cafe, "winter") <> true or ItemOnScreen(cafe, "summer") <> true
        print "FAIL year-round dining missed dining, winter, or summer"
        missed = missed + 1
    end if
    if ItemOnScreen(cafe, "biking") <> false or ItemOnScreen(cafe, "todo") <> false
        print "FAIL dining leaked into biking or the parent menu"
        missed = missed + 1
    end if
    if ItemOnScreen(trail, "hiking") <> true or ItemOnScreen(trail, "summer") <> true or ItemOnScreen(trail, "winter") <> false
        print "FAIL the summer hike was filed wrong"
        missed = missed + 1
    end if
    if ItemOnScreen(mtb, "biking") <> true or ItemOnScreen(mtb, "summer") <> true or ItemOnScreen(mtb, "winter") <> false
        print "FAIL the mountain-biking section was filed wrong"
        missed = missed + 1
    end if
    if ItemOnScreen(ride, "biking") <> true or ItemOnScreen(ride, "summer") <> false
        print "FAIL an e-bike name was not filed under biking"
        missed = missed + 1
    end if
    if ItemOnScreen(fallColor, "dining") <> false or ItemOnScreen(fallColor, "hiking") <> false or ItemOnScreen(fallColor, "biking") <> false or ItemOnScreen(fallColor, "fishing") <> false or ItemOnScreen(fallColor, "winter") <> false or ItemOnScreen(fallColor, "summer") <> false
        print "FAIL a fall-only scenic stop was forced into a submenu"
        missed = missed + 1
    end if
    copied = DecodeList(EncodeJson(mapped.items))
    if copied.Count() <> 5 or ItemOnScreen(copied[0], "winter") <> true or copied[2].sectionTitle <> "Mountain biking"
        print "FAIL season or sectionTitle was lost in the scene copy"
        missed = missed + 1
    end if
    return missed
end function

function ExpectMenuFile() as integer
    text = ReadAsciiFile("pkg:/data/menu.json")
    loaded = AcceptMenuText(text, "pkg")
    if loaded = invalid
        print "FAIL bundled menu.json did not parse"
        return 1
    end if
    InstallMenu(loaded)
    again = AcceptMenuText(text, "remote")
    if again = invalid
        print "FAIL the same menu text was rejected as a remote file"
        return 1
    end if
    if MenuSectionIds().Count() <> again.items.Count()
        print "FAIL bundled and remote menus differ"
        return 1
    end if
    bad = AcceptMenuText("{""version"":1,""items"":[{""id"":""x"",""label"":""Nope"",""type"":""lawn""}]}", "remote")
    if bad <> invalid
        print "FAIL an unknown menu type was accepted"
        return 1
    end if
    if RailChevron("todo") <> ">" or RailChevron("fixes") <> ">" or RailChevron("dining") <> ">"
        print "FAIL a submenu row is missing its chevron"
        return 1
    end if
    if RailChevron("home") <> "" then return 1
    return 0
end function

function ExpectTextFit() as integer
    missed = 0
    fullSeason = "Year-round (seasonal trail conditions vary)"
    if SeasonChipText("Year-round") <> "Year-round" then missed = missed + 1
    if SeasonChipText(fullSeason) <> "Year-round" then missed = missed + 1
    if ChipWidthFor("Year-round") > 330 then missed = missed + 1
    if ChipWidthFor("Year-round") < 140 then missed = missed + 1
    for each pair in [["April through October", "Apr–Oct"], ["June through September", "Jun–Sep"], ["July through September", "Jul–Sep"], ["November through May", "Nov–May"]]
        if SeasonChipText(pair[0]) <> pair[1]
            print "FIT pill "; pair[0]; " -> "; SeasonChipText(pair[0])
            missed = missed + 1
        end if
    end for
    text = ReadAsciiFile("pkg:/data/activities.json")
    norm = NormalizeActivities(ParseObjectText(text))
    if norm = invalid or not IsList(norm.items) then return missed + 1
    last = norm.items.Count() - 1
    for index = 0 to last
        item = norm.items[index]
        ' Build 30: CardLayout pre-breaks at 0.6 em and shrinks the photo.
        card = CardLayout(ItemText(item, "name"), ItemText(item, "distance"))
        if card.bottom > 415 or card.photoH < 124 or card.name.Count() > 5 or card.meta.Count() > 2
            print "FIT card "; ItemText(item, "name"); " bottom="; card.bottom
            missed = missed + 1
        end if
        for each line in card.name
            if Len(line) * 18 > 332 then missed = missed + 1
        end for
        for each line in card.meta
            if Len(line) * 15 > 332 then missed = missed + 1
        end for
        if LabelFitsBox(SeasonChipText(ItemText(item, "seasonLabel")), CardSeasonBox()) <> true
            print "FIT season "; ItemText(item, "seasonLabel")
            missed = missed + 1
        end if
    end for
    guide = ParseObjectText(ReadAsciiFile("pkg:/data/guide.json"))
    issues = []
    if IsAssoc(guide) then issues = IssuesForFixes(guide.Lookup("troubleshooting"))
    issueLast = issues.Count() - 1
    if issueLast >= 0
        for index = 0 to issueLast
            title = AsText(issues[index].Lookup("issue"))
            if LabelFitsBox(title, MenuTitleBox()) <> true
                print "FIT issue "; title
                missed = missed + 1
            end if
        end for
    end if
    menus = TopMenu()
    menuLast = menus.Count() - 1
    if menuLast >= 0
        for index = 0 to menuLast
            label = RailLabel(menus[index])
            wide = RailLabelWidth()
            if RailChevron(menus[index]) = "" then wide = CheckoutLabelWidth()
            fit = { w: wide, h: RailRowHeight(), maxLines: 2, size: NavFontSize() }
            if LabelFitsBox(label, fit) <> true
                print "FIT rail "; label
                missed = missed + 1
            end if
        end for
    end if
    if LabelFitsBox(WifiFallbackMessage(), WifiStatusBodyBox()) <> true
        print "FIT wifi fallback"
        missed = missed + 1
    end if
    if LabelFitsBox(WifiStatusHeading(), WifiStatusHeadingBox()) <> true
        print "FIT wifi status heading"
        missed = missed + 1
    end if
    routerText = "If it still doesn't connect, try restarting the router. The router is located in the cabinet under the TV in the living room. Unplug the power, wait 30 seconds, and plug it back in."
    if LabelFitsBox(routerText, WifiRouterBox(true)) <> true or LabelFitsBox(routerText, WifiRouterBox(false)) <> true
        print "FIT wifi router tip"
        missed = missed + 1
    end if
    if FlushText(" cabinet  under ") <> "cabinet under"
        print "FIT wifi router tip keeps a leading or double space"
        missed = missed + 1
    end if
    if WifiTop() + WifiPanelHeight() > 972
        print "FIT wifi status panel leaves title-safe"
        missed = missed + 1
    end if
    print "ellipsis failures="; missed
    if missed <> 0 then print "FAIL text fit"
    return missed
end function

function ExpectScroll() as integer
    missed = 0
    guide = ParseObjectText(ReadAsciiFile("pkg:/data/guide.json"))
    issues = []
    if IsAssoc(guide) then issues = IssuesForFixes(guide.Lookup("troubleshooting"))
    longestFix = ""
    fixLines = 0
    issueLast = issues.Count() - 1
    if issueLast >= 0
        for index = 0 to issueLast
            m.issueIndex = index
            m.fixIssues = issues
            body = FixScrollText()
            lines = CountWrapped(body, DetailTextWidth(), PessimisticCharWidth(ScrollFontSize()))
            if lines > fixLines
                fixLines = lines
                longestFix = body
            end if
        end for
    end if
    m.issueIndex = 0
    fixHeight = ScrollContentHeight(longestFix, DetailTextWidth())
    fixRange = ScrollRange(longestFix, DetailTextWidth(), FixScrollViewport())
    print "Eaglewood: scroll fixes lines="; fixLines; " contentH="; fixHeight; " viewport="; FixScrollViewport(); " range="; fixRange
    acts = NormalizeActivities(ParseObjectText(ReadAsciiFile("pkg:/data/activities.json")))
    dining = []
    if acts <> invalid then dining = ActivitiesForScreen(acts.items, "dining")
    longestDining = ""
    diningLines = 0
    diningLast = dining.Count() - 1
    if diningLast >= 0
        for index = 0 to diningLast
            item = dining[index]
            body = ItemText(item, "description")
            tip = ItemText(item, "tip")
            if tip <> "" then body = body + Chr(10) + "Tip: " + tip
            lines = CountWrapped(body, DetailTextWidth(), PessimisticCharWidth(ScrollFontSize()))
            if lines > diningLines
                diningLines = lines
                longestDining = body
            end if
        end for
    end if
    diningHeight = ScrollContentHeight(longestDining, DetailTextWidth())
    diningRange = ScrollRange(longestDining, DetailTextWidth(), ActivityScrollViewport())
    print "Eaglewood: scroll dining lines="; diningLines; " contentH="; diningHeight; " viewport="; ActivityScrollViewport(); " range="; diningRange
    if fixLines < 1 or diningLines < 1 then missed = missed + 1
    if missed <> 0 then print "FAIL scroll range"
    return missed
end function

function ExpectState(state as object, depth as string, zone as string, section as string, index as integer, label as string) as integer
    print "NAV "; label; " depth="; state.depth; " zone="; state.zone; " section="; state.section; " index="; state.index
    if state.depth <> depth then return 1
    if state.zone <> zone then return 1
    if state.section <> section then return 1
    if state.index <> index then return 1
    return 0
end function

function PrintNavTrace() as integer
    missed = 0
    menus = TopMenu()
    last = menus.Count() - 1
    order = ""
    for index = 0 to last
        if index > 0 then order = order + " | "
        order = order + RailLabel(menus[index])
    end for
    print "NAV top "; order
    subs = TodoMenu()
    subOrder = ""
    subLast = subs.Count() - 1
    for index = 0 to subLast
        if index > 0 then subOrder = subOrder + " | "
        subOrder = subOrder + RailLabel(subs[index])
    end for
    print "NAV submenu "; subOrder
    start = HomePromptState()
    missed = missed + ExpectState(start, "top", "rail", "home", 0, "start")
    rail = { depth: "top", zone: "rail", section: "home", index: start.index }
    missed = missed + ExpectState(rail, "top", "rail", "home", 0, "left-to-rail")
    stayUp = NextNav("top", "rail", "home", 0, "up")
    missed = missed + ExpectState(stayUp, "top", "rail", "home", 0, "up-home-stays")
    wifiRow = NextNav(rail.depth, rail.zone, rail.section, rail.index, "down")
    missed = missed + ExpectState(wifiRow, "top", "rail", "wifi", 1, "down")
    up = NextNav(wifiRow.depth, wifiRow.zone, wifiRow.section, wifiRow.index, "down")
    missed = missed + ExpectState(up, "top", "rail", "todo", 2, "down")
    rules = NextNav(up.depth, up.zone, up.section, up.index, "down")
    missed = missed + ExpectState(rules, "top", "rail", "rules", 3, "down")
    fixes = NextNav(rules.depth, rules.zone, rules.section, rules.index, "down")
    missed = missed + ExpectState(fixes, "top", "rail", "fixes", 4, "down")
    book = NextNav(fixes.depth, fixes.zone, fixes.section, fixes.index, "down")
    missed = missed + ExpectState(book, "top", "rail", "book", 5, "down")
    checkout = NextNav(book.depth, book.zone, book.section, book.index, "down")
    missed = missed + ExpectState(checkout, "top", "rail", "checkout", 6, "down")
    checkoutStay = NextNav(checkout.depth, checkout.zone, checkout.section, checkout.index, "down")
    missed = missed + ExpectState(checkoutStay, "top", "rail", "checkout", 6, "down-checkout-stays")
    homeLeft = NextNav("top", "rail", "home", 0, "left")
    missed = missed + ExpectState(homeLeft, "top", "rail", "home", 0, "left-home")
    if homeLeft.leave = true then missed = missed + 1
    homeBack = NextNav("top", "rail", "home", 0, "back")
    missed = missed + ExpectState(homeBack, "top", "rail", "home", 0, "back-home")
    if homeBack.leave <> true then missed = missed + 1
    homeOk = NextNav("top", "rail", "home", 0, "OK")
    missed = missed + ExpectState(homeOk, "top", "prompt", "home", 0, "ok-home")
    rulesBack = NextNav("top", "rail", "rules", 3, "back")
    missed = missed + ExpectState(rulesBack, "top", "rail", "home", 0, "back-rules")
    rulesOk = NextNav("top", "rail", "rules", 3, "OK")
    missed = missed + ExpectState(rulesOk, "top", "panel", "rules", 3, "ok-rules")
    fixesOk = NextNav("top", "rail", "fixes", 4, "OK")
    missed = missed + ExpectState(fixesOk, "fixes", "rail", "fixes", 0, "ok-fixes")
    fixesRight = NextNav("top", "rail", "fixes", 4, "right")
    missed = missed + ExpectState(fixesRight, "fixes", "rail", "fixes", 0, "right-fixes")
    fixesOpen = NextNav("fixes", "rail", "fixes", 0, "OK")
    missed = missed + ExpectState(fixesOpen, "fixes", "item", "fixes", 0, "ok-fix-detail")
    fixesDetailBack = NextNav("fixes", "item", "fixes", 0, "back")
    missed = missed + ExpectState(fixesDetailBack, "fixes", "rail", "fixes", 0, "back-fix-detail")
    fixesBack = NextNav("fixes", "rail", "fixes", 0, "back")
    missed = missed + ExpectState(fixesBack, "top", "rail", "fixes", 4, "back-fixes")
    bookOk = NextNav("top", "rail", "book", 5, "OK")
    missed = missed + ExpectState(bookOk, "top", "panel", "book", 5, "ok-book")
    opened = NextNav(up.depth, up.zone, up.section, up.index, "OK")
    missed = missed + ExpectState(opened, "todo", "rail", "dining", 0, "ok-todo")
    openedRight = NextNav("top", "rail", "todo", 2, "right")
    missed = missed + ExpectState(openedRight, "todo", "rail", "dining", 0, "right-todo")
    diningStay = NextNav("todo", "rail", "dining", 0, "up")
    missed = missed + ExpectState(diningStay, "todo", "rail", "dining", 0, "up-dining-stays")
    hiking = NextNav(opened.depth, opened.zone, opened.section, opened.index, "down")
    missed = missed + ExpectState(hiking, "todo", "rail", "hiking", 1, "down")
    winter = NextNav(hiking.depth, hiking.zone, hiking.section, hiking.index, "down")
    missed = missed + ExpectState(winter, "todo", "rail", "winter", 2, "down")
    summer = NextNav(winter.depth, winter.zone, winter.section, winter.index, "down")
    missed = missed + ExpectState(summer, "todo", "rail", "summer", 3, "down")
    fishing = NextNav(summer.depth, summer.zone, summer.section, summer.index, "down")
    missed = missed + ExpectState(fishing, "todo", "rail", "fishing", 4, "down")
    biking = NextNav(fishing.depth, fishing.zone, fishing.section, fishing.index, "down")
    missed = missed + ExpectState(biking, "todo", "rail", "biking", 5, "down")
    bikingStay = NextNav(biking.depth, biking.zone, biking.section, biking.index, "down")
    missed = missed + ExpectState(bikingStay, "todo", "rail", "biking", 5, "down-biking-stays")
    cards = NextNav(fishing.depth, fishing.zone, fishing.section, fishing.index, "OK")
    missed = missed + ExpectState(cards, "todo", "grid", "fishing", 4, "ok-fishing")
    cardsRight = NextNav("todo", "rail", "fishing", 4, "right")
    missed = missed + ExpectState(cardsRight, "todo", "grid", "fishing", 4, "right-fishing")
    print "NAV fishing-empty title="; RailLabel("fishing"); " text="; ActivityEmptyText("fishing"); " grid=hidden"
    if ActivityEmptyText("fishing") <> "No fishing spots listed right now." then missed = missed + 1
    emptyLeft = GridNav(0, 0, "left")
    print "NAV left-empty-grid zone="; emptyLeft.zone; " section=fishing railIndex=4"
    if emptyLeft.zone <> "rail" then missed = missed + 1
    emptyOk = GridNav(0, 0, "OK")
    if emptyOk.zone <> "grid" then missed = missed + 1
    populated = GridNav(4, 0, "left")
    print "NAV left-grid-col0 zone="; populated.zone; " index="; populated.index
    if populated.zone <> "rail" then missed = missed + 1
    gridRight = GridNav(4, 0, "right")
    print "NAV right-grid zone="; gridRight.zone; " index="; gridRight.index
    if gridRight.zone <> "grid" then missed = missed + 1
    if gridRight.index <> 1 then missed = missed + 1
    gridDown = GridNav(4, 0, "down")
    print "NAV down-grid zone="; gridDown.zone; " index="; gridDown.index
    if gridDown.zone <> "grid" then missed = missed + 1
    if gridDown.index <> 3 then missed = missed + 1
    detail = { depth: cards.depth, zone: "item", section: cards.section, index: cards.index }
    backDetail = NextNav(detail.depth, detail.zone, detail.section, detail.index, "back")
    missed = missed + ExpectState(backDetail, "todo", "grid", "fishing", 4, "back-detail")
    leftDetail = NextNav(detail.depth, detail.zone, detail.section, detail.index, "left")
    missed = missed + ExpectState(leftDetail, "todo", "grid", "fishing", 4, "left-detail")
    detailStay = NextNav(detail.depth, detail.zone, detail.section, detail.index, "down")
    missed = missed + ExpectState(detailStay, "todo", "item", "fishing", 4, "down-detail-stays")
    backGrid = NextNav(backDetail.depth, backDetail.zone, backDetail.section, backDetail.index, "back")
    missed = missed + ExpectState(backGrid, "todo", "rail", "fishing", 4, "back-grid")
    backSub = NextNav(backGrid.depth, backGrid.zone, backGrid.section, backGrid.index, "left")
    missed = missed + ExpectState(backSub, "top", "rail", "todo", 2, "left-submenu")
    backSubBack = NextNav("todo", "rail", "dining", 0, "back")
    missed = missed + ExpectState(backSubBack, "top", "rail", "todo", 2, "back-submenu")
    idle = HomePromptState()
    missed = missed + ExpectState(idle, "top", "rail", "home", 0, "idle")
    print "NAV idle-seconds 600"
    if missed <> 0 then print "FAIL nav trace"
    return missed
end function

function ExpectBrandCopy() as integer
    missed = 0
    if FallbackGreeting() <> "Welcome to Eaglewood 19" then missed = missed + 1
    if ShownBrand("Eaglewood") <> "Eaglewood 19" then missed = missed + 1
    if ShownBrand("") <> "Eaglewood 19" then missed = missed + 1
    text = ReadAsciiFile("pkg:/data/activities.json")
    parsed = ParseObjectText(text)
    norm = NormalizeActivities(parsed)
    if norm = invalid
        print "FAIL packaged activities did not normalize"
        return missed + 1
    end if
    if not IsList(norm.items)
        print "FAIL packaged activities did not normalize"
        return missed + 1
    end if
    poolName = ""
    poolBody = ""
    last = norm.items.Count() - 1
    for index = 0 to last
        item = norm.items[index]
        if ItemText(item, "id") = "eaglewood-pool"
            poolName = ItemText(item, "name")
            poolBody = ItemText(item, "description")
        end if
    end for
    print "NAV pool-title "; poolName
    print "NAV pool-body "; poolBody
    if poolName <> "Eaglewood Community Pool" then missed = missed + 1
    if Instr(1, poolBody, "exclusive to Eaglewood guests and residents") < 1 then missed = missed + 1
    if Instr(1, poolName, "Eaglewood 19") > 0 then missed = missed + 1
    if Instr(1, poolBody, "Eaglewood 19") > 0 then missed = missed + 1
    if missed <> 0 then print "FAIL pool title was rewritten"
    return missed
end function

function Sample(id as string, url as string) as object
    return {
        id: id,
        name: "Electric Bike Tour",
        url: url,
        imageTvUrl: "/images/tv/" + id + ".jpg",
        qrUrl: "/data/qr/" + id + ".png"
    }
end function

function ExpectSeason(seconds as integer, month as integer, hour as integer, season as string) as integer
    parts = PacificLocalParts(seconds)
    if parts = invalid or parts.month <> month or parts.hour <> hour or CalendarSeasonForMonth(parts.month) <> season
        print "FAIL pacific "; seconds
        return 1
    end if
    return 0
end function

function ExpectHour(seconds as integer, month as integer, day as integer, hour as integer, offset as integer) as integer
    parts = PacificLocalParts(seconds)
    if parts = invalid or parts.month <> month or parts.day <> day or parts.hour <> hour or parts.offsetHours <> offset
        print "FAIL dst "; seconds
        return 1
    end if
    return 0
end function

function ExpectDay(seconds as integer, year as integer, month as integer, day as integer, hour as integer) as integer
    parts = PacificLocalParts(seconds)
    if parts = invalid or parts.year <> year or parts.month <> month or parts.day <> day or parts.hour <> hour
        print "FAIL year boundary "; seconds
        return 1
    end if
    return 0
end function

' Build 30 regression: Summer sorts all ranked activities by seasonRank.summer,
' not by the calendar season (which put Hiking first).
function ExpectSummerOrder() as integer
    missed = 0
    if ScreenSortSeason("summer", "fall") <> "summer" then missed = missed + 1
    if ScreenSortSeason("winter", "fall") <> "winter" then missed = missed + 1
    if ScreenSortSeason("hiking", "fall") <> "fall" then missed = missed + 1
    norm = NormalizeActivities(ParseObjectText(ReadAsciiFile("pkg:/data/activities.json")))
    if norm = invalid or not IsList(norm.items) then return missed + 1
    picked = ActivitiesForScreen(norm.items, "summer")
    ordered = SortActivities(picked, ScreenSortSeason("summer", "fall"))
    want = ["deschutes-float", "standup-paddle-deschtues", "sharc", "sunriver-paths", "village-sunriver", "stargazing", "woodlands-golf"]
    if ordered.Count() < want.Count() then return missed + 1
    for index = 0 to want.Count() - 1
        id = ItemText(ordered[index], "id")
        if id <> want[index]
            print "FAIL summer order "; index; " got "; id; " want "; want[index]
            missed = missed + 1
        end if
        if ActivityHasQr(ordered[index]) <> true
            print "FAIL summer qr "; id
            missed = missed + 1
        end if
    end for
    if missed = 0 then print "summer order ok"
    return missed
end function

' Build 31 regression: the subhead names the season the screen sorts by,
' whatever grid was built last.
function ExpectSeasonSubhead() as integer
    missed = 0
    cases = [["summer", "summer"], ["winter", "winter"], ["biking", "fall"], ["hiking", "fall"], ["dining", "fall"], ["todo", "fall"]]
    for each c in cases
        got = SeasonSubheadFor(c[0], "fall")
        if got <> "Sorted for " + c[1]
            print "FAIL subhead "; c[0]; " got "; got
            missed = missed + 1
        end if
    end for
    saved = m.section
    for each screen in ["summer", "winter", "biking", "todo"]
        m.section = screen
        m.activitySeason = "winter"
        want = SeasonSubheadFor(screen, CurrentSeason())
        if Left(ActivitySubtitle(), Len(want)) <> want
            print "FAIL subtitle "; screen; " got "; ActivitySubtitle()
            missed = missed + 1
        end if
    end for
    m.section = saved
    if missed = 0 then print "season subhead ok"
    return missed
end function

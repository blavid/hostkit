' The scene path: parse the live file, slim it, EncodeJson, DecodeList, then
' the same detail lookup PaintDetail uses. ContentNode is not involved.
sub Main()
    failed = 0
    text = ReadAsciiFile("pkg:/data/activities-live.json")
    print "Eaglewood: live bytes="; Len(text)
    parsed = ParseObjectText(text)
    norm = ActivitiesFromFetch(parsed, "network", "200", invalid)
    if norm = invalid
        print "FAIL live activities did not normalize"
        print "detail live checks failed"
        return
    end if
    if not IsList(norm.items)
        print "FAIL live activities did not normalize"
        print "detail live checks failed"
        return
    end if
    if norm.items.Count() < 1
        print "FAIL live activities did not normalize"
        print "detail live checks failed"
        return
    end if
    print "Eaglewood: live normalized count="; norm.items.Count(); " qr="; ActivitiesQrCount(norm.items)
    result = {}
    result["activitiesJson"] = EncodeJson(norm.items)
    result["activitiesSource"] = "network"
    result["activitiesCode"] = "200"
    result["activitiesVersion"] = VersionText(norm.activitiesVersion)
    bundle = BundleFromResult(result)
    items = []
    if bundle <> invalid
        if IsList(bundle.activities) then items = bundle.activities
    end if
    print "Eaglewood: scene activities count="; items.Count(); " qr="; ActivitiesQrCount(items)
    m.activities = items
    m.section = "biking"
    m.zone = "item"
    season = CurrentSeason()
    m.sortedCards = SortActivities(ActivitiesForScreen(items, "biking"), season)
    print "Eaglewood: biking cards="; m.sortedCards.Count(); " season="; season
    poster = DetailQrPosterRect()
    print "Eaglewood: detail poster rect="; ScreenRectText(poster)
    failed = failed + ProveDetailId("viator-ebike-tour")
    failed = failed + ProveDetailId("ride-the-river-ebike")
    card = DetailQrCardRect()
    photo = DetailPhotoRect()
    body = DetailBodyRect()
    badge = BadgeFrame()
    print "Eaglewood: detail card rect="; ScreenRectText(card)
    print "Eaglewood: detail photo rect="; ScreenRectText(photo)
    print "Eaglewood: detail body rect="; ScreenRectText(body)
    print "Eaglewood: detail badge rect="; ScreenRectText(badge)
    if RectOnScreen(card) <> true
        print "FAIL detail QR card is outside 0..1920 x 0..1080"
        failed = failed + 1
    end if
    if RectsClear(card, photo, 0) <> true
        print "FAIL detail QR card intersects the photo"
        failed = failed + 1
    end if
    if RectsClear(card, body, 0) <> true
        print "FAIL detail QR card intersects the description"
        failed = failed + 1
    end if
    if RectOnScreen(badge) <> true
        print "FAIL corner badge is outside 0..1920 x 0..1080"
        failed = failed + 1
    end if
    if BadgeShown("dining") = true and (RectsClear(badge, card, 0) <> true or RectsClear(badge, photo, 0) <> true or RectsClear(badge, body, 0) <> true)
        print "FAIL corner badge intersects the detail photo, description, or QR card"
        failed = failed + 1
    end if
    if RectsClear(poster, photo, 0) <> true or RectsClear(poster, body, 0) <> true
        print "FAIL the larger detail QR intersects the photo or description"
        failed = failed + 1
    end if
    if poster.x < card.x or poster.y < card.y or poster.x + poster.w > card.x + card.w or poster.y + poster.h > card.y + card.h
        print "FAIL the detail QR poster leaves its card"
        failed = failed + 1
    end if
    folded = ParseJson("{""id"":""ride-the-river-ebike"",""qrurl"":""https://sunrivertownhome.com/data/qr/ride-the-river-ebike.png?v=rgb2""}")
    foldedQr = DetailQrUrl(folded)
    print "Eaglewood: folded qrurl="; foldedQr
    if foldedQr <> "https://sunrivertownhome.com/data/qr/ride-the-river-ebike.png?v=rgb2"
        print "FAIL a lowercase qrurl was not what the detail screen reads"
        failed = failed + 1
    end if
    if failed = 0 then print "detail live checks passed"
    if failed <> 0 then print "detail live checks failed"
end sub

function ProveDetailId(id as string) as integer
    if not IsList(m.sortedCards) then return 1
    last = m.sortedCards.Count() - 1
    found = 0
    if last < 0
        print "FAIL "; id; " biking list was empty"
        return 1
    end if
    for index = 0 to last
        item = m.sortedCards[index]
        if ItemText(item, "id") = id
            found = found + 1
            m.cardIndex = index
            LogDetailOpen()
            qr = DetailQrForItem(item)
            if Instr(1, qr, id + ".png") < 1
                print "FAIL "; id; " index="; index; " qrUrl="; qr
                return 1
            end if
        end if
    end for
    if found < 1
        print "FAIL "; id; " was not on the biking detail list"
        return 1
    end if
    print "Eaglewood: "; id; " cards="; found
    return 0
end function

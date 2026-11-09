' Live activities.json through the same slim record the scene paints.
sub Main()
    text = ReadAsciiFile("pkg:/data/activities-live.json")
    print "Eaglewood: map bytes="; Len(text)
    parsed = ParseObjectText(text)
    norm = ActivitiesFromFetch(parsed, "network", "200", invalid)
    if norm = invalid or not IsList(norm.items) or norm.items.Count() < 1
        print "FAIL live activities did not normalize"
        print "activity map failed"
        return
    end if
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
    print "Eaglewood: map scene count="; items.Count()
    menus = TodoMenu()
    menuLast = menus.Count() - 1
    for menuAt = 0 to menuLast
        screen = menus[menuAt]
        picked = ActivitiesForScreen(items, screen)
        print "Eaglewood: map "; screen; " count="; picked.Count()
        ' Build 41: no row repeats a card (the live file lists viator-ebike-tour twice).
        ids = {}
        for each item in picked
            key = ActivityDedupeKey(item)
            if key <> "" and ids.DoesExist(key)
                print "FAIL row "; screen; " repeats "; key
                print "activity map failed"
                return
            end if
            ids[key] = true
        end for
        rowLast = picked.Count() - 1
        if rowLast >= 0
            for rowAt = 0 to rowLast
                item = picked[rowAt]
                print "Eaglewood: map "; screen; " id="; ItemText(item, "id"); " source="; SourceIndexOf(item)
            end for
        end if
    end for
    none = 0
    itemLast = items.Count() - 1
    if itemLast >= 0
        for itemAt = 0 to itemLast
            item = items[itemAt]
            hit = false
            for menuAt = 0 to menuLast
                if ItemOnScreen(item, menus[menuAt]) = true then hit = true
            end for
            if hit = false
                none = none + 1
                print "Eaglewood: map none id="; ItemText(item, "id"); " section="; ItemText(item, "sectionId"); " title="; ItemText(item, "sectionTitle"); " season="; SeasonLine(AaField(item, "season")); " source="; SourceIndexOf(item)
            end if
        end for
    end if
    print "Eaglewood: map none count="; none
    print "Eaglewood: map note=add a category array on each activity. Fishing has no section. Year-round is both winter and summer because season has no submenu tag."
    dupItems = [{ id: "same", name: "E-bike tour", sectionId: "guided-tours-and-activities" }, { id: "same", name: "E-bike tour", sectionId: "golf-family" }, { id: "other", name: "Bike rental", sectionId: "mountain-biking" }]
    dupPicked = ActivitiesForScreen(dupItems, "biking")
    if dupPicked.Count() <> 2
        print "FAIL dedupe fixture: biking count="; dupPicked.Count(); " want 2"
        print "activity map failed"
        return
    end if
    print "Eaglewood: map dedupe fixture ok"
    if ProveGuideBody() <> true
        print "activity map failed"
        return
    end if
    print "activity map passed"
end sub

function SeasonLine(raw as object) as string
    if not IsList(raw) then return ""
    last = raw.Count() - 1
    if last < 0 then return ""
    line = ""
    for index = 0 to last
        if index > 0 then line = line + ","
        line = line + GuideLimitedText(raw[index], 40)
    end for
    return line
end function

function ProveGuideBody() as boolean
    text = ReadAsciiFile("pkg:/data/guide-live.json")
    print "Eaglewood: guide bytes="; Len(text)
    parsed = ParseObjectText(text)
    body = ""
    if IsAssoc(parsed)
        block = parsed.Lookup("bookDirect")
        if IsAssoc(block) then body = GuideLimitedText(block.Lookup("body"), 280)
    end if
    rect = BookBodyRect()
    lines = WrapGreeting(body, rect.w, invalid, FallbackCharWidth(BookBodyFontSize()))
    print "Eaglewood: book body lines="; lines.Count(); " rect="; ScreenRectText(rect)
    print "Eaglewood: book body live="; body
    if body = ""
        print "FAIL the live Book Direct body was empty"
        return false
    end if
    if lines.Count() < 1
        print "FAIL the live Book Direct body did not wrap"
        return false
    end if
    if lines.Count() * BookBodyLineHeight() > rect.h
        print "FAIL the live Book Direct body does not fit"
        return false
    end if
    return true
end function

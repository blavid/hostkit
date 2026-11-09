' Guest menu. The packaged file is the fallback. A fetched menu.json replaces it
' only after the same checks pass.

function KnownMenuType(kind as string) as boolean
    if kind = "home" then return true
    if kind = "wifi" then return true
    if kind = "things" then return true
    if kind = "rules" then return true
    if kind = "quickfixes" then return true
    if kind = "book" then return true
    if kind = "checkout" then return true
    return false
end function

function SectionForMenuType(kind as string) as string
    if kind = "home" then return "home"
    if kind = "wifi" then return "wifi"
    if kind = "things" then return "todo"
    if kind = "rules" then return "rules"
    if kind = "quickfixes" then return "fixes"
    if kind = "book" then return "book"
    if kind = "checkout" then return "checkout"
    return ""
end function

function MenuDataUrl() as string
    return "https://sunrivertownhome.com/data/menu.json"
end function

function MenuStringList(value as object) as object
    items = []
    if not IsList(value) then return items
    last = value.Count() - 1
    if last < 0 then return items
    for index = 0 to last
        text = GuideLimitedText(value[index], 80)
        if text <> "" then items.Push(text)
    end for
    return items
end function

function MenuRejectReason(parsed as object) as string
    if not IsAssoc(parsed) then return "badjson"
    rawItems = AaField(parsed, "items")
    if not IsList(rawItems) then return "badjson"
    if rawItems.Count() < 1 then return "badjson"
    last = rawItems.Count() - 1
    for index = 0 to last
        entry = rawItems[index]
        if not IsAssoc(entry) then return "badjson"
        kind = LCase(GuideLimitedText(AaField(entry, "type"), 40))
        if KnownMenuType(kind) <> true then return "badtype"
        label = GuideLimitedText(AaField(entry, "label"), 80)
        if label = "" then return "badjson"
        if kind = "things"
            kids = AaField(entry, "children")
            if not IsList(kids) then return "badjson"
            if kids.Count() < 1 then return "badjson"
            childLast = kids.Count() - 1
            for childAt = 0 to childLast
                child = kids[childAt]
                if not IsAssoc(child) then return "badjson"
                if GuideLimitedText(AaField(child, "id"), 40) = "" then return "badjson"
                if GuideLimitedText(AaField(child, "label"), 80) = "" then return "badjson"
            end for
        end if
    end for
    return "ok"
end function

function NormalizeMenuChild(entry as object) as object
    if not IsAssoc(entry) then return invalid
    id = GuideLimitedText(AaField(entry, "id"), 40)
    if id = "" then id = GuideLimitedText(AaField(entry, "section"), 40)
    label = GuideLimitedText(AaField(entry, "label"), 80)
    if id = "" or label = "" then return invalid
    child = {}
    child["section"] = id
    child["label"] = label
    empty = GuideLimitedText(AaField(entry, "empty"), 120)
    if empty = "" then empty = "Nothing to show yet."
    child["empty"] = empty
    child["sectionIds"] = MenuStringList(AaField(entry, "sectionIds"))
    child["keywords"] = MenuStringList(AaField(entry, "keywords"))
    child["seasons"] = MenuStringList(AaField(entry, "seasons"))
    return child
end function

function NormalizeMenu(parsed as object) as object
    if MenuRejectReason(parsed) <> "ok" then return invalid
    rawItems = AaField(parsed, "items")
    items = []
    last = rawItems.Count() - 1
    for index = 0 to last
        entry = rawItems[index]
        kind = LCase(GuideLimitedText(AaField(entry, "type"), 40))
        item = {}
        item["section"] = SectionForMenuType(kind)
        item["label"] = GuideLimitedText(AaField(entry, "label"), 80)
        item["type"] = kind
        item["feed"] = GuideLimitedText(AaField(entry, "source"), 80)
        children = []
        if kind = "things"
            rawChildren = AaField(entry, "children")
            childLast = rawChildren.Count() - 1
            for childAt = 0 to childLast
                child = NormalizeMenuChild(rawChildren[childAt])
                if child = invalid then return invalid
                children.Push(child)
            end for
        end if
        item["children"] = children
        items.Push(item)
    end for
    menu = {}
    menu["items"] = items
    menu["source"] = "parsed"
    return menu
end function

function MenuFeed(section as string) as string
    doc = ActiveMenuDoc()
    if doc = invalid then return ""
    items = doc.Lookup("items")
    if not IsList(items) then return ""
    last = items.Count() - 1
    if last < 0 then return ""
    for index = 0 to last
        item = items[index]
        if IsAssoc(item)
            if GuideLimitedText(item.Lookup("section"), 40) = section
                return GuideLimitedText(item.Lookup("feed"), 80)
            end if
        end if
    end for
    return ""
end function

function FixesFromGuide() as boolean
    feed = MenuFeed("fixes")
    if feed = "" then return true
    marker = "guide.troubleshooting"
    if feed = marker then return true
    return false
end function

function AcceptMenuText(text as string, source as string) as object
    if text = invalid or text = "" then return invalid
    parsed = ParseObjectText(text)
    reason = MenuRejectReason(parsed)
    if reason <> "ok"
        print "Eaglewood: menu fallback reason="; reason
        return invalid
    end if
    menu = NormalizeMenu(parsed)
    if menu = invalid then return invalid
    menu.source = source
    menu.body = text
    return menu
end function

function BuiltinMenu() as object
    text = ReadAsciiFile("pkg:/data/menu.json")
    loaded = invalid
    if text <> invalid and text <> "" then loaded = NormalizeMenu(ParseObjectText(text))
    if loaded <> invalid
        loaded.source = "pkg"
        loaded.body = text
        return loaded
    end if
    menu = {}
    menu["source"] = "builtin"
    menu["body"] = ""
    home = { section: "home", label: "Home", type: "home", children: [] }
    wifi = { section: "wifi", label: "Wi-Fi", type: "wifi", children: [] }
    dining = {}
    dining["section"] = "dining"
    dining["label"] = "Dining"
    dining["empty"] = "Nothing to show yet."
    dining["sectionIds"] = ["dining"]
    dining["keywords"] = []
    dining["seasons"] = []
    hiking = {}
    hiking["section"] = "hiking"
    hiking["label"] = "Hiking"
    hiking["empty"] = "Nothing to show yet."
    hiking["sectionIds"] = ["hiking"]
    hiking["keywords"] = []
    hiking["seasons"] = []
    winter = {}
    winter["section"] = "winter"
    winter["label"] = "Winter"
    winter["empty"] = "Nothing to show yet."
    winter["sectionIds"] = []
    winter["keywords"] = []
    winter["seasons"] = ["winter", "year-round"]
    summer = {}
    summer["section"] = "summer"
    summer["label"] = "Summer"
    summer["empty"] = "Nothing to show yet."
    summer["sectionIds"] = []
    summer["keywords"] = []
    summer["seasons"] = ["summer", "year-round"]
    fishing = {}
    fishing["section"] = "fishing"
    fishing["label"] = "Fishing"
    fishing["empty"] = "No fishing spots listed right now."
    fishing["sectionIds"] = []
    fishing["keywords"] = ["fish"]
    fishing["seasons"] = []
    biking = {}
    biking["section"] = "biking"
    biking["label"] = "Biking"
    biking["empty"] = "Nothing to show yet."
    biking["sectionIds"] = ["mountain-biking"]
    biking["keywords"] = ["bike", "biking"]
    biking["seasons"] = []
    things = {}
    things["section"] = "todo"
    things["label"] = "Things to Do"
    things["type"] = "things"
    things["children"] = [dining, hiking, winter, summer, fishing, biking]
    rules = { section: "rules", label: "House Rules", type: "rules", children: [] }
    fixes = { section: "fixes", label: "Quick Fixes", type: "quickfixes", children: [] }
    fixes["feed"] = "guide.troubleshooting"
    book = { section: "book", label: "Book Direct", type: "book", children: [] }
    checkout = { section: "checkout", label: "Checkout", type: "checkout", children: [] }
    menu["items"] = [home, wifi, things, rules, fixes, book, checkout]
    return menu
end function

function ActiveMenuDoc() as object
    if m.menuDoc <> invalid then return m.menuDoc
    loaded = AcceptMenuText(ReadAsciiFile("pkg:/data/menu.json"), "pkg")
    if loaded = invalid
        print "Eaglewood: menu fallback reason=bundle"
        loaded = BuiltinMenu()
    end if
    m.menuDoc = loaded
    return loaded
end function

sub InstallMenu(menu as object)
    if menu = invalid then return
    m.menuDoc = menu
end sub

function MenuItems() as object
    doc = ActiveMenuDoc()
    items = AaField(doc, "items")
    if not IsList(items) then return []
    return items
end function

function MenuSection(item as object) as string
    return GuideLimitedText(AaField(item, "section"), 40)
end function

function MenuSectionIds() as object
    ids = []
    items = MenuItems()
    last = items.Count() - 1
    if last < 0 then return ids
    for index = 0 to last
        section = MenuSection(items[index])
        if section <> "" then ids.Push(section)
    end for
    return ids
end function

function TodoMenuIds() as object
    ids = []
    items = MenuItems()
    last = items.Count() - 1
    if last < 0 then return ids
    for index = 0 to last
        item = items[index]
        if MenuSection(item) = "todo"
            kids = AaField(item, "children")
            if IsList(kids)
                childLast = kids.Count() - 1
                if childLast >= 0
                    for childAt = 0 to childLast
                        section = MenuSection(kids[childAt])
                        if section <> "" then ids.Push(section)
                    end for
                end if
            end if
        end if
    end for
    return ids
end function

function MenuChild(section as string) as object
    if section = invalid or section = "" then return invalid
    items = MenuItems()
    last = items.Count() - 1
    if last < 0 then return invalid
    for index = 0 to last
        item = items[index]
        if MenuSection(item) = "todo"
            kids = AaField(item, "children")
            if IsList(kids)
                childLast = kids.Count() - 1
                if childLast >= 0
                    for childAt = 0 to childLast
                        child = kids[childAt]
                        if MenuSection(child) = section then return child
                    end for
                end if
            end if
        end if
    end for
    return invalid
end function

function MenuLabel(section as string) as string
    items = MenuItems()
    last = items.Count() - 1
    if last < 0 then return ""
    for index = 0 to last
        item = items[index]
        if MenuSection(item) = section then return GuideLimitedText(AaField(item, "label"), 80)
    end for
    child = MenuChild(section)
    if child = invalid then return ""
    return GuideLimitedText(AaField(child, "label"), 80)
end function

function MenuSourceText(menu as object) as string
    if menu = invalid or menu.source = invalid then return "builtin"
    return menu.source
end function

function MenuBodyText(menu as object) as string
    if menu = invalid then return ""
    body = menu.body
    if body <> invalid and body <> "" then return body
    return EncodeJson(menu)
end function

function MenuEmptyText(section as string) as string
    child = MenuChild(section)
    if child = invalid then return ""
    return GuideLimitedText(AaField(child, "empty"), 120)
end function

function ItemMatchesRule(item as object, rule as object) as boolean
    if not IsAssoc(item) or not IsAssoc(rule) then return false
    section = GuideLimitedText(AaField(item, "sectionId"), 80)
    ids = AaField(rule, "sectionIds")
    if IsList(ids)
        last = ids.Count() - 1
        if last >= 0
            for index = 0 to last
                if section = GuideLimitedText(ids[index], 80) then return true
            end for
        end if
    end if
    wanted = AaField(rule, "seasons")
    if IsList(wanted)
        raw = AaField(item, "season")
        if IsList(raw)
            rawLast = raw.Count() - 1
            wantLast = wanted.Count() - 1
            if rawLast >= 0 and wantLast >= 0
                for rawAt = 0 to rawLast
                    have = LCase(GuideLimitedText(raw[rawAt], 40))
                    for wantAt = 0 to wantLast
                        if have = LCase(GuideLimitedText(wanted[wantAt], 40)) then return true
                    end for
                end for
            end if
        end if
    end if
    keys = AaField(rule, "keywords")
    if IsList(keys)
        blob = ItemSearchText(item, section)
        keyLast = keys.Count() - 1
        if keyLast >= 0
            for index = 0 to keyLast
                needle = LCase(GuideLimitedText(keys[index], 40))
                if TextHas(blob, needle) then return true
            end for
        end if
    end if
    return false
end function

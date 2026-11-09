' SceneGraph chrome for the guest guide. The scene keeps focus; these nodes are not focusable.

function ContentLeft() as integer
    return 588
end function

function ContentTop() as integer
    return 154
end function

function ContentWidth() as integer
    return GreetingLabelWidth()
end function

function RailX() as integer
    return 96
end function

function RailY() as integer
    return 64
end function

function RailW() as integer
    return 440
end function

' Build 36 (Pixel b35 Home #1): the top panel ends at y 742 (64 + 678),
' 16px under the Checkout pill and 16px above the corner ad at y 758.
function RailH() as integer
    return 678
end function

' The Quick Fixes child panel keeps its b35 height.
function RailChildH() as integer
    return 664
end function

function VisibleIssueRows() as integer
    return 8
end function

function VisibleSteps() as integer
    return 4
end function

function VisibleRules() as integer
    return 8
end function

function VisibleCheckoutSteps() as integer
    return 6
end function

function AmberColor() as string
    return "0xF2A93BFF"
end function

function InkColor() as string
    return "0xFFFFFFFF"
end function

function MuteColor() as string
    return "0xD5DBE8FF"
end function

function InkOnAmber() as string
    return "0x1C1408FF"
end function

function GlassColor() as string
    return "0x1A2438D0"
end function

function TileColor() as string
    return "0x243044C8"
end function

function TopMenu() as object
    ids = MenuSectionIds()
    if ids.Count() < 1 then return ["home", "wifi", "todo", "rules", "fixes", "book", "checkout"]
    return ids
end function

function TodoMenu() as object
    ids = TodoMenuIds()
    if ids.Count() < 1 then ids = ["dining", "hiking", "winter", "summer", "fishing", "biking"]
    return NonEmptyTodo(ids)
end function

' Build 30 (Captain #7): a category with no items is left out of the rail and
' the preview. With no activities loaded yet, every category stays.
function NonEmptyTodo(ids as object) as object
    if not IsList(m.activities) then return ids
    if m.activities.Count() < 1 then return ids
    kept = []
    for each id in ids
        if ActivitiesForScreen(m.activities, id).Count() > 0 then kept.Push(id)
    end for
    if kept.Count() < 1 then return ids
    return kept
end function

function RailSections() as object
    return TopMenu()
end function

function HomeMenuIndex() as integer
    return MenuIndex(TopMenu(), "home")
end function

function MenuSlotCount() as integer
    return 7
end function

function ActiveMenu(depth as string) as object
    if depth = "todo" then return TodoMenu()
    if depth = "fixes" then return FixMenu()
    return TopMenu()
end function

function FixMenu() as object
    ids = []
    count = IssueCount()
    if count < 1 then count = 1
    index = 0
    while index < count
        ids.Push("fixes")
        index = index + 1
    end while
    return ids
end function

function MenuIndex(menu as object, section as string) as integer
    if menu = invalid then return 0
    last = menu.Count() - 1
    if last < 0 then return 0
    for index = 0 to last
        if menu[index] = section then return index
    end for
    return 0
end function

function TileSections() as object
    return ["wifi", "todo", "dining", "hiking", "fixes", "checkout"]
end function

function RailChevron(section as string) as string
    if section = "todo" then return ">"
    if section = "fixes" then return ">"
    if MenuChild(section) <> invalid then return ">"
    return ""
end function

' Pixel b28: the rail says "Checkout" so it stays on one line; the page H1
' keeps the full name (PageTitle).
function PageTitle(section as string) as string
    if section = "checkout" then return "Checkout Instructions"
    return RailLabel(section)
end function

function RailLabel(section as string) as string
    if section = "checkout" then return "Checkout"
    named = MenuLabel(section)
    if named <> "" then return named
    if section = "home" then return "Home"
    if section = "rules" then return "House Rules"
    if section = "fixes" then return "Quick Fixes"
    if section = "todo" then return "Things to Do"
    if section = "dining" then return "Dining"
    if section = "hiking" then return "Hiking"
    if section = "winter" then return "Winter"
    if section = "summer" then return "Summer"
    if section = "fishing" then return "Fishing"
    if section = "biking" then return "Biking"
    if section = "book" then return "Book Direct"
    if section = "checkout" then return "Checkout"
    if section = "wifi" then return "Wi-Fi"
    return "Home"
end function

function ShownBrand(brand as string) as string
    text = AsText(brand)
    if text = "" or text = "Eaglewood" then return "Eaglewood 19"
    return text
end function

function ActivityEmptyText(section as string) as string
    named = MenuEmptyText(section)
    if named <> "" then return named
    if section = "todo" then return "OK for Dining, Hiking, and the seasons."
    if section = "fishing" then return "No fishing spots listed right now."
    return "Nothing to show yet."
end function

function RailLabelWidth() as integer
    return CheckoutLabelWidth() - 36
end function

function CheckoutLabelWidth() as integer
    return RailW() - 24 - 84 - 8
end function

function RailRowHeight() as integer
    return 80
end function

function RailStride() as integer
    return 84
end function

' Build 36: rows start 22px higher so the 7th (Checkout) pill spans
' y 646-726 on screen (64 + 78 + 6*84 + 80 = 726).
function ParentRowY(index as integer) as integer
    return 78 + (index * RailStride())
end function

function ChildRowY(index as integer) as integer
    return 72 + (index * RailStride())
end function

function NavFontSize() as integer
    return 27
end function

function NavLineHeight() as integer
    return 44
end function

function PessimisticCharWidth(size as integer) as integer
    base = FallbackCharWidth(size)
    width = (base * 115 + 99) \ 100
    if width <= base then width = base + 1
    return width
end function

function LineBox(size as integer) as integer
    return size + 13
end function

function LongestWordWidth(text as string, charWidth as integer) as integer
    if text = invalid or text = "" then return 0
    if charWidth < 1 then charWidth = 1
    best = 0
    rest = text
    while Len(rest) > 0
        space = Instr(1, rest, " ")
        word = rest
        if space > 0
            word = Left(rest, space - 1)
            rest = Mid(rest, space + 1)
        else
            rest = ""
        end if
        wide = Len(word) * charWidth
        if wide > best then best = wide
    end while
    return best
end function

function CountWrapped(text as string, width as integer, charWidth as integer) as integer
    if text = invalid or text = "" then return 0
    total = 0
    rest = text
    while Len(rest) > 0
        nl = Instr(1, rest, Chr(10))
        piece = rest
        if nl > 0
            piece = Left(rest, nl - 1)
            rest = Mid(rest, nl + 1)
        else
            rest = ""
        end if
        lines = WrapGreeting(piece, width, invalid, charWidth)
        count = lines.Count()
        if count < 1 then count = 1
        total = total + count
        if total > 80 then return total
    end while
    return total
end function

function ScrollFontSize() as integer
    return 30
end function

' 42px leading at 30px.
function ScrollLineSpacing() as integer
    return 12
end function

function DetailTextWidth() as integer
    return ContentWidth() - 64
end function

' Quick Fixes panel: below the H1, grown to y 960 at most, 32px padding,
' hint row 24px above the bottom (DetailScroll.AreaHeight).
function FixPanelTop() as integer
    return ContentTop() + 80
end function

function FixPanelMaxHeight() as integer
    return 960 - FixPanelTop()
end function

function FixScrollViewport() as integer
    return FixPanelMaxHeight() - 32 - 24 - 40 - 16
end function

function ActivityScrollViewport() as integer
    return DetailBodyRect().h - 16 - 24 - 40 - 16
end function

function ScrollContentHeight(text as string, width as integer) as integer
    lines = CountWrapped(text, width, PessimisticCharWidth(ScrollFontSize()))
    return lines * (ScrollFontSize() + ScrollLineSpacing())
end function

function ScrollRange(text as string, width as integer, viewport as integer) as integer
    span = ScrollContentHeight(text, width) - viewport
    if span < 0 then return 0
    return span
end function

function MenuTitleBox() as object
    return { w: 300, h: 160, maxLines: 4, size: 27 }
end function

' ActivityCard, build 30: 30px title, 24px meta, 22px season pill text.
function CardNameBox() as object
    return { w: 332, h: 190, maxLines: 5, size: 30 }
end function

function CardDistanceBox() as object
    return { w: 332, h: 74, maxLines: 2, size: 24 }
end function

function CardSeasonBox() as object
    ' The pill draws one line (about 0.55 em per character); the pessimistic
    ' width allows a second line so no label can ellipsize.
    return { w: 306, h: 72, maxLines: 2, size: 22 }
end function

function LabelFitsBox(text as string, fit as object) as boolean
    if fit = invalid then return false
    if text = invalid then text = ""
    if text = "" then return true
    charWidth = PessimisticCharWidth(fit.size)
    if LongestWordWidth(text, charWidth) > fit.w then return false
    lines = WrapGreeting(text, fit.w, invalid, charWidth)
    count = lines.Count()
    if count > fit.maxLines then return false
    if count * LineBox(fit.size) > fit.h then return false
    last = count - 1
    if last >= 0
        for index = 0 to last
            if lines[index] = "overflow" then return false
        end for
    end if
    return true
end function

' Pixel b27: one 24px inner left padding and 20px top padding for both lines.
function TileTitleBox() as object
    grid = HomeGrid()
    return { x: TilePad(), y: 20, w: grid.w - (2 * TilePad()), h: 88 }
end function

function TileSubBox() as object
    grid = HomeGrid()
    ' Bottom-anchored, two lines, so a long subtitle wraps instead of clipping.
    return { x: TilePad(), y: 72, w: grid.w - (2 * TilePad()), h: 84, maxLines: 2, size: 28 }
end function

function TileTitleSize() as integer
    return 32
end function

' Text inset inside a Home tile (Pixel b28: 18px each side).
function TilePad() as integer
    return 18
end function

function TileSubColor() as string
    return "0xC9D1E0FF"
end function

' Home column, top to bottom: H1, subhead 12px under it, strip 32px under
' that, then a 3x2 grid with 24px gutters. The QR card sits right of the grid.
function HomeSubheadY() as integer
    ' Pixel b28: the subhead glyphs sit 12px under the H1 glyphs.
    return ContentTop() + 66
end function

function HomeStripRect() as object
    ' 32px from the subhead glyphs (box 40, glyph bottom about +34) to the strip.
    return { x: ContentLeft(), y: HomeSubheadY() + 66, w: HomeRight() - ContentLeft(), h: 164 }
end function

function HomeRight() as integer
    return 1717
end function

function HomeGrid() as object
    strip = HomeStripRect()
    gap = 24
    ' Build 35 (pixel b34 Home #3): the QR card is gone, so the three tiles
    ' span the Book Direct strip and end on its right edge (x 1699).
    span = HomeGridRight() - ContentLeft()
    w = (span - (2 * gap)) \ 3
    return { x: ContentLeft(), y: strip.y + strip.h + gap, w: w, h: 168, gap: gap }
end function

function HomeGridRight() as integer
    ' Banner ink ends at x 1699 (measured on b34 home-prompt-focus).
    return 1700
end function

function HomeGridBottom() as integer
    grid = HomeGrid()
    return grid.y + (2 * grid.h) + grid.gap
end function

' Pixel b27 drops the footer on Home, Things to Do and Wi-Fi. The domain is in
' the QR card on every page except Book Direct, which spells it out, so it is
' off everywhere.
function FooterShown(section as string) as boolean
    if section = "" then return false
    return false
end function

' Roku system fonts take a size on the Font node the label gets.
sub SetFontSize(label as object, size as integer)
    if label = invalid then return
    font = label.font
    if font = invalid then return
    if type(font) <> "roSGNode" then return
    font.size = size
end sub

function LabelLinesFit(text as string, width as integer, charWidth as integer, maxLines as integer, lineHeight as integer, boxHeight as integer) as boolean
    lines = WrapGreeting(text, width, invalid, charWidth)
    count = lines.Count()
    if count < 1 then return false
    if count > maxLines then return false
    if count * lineHeight > boxHeight then return false
    last = count - 1
    if last >= 0
        for index = 0 to last
            if lines[index] = "overflow" then return false
        end for
    end if
    return true
end function

function CheckoutNavFits() as boolean
    return LabelLinesFit(RailLabel("checkout"), CheckoutLabelWidth(), PessimisticCharWidth(NavFontSize()), 2, NavLineHeight(), RailRowHeight())
end function

function CheckoutTileFits() as boolean
    return TileTitleFits("checkout")
end function

function TileTitleFits(section as string) as boolean
    tileBox = TileTitleBox()
    return LabelLinesFit(TileTitle(section), tileBox.w, PessimisticCharWidth(NavFontSize()), 2, NavLineHeight(), tileBox.h)
end function

function CheckoutHeadingFits() as boolean
    return LabelLinesFit(PageTitle("checkout"), ContentWidth(), FallbackCharWidth(54), 1, 54, 64)
end function

function RailClearsContent() as boolean
    gap = ContentLeft() - (RailX() + RailW())
    if gap < 8 then return false
    return true
end function

function TileTitle(section as string) as string
    if section = "fixes" then return "Quick Fixes"
    ' The tile column is narrower now; the rail and the page keep the full name.
    if section = "checkout" then return "Checkout"
    ' "Things to Do" wraps in the 212px tile text box.
    if section = "todo" then return "To Do"
    return RailLabel(section)
end function

function SoonSection(section as string) as boolean
    return section = "soon"
end function

function AsText(value as object) as string
    if value = invalid then return ""
    kind = type(value)
    if kind = "roInt" or kind = "Integer" or kind = "roLongInteger" or kind = "LongInteger" then return value.ToStr()
    if kind <> "String" and kind <> "roString" then return ""
    return Left(value, Len(value))
end function

function OrText(value as object, fallback as string) as string
    text = AsText(value)
    if text = "" then return fallback
    return text
end function

function DecodeList(text as object) as object
    parsed = DecodeJson(text)
    if not IsList(parsed) then return []
    return parsed
end function

function DecodeAssoc(text as object) as object
    parsed = DecodeJson(text)
    if not IsAssoc(parsed) then return invalid
    return parsed
end function

function DecodeJson(text as object) as object
    raw = AsText(text)
    if raw = "" then return invalid
    return ParseJson(raw)
end function

sub BuildShell()
    shell = CreateObject("roSGNode", "Group")
    shell.id = "shell"
    shell.translation = [0, 0]
    if m.menuDepth = invalid or m.menuDepth = "" then m.menuDepth = "top"

    m.railDock = CreateObject("roSGNode", "Group")
    m.railDock.translation = [RailX(), RailY()]
    shell.appendChild(m.railDock)
    m.railTop = CreateObject("roSGNode", "Group")
    m.railTop.id = "railTop"
    m.railTop.translation = [0, 0]
    m.railDock.appendChild(m.railTop)
    AddRect(m.railTop, GlassColor(), 0, 0, RailW(), RailH())
    m.railBrand = AddLabel(m.railTop, ShownBrand("Eaglewood"), "font:MediumBoldSystemFont", InkColor(), 24, 8, RailW() - 48, 40)
    m.railPlace = AddLabel(m.railTop, "Sunriver, Oregon", "font:SmallSystemFont", MuteColor(), 24, 44, RailW() - 48, 32)

    m.railItems = []
    last = MenuSlotCount() - 1
    for index = 0 to last
        m.railItems.Push(MakeRailRow(m.railTop, ParentRowY(index)))
    end for

    m.railChild = CreateObject("roSGNode", "Group")
    m.railChild.id = "railChild"
    m.railChild.translation = [RailW(), 0]
    m.railChild.visible = false
    m.railDock.appendChild(m.railChild)
    AddRect(m.railChild, GlassColor(), 0, 0, RailW(), RailChildH())
    m.childHeader = AddLabel(m.railChild, "<  Things to Do", "font:SmallBoldSystemFont", AmberColor(), 16, 8, RailW() - 32, 52)
    m.childMenu = CreateObject("roSGNode", "MenuPanel")
    m.railChild.appendChild(m.childMenu)
    m.childMenuQuiet = false
    if m.childMenu.list <> invalid
        menuBox = MenuTitleBox()
        m.childMenu.list.itemSize = [menuBox.w + 64, menuBox.h + 16]
        m.childMenu.list.itemSpacing = [0, 4]
        m.childMenu.list.numRows = 4
    end if
    m.detailScroll = CreateObject("roSGNode", "DetailScroll")
    m.detailScroll.translation = [ContentLeft(), ContentTop()]
    m.detailScroll.visible = false
    shell.appendChild(m.detailScroll)
    BuildFixesPage(shell)

    m.homePane = CreateObject("roSGNode", "Group")
    shell.appendChild(m.homePane)
    m.subtitle = AddLabel(m.homePane, "Checkout", "font:SmallSystemFont", MuteColor(), ContentLeft(), HomeSubheadY(), ContentWidth(), 40)
    SetFontSize(m.subtitle, 28)
    m.subtitle.vertAlign = "top"
    m.subtitle.maxLines = 1
    BuildTiles(m.homePane)

    m.rulesPane = BuildRulesPane(shell)
    m.fixesPane = BuildFixesPane(shell)
    m.checkoutPane = BuildCheckoutPane(shell)
    m.helpPane = BuildHelpPane(shell)
    m.soonPane = BuildSoonPane(shell)
    BuildPhase2(shell)

    footerW = ContentWidth()
    m.footer = AddLabel(shell, FooterLine(), "font:SmallSystemFont", MuteColor(), ContentLeft(), 848, footerW, 88)
    m.footer.maxLines = 2
    m.footer.vertAlign = "top"
    m.offline = AddLabel(shell, "", "font:SmallSystemFont", AmberColor(), ContentLeft(), 968, 280, 32)
    m.offline.horizAlign = "right"
    m.offline.visible = false

    m.top.appendChild(shell)
    m.shell = shell
    ' Scroll sits above the detail pane. The badge stays the last shell child.
    RaiseDetailScroll()
    RaiseBadge()
end sub

' Quick Fixes H1 at the standard H1 spot, and a rail-focus preview of the
' first four issue titles (Pixel b28).
sub BuildFixesPage(shell as object)
    page = CreateObject("roSGNode", "Group")
    page.visible = false
    shell.appendChild(page)
    m.fixesPage = page
    m.fixesTitle = AddLabel(page, RailLabel("fixes"), "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 68)
    SetFontSize(m.fixesTitle, PageH1Size())
    m.fixesPreview = []
    for index = 0 to 3
        y = FixPanelTop() + 8 + (index * 64)
        dot = AddRect(page, AmberColor(), ContentLeft() + 4, y + 13, 12, 12)
        line = AddLabel(page, "", "font:SmallSystemFont", InkColor(), ContentLeft() + 32, y, ContentWidth() - 32, 40)
        SetFontSize(line, 30)
        line.maxLines = 1
        m.fixesPreview.Push({ dot: dot, line: line })
    end for
end sub

sub PaintFixesPage(section as string)
    if m.fixesPage = invalid then return
    show = (section = "fixes")
    m.fixesPage.visible = show
    preview = show and MenuDepth() = "top"
    issues = []
    if preview then issues = FixIssues()
    for index = 0 to m.fixesPreview.Count() - 1
        entry = m.fixesPreview[index]
        text = ""
        if index < issues.Count() then text = AsText(issues[index].Lookup("issue"))
        entry.line.text = text
        entry.line.visible = (text <> "")
        entry.dot.visible = (text <> "")
    end for
end sub

sub RaiseDetailScroll()
    if m.detailScroll = invalid or m.shell = invalid then return
    m.shell.removeChild(m.detailScroll)
    m.shell.appendChild(m.detailScroll)
end sub

sub BuildTiles(parent as object)
    m.tiles = []
    sections = TileSections()
    grid = HomeGrid()
    last = sections.Count() - 1
    for index = 0 to last
        col = index mod 3
        row = index \ 3
        x = grid.x + (col * (grid.w + grid.gap))
        y = grid.y + (row * (grid.h + grid.gap))
        group = CreateObject("roSGNode", "Group")
        group.translation = [x, y]
        ' No drop shadow: it made the 24px gutters read as 26 across and 19 down.
        outer = AddRect(group, TileColor(), 0, 0, grid.w, grid.h)
        inner = AddRect(group, TileColor(), 0, 0, grid.w, grid.h)
        titleBox = TileTitleBox()
        title = AddLabel(group, TileTitle(sections[index]), "font:SmallBoldSystemFont", "0xFFFFFFFF", titleBox.x, titleBox.y, titleBox.w, titleBox.h)
        SetFontSize(title, TileTitleSize())
        title.maxLines = 2
        title.vertAlign = "top"
        subBox = TileSubBox()
        subLabel = AddLabel(group, "", "font:SmallSystemFont", TileSubColor(), subBox.x, subBox.y, subBox.w, subBox.h)
        SetFontSize(subLabel, subBox.size)
        subLabel.wrap = true
        subLabel.vertAlign = "bottom"
        subLabel.maxLines = subBox.maxLines
        parent.appendChild(group)
        m.tiles.Push({
            group: group,
            outer: outer,
            inner: inner,
            title: title,
            subLabel: subLabel,
            wide: grid.w,
            tall: grid.h,
            section: sections[index]
        })
    end for
end sub

function BuildRulesPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, "House Rules", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.rulesMeta = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 68, ContentWidth(), 36)
    ' Build 29 (Pixel b28): navy 70% scrim at x 588-1300 with 32px padding,
    ' 12px gold round bullets, 30px text at a 56px pitch.
    m.rulesScrim = AddRect(pane, "0x1B2A44B3", ContentLeft(), RulesTop(), RulesScrimWidth(), 120)
    m.ruleLabels = []
    m.ruleDots = []
    last = VisibleRules() - 1
    for index = 0 to last
        dot = CreateObject("roSGNode", "Poster")
        dot.uri = "pkg:/images/dot-gold.png"
        dot.width = 12
        dot.height = 12
        dot.visible = false
        pane.appendChild(dot)
        m.ruleDots.Push(dot)
        label = AddLabel(pane, "", "font:SmallSystemFont", InkColor(), ContentLeft() + 32 + 28, RulesTop() + 32 + (index * 56), RuleTextWidth(), 40)
        SetFontSize(label, 30)
        label.vertAlign = "top"
        label.maxLines = 3
        m.ruleLabels.Push(label)
    end for
    return pane
end function

function CheckoutStepsTop() as integer
    return ContentTop() + 124
end function

function RulesTop() as integer
    return ContentTop() + 116
end function

function RulesScrimWidth() as integer
    return 1300 - ContentLeft()
end function

function RuleTextWidth() as integer
    return RulesScrimWidth() - 64 - 28
end function

' The subhead already gives check-in and check-out, so those bullets go.
function ShownRules(rules as object) as object
    out = []
    if not IsList(rules) then return out
    for each rule in rules
        text = LCase(AsText(rule).Trim())
        repeat = (Left(text, 8) = "check-in" or Left(text, 9) = "check-out" or Left(text, 8) = "checkout")
        if not repeat then out.Push(rule)
    end for
    return out
end function

function BuildFixesPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    pane.id = "fixesPane"
    parent.appendChild(pane)
    return pane
end function

function BuildCheckoutPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, PageTitle("checkout"), "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.checkoutWhen = AddLabel(pane, "", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 68, ContentWidth(), 36)
    ' Build 29: the summary sentence repeated the subhead and steps, so it is
    ' kept only as a hidden node.
    m.checkoutSummary = AddLabel(pane, "", "font:SmallSystemFont", InkColor(), ContentLeft(), ContentTop() + 112, ContentWidth(), 110)
    m.checkoutSummary.vertAlign = "top"
    m.checkoutSummary.maxLines = 4
    m.checkoutSummary.visible = false
    m.checkoutStepRows = []
    last = VisibleCheckoutSteps() - 1
    for index = 0 to last
        group = CreateObject("roSGNode", "Group")
        group.translation = [ContentLeft(), CheckoutStepsTop() + (index * 72)]
        ' 44px gold circle, 28px navy numeral, text 20px to the right.
        badge = CreateObject("roSGNode", "Poster")
        badge.uri = "pkg:/images/circle-gold.png"
        badge.width = 44
        badge.height = 44
        group.appendChild(badge)
        numberLabel = AddLabel(group, "", "font:SmallBoldSystemFont", "0x1B2A44FF", 0, 0, 44, 44)
        SetFontSize(numberLabel, 28)
        numberLabel.horizAlign = "center"
        numberLabel.vertAlign = "center"
        body = AddLabel(group, "", "font:SmallSystemFont", InkColor(), 64, 2, ContentWidth() - 64, 80)
        SetFontSize(body, 30)
        body.vertAlign = "top"
        body.maxLines = 3
        pane.appendChild(group)
        m.checkoutStepRows.Push({ group: group, numberLabel: numberLabel, body: body })
    end for
    ' Host line pinned at y 920, 26px #C9D1E0. The text (name and business
    ' email) is unchanged.
    m.checkoutHost = AddLabel(pane, "", "font:SmallSystemFont", "0xC9D1E0FF", ContentLeft(), 920, ContentWidth(), 40)
    SetFontSize(m.checkoutHost, 26)
    return pane
end function

function BuildHelpPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    AddLabel(pane, "Help", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.helpName = AddLabel(pane, "", "font:MediumBoldSystemFont", InkColor(), ContentLeft(), ContentTop() + 96, ContentWidth(), 48)
    m.helpEmail = AddLabel(pane, "", "font:MediumSystemFont", InkColor(), ContentLeft(), ContentTop() + 156, ContentWidth(), 44)
    m.helpPhone = AddLabel(pane, "", "font:MediumBoldSystemFont", AmberColor(), ContentLeft(), ContentTop() + 214, ContentWidth(), 48)
    m.helpPhone.visible = false
    m.helpNote = AddLabel(pane, "Message us in your booking app.", "font:SmallSystemFont", MuteColor(), ContentLeft(), ContentTop() + 280, ContentWidth(), 40)
    return pane
end function

function BuildSoonPane(parent as object) as object
    pane = CreateObject("roSGNode", "Group")
    pane.visible = false
    parent.appendChild(pane)
    m.soonTitle = AddLabel(pane, "", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop(), ContentWidth(), 64)
    m.soonBody = AddLabel(pane, "Coming soon", "font:LargeBoldSystemFont", InkColor(), ContentLeft(), ContentTop() + 140, ContentWidth(), 64)
    m.soonMore = AddLabel(pane, "Coming in a later update.", "font:MediumSystemFont", MuteColor(), ContentLeft(), ContentTop() + 214, ContentWidth(), 44)
    return pane
end function

function AddRect(parent as object, color as string, x as integer, y as integer, width as integer, height as integer) as object
    rect = CreateObject("roSGNode", "Rectangle")
    rect.color = color
    rect.width = width
    rect.height = height
    rect.translation = [x, y]
    parent.appendChild(rect)
    return rect
end function

function AddLabel(parent as object, text as string, fontName as string, color as string, x as integer, y as integer, width as integer, height as integer) as object
    label = CreateObject("roSGNode", "Label")
    label.font = fontName
    label.color = color
    label.width = width
    label.height = height
    label.wrap = true
    label.vertAlign = "center"
    label.text = text
    label.translation = [x, y]
    parent.appendChild(label)
    return label
end function

sub ShowSection(section as string)
    home = (section = "home")
    if m.homePane <> invalid then m.homePane.visible = home
    if m.greeting <> invalid then m.greeting.visible = home
    if m.rulesPane <> invalid then m.rulesPane.visible = (section = "rules")
    if m.fixesPane <> invalid then m.fixesPane.visible = false
    if m.checkoutPane <> invalid then m.checkoutPane.visible = (section = "checkout")
    if m.helpPane <> invalid then m.helpPane.visible = false
    if m.soonPane <> invalid then m.soonPane.visible = SoonSection(section)
    if m.bookPane <> invalid then m.bookPane.visible = (section = "book")
    if m.wifiPane <> invalid then m.wifiPane.visible = (section = "wifi")
    onActivity = ActivitySection(section)
    if m.activityPane <> invalid then m.activityPane.visible = onActivity and m.zone <> "item"
    if m.detailPane <> invalid then m.detailPane.visible = onActivity and m.zone = "item"
    showScroll = false
    if MenuDepth() = "fixes" then showScroll = true
    if onActivity = true
        if m.zone = "item" then showScroll = true
    end if
    if m.detailScroll <> invalid
        m.detailScroll.visible = showScroll
        if showScroll = true
            PlaceDetailScroll()
            FillDetailBody()
        end if
    end if
    if m.footer <> invalid then m.footer.visible = FooterShown(section)
    PaintFixesPage(section)
    if not onActivity then ReleaseCardImages()
    ShowQrFrame("badge", BadgeShown(section))
    ShowQrFrame("book", QrRemote("book") <> "")
    ShowQrFrame("detail", QrRemote("detail") <> "")
    ReassignStoredQrs()
    LogQrScreen()
    LogBadgePlacement()
    Nav2Paint()
end sub

sub PaintAll()
    if m.shell = invalid then return
    PaintChrome()
    PaintRail()
    PaintTiles()
    PaintRules()
    PaintFixes()
    PaintCheckout()
    PaintHelp()
    PaintSoon()
    PaintPhase2()
    RefreshHomeLine()
    Nav2Paint()
end sub

sub PaintChrome()
    if m.railBrand <> invalid then m.railBrand.text = ShownBrand(OrText(m.brand, "Eaglewood"))
    if m.railPlace <> invalid then m.railPlace.text = OrText(m.place, "Sunriver, Oregon")
    if m.footer <> invalid then m.footer.text = FooterLine()
    PaintOffline()
end sub

sub PaintOffline()
    if m.offline = invalid then return
    text = ""
    if m.guideSource = "builtin" then text = "Offline copy"
    if m.guideSource = "pkg" then text = "Packaged copy"
    if m.guideSource = "cachefs" then text = "Saved copy"
    if text = ""
        m.offline.text = ""
        m.offline.visible = false
        return
    end if
    m.offline.text = text
    m.offline.visible = true
end sub

sub RefreshHomeLine()
    if m.subtitle = invalid then return
    m.subtitle.text = HomeStatusLine()
end sub

function MakeRailRow(parent as object, rowY as integer) as object
    group = CreateObject("roSGNode", "Group")
    group.translation = [12, rowY]
    bg = AddRect(group, "0x00000000", 0, 0, RailW() - 24, RailRowHeight())
    label = AddLabel(group, "", "font:SmallBoldSystemFont", InkColor(), 84, 0, RailLabelWidth(), RailRowHeight())
    label.maxLines = 2
    label.wrap = true
    mark = AddLabel(group, "", "font:SmallBoldSystemFont", InkColor(), 84 + RailLabelWidth() + 4, 0, 36, RailRowHeight())
    mark.horizAlign = "center"
    parent.appendChild(group)
    return { group: group, bg: bg, label: label, mark: mark }
end function

sub PaintRailRows(rows as object, menu as object, childPanel as boolean)
    if rows = invalid or menu = invalid then return
    active = false
    if MenuDepth() = "top" then active = true
    if childPanel = true then active = false
    last = rows.Count() - 1
    if last < 0 then return
    for index = 0 to last
        row = rows[index]
        if index < menu.Count()
            row.group.visible = true
            row.label.text = RailLabel(menu[index])
            row.mark.text = RailChevron(menu[index])
            wide = RailLabelWidth()
            if row.mark.text = "" then wide = CheckoutLabelWidth()
            row.label.width = wide
            current = false
            if active = true
                if index = m.railIndex then current = true
            end if
            focused = false
            if current = true
                if m.zone = "rail" then focused = true
            end if
            ' Quick Fixes keeps its row selected while its list and steps show.
            if childPanel <> true and MenuDepth() = "fixes" and menu[index] = "fixes"
                current = true
                focused = false
            end if
            ' Build 37: remember the state as a boolean; reading bg.color back
            ' gives an roInt on the TV, and comparing it with a "0x..." string
            ' is a Type Mismatch there.
            row.focused = focused
            if focused
                row.bg.color = AmberColor()
                row.label.color = InkOnAmber()
                row.mark.color = InkOnAmber()
            else if current
                row.bg.color = "0x3A4A66FF"
                row.label.color = InkColor()
                row.mark.color = InkColor()
            else
                row.bg.color = "0x00000000"
                row.label.color = InkColor()
                row.mark.color = AmberColor()
            end if
        else
            row.focused = false
            row.group.visible = false
            row.label.text = ""
            row.mark.text = ""
        end if
    end for
end sub

sub PaintRail()
    if m.bookFocusFrame <> invalid then m.bookFocusFrame.visible = (m.section = "book" and m.zone <> "rail")
    heading = RailLabel("todo")
    if MenuDepth() = "fixes" then heading = RailLabel("fixes")
    if m.childHeader <> invalid then m.childHeader.text = "<  " + heading
    PaintRailRows(m.railItems, TopMenu(), false)
    FillChildMenu()
end sub

'' Things to Do labels are one line, so its rows are half the Quick Fixes height.
function ChildLabelWidth() as integer
    return MenuTitleBox().w
end function

sub SizeChildRows(depth as string)
    if m.childMenu = invalid or m.childMenu.list = invalid then return
    menuBox = MenuTitleBox()
    tall = menuBox.h + 16
    rows = 4
    if depth = "todo"
        tall = RailRowHeight()
        rows = 6
    end if
    m.childMenu.list.itemSize = [menuBox.w + 64, tall]
    m.childMenu.list.numRows = rows
end sub

sub FillChildMenu()
    if m.childMenu = invalid then return
    titles = []
    fromGuide = false
    if MenuDepth() = "fixes"
        if FixesFromGuide() then fromGuide = true
    end if
    if fromGuide
        issues = FixIssues()
        last = issues.Count() - 1
        if last >= 0
            for index = 0 to last
                titles.Push(AsText(issues[index].Lookup("issue")))
            end for
        end if
    else
        menu = TodoMenu()
        last = menu.Count() - 1
        if last >= 0
            for index = 0 to last
                titles.Push(RailLabel(menu[index]))
            end for
        end if
    end if
    key = MenuDepth() + ":" + titles.Count().ToStr()
    if m.childMenuKey = key then return
    m.childMenuKey = key
    SizeChildRows(MenuDepth())
    root = CreateObject("roSGNode", "ContentNode")
    if root = invalid then return
    last = titles.Count() - 1
    if last >= 0
        for index = 0 to last
            node = root.createChild("ContentNode")
            ' Build 33 (Pixel b32 P3): break the title here and trim each line,
            ' so a wrapped line never starts with the space the label kept.
            node.title = JoinLines(BreakLines(titles[index], ChildLabelWidth(), MenuTitleBox().size))
            node.shortDescriptionLine1 = ">"
            node.addField("lit", "boolean", false)
        end for
    end if
    m.childMenuQuiet = true
    if m.childMenu.list <> invalid then m.childMenu.list.content = root
    m.childMenuQuiet = false
    SyncChildList()
end sub

sub PlaceDetailScroll()
    if m.detailScroll = invalid then return
    ' Build 30 (Pixel b29 P3): 28px body; 42px pitch in Quick Fixes, 40 in details.
    m.detailScroll.fontSize = 28
    if MenuDepth() = "fixes"
        m.detailScroll.pitch = 42
        m.detailScroll.padding = 32
        m.detailScroll.translation = [ContentLeft(), FixPanelTop()]
        m.detailScroll.frameWidth = ContentWidth()
        m.detailScroll.frameHeight = FixPanelMaxHeight()
        return
    end if
    body = DetailBodyRect()
    m.detailScroll.pitch = 40
    m.detailScroll.padding = 16
    m.detailScroll.translation = [body.x, body.y]
    m.detailScroll.frameWidth = body.w
    m.detailScroll.frameHeight = body.h
end sub

' Quick Fixes: the panel hugs its content, 360px minimum, y 960 maximum.
sub FitFixPanel()
    if m.detailScroll = invalid then return
    if MenuDepth() <> "fixes" then return
    m.detailScroll.frameHeight = FixPanelMaxHeight()
    need = m.detailScroll.contentHeight + 32 + 16 + 40 + 24
    if need < 360 then need = 360
    if need > FixPanelMaxHeight() then need = FixPanelMaxHeight()
    m.detailScroll.frameHeight = need
end sub

function MoveBodyScroll(direction as integer) as boolean
    if m.detailScroll = invalid then return true
    nextOffset = m.detailScroll.offset + direction
    if nextOffset < 0 or nextOffset > m.detailScroll.maxOffset then return true
    m.detailScroll.offset = nextOffset
    print "Eaglewood: body scroll offset="; nextOffset; " max="; m.detailScroll.maxOffset
    return true
end function

function FixScrollText() as string
    title = FixHeading()
    steps = FixStepsText()
    if steps = "" then return title
    return title + Chr(10) + steps
end function

function FixHeading() as string
    issue = CurrentIssue()
    if issue = invalid then return "Nothing to show yet."
    return AsText(issue.Lookup("issue"))
end function

function FixStepsText() as string
    issue = CurrentIssue()
    if issue = invalid then return ""
    steps = issue.Lookup("steps")
    if steps = invalid then return ""
    kind = type(steps)
    if kind <> "roArray" and kind <> "Array" then return ""
    text = ""
    last = steps.Count() - 1
    if last < 0 then return ""
    for index = 0 to last
        if text <> "" then text = text + Chr(10)
        text = text + (index + 1).ToStr() + ". " + AsText(steps[index]).Trim()
    end for
    return text
end function

sub FillDetailBody()
    if m.detailScroll = invalid then return
    text = ""
    heading = ""
    hint = ""
    if MenuDepth() = "fixes"
        heading = FixHeading()
        text = FixStepsText()
        ' Build 30 (Captain #8): Right from the fix list lands in zone "item",
        ' where Up/Down scroll the steps, so that zone gets the scroll hint.
        ' Build 32: the same submenu as Things to Do. Right/OK open the steps,
        ' Left/Back return to the fix list, Back again slides the menu out.
        if m.zone = "detail" or m.zone = "item"
            hint = "Up/Down|Scroll|Back|Fixes list"
        else
            hint = "Up/Down|Next fix|OK|Open steps|Back|Menu"
        end if
    else
        if ActivitySection(m.section) = true
            if m.zone = "item" then text = ActivityScrollText()
        end if
        hint = "Up/Down|Scroll|Back|Back to the list"
    end if
    m.detailScroll.heading = heading
    m.detailScroll.body = text
    m.detailScroll.hint = hint
    FitFixPanel()
end sub

sub PaintTiles()
    if m.tiles = invalid then return
    last = m.tiles.Count() - 1
    if last < 0 then return
    for index = 0 to last
        tile = m.tiles[index]
        focused = (m.zone = "tiles" and index = m.tileIndex and m.section = "home")
        if focused
            tile.outer.color = AmberColor()
            tile.inner.translation = [6, 6]
            tile.inner.width = tile.wide - 12
            tile.inner.height = tile.tall - 12
        else
            tile.outer.color = TileColor()
            tile.inner.translation = [0, 0]
            tile.inner.width = tile.wide
            tile.inner.height = tile.tall
        end if
        tile.inner.color = TileColor()
        tile.subLabel.text = TileSubtitle(tile.section)
    end for
end sub

function TileSubtitle(section as string) as string
    if section = "wifi" then return "Scan to join"
    if section = "todo" then return "Seasonal picks"
    if section = "dining" then return "Village & Bend"
    if section = "hiking" then return "Trails nearby"
    if section = "fixes" then return "How-tos"
    if section = "checkout"
        if m.checkOut <> invalid and m.checkOut <> "" then return "By " + ShortClock(m.checkOut)
        return "By checkout"
    end if
    return ""
end function

'' "11:00 AM" -> "11 AM"; "10:30 AM" stays. Keeps the Checkout tile on one line.
function ShortClock(text as string) as string
    if text = invalid then return ""
    return text.Replace(":00 ", " ")
end function

function FixIssues() as object
    if m.fixIssues = invalid then return []
    return m.fixIssues
end function

function IssueCount() as integer
    return FixIssues().Count()
end function

function RuleCount() as integer
    if m.rules = invalid then return 0
    return m.rules.Count()
end function

function CheckoutStepCount() as integer
    if m.checkoutSteps = invalid then return 0
    return m.checkoutSteps.Count()
end function

function CurrentIssue() as object
    issues = FixIssues()
    if m.issueIndex < 0 or m.issueIndex >= issues.Count() then return invalid
    return issues[m.issueIndex]
end function

function StepCount() as integer
    issue = CurrentIssue()
    if issue = invalid then return 0
    steps = issue.Lookup("steps")
    if steps = invalid then return 0
    kind = type(steps)
    if kind <> "roArray" and kind <> "Array" then return 0
    return steps.Count()
end function

function ListText(value as object, index as integer) as string
    if value = invalid then return ""
    if index < 0 or index >= value.Count() then return ""
    return AsText(value[index])
end function

sub PaintRules()
    if m.ruleLabels = invalid then return
    if m.rulesMeta <> invalid
        m.rulesMeta.text = "Check-in " + m.checkIn + " · Check-out " + m.checkOut
    end if
    start = WindowStart(RuleCount(), VisibleRules(), m.ruleScroll)
    last = m.ruleLabels.Count() - 1
    if last < 0 then return
    y = RulesTop() + 32
    shown = 0
    for index = 0 to last
        label = m.ruleLabels[index]
        dot = m.ruleDots[index]
        text = ListText(m.rules, start + index)
        lines = BreakLines(text, RuleTextWidth(), 30)
        if text = "" or y + (lines.Count() * 40) > 940
            label.visible = false
            label.text = ""
            dot.visible = false
        else
            label.visible = true
            label.text = JoinLines(lines)
            label.translation = [ContentLeft() + 32 + 28, y]
            label.height = lines.Count() * 40
            dot.translation = [ContentLeft() + 32, y + 13]
            dot.visible = true
            y = y + 56 + ((lines.Count() - 1) * 40)
            shown = shown + 1
        end if
    end for
    if m.rulesScrim <> invalid
        m.rulesScrim.visible = (shown > 0)
        m.rulesScrim.height = (y - 56 + 40 + 32) - RulesTop()
    end if
end sub

sub PaintFixes()
    if MenuDepth() = "fixes" then FillDetailBody()
end sub

function IssueWindowBias() as integer
    count = IssueCount()
    visible = VisibleIssueRows()
    if count <= visible then return 0
    start = m.issueIndex - 3
    if start < 0 then start = 0
    if start > count - visible then return count - visible
    return start
end function

function WindowStart(count as integer, visible as integer, scroll as integer) as integer
    if count <= visible then return 0
    start = scroll
    if start < 0 then start = 0
    if start > count - visible then return count - visible
    return start
end function

sub PaintSteps()
    if m.stepRows = invalid then return
    issue = CurrentIssue()
    title = ""
    steps = invalid
    if issue <> invalid
        title = AsText(issue.Lookup("issue"))
        steps = issue.Lookup("steps")
    end if
    if m.detailTitle <> invalid then m.detailTitle.text = title
    maxScroll = StepCount() - VisibleSteps()
    if maxScroll < 0 then maxScroll = 0
    if m.stepScroll > maxScroll then m.stepScroll = maxScroll
    if m.stepScroll < 0 then m.stepScroll = 0
    last = m.stepRows.Count() - 1
    for index = 0 to last
        row = m.stepRows[index]
        stepIndex = m.stepScroll + index
        text = ""
        if steps <> invalid then text = ListText(steps, stepIndex)
        if text = ""
            row.group.visible = false
        else
            row.group.visible = true
            row.numberLabel.text = (stepIndex + 1).ToStr()
            row.body.text = text
        end if
    end for
end sub

function FixesHint() as string
    if m.zone = "detail" then return "Up/Down scroll    Left list    Back menu"
    if StepCount() > VisibleSteps() then return "Up/Down choose    Right steps    Left menu    Back"
    return "Up/Down choose    Left menu    Back"
end function

sub PaintCheckout()
    if m.checkoutSummary = invalid then return
    m.checkoutSummary.text = m.summary
    if m.checkoutWhen <> invalid then m.checkoutWhen.text = CheckoutWhenLine()
    if m.checkoutHost <> invalid then m.checkoutHost.text = HostLine()
    if m.checkoutStepRows = invalid then return
    maxScroll = CheckoutStepCount() - VisibleCheckoutSteps()
    if maxScroll < 0 then maxScroll = 0
    if m.checkoutScroll > maxScroll then m.checkoutScroll = maxScroll
    if m.checkoutScroll < 0 then m.checkoutScroll = 0
    start = WindowStart(CheckoutStepCount(), VisibleCheckoutSteps(), m.checkoutScroll)
    last = m.checkoutStepRows.Count() - 1
    stepY = CheckoutStepsTop()
    for index = 0 to last
        row = m.checkoutStepRows[index]
        text = ListText(m.checkoutSteps, start + index)
        if text = ""
            row.group.visible = false
        else
            row.group.visible = true
            row.numberLabel.text = (start + index + 1).ToStr()
            lines = BreakLines(text, ContentWidth() - 64, 30)
            row.body.text = JoinLines(lines)
            row.body.height = (lines.Count() * 40) + 8
            row.group.translation = [ContentLeft(), stepY]
            tall = lines.Count() * 40
            if tall < 44 then tall = 44
            stepY = stepY + tall + 28
        end if
    end for
end sub

function CheckoutWhenLine() as string
    when = m.checkOut
    if when = invalid or when = "" then when = "11:00 AM"
    dateLabel = ""
    if m.guestStay = "current" then dateLabel = FormatStayDate(m.guestCheckout)
    if dateLabel <> "" then return "Your checkout is " + dateLabel + " at " + when
    return "Checkout time " + when
end function

sub PaintHelp()
    if m.helpName = invalid then return
    m.helpName.text = m.hostName
    if m.helpEmail <> invalid then m.helpEmail.text = m.hostEmail
    if m.helpPhone = invalid then return
    if m.hostPhone = ""
        m.helpPhone.text = ""
        m.helpPhone.visible = false
    else
        m.helpPhone.text = m.hostPhone
        m.helpPhone.visible = true
    end if
    if m.helpNote <> invalid then m.helpNote.text = "Message us in your booking app."
end sub

sub PaintSoon()
    if m.soonTitle = invalid then return
    m.soonTitle.text = RailLabel(m.section)
    if m.soonBody <> invalid then m.soonBody.text = "Coming soon"
    if m.soonMore <> invalid then m.soonMore.text = "Coming in a later update."
end sub

function BundleFromResult(result as object) as object
    return {
        brand: AsText(result.brand),
        place: AsText(result.place),
        domain: AsText(result.domain),
        checkIn: AsText(result.checkIn),
        checkOut: AsText(result.checkOut),
        quietHours: AsText(result.quietHours),
        hostName: AsText(result.hostName),
        hostEmail: AsText(result.hostEmail),
        hostPhone: AsText(result.hostPhone),
        summary: AsText(result.summary),
        guideSource: AsText(result.guideSource),
        guideCode: AsText(result.guideCode),
        guideVersion: AsText(result.guideVersion),
        checkoutSource: AsText(result.checkoutSource),
        checkoutCode: AsText(result.checkoutCode),
        checkoutVersion: AsText(result.checkoutVersion),
        rules: DecodeList(result.rulesJson),
        issues: DecodeList(result.issuesJson),
        checkoutSteps: DecodeList(result.stepsJson),
        activities: DecodeList(result.activitiesJson),
        book: DecodeAssoc(result.bookJson),
        activitiesSource: AsText(result.activitiesSource),
        activitiesCode: AsText(result.activitiesCode),
        activitiesVersion: AsText(result.activitiesVersion),
        menuSource: AsText(result.menuSource),
        menuJson: AsText(result.menuJson)
    }
end function

sub ApplyBundle(bundle as object)
    if bundle = invalid then return
    m.brand = OrText(bundle.brand, "Eaglewood")
    m.place = OrText(bundle.place, "Sunriver, Oregon")
    m.domain = OrText(bundle.domain, "sunrivertownhome.com")
    m.checkIn = OrText(bundle.checkIn, "4:00 PM")
    m.checkOut = OrText(bundle.checkOut, "11:00 AM")
    m.quietHours = AsText(bundle.quietHours)
    m.hostName = AsText(bundle.hostName)
    m.hostEmail = AsText(bundle.hostEmail)
    m.hostPhone = AsText(bundle.hostPhone)
    m.summary = AsText(bundle.summary)
    m.guideSource = OrText(bundle.guideSource, "builtin")
    m.guideCode = OrText(bundle.guideCode, "0")
    m.guideVersion = OrText(bundle.guideVersion, "0")
    m.checkoutSource = OrText(bundle.checkoutSource, "builtin")
    m.checkoutCode = OrText(bundle.checkoutCode, "0")
    m.checkoutVersion = OrText(bundle.checkoutVersion, "0")
    if bundle.rules <> invalid
        m.rules = ShownRules(bundle.rules)
    else
        m.rules = []
    end if
    if bundle.issues <> invalid
        m.issues = bundle.issues
    else
        m.issues = []
    end if
    if bundle.checkoutSteps <> invalid
        m.checkoutSteps = bundle.checkoutSteps
    else
        m.checkoutSteps = []
    end if
    if IsList(bundle.activities)
        m.activities = bundle.activities
    else
        m.activities = []
    end if
    if IsAssoc(bundle.book)
        m.book = bundle.book
    else
        m.book = DefaultBookDirect()
    end if
    m.activitiesSource = OrText(bundle.activitiesSource, "builtin")
    m.activitiesCode = OrText(bundle.activitiesCode, "0")
    m.activitiesVersion = OrText(bundle.activitiesVersion, "0")
    if m.activitiesToken = invalid then m.activitiesToken = 0
    m.activitiesToken = m.activitiesToken + 1
    if bundle.menuJson <> invalid and bundle.menuJson <> ""
        accepted = AcceptMenuText(bundle.menuJson, OrText(bundle.menuSource, "pkg"))
        if accepted <> invalid then InstallMenu(accepted)
    end if
    m.fixIssues = IssuesForFixes(m.issues)
    if IssueCount() = 0
        m.issueIndex = 0
    else if m.issueIndex >= IssueCount()
        m.issueIndex = 0
    end if
    if m.issueIndex < 0 then m.issueIndex = 0
    PaintAll()
end sub

sub RefreshRail()
    PaintRail()
end sub

function ZoneForSection(section as string) as string
    if section = "home" then return "prompt"
    if section = "fixes" then return "rail"
    if ActivitySection(section) then return "grid"
    return "panel"
end function

function HomeRailState() as object
    return { depth: "top", zone: "rail", section: "home", index: HomeMenuIndex(), handled: true, leave: false }
end function

function HomePromptState() as object
    return { depth: "top", zone: "rail", section: "home", index: HomeMenuIndex(), handled: true, leave: false }
end function

function SubmenuSection(section as string) as boolean
    if MenuChild(section) <> invalid then return true
    return false
end function

function OpenTarget(section as string) as object
    if SubmenuSection(section) = true
        return { depth: "todo", zone: "grid", section: section, index: MenuIndex(TodoMenu(), section), handled: true, leave: false }
    end if
    if section = "todo"
        first = TodoMenu()[0]
        return { depth: "todo", zone: "rail", section: first, index: 0, handled: true, leave: false }
    end if
    if section = "home" then return HomePromptState()
    if section = "fixes"
        return { depth: "fixes", zone: "rail", section: "fixes", index: 0, handled: true, leave: false }
    end if
    return { depth: "top", zone: "panel", section: section, index: MenuIndex(TopMenu(), section), handled: true, leave: false }
end function

function NavKeyKind(key as string) as string
    if key = "up" then return "move"
    if key = "down" then return "move"
    if key = "OK" then return "open"
    if key = "right" then return "open"
    if key = "back" then return "back"
    if key = "left" then return "back"
    return ""
end function

' Rail, submenu, and detail transitions. Card arrows stay in MoveCards.
function NextNav(depth as string, zone as string, section as string, index as integer, key as string) as object
    menu = ActiveMenu(depth)
    count = menu.Count()
    nextDepth = depth
    nextZone = zone
    nextSection = section
    nextIndex = index
    leave = false
    kind = NavKeyKind(key)
    if kind = "move"
        if zone = "rail"
            moved = index + 1
            if key = "up" then moved = index - 1
            if moved >= 0
                if moved < count
                    nextIndex = moved
                    nextSection = menu[moved]
                end if
            end if
        end if
    else if kind = "open"
        if zone = "rail"
            drill = false
            if depth = "top"
                if section = "todo" or section = "fixes" then drill = true
            end if
            if drill = true
                if section = "fixes"
                    nextDepth = "fixes"
                    nextZone = "rail"
                    nextIndex = 0
                    nextSection = "fixes"
                else
                    nextDepth = "todo"
                    nextZone = "rail"
                    nextIndex = 0
                    nextSection = TodoMenu()[0]
                end if
            else if depth = "todo"
                nextZone = "grid"
            else if depth = "fixes"
                nextZone = "item"
            else
                nextZone = ZoneForSection(section)
            end if
        end if
    else if kind = "back"
        if zone = "item"
            if depth = "fixes"
                nextZone = "rail"
            else
                nextZone = "grid"
            end if
        else if zone = "grid"
            if key = "back" then nextZone = "rail"
        else if zone = "rail"
            openChild = false
            if depth = "todo" then openChild = true
            if depth = "fixes" then openChild = true
            if openChild
                nextDepth = "top"
                nextZone = "rail"
                nextSection = "todo"
                if depth = "fixes" then nextSection = "fixes"
                nextIndex = MenuIndex(TopMenu(), nextSection)
            else if depth = "top"
                if section = "home"
                    if key = "back" then leave = true
                else
                    nextDepth = "top"
                    nextZone = "rail"
                    nextSection = "home"
                    nextIndex = HomeMenuIndex()
                end if
            end if
        end if
    end if
    return { depth: nextDepth, zone: nextZone, section: nextSection, index: nextIndex, handled: true, leave: leave }
end function

' Card arrows. Left from the first column, or from an empty grid, returns to the rail.
function GridNav(count as integer, index as integer, key as string) as object
    if count < 1
        if key = "left" then return { zone: "rail", index: index }
        return { zone: "grid", index: index }
    end if
    if index < 0
        index = 0
    else if index >= count
        index = 0
    end if
    if key = "left"
        col = index mod 3
        if col = 0 then return { zone: "rail", index: index }
        return { zone: "grid", index: index - 1 }
    end if
    if key = "right"
        col = index mod 3
        if col >= 2 then return { zone: "grid", index: index }
        nextIndex = index + 1
        if nextIndex >= count then return { zone: "grid", index: index }
        return { zone: "grid", index: nextIndex }
    end if
    if key = "up"
        nextIndex = index - 3
        if nextIndex < 0 then return { zone: "grid", index: index }
        return { zone: "grid", index: nextIndex }
    end if
    if key = "down"
        nextIndex = index + 3
        if nextIndex >= count then return { zone: "grid", index: index }
        return { zone: "grid", index: nextIndex }
    end if
    return { zone: "grid", index: index }
end function

' Build 43 (Blake's TV, b42: Things to Do cards drew as thin photo strips).
' Card geometry must not depend on text metrics: whatever a device measures
' (zero, tiny or huge widths, any line count), every card keeps its 209px
' photo, a caption body inside its clamped range, captions inside the card,
' and its row a real non-empty clip that holds the whole focused card.
sub Main()
    failed = 0
    text = "Rio Sol at Sunriver Marina, a long name that wraps onto several lines on any device"
    ' Simulated metrics: char width 0/1 (measures nothing), normal, and huge.
    counts = []
    for each width in [0, 1, Nav2CapTextW(), 4000]
        for each size in [0, 1, 30, 300]
            counts.Push(BreakLines(text, width, size).Count())
        end for
    end for
    for each n in [0, 1, 2, 3, 4, 12, 99]
        counts.Push(n)
    end for
    for each nameLines in counts
        for each metaLines in counts
            capH = FyCapHeight(nameLines, metaLines)
            if capH < Nav2CapMinH() or capH > Nav2CapMaxH()
                print "FAIL caption height "; capH; " for "; nameLines; "/"; metaLines; " lines outside "; Nav2CapMinH(); "-"; Nav2CapMaxH()
                failed = failed + 1
            end if
            shownName = nameLines
            if shownName > 3 then shownName = 3
            if shownName < 1 then shownName = 1
            nameY = Nav2CardH() + Nav2CapPad()
            metaY = nameY + shownName * Nav2NameLine() + Nav2NameGap()
            if nameY < Nav2CardH() or metaY >= Nav2CardH() + capH
                print "FAIL caption text outside the card body: nameY "; nameY; " metaY "; metaY; " body "; Nav2CardH(); "+"; capH
                failed = failed + 1
            end if
            ' The first row's whole card stays above action-safe y 1023.
            if 106 + 136 + 52 + Nav2CardH() + capH > 1023
                print "FAIL first row card runs past action-safe with capH "; capH
                failed = failed + 1
            end if
            for each width in [1100, 1500, 1572]
                clip = FyRowClip(width, capH)
                grow = Int(0.04 * (Nav2CardH() + capH)) + 7
                if clip[2] <= 0 or clip[3] <= 0
                    print "FAIL row clip is empty: "; clip[2]; "x"; clip[3]
                    failed = failed + 1
                else if clip[1] > 0 or clip[0] > -48 or clip[0] + clip[2] < width + 48 or clip[1] + clip[3] < 52 + Nav2CardH() + capH + grow
                    print "FAIL row clip does not hold the label, arrows and focused card: "; clip[0]; ","; clip[1]; ","; clip[2]; ","; clip[3]
                    failed = failed + 1
                end if
            end for
        end for
    end for
    if Nav2CardH() < 200 or Nav2CapMinH() < 90
        print "FAIL card photo or caption minimum too small"
        failed = failed + 1
    end if
    if ClampLines(["a", "b", "c", "d"], 3).Count() <> 3 or ClampLines(["a"], 3).Count() <> 1
        print "FAIL ClampLines"
        failed = failed + 1
    end if
    print "Eaglewood: fycard capMin="; Nav2CapMinH(); " capMax="; Nav2CapMaxH(); " photo="; Nav2CardW(); "x"; Nav2CardH(); " cases="; counts.Count() * counts.Count()
    if failed = 0 then print "brs fycard checks passed" else print "brs fycard checks failed: "; failed
end sub

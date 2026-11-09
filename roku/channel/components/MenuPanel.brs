sub init()
    m.list = m.top.findNode("list")
    m.top.list = m.list
    m.list.observeField("itemSelected", "onSelected")
    m.list.observeField("itemFocused", "onFocused")
    ' Build 32: display only. The scene keeps remote focus and moves the list
    ' with jumpToItem, so a hidden list can never swallow Up/Down.
    m.list.focusable = false
    m.more = m.top.findNode("more")
end sub

sub onMoreBelow()
    if m.more = invalid then return
    m.more.translation = [186, m.top.moreY]
    m.more.visible = (m.top.moreBelow = true)
end sub

sub onSelected()
    m.top.selectedIndex = m.list.itemSelected
end sub

sub onFocused()
    m.top.focusedIndex = m.list.itemFocused
end sub

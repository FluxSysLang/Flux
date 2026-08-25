// fide.fx - Flux IDE

#import <standard.fx>, <windows.fx>;
#import "editor_core.fx";
#import "guide_data.fx";

using standard::io::console,
      standard::math,
      standard::strings,
      standard::system::windows,
      FluxIDE;

// ============================================================================
// SUBLIME TEXT THEME COLORS  (COLORREF = 0x00BBGGRR)
// ============================================================================

#def CLR_BG        0x00222827;
#def CLR_FG        0x00F2F8F8;
#def CLR_WIN_BG    0x00222827;
#def CLR_CARET     0x00F8F8F2;
#def CLR_SEL       0x00574E49;
#def CLR_LINENO_BG 0x00272920;
#def CLR_LINENO_FG 0x00807C75;

// Tab bar colors
#def CLR_TAB_ACTIVE_BG  0x00222827;  // same as editor bg -- active tab blends in
#def CLR_TAB_ACTIVE_FG  0x00F2F8F8;
#def CLR_TAB_IDLE_BG    0x001A1F1E;  // darker inactive tab
#def CLR_TAB_IDLE_FG    0x00807C75;
#def CLR_TAB_BORDER     0x00383D3B;
#def CLR_SPLIT_BAR      0x00383D3B;  // vertical divider between panes
#def CLR_SPLIT_FOCUS    0x006272A4;  // accent color for focused pane border

// Link color for clickable example entries (COLORREF 0x00BBGGRR)
#def CLR_LINK        0x00E6B87A;
#def CLR_CODE_BG     0x002D3330;
#def CLR_CODE_BORDER 0x00807C75;

UINT CF_TEXT            = 1;
UINT GMEM_MOVEABLE      = 0x0002;
UINT WM_MOUSEWHEEL      = 0x020A;
UINT WM_PAINT           = 0x000F;
DWORD DWMWA_DARK        = 20;
int   FW_NORMAL         = 400;
DWORD ANSI_CHARSET        = 0,
      OUT_DEFAULT_PRECIS  = 0,
      CLIP_DEFAULT_PRECIS = 0,
      DEFAULT_QUALITY     = 0,
      FIXED_PITCH         = 1,
      FF_MODERN           = 0x30;
int   SB_VERT        = 1,
      SB_HORZ        = 0,
      SB_THUMBTRACK  = 5,
      SB_LINEDOWN    = 1,
      SB_LINEUP      = 0,
      SB_PAGEDOWN    = 3,
      SB_PAGEUP      = 2,
      SB_LINERIGHT   = 1,
      SB_LINELEFT    = 0,
      SB_PAGERIGHT   = 3,
      SB_PAGELEFT    = 2;
UINT  SIF_RANGE     = 0x0001,
      SIF_PAGE      = 0x0002,
      SIF_POS       = 0x0004,
      SIF_TRACKPOS  = 0x0010,
      SIF_ALL       = 0x0017;
UINT  ETO_OPAQUE    = 0x0002;
DWORD SRCCOPY       = 0x00CC0020;
int   TRANSPARENT_MODE = 1,
      OPAQUE_MODE      = 2;

// IDE-specific menu IDs
int IDM_LANG_GUIDE   = 3002;
int IDM_SPLIT_VERT   = 4001;
int IDM_CLOSE_PANE   = 4002;
int IDM_NEW_TAB      = 4003;
int IDM_CLOSE_TAB    = 4004;

// Custom message: lParam = byte* pointing to example code to load
UINT WM_APP_LOAD_EXAMPLE = 0x8001;

// Global editor window handle -- used by the guide window to send examples back
HWND g_editor_hwnd;

// ============================================================================
// GUIDE WINDOW STATE
// ============================================================================

int  g_guide_page;
HWND g_guide_hwnd;
int  g_guide_scroll;

int g_detail_home_y;
int g_detail_paste_y;
int g_guide_min_h;

// ============================================================================
// TITLE
// ============================================================================

def update_title(HWND hwnd) -> void
{
    EditorTab* t = active_tab(focused_pane());
    byte[300] title;
    noopstr base     = "Flux IDE - ",
            untitled = "Untitled",
            star     = " *";
    strcpy(title, base);
    strcat(title, (t.filename[0] != (byte)0) ? t.filename : untitled);
    if (t.modified) { strcat(title, star); };
    SetWindowTextA(hwnd, (LPCSTR)title);
    return;
};

// ============================================================================
// SCROLL HELPERS (Win32-coupled)
// ============================================================================

def update_vscroll_pane(HWND hwnd, EditorPane* p) -> void
{
    EditorTab* t = active_tab(p);
    SCROLLINFO si;
    if (g_char_h == 0) { return; };
    int edit_h = p.h - TAB_HEIGHT;
    si.cbSize = (UINT)(sizeof(SCROLLINFO) / 8);
    si.fMask  = SIF_RANGE | SIF_PAGE | SIF_POS;
    si.nMin   = 0;
    si.nMax   = t.li.count - 1;
    si.nPage  = (UINT)(edit_h / g_char_h);
    si.nPos   = t.scroll_line;
    // Vertical scrollbar is shared -- only update when this is the focused pane
    if (p == focused_pane())
    {
        SetScrollInfo(hwnd, SB_VERT, (void*)@si, true);
    };
    return;
};

def scroll_to_cursor_tab(HWND hwnd, EditorPane* p, EditorTab* t) -> void
{
    int cur_line, vis_lines, cur_col, vis_cols, edit_h;
    if (g_char_h == 0 | g_char_w == 0) { return; };
    edit_h    = p.h - TAB_HEIGHT;
    vis_lines = edit_h / g_char_h;
    cur_line  = li_line_of(@t.li, t.cursor);
    if (cur_line < t.scroll_line)              { t.scroll_line = cur_line; };
    if (cur_line >= t.scroll_line + vis_lines) { t.scroll_line = cur_line - vis_lines + 1; };
    cur_col  = li_col_of(@t.li, t.cursor);
    vis_cols = (p.w - LINENO_WIDTH) / g_char_w;
    if (cur_col < t.scroll_col)               { t.scroll_col = cur_col; };
    if (cur_col >= t.scroll_col + vis_cols)   { t.scroll_col = cur_col - vis_cols + 1; };
    clamp_scroll_tab(t);
    update_vscroll_pane(hwnd, p);
    return;
};

def recreate_font(HWND hwnd) -> void
{
    noopstr font_face = "Consolas";
    HDC hdc_tmp;
    TEXTMETRIC tm;

    DeleteObject((HDC)g_font);
    g_font = CreateFontA(
        g_font_size, 0, 0, 0, FW_NORMAL, 0, 0, 0,
        ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        DEFAULT_QUALITY, FIXED_PITCH | FF_MODERN, (LPCSTR)font_face);

    hdc_tmp = GetDC(hwnd);
    SelectObject(hdc_tmp, g_font);
    GetTextMetricsA(hdc_tmp, (void*)@tm);
    g_char_w = (int)tm.tmAveCharWidth;
    g_char_h = (int)tm.tmHeight;
    ReleaseDC(hwnd, hdc_tmp);

    // Clamp all tabs in all panes
    int i = 0;
    while (i < g_pane_count)
    {
        int j = 0;
        while (j < g_panes[i].tab_count)
        {
            clamp_scroll_tab(@g_panes[i].tabs[j]);
            j++;
        };
        i++;
    };
    update_vscroll_pane(hwnd, focused_pane());
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

// ============================================================================
// SELECTION (Win32-coupled: calls update_title)
// ============================================================================

def tab_sel_delete(EditorTab* t, HWND hwnd) -> void
{
    int lo, hi, count, i;
    if (!tab_sel_has(t)) { return; };
    lo    = tab_sel_min(t);
    hi    = tab_sel_max(t);
    count = hi - lo;
    i     = 0;
    while (i < count)
    {
        gb_delete(@t.gb, lo);
        i++;
    };
    t.cursor     = lo;
    t.sel_anchor = lo;
    li_rebuild(@t.li, @t.gb);
    t.modified = true;
    update_title(hwnd);
    return;
};

// ============================================================================
// CLIPBOARD
// ============================================================================

def clipboard_copy(HWND hwnd) -> void
{
    EditorTab* t = active_tab(focused_pane());
    int   lo, hi, len;
    HWND  hmem;
    void* ptr;
    int   i;
    if (!tab_sel_has(t)) { return; };
    lo  = tab_sel_min(t);
    hi  = tab_sel_max(t);
    len = hi - lo;
    hmem = GlobalAlloc(GMEM_MOVEABLE, (size_t)(len + 1));
    if (hmem == (HWND)0) { return; };
    ptr = GlobalLock(hmem);
    if (ptr == STDLIB_GVP) { return; };
    i = 0;
    while (i < len)
    {
        ((byte*)ptr)[i] = gb_get(@t.gb, lo + i);
        i++;
    };
    ((byte*)ptr)[len] = (byte)0;
    GlobalUnlock(hmem);
    if (OpenClipboard(hwnd))
    {
        EmptyClipboard();
        SetClipboardData((UINT)CF_TEXT, hmem);
        CloseClipboard();
    };
    return;
};

def clipboard_paste(HWND hwnd) -> void
{
    EditorPane* p = focused_pane();
    EditorTab*  t = active_tab(p);
    HWND  hmem;
    void* ptr;
    size_t sz;
    int    i;
    byte   ch;
    if (!OpenClipboard(hwnd)) { return; };
    hmem = GetClipboardData((UINT)CF_TEXT);
    if (hmem == (HWND)0) { CloseClipboard(); return; };
    ptr = GlobalLock(hmem);
    if (ptr == STDLIB_GVP) { CloseClipboard(); return; };
    sz = GlobalSize(hmem);
    if (tab_sel_has(t))
    {
        tab_sel_delete(t, hwnd);
        update_vscroll_pane(hwnd, p);
    };
    i = 0;
    while (i < (int)sz)
    {
        ch = ((byte*)ptr)[i];
        if (ch == (byte)0) { break; };
        if (ch == (byte)13)
        {
            i++;
            gb_insert(@t.gb, t.cursor, (byte)10);
            t.cursor++;
        }
        else
        {
            gb_insert(@t.gb, t.cursor, ch);
            t.cursor++;
        };
        i++;
    };
    t.sel_anchor = t.cursor;
    GlobalUnlock(hmem);
    CloseClipboard();
    li_rebuild(@t.li, @t.gb);
    t.modified = true;
    update_title(hwnd);
    scroll_to_cursor_tab(hwnd, p, t);
    update_vscroll_pane(hwnd, p);
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

// ============================================================================
// PAINT -- tab bar for one pane
// ============================================================================

def paint_tab_bar(HDC back_dc, EditorPane* p, bool is_focused) -> void
{
    int tab_w = p.w / p.tab_count;
    if (tab_w > TAB_MAX_W) { tab_w = TAB_MAX_W; };
    if (tab_w < TAB_MIN_W) { tab_w = TAB_MIN_W; };

    // Background strip
    RECT bar;
    bar.left = p.x; bar.top = 0; bar.right = p.x + p.w; bar.bottom = TAB_HEIGHT;
    HBRUSH bar_bg = CreateSolidBrush((DWORD)CLR_TAB_IDLE_BG);
    FillRect(back_dc, @bar, bar_bg);
    DeleteObject((HDC)bar_bg);

    int i = 0;
    while (i < p.tab_count)
    {
        EditorTab* t = @p.tabs[i];
        bool is_active = (i == p.active_tab);

        RECT tr;
        tr.left   = p.x + i * tab_w;
        tr.top    = 0;
        tr.right  = tr.left + tab_w;
        tr.bottom = TAB_HEIGHT;

        DWORD bg = is_active ? (DWORD)CLR_TAB_ACTIVE_BG : (DWORD)CLR_TAB_IDLE_BG;
        DWORD fg = is_active ? (DWORD)CLR_TAB_ACTIVE_FG : (DWORD)CLR_TAB_IDLE_FG;

        HBRUSH tab_brush = CreateSolidBrush(bg);
        FillRect(back_dc, @tr, tab_brush);
        DeleteObject((HDC)tab_brush);

        // Bottom border line for active tab (blends with editor)
        if (is_active)
        {
            RECT bot;
            bot.left = tr.left; bot.top = TAB_HEIGHT - 2;
            bot.right = tr.right; bot.bottom = TAB_HEIGHT;
            HBRUSH accent = CreateSolidBrush(is_focused ? (DWORD)CLR_SPLIT_FOCUS : (DWORD)CLR_BG);
            FillRect(back_dc, @bot, accent);
            DeleteObject((HDC)accent);
        };

        // Right border between tabs
        RECT tbord;
        tbord.left = tr.right - 1; tbord.top = 2;
        tbord.right = tr.right; tbord.bottom = TAB_HEIGHT - 2;
        HBRUSH bord = CreateSolidBrush((DWORD)CLR_TAB_BORDER);
        FillRect(back_dc, @tbord, bord);
        DeleteObject((HDC)bord);

        // Tab label: short filename or "Untitled"
        byte* name = t.filename;
        // Find basename
        byte* base = name;
        int ni = 0;
        while (name[ni] != (byte)0)
        {
            if (name[ni] == (byte)92 | name[ni] == (byte)47)  // \ or /
            {
                base = name + ni + 1;
            };
            ni++;
        };
        noopstr unt = "Untitled";
        byte* labelx = (name[0] != (byte)0) ? base : (byte*)unt;

        // Modified bullet
        byte[4] bullet;
        if (t.modified) { bullet[0] = (byte)42; bullet[1] = (byte)32; bullet[2] = (byte)0; }  // "* "
        else            { bullet[0] = (byte)0; };

        RECT text_rc;
        text_rc.left   = tr.left + 8;
        text_rc.top    = (TAB_HEIGHT - g_char_h) / 2;
        text_rc.right  = tr.right - 4;
        text_rc.bottom = text_rc.top + g_char_h;

        SetBkMode(back_dc, TRANSPARENT_MODE);
        SetTextColor(back_dc, fg);

        // Draw bullet prefix
        int blen = strlen(bullet);
        if (blen > 0)
        {
            ExtTextOutA(back_dc, text_rc.left, text_rc.top, 0, @text_rc,
                        (LPCSTR)bullet, (UINT)blen, (void*)0);
            text_rc.left += blen * g_char_w;
        };
        int llen = strlen(labelx);
        ExtTextOutA(back_dc, text_rc.left, text_rc.top, 0, @text_rc,
                    (LPCSTR)labelx, (UINT)llen, (void*)0);
        SetBkMode(back_dc, OPAQUE_MODE);

        i++;
    };
    return;
};

// ============================================================================
// PAINT -- one editor pane body (below tab bar)
// ============================================================================

def paint_pane_body(HDC back_dc, EditorPane* p, bool is_focused) -> void
{
    EditorTab* t = active_tab(p);
    int edit_top = TAB_HEIGHT;
    int edit_h   = p.h - TAB_HEIGHT;
    int edit_w   = p.w;

    RECT pane_rc;
    pane_rc.left = p.x; pane_rc.top = edit_top;
    pane_rc.right = p.x + p.w; pane_rc.bottom = p.h;

    // Fill pane background
    FillRect(back_dc, @pane_rc, g_brush_bg);

    // Line number gutter
    RECT gutter;
    gutter.left = p.x; gutter.top = edit_top;
    gutter.right = p.x + LINENO_WIDTH; gutter.bottom = p.h;
    FillRect(back_dc, @gutter, g_brush_lineno);

    if (g_char_h == 0) { return; };

    int vis_lines = (edit_h / g_char_h) + 2;
    int vis_cols  = (edit_w - LINENO_WIDTH) / g_char_w + 2;

    int cur_line = li_line_of(@t.li, t.cursor);
    int cur_col  = li_col_of(@t.li, t.cursor);

    int sel_lo = tab_sel_min(t);
    int sel_hi = tab_sel_max(t);

    int ln = t.scroll_line;
    int y  = edit_top;
    byte[32] lnbuf;

    while (ln < t.li.count & y < p.h + g_char_h)
    {
        // Line number
        snprintf(lnbuf, (size_t)31, "%d", ln + 1);
        int lnlen = strlen(lnbuf);
        int lnx   = p.x + LINENO_WIDTH - (lnlen * g_char_w) - 6;
        RECT lcell;
        lcell.left = p.x; lcell.top = y; lcell.right = p.x + LINENO_WIDTH; lcell.bottom = y + g_char_h;
        SetBkColor(back_dc, (DWORD)CLR_LINENO_BG);
        SetTextColor(back_dc, (DWORD)CLR_LINENO_FG);
        ExtTextOutA(back_dc, lnx, y, ETO_OPAQUE, @lcell, (LPCSTR)lnbuf, (UINT)lnlen, (void*)0);

        // Text cell
        int line_start = t.li.starts[ln];
        int line_len   = li_line_len(@t.li, @t.gb, ln);

        int draw_start, draw_len;
        if (t.scroll_col >= line_len)
        {
            draw_start = line_start + line_len;
            draw_len   = 0;
        }
        else
        {
            draw_start = line_start + t.scroll_col;
            draw_len   = line_len - t.scroll_col;
            if (draw_len > vis_cols) { draw_len = vis_cols; };
        };

        RECT cell;
        cell.left   = p.x + LINENO_WIDTH;
        cell.top    = y;
        cell.right  = p.x + p.w;
        cell.bottom = y + g_char_h;
        SetBkColor(back_dc, (DWORD)CLR_BG);
        SetTextColor(back_dc, (DWORD)CLR_FG);
        ExtTextOutA(back_dc, p.x + LINENO_WIDTH, y, ETO_OPAQUE, @cell, (LPCSTR)"", 0, (void*)0);

        // Selection highlight
        if (tab_sel_has(t))
        {
            int line_end = line_start + line_len;
            if (sel_lo < line_end + 1 & sel_hi > line_start)
            {
                int sc_lo = sel_lo - line_start;
                if (sc_lo < 0) { sc_lo = 0; };
                int sc_hi = sel_hi - line_start;
                if (sc_hi > line_len) { sc_hi = line_len; };
                if (sel_hi > line_end) { sc_hi = line_len + 1; };
                int sx = p.x + LINENO_WIDTH + (sc_lo - t.scroll_col) * g_char_w;
                int sw = (sc_hi - sc_lo) * g_char_w;
                if (sx < p.x + LINENO_WIDTH) { sw -= (p.x + LINENO_WIDTH - sx); sx = p.x + LINENO_WIDTH; };
                if (sw > 0)
                {
                    RECT sel_cell;
                    sel_cell.left = sx; sel_cell.top = y;
                    sel_cell.right = sx + sw; sel_cell.bottom = y + g_char_h;
                    HBRUSH sel_fill = CreateSolidBrush((DWORD)CLR_SEL);
                    FillRect(back_dc, @sel_cell, sel_fill);
                    DeleteObject((HDC)sel_fill);
                };
            };
        };

        // Text
        if (draw_len > 0)
        {
            void* seg_buf = (void*)fmalloc((size_t)(draw_len + 1));
            if (seg_buf != STDLIB_GVP)
            {
                int si = 0;
                while (si < draw_len)
                {
                    ((byte*)seg_buf)[si] = gb_get(@t.gb, draw_start + si);
                    si++;
                };
                ((byte*)seg_buf)[draw_len] = (byte)0;
                SetBkMode(back_dc, TRANSPARENT_MODE);
                ExtTextOutA(back_dc, p.x + LINENO_WIDTH, y, 0, @cell,
                            (LPCSTR)seg_buf, (UINT)draw_len, (void*)0);
                SetBkMode(back_dc, OPAQUE_MODE);
                ffree(long(seg_buf));
            };
        };

        // Caret (only in focused pane with caret on)
        if (p.caret_on & is_focused & cur_line == ln)
        {
            int caret_x = p.x + LINENO_WIDTH + (cur_col - t.scroll_col) * g_char_w;
            if (caret_x >= p.x + LINENO_WIDTH)
            {
                RECT car;
                car.left = caret_x; car.top = y;
                car.right = caret_x + 2; car.bottom = y + g_char_h;
                HBRUSH caret_brush = CreateSolidBrush((DWORD)CLR_CARET);
                FillRect(back_dc, @car, caret_brush);
                DeleteObject((HDC)caret_brush);
            };
        };

        y  += g_char_h;
        ln++;
    };

    // Focused pane border accent (top edge of tab bar)
    if (is_focused)
    {
        RECT top_border;
        top_border.left = p.x; top_border.top = 0;
        top_border.right = p.x + p.w; top_border.bottom = 2;
        HBRUSH acc = CreateSolidBrush((DWORD)CLR_SPLIT_FOCUS);
        FillRect(back_dc, @top_border, acc);
        DeleteObject((HDC)acc);
    };

    return;
};

// ============================================================================
// MAIN PAINT
// ============================================================================

def editor_paint(HWND hwnd) -> void
{
    PAINTSTRUCT ps;
    HDC hdc, back_dc, back_bmp;
    RECT rc;

    hdc = BeginPaint(hwnd, (void*)@ps);
    GetClientRect(hwnd, @rc);
    int w = rc.right  - rc.left;
    int h = rc.bottom - rc.top;

    back_dc  = CreateCompatibleDC(hdc);
    back_bmp = CreateCompatibleBitmap(hdc, w, h);
    SelectObject(back_dc, (HFONT)back_bmp);
    SelectObject(back_dc, g_font);
    SetBkMode(back_dc, OPAQUE_MODE);

    // Fill entire buffer
    FillRect(back_dc, @rc, g_brush_bg);

    // Draw each pane
    int i = 0;
    while (i < g_pane_count)
    {
        bool foc = (i == g_focused_pane);
        paint_tab_bar(back_dc, @g_panes[i], foc);
        paint_pane_body(back_dc, @g_panes[i], foc);
        i++;
    };

    // Draw split bars between panes
    i = 0;
    while (i < g_pane_count - 1)
    {
        int bx = g_panes[i].x + g_panes[i].w;
        RECT bar;
        bar.left = bx; bar.top = 0; bar.right = bx + SPLIT_BAR_W; bar.bottom = h;
        HBRUSH sbr = CreateSolidBrush((DWORD)CLR_SPLIT_BAR);
        FillRect(back_dc, @bar, sbr);
        DeleteObject((HDC)sbr);
        i++;
    };

    BitBlt(hdc, 0, 0, w, h, back_dc, 0, 0, SRCCOPY);
    DeleteObject((HDC)back_bmp);
    DeleteDC(back_dc);
    EndPaint(hwnd, (void*)@ps);
    return;
};

// ============================================================================
// CURSOR MOVEMENT
// ============================================================================

def cursor_move_left(HWND hwnd, EditorPane* p, bool shift) -> void
{
    EditorTab* t = active_tab(p);
    if (!shift & tab_sel_has(t)) { t.cursor = tab_sel_min(t); t.sel_anchor = t.cursor; scroll_to_cursor_tab(hwnd, p, t); return; };
    if (!shift) { t.sel_anchor = t.cursor; };
    if (t.cursor > 0) { t.cursor--; };
    if (!shift) { t.sel_anchor = t.cursor; };
    scroll_to_cursor_tab(hwnd, p, t);
    return;
};

def cursor_move_right(HWND hwnd, EditorPane* p, bool shift) -> void
{
    EditorTab* t = active_tab(p);
    if (!shift & tab_sel_has(t)) { t.cursor = tab_sel_max(t); t.sel_anchor = t.cursor; scroll_to_cursor_tab(hwnd, p, t); return; };
    if (!shift) { t.sel_anchor = t.cursor; };
    if (t.cursor < gb_len(@t.gb)) { t.cursor++; };
    if (!shift) { t.sel_anchor = t.cursor; };
    scroll_to_cursor_tab(hwnd, p, t);
    return;
};

def cursor_move_up(HWND hwnd, EditorPane* p, bool shift) -> void
{
    EditorTab* t = active_tab(p);
    int ln, col, new_line_len;
    if (!shift) { t.sel_anchor = t.cursor; };
    ln  = li_line_of(@t.li, t.cursor);
    col = li_col_of(@t.li, t.cursor);
    if (ln == 0) { t.cursor = 0; if (!shift) { t.sel_anchor = t.cursor; }; scroll_to_cursor_tab(hwnd, p, t); return; };
    ln--;
    new_line_len = li_line_len(@t.li, @t.gb, ln);
    if (col > new_line_len) { col = new_line_len; };
    t.cursor = t.li.starts[ln] + col;
    if (!shift) { t.sel_anchor = t.cursor; };
    scroll_to_cursor_tab(hwnd, p, t);
    return;
};

def cursor_move_down(HWND hwnd, EditorPane* p, bool shift) -> void
{
    EditorTab* t = active_tab(p);
    int ln, col, new_line_len;
    if (!shift) { t.sel_anchor = t.cursor; };
    ln  = li_line_of(@t.li, t.cursor);
    col = li_col_of(@t.li, t.cursor);
    if (ln >= t.li.count - 1) { t.cursor = gb_len(@t.gb); if (!shift) { t.sel_anchor = t.cursor; }; scroll_to_cursor_tab(hwnd, p, t); return; };
    ln++;
    new_line_len = li_line_len(@t.li, @t.gb, ln);
    if (col > new_line_len) { col = new_line_len; };
    t.cursor = t.li.starts[ln] + col;
    if (!shift) { t.sel_anchor = t.cursor; };
    scroll_to_cursor_tab(hwnd, p, t);
    return;
};

def cursor_home(HWND hwnd, EditorPane* p, bool shift) -> void
{
    EditorTab* t = active_tab(p);
    if (!shift) { t.sel_anchor = t.cursor; };
    int ln = li_line_of(@t.li, t.cursor);
    t.cursor = t.li.starts[ln];
    if (!shift) { t.sel_anchor = t.cursor; };
    scroll_to_cursor_tab(hwnd, p, t);
    return;
};

def cursor_end(HWND hwnd, EditorPane* p, bool shift) -> void
{
    EditorTab* t = active_tab(p);
    if (!shift) { t.sel_anchor = t.cursor; };
    int ln = li_line_of(@t.li, t.cursor);
    t.cursor = t.li.starts[ln] + li_line_len(@t.li, @t.gb, ln);
    if (!shift) { t.sel_anchor = t.cursor; };
    scroll_to_cursor_tab(hwnd, p, t);
    return;
};

def cursor_page_up(HWND hwnd, EditorPane* p) -> void
{
    EditorTab* t = active_tab(p);
    if (g_char_h == 0) { return; };
    int edit_h    = p.h - TAB_HEIGHT;
    int vis_lines = edit_h / g_char_h;
    t.scroll_line -= vis_lines;
    int ln  = li_line_of(@t.li, t.cursor) - vis_lines;
    int col = li_col_of(@t.li, t.cursor);
    if (ln < 0) { ln = 0; };
    int new_line_len = li_line_len(@t.li, @t.gb, ln);
    if (col > new_line_len) { col = new_line_len; };
    t.cursor = t.li.starts[ln] + col;
    clamp_scroll_tab(t);
    update_vscroll_pane(hwnd, p);
    return;
};

def cursor_page_down(HWND hwnd, EditorPane* p) -> void
{
    EditorTab* t = active_tab(p);
    if (g_char_h == 0) { return; };
    int edit_h    = p.h - TAB_HEIGHT;
    int vis_lines = edit_h / g_char_h;
    t.scroll_line += vis_lines;
    int ln  = li_line_of(@t.li, t.cursor) + vis_lines;
    int col = li_col_of(@t.li, t.cursor);
    if (ln >= t.li.count) { ln = t.li.count - 1; };
    int new_line_len = li_line_len(@t.li, @t.gb, ln);
    if (col > new_line_len) { col = new_line_len; };
    t.cursor = t.li.starts[ln] + col;
    clamp_scroll_tab(t);
    update_vscroll_pane(hwnd, p);
    return;
};

// ============================================================================
// EDIT OPERATIONS
// ============================================================================

def editor_insert(HWND hwnd, EditorPane* p, byte ch) -> void
{
    EditorTab* t = active_tab(p);
    int  ln, line_start, line_len, ei, ns_count, spaces, di;
    byte ec, ns_prev, ns_cur;

    if (tab_sel_has(t)) { tab_sel_delete(t, hwnd); };
    gb_insert(@t.gb, t.cursor, ch);
    t.cursor++;
    t.sel_anchor = t.cursor;
    li_rebuild(@t.li, @t.gb);

    if (ch == (byte)59)
    {
        ln         = li_line_of(@t.li, t.cursor - 1);
        line_start = t.li.starts[ln];
        line_len   = li_line_len(@t.li, @t.gb, ln);
        ei = 0;
        while (ei < line_len)
        {
            ec = gb_get(@t.gb, line_start + ei);
            if (ec != (byte)32 & ec != (byte)9 & ec != (byte)13)
            {
                ns_prev = ns_cur;
                ns_cur  = ec;
                ns_count++;
            }
            else
            {
                if (ns_count == 0) { spaces++; };
            };
            ei++;
        };
        if (ns_count == 2 & ns_prev == (byte)125 & ns_cur == (byte)59)
        {
            while (di < 4 & spaces > 0)
            {
                gb_delete(@t.gb, line_start);
                t.cursor--;
                spaces--;
                di++;
            };
            t.sel_anchor = t.cursor;
            li_rebuild(@t.li, @t.gb);
        };
    };

    t.modified = true;
    update_title(hwnd);
    scroll_to_cursor_tab(hwnd, p, t);
    update_vscroll_pane(hwnd, p);
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

def editor_newline(HWND hwnd, EditorPane* p) -> void
{
    EditorTab* t = active_tab(p);
    int  ln, line_start, line_len, spaces, i, last_nonspace, ins;
    byte ch;

    if (tab_sel_has(t)) { tab_sel_delete(t, hwnd); };

    ln         = li_line_of(@t.li, t.cursor);
    line_start = t.li.starts[ln];
    line_len   = li_line_len(@t.li, @t.gb, ln);

    while (i < line_len)
    {
        if (gb_get(@t.gb, line_start + i) != (byte)32) { break; };
        spaces++;
        i++;
    };

    last_nonspace = -1;
    i = 0;
    while (i < line_len & (line_start + i) < t.cursor)
    {
        ch = gb_get(@t.gb, line_start + i);
        if (ch != (byte)32) { last_nonspace = i; };
        i++;
    };

    gb_insert(@t.gb, t.cursor, (byte)10);
    t.cursor++;

    ins = 0;
    while (ins < spaces)
    {
        gb_insert(@t.gb, t.cursor, (byte)32);
        t.cursor++;
        ins++;
    };

    if (last_nonspace >= 0)
    {
        if (gb_get(@t.gb, line_start + last_nonspace) == (byte)123)
        {
            ins = 0;
            while (ins < 4)
            {
                gb_insert(@t.gb, t.cursor, (byte)32);
                t.cursor++;
                ins++;
            };
        };
    };

    t.sel_anchor = t.cursor;
    li_rebuild(@t.li, @t.gb);
    t.modified = true;
    update_title(hwnd);
    scroll_to_cursor_tab(hwnd, p, t);
    update_vscroll_pane(hwnd, p);
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

def editor_backspace(HWND hwnd, EditorPane* p) -> void
{
    EditorTab* t = active_tab(p);
    if (tab_sel_has(t))
    {
        tab_sel_delete(t, hwnd);
        update_vscroll_pane(hwnd, p);
        InvalidateRect(hwnd, (RECT*)0, false);
        return;
    };
    if (t.cursor == 0) { return; };
    t.cursor--;
    gb_delete(@t.gb, t.cursor);
    t.sel_anchor = t.cursor;
    li_rebuild(@t.li, @t.gb);
    t.modified = true;
    update_title(hwnd);
    scroll_to_cursor_tab(hwnd, p, t);
    update_vscroll_pane(hwnd, p);
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

def editor_delete(HWND hwnd, EditorPane* p) -> void
{
    EditorTab* t = active_tab(p);
    if (tab_sel_has(t))
    {
        tab_sel_delete(t, hwnd);
        update_vscroll_pane(hwnd, p);
        InvalidateRect(hwnd, (RECT*)0, false);
        return;
    };
    if (t.cursor >= gb_len(@t.gb)) { return; };
    gb_delete(@t.gb, t.cursor);
    t.sel_anchor = t.cursor;
    li_rebuild(@t.li, @t.gb);
    t.modified = true;
    update_title(hwnd);
    update_vscroll_pane(hwnd, p);
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

def editor_delete_word(HWND hwnd, EditorPane* p) -> void
{
    EditorTab* t = active_tab(p);
    int  i, word_start;
    byte ch;
    if (tab_sel_has(t)) { tab_sel_delete(t, hwnd); update_vscroll_pane(hwnd, p); InvalidateRect(hwnd, (RECT*)0, false); return; };
    if (t.cursor == 0) { return; };
    i = t.cursor - 1;
    while (i >= 0)
    {
        ch = gb_get(@t.gb, i);
        if (ch != (byte)32 & ch != (byte)9 & ch != (byte)13 & ch != (byte)10) { break; };
        i--;
    };
    while (i >= 0)
    {
        ch = gb_get(@t.gb, i);
        if (ch == (byte)32 | ch == (byte)9 | ch == (byte)13 | ch == (byte)10) { break; };
        i--;
    };
    word_start = i + 1;
    while (t.cursor > word_start)
    {
        t.cursor--;
        gb_delete(@t.gb, t.cursor);
    };
    t.sel_anchor = t.cursor;
    li_rebuild(@t.li, @t.gb);
    t.modified = true;
    update_title(hwnd);
    scroll_to_cursor_tab(hwnd, p, t);
    update_vscroll_pane(hwnd, p);
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

// ============================================================================
// CLICK TO POSITION
// ============================================================================

def select_word_at(HWND hwnd, EditorPane* p, int pos) -> void
{
    EditorTab* t = active_tab(p);
    int len, lo, hi;
    len = gb_len(@t.gb);
    if (len == 0) { return; };
    if (pos >= len) { pos = len - 1; };
    if (!is_word_char(gb_get(@t.gb, pos)))
    {
        t.sel_anchor = pos;
        t.cursor     = pos + 1;
        InvalidateRect(hwnd, (RECT*)0, false);
        return;
    };
    lo = pos;
    while (lo > 0 & is_word_char(gb_get(@t.gb, lo - 1))) { lo--; };
    hi = pos;
    while (hi < len & is_word_char(gb_get(@t.gb, hi))) { hi++; };
    t.sel_anchor = lo;
    t.cursor     = hi;
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

def editor_click(HWND hwnd, EditorPane* p, int mx, int my, bool extend) -> void
{
    EditorTab* t = active_tab(p);
    if (g_char_h == 0 | g_char_w == 0) { return; };
    int local_y = my - TAB_HEIGHT;
    int clicked_line = t.scroll_line + (local_y / g_char_h);
    if (clicked_line >= t.li.count) { clicked_line = t.li.count - 1; };
    if (clicked_line < 0)           { clicked_line = 0; };
    int clicked_col = t.scroll_col + ((mx - p.x - LINENO_WIDTH) / g_char_w);
    if (clicked_col < 0) { clicked_col = 0; };
    int line_len = li_line_len(@t.li, @t.gb, clicked_line);
    if (clicked_col > line_len) { clicked_col = line_len; };
    t.cursor = t.li.starts[clicked_line] + clicked_col;
    if (!extend) { t.sel_anchor = t.cursor; };
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

// ============================================================================
// SAVE / OPEN / NEW
// ============================================================================

def ask_save(HWND hwnd) -> int
{
    noopstr msg = "Do you want to save changes?",
            cap = "Flux IDE";
    return MessageBoxA(hwnd, (LPCSTR)msg, (LPCSTR)cap, MB_YESNOCANCEL | MB_ICONQUESTION);
};

def do_save_tab(HWND hwnd, EditorTab* t, bool save_as) -> bool
{
    byte[260]     path;
    OPENFILENAMEA ofn;
    DWORD         written;
    noopstr filter = "Flux Files*.fxAll Files*.*",
            defext = "fx",
            cap    = "Save As";

    if (t.filename[0] == (byte)0 | save_as)
    {
        path[0] = (byte)0;
        if (t.filename[0] != (byte)0) { strcpy(path, t.filename); };
        memset((void*)@ofn, 0, sizeof(OPENFILENAMEA) / 8);
        ofn.lStructSize = (DWORD)(sizeof(OPENFILENAMEA) / 8);
        ofn.hwndOwner   = hwnd;
        ofn.lpstrFilter = (LPCSTR)filter;
        ofn.lpstrFile   = (LPSTR)path;
        ofn.nMaxFile    = 260;
        ofn.lpstrDefExt = (LPCSTR)defext;
        ofn.lpstrTitle  = (LPCSTR)cap;
        ofn.Flags       = OFN_OVERWRITEPROMPT | OFN_HIDEREADONLY;
        if (!GetSaveFileNameA((void*)@ofn)) { return false; };
        strcpy(t.filename, path);
    };

    int   len = gb_len(@t.gb);
    void* buf = (void*)fmalloc((size_t)(len + 1));
    if (buf == STDLIB_GVP) { return false; };
    gb_flatten(@t.gb, (byte*)buf);

    HWND hf = CreateFileA((LPCSTR)t.filename, GENERIC_WRITE, 0,
                           STDLIB_GVP, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, (HWND)0);
    if (hf == (HWND)0xFFFFFFFFFFFFFFFFu) { ffree(long(buf)); return false; };
    WriteFile(hf, buf, (DWORD)len, @written, STDLIB_GVP);
    CloseHandle(hf);
    ffree(long(buf));
    t.modified = false;
    update_title(hwnd);
    return true;
};

def do_open_tab(HWND hwnd, EditorPane* p) -> void
{
    byte[260]     path;
    OPENFILENAMEA ofn;
    DWORD         bread;
    i64           fsize;
    noopstr filter = "Flux Files*.fxAll Files*.*",
            cap    = "Open";

    path[0] = (byte)0;
    memset((void*)@ofn, 0, sizeof(OPENFILENAMEA) / 8);
    ofn.lStructSize = (DWORD)(sizeof(OPENFILENAMEA) / 8);
    ofn.hwndOwner   = hwnd;
    ofn.lpstrFilter = (LPCSTR)filter;
    ofn.lpstrFile   = (LPSTR)path;
    ofn.nMaxFile    = 260;
    ofn.lpstrTitle  = (LPCSTR)cap;
    ofn.Flags       = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY;
    if (!GetOpenFileNameA((void*)@ofn)) { return; };

    HWND hf = CreateFileA((LPCSTR)path, GENERIC_READ, FILE_SHARE_READ,
                           STDLIB_GVP, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, (HWND)0);
    if (hf == (HWND)0xFFFFFFFFFFFFFFFFu) { return; };

    GetFileSizeEx(hf, @fsize);
    void* buf = (void*)fmalloc((size_t)(fsize + 1));
    if (buf == STDLIB_GVP) { CloseHandle(hf); return; };
    ReadFile(hf, buf, (DWORD)fsize, @bread, STDLIB_GVP);
    CloseHandle(hf);

    int new_idx = pane_new_tab(p);
    if (new_idx < 0) { ffree(long(buf)); return; };

    EditorTab* t = @p.tabs[new_idx];
    int fi = 0;
    while (fi < (int)fsize)
    {
        gb_insert(@t.gb, fi, ((byte*)buf)[fi]);
        fi++;
    };
    ffree(long(buf));

    t.cursor      = 0;
    t.scroll_line = 0;
    t.scroll_col  = 0;
    li_rebuild(@t.li, @t.gb);
    strcpy(t.filename, path);
    t.modified = false;
    update_title(hwnd);
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

def do_new_tab(HWND hwnd, EditorPane* p) -> void
{
    pane_new_tab(p);
    update_title(hwnd);
    InvalidateRect(hwnd, (RECT*)0, false);
    return;
};

// ============================================================================
// LANGUAGE GUIDE WINDOW
// ============================================================================

#def GUIDE_LINK_HEIGHT    22;
#def GUIDE_LINK_X         20;

def LangGuideWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) -> LRESULT
{
    switch (msg)
    {
        case (WM_PAINT)
        {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hwnd, (void*)@ps);

            RECT rc,
                 sub_rc,
                 ltr_rc,
                 link_rc,
                 head_rc,
                 desc_rc,
                 box_rc,
                 home_rc,
                 code_rc,
                 paste_rc,
                 meas_rc;
            int box_left, box_right, text_min_h, box_top, box_avail, box_h;
            GetClientRect(hwnd, @rc);

            HBRUSH bg = CreateSolidBrush((DWORD)CLR_BG),
                   code_border = CreateSolidBrush((DWORD)CLR_CODE_BORDER),
                   code_bg = CreateSolidBrush((DWORD)CLR_CODE_BG);
            FillRect(hdc, @rc, bg);
            DeleteObject((HDC)bg);

            SetBkMode(hdc, TRANSPARENT_MODE);

            HFONT hfont_head = CreateFontA(
                28, 0, 0, 0, 700, 0, 0, 0,
                ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                DEFAULT_QUALITY, FIXED_PITCH | FF_MODERN,
                (LPCSTR)"Consolas");

            HFONT hfont_body = CreateFontA(
                16, 0, 0, 0, FW_NORMAL, 0, 0, 0,
                ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                DEFAULT_QUALITY, FIXED_PITCH | FF_MODERN,
                (LPCSTR)"Consolas");

            HFONT hfont_mono = CreateFontA(
                15, 0, 0, 0, FW_NORMAL, 0, 0, 0,
                ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                DEFAULT_QUALITY, FIXED_PITCH | FF_MODERN,
                (LPCSTR)"Consolas");

            noopstr heading   = "Language Guide";
            noopstr sub       = "Click a keyword to view its description and example.";
            noopstr home_lbl  = "Main Help";
            noopstr paste_lbl = "Paste into IDE";

            if (g_guide_page < 0)
            {
                HFONT hfont_letter = CreateFontA(
                    18, 0, 0, 0, 700, 0, 0, 0,
                    ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                    DEFAULT_QUALITY, FIXED_PITCH | FF_MODERN,
                    (LPCSTR)"Consolas");

                SelectObject(hdc, (HDC)hfont_head);
                SetTextColor(hdc, (DWORD)CLR_FG);
                head_rc.left = GUIDE_LINK_X; head_rc.top = 20;
                head_rc.right = rc.right - 20; head_rc.bottom = 56;
                DrawTextA(hdc, (LPCSTR)heading, 14, @head_rc,
                          DT_LEFT | DT_TOP | DT_SINGLELINE);

                SelectObject(hdc, (HDC)hfont_body);
                SetTextColor(hdc, (DWORD)CLR_FG);

                sub_rc.left = GUIDE_LINK_X; sub_rc.top = 58;
                sub_rc.right = rc.right - 20; sub_rc.bottom = 80;
                DrawTextA(hdc, (LPCSTR)sub, 51, @sub_rc,
                          DT_LEFT | DT_TOP | DT_SINGLELINE);

                int virtual_y = 90;
                byte prev_letter, first;
                byte* name;
                byte[2] lbuf;
                int i, nlen, screen_y;

                while (i < sizeof(g_examples) / sizeof(FluxExample))
                {
                    name = g_examples[i].name;
                    first = name[0];

                    if (first != prev_letter)
                    {
                        screen_y = virtual_y - g_guide_scroll;
                        if (screen_y >= 80 & screen_y < rc.bottom)
                        {
                            SelectObject(hdc, (HDC)hfont_letter);
                            SetTextColor(hdc, (DWORD)CLR_FG);
                            lbuf[0] = first;
                            lbuf[1] = (byte)0;
                            ltr_rc.left = GUIDE_LINK_X; ltr_rc.top = screen_y;
                            ltr_rc.right = rc.right - 20; ltr_rc.bottom = screen_y + GUIDE_LINK_HEIGHT + 4;
                            DrawTextA(hdc, (LPCSTR)lbuf, 1, @ltr_rc,
                                      DT_LEFT | DT_TOP | DT_SINGLELINE);
                            SelectObject(hdc, (HDC)hfont_body);
                        };
                        prev_letter = first;
                        virtual_y = virtual_y + GUIDE_LINK_HEIGHT + 4;
                    };

                    screen_y = virtual_y - g_guide_scroll;
                    if (screen_y >= 80 & screen_y < rc.bottom)
                    {
                        nlen = strlen(name);
                        SetTextColor(hdc, (DWORD)CLR_LINK);
                        link_rc.left = GUIDE_LINK_X + 12; link_rc.top = screen_y;
                        link_rc.right = rc.right - 20; link_rc.bottom = screen_y + GUIDE_LINK_HEIGHT;
                        DrawTextA(hdc, (LPCSTR)name, nlen, @link_rc,
                                  DT_LEFT | DT_TOP | DT_SINGLELINE);
                    };

                    virtual_y = virtual_y + GUIDE_LINK_HEIGHT;
                    i++;
                };

                DeleteObject((HDC)hfont_letter);
            }
            else
            {
                int idx = g_guide_page;

                byte* ex_name = g_examples[idx].name;
                int ex_name_len = strlen(ex_name);
                SelectObject(hdc, (HDC)hfont_head);
                SetTextColor(hdc, (DWORD)CLR_FG);
                head_rc.left = GUIDE_LINK_X; head_rc.top = 20;
                head_rc.right = rc.right - 20; head_rc.bottom = 68;
                DrawTextA(hdc, (LPCSTR)ex_name, ex_name_len, @head_rc,
                          DT_LEFT | DT_TOP | DT_SINGLELINE);

                byte* ex_desc = g_examples[idx].desc;
                int ex_desc_len = strlen(ex_desc);
                SelectObject(hdc, (HDC)hfont_body);
                SetTextColor(hdc, (DWORD)CLR_FG);
                desc_rc.left = GUIDE_LINK_X; desc_rc.top = 72;
                desc_rc.right = rc.right - 20; desc_rc.bottom = 72 + 48;
                DrawTextA(hdc, (LPCSTR)ex_desc, ex_desc_len, @desc_rc,
                          DT_LEFT | DT_TOP | DT_WORDBREAK);

                byte* ex_code = g_examples[idx].code;
                int ex_code_len = strlen(ex_code);

                box_left  = GUIDE_LINK_X;
                box_right = rc.right - 20;
                if (box_right - box_left > 600) { box_right = box_left + 600; };
                box_top = 132;

                SelectObject(hdc, (HDC)hfont_mono);
                meas_rc.left = box_left + 8; meas_rc.top = 0;
                meas_rc.right = box_right - 8; meas_rc.bottom = 0;
                DrawTextA(hdc, (LPCSTR)ex_code, ex_code_len, @meas_rc,
                          DT_LEFT | DT_TOP | DT_WORDBREAK | DT_CALCRECT);

                text_min_h = (meas_rc.bottom - meas_rc.top) + 12;
                g_guide_min_h = box_top + text_min_h + 8 + (2 * GUIDE_LINK_HEIGHT) + 20 + 30;

                box_h = text_min_h;
                if (box_h > 600) { box_h = 600; };

                box_rc.left = box_left; box_rc.top = box_top;
                box_rc.right = box_right; box_rc.bottom = box_top + box_h;

                int nav_home_y  = box_rc.bottom + 8;
                int nav_paste_y = nav_home_y + GUIDE_LINK_HEIGHT + 4;

                FillRect(hdc, @box_rc, code_bg);
                DeleteObject((HDC)code_bg);
                FrameRect(hdc, @box_rc, code_border);
                DeleteObject((HDC)code_border);

                code_rc.left = box_rc.left + 8; code_rc.top = box_rc.top + 6;
                code_rc.right = box_rc.right - 8; code_rc.bottom = box_rc.bottom - 6;

                SetBkMode(hdc, TRANSPARENT_MODE);
                SetTextColor(hdc, (DWORD)CLR_FG);
                IntersectClipRect(hdc, code_rc.left, code_rc.top, code_rc.right, code_rc.bottom);
                DrawTextA(hdc, (LPCSTR)ex_code, ex_code_len, @code_rc,
                          DT_LEFT | DT_TOP | DT_WORDBREAK);
                SelectClipRgn(hdc, (HRGN)0);

                DeleteObject((HDC)hfont_mono);

                SelectObject(hdc, (HDC)hfont_body);
                SetTextColor(hdc, (DWORD)CLR_LINK);
                home_rc.left = GUIDE_LINK_X; home_rc.top = nav_home_y;
                home_rc.right = rc.right - 20; home_rc.bottom = nav_home_y + GUIDE_LINK_HEIGHT;
                DrawTextA(hdc, (LPCSTR)home_lbl, 9, @home_rc,
                          DT_LEFT | DT_TOP | DT_SINGLELINE);

                SetTextColor(hdc, (DWORD)CLR_LINK);
                paste_rc.left = GUIDE_LINK_X; paste_rc.top = nav_paste_y;
                paste_rc.right = rc.right - 20; paste_rc.bottom = nav_paste_y + GUIDE_LINK_HEIGHT;
                DrawTextA(hdc, (LPCSTR)paste_lbl, 14, @paste_rc,
                          DT_LEFT | DT_TOP | DT_SINGLELINE);

                g_detail_home_y  = nav_home_y;
                g_detail_paste_y = nav_paste_y;
            };

            DeleteObject((HDC)hfont_head);
            DeleteObject((HDC)hfont_body);
            EndPaint(hwnd, (void*)@ps);
            return 0;
        }
        case (WM_LBUTTONDOWN)
        {
            int my = (int)(lParam >> 16) & 0xFFFF;
            if (my & 0x8000) { my = my | (int)0xFFFF0000; };

            if (g_guide_page < 0)
            {
                int virtual_y = 90;
                byte prev_letter, first;
                byte* name;
                int i, screen_y;
                while (i < sizeof(g_examples) / sizeof(FluxExample))
                {
                    name = g_examples[i].name;
                    first = name[0];
                    if (first != prev_letter)
                    {
                        prev_letter = first;
                        virtual_y = virtual_y + GUIDE_LINK_HEIGHT + 4;
                    };
                    screen_y = virtual_y - g_guide_scroll;
                    if (my >= screen_y & my < screen_y + GUIDE_LINK_HEIGHT)
                    {
                        g_guide_page = i;
                        g_guide_scroll = 0;
                        InvalidateRect(hwnd, (RECT*)0, false);
                        return 0;
                    };
                    virtual_y = virtual_y + GUIDE_LINK_HEIGHT;
                    i++;
                };
            }
            else
            {
                if (my >= g_detail_home_y & my < g_detail_home_y + GUIDE_LINK_HEIGHT)
                {
                    g_guide_page = -1;
                    InvalidateRect(hwnd, (RECT*)0, false);
                    return 0;
                };
                if (my >= g_detail_paste_y & my < g_detail_paste_y + GUIDE_LINK_HEIGHT)
                {
                    SendMessageA(g_editor_hwnd, (UINT)WM_APP_LOAD_EXAMPLE,
                                 0, (LPARAM)g_examples[g_guide_page].code);
                };
            };
            return 0;
        }
        case (WM_MOUSEWHEEL)
        {
            if (g_guide_page < 0)
            {
                int delta = (int)((wParam >> 16) & 0xFFFF);
                if (delta & 0x8000) { delta = delta | (int)0xFFFF0000; };
                if (delta > 0) { g_guide_scroll -= 3 * GUIDE_LINK_HEIGHT; }
                else           { g_guide_scroll += 3 * GUIDE_LINK_HEIGHT; };
                if (g_guide_scroll < 0) { g_guide_scroll = 0; };
                InvalidateRect(hwnd, (RECT*)0, false);
            };
            return 0;
        }
        case (WM_GETMINMAXINFO)
        {
            MINMAXINFO* mmi = (MINMAXINFO*)lParam;
            mmi.ptMinTrackSize.x = 300;
            int min_h = g_guide_min_h;
            if (min_h < 200) { min_h = 200; };
            mmi.ptMinTrackSize.y = min_h;
            return 0;
        }
        case (WM_CLOSE)
        {
            DestroyWindow(hwnd);
            return 0;
        }
        case (WM_DESTROY)
        {
            return 0;
        }
        default
        {
            return DefWindowProcA(hwnd, msg, wParam, lParam);
        };
    };

    return DefWindowProcA(hwnd, msg, wParam, lParam);
};

def do_lang_guide(HWND parent) -> void
{
    g_editor_hwnd  = parent;
    g_guide_page   = -1;
    g_guide_scroll = 0;
    HINSTANCE hinstance = GetModuleHandleA((LPCSTR)0);
    noopstr cls = "FluxLangGuide",
            ttl = "Language Guide";

    WNDCLASSEXA wc;
    wc.cbSize        = (UINT)(sizeof(WNDCLASSEXA) / 8);
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = (WNDPROC)@LangGuideWndProc;
    wc.cbClsExtra    = 0;
    wc.cbWndExtra    = 0;
    wc.hInstance     = hinstance;
    wc.hIcon         = LoadIconA((HINSTANCE)0, (LPCSTR)32512);
    wc.hCursor       = LoadCursorA((HINSTANCE)0, (LPCSTR)32512);
    wc.hbrBackground = (HBRUSH)0;
    wc.lpszMenuName  = (LPCSTR)0;
    wc.lpszClassName = (LPCSTR)cls;
    wc.hIconSm       = (HICON)0;
    RegisterClassExA(@wc);

    HWND hwnd_guide = CreateWindowExA(
        0, (LPCSTR)cls, (LPCSTR)ttl,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT, 600, 400,
        parent, (HMENU)0, hinstance, STDLIB_GVP);

    g_guide_hwnd = hwnd_guide;

    DWORD dark = 1;
    DwmSetWindowAttribute(hwnd_guide, DWMWA_DARK, (void*)@dark, (DWORD)(sizeof(DWORD) / 8));

    ShowWindow(hwnd_guide, SW_SHOW);
    UpdateWindow(hwnd_guide);
    return;
};

// ============================================================================
// WINDOW PROCEDURE
// ============================================================================

def EditorWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) -> LRESULT
{
    RECT rc;
    int  r, lo, vk, action;
    bool ctrl, shift;
    int  mx, my, delta;
    int  ch;
    SCROLLINFO si;
    EditorPane* fp;
    EditorTab*  ft;
    int tab_clicked;

    switch (msg)
    {
        case (WM_CREATE)
        {
            HMENU hmenu = CreateMenu(),
                  hfile = CreatePopupMenu(),
                  hedit = CreatePopupMenu(),
                  hview = CreatePopupMenu(),
                  hhelp = CreatePopupMenu();

            noopstr sNew      = "&New Tab\tCtrl+N",    sOpen      = "&Open...\tCtrl+O",
                    sSave     = "&Save\tCtrl+S",        sSaveAs    = "Save &As...",
                    sCloseTab = "Close Tab\tCtrl+W",    sExit      = "E&xit",
                    sUndo     = "&Undo\tCtrl+Z",        sCut       = "Cu&t\tCtrl+X",
                    sCopy     = "&Copy\tCtrl+C",        sPaste     = "&Paste\tCtrl+V",
                    sSel      = "Select &All\tCtrl+A",
                    sSplitV   = "Split &Vertical\tCtrl+\\",
                    sClosePane= "Close Pane",
                    sLangGuide= "&Language Guide",      sAbout     = "&About",
                    mFile = "&File", mEdit = "&Edit", mView = "&View", mHelp = "&Help";

            AppendMenuA(hfile, MF_STRING,    (UINT_PTR)IDM_NEW_TAB,   (LPCSTR)sNew);
            AppendMenuA(hfile, MF_STRING,    (UINT_PTR)IDM_OPEN,      (LPCSTR)sOpen);
            AppendMenuA(hfile, MF_STRING,    (UINT_PTR)IDM_SAVE,      (LPCSTR)sSave);
            AppendMenuA(hfile, MF_STRING,    (UINT_PTR)IDM_SAVEAS,    (LPCSTR)sSaveAs);
            AppendMenuA(hfile, MF_STRING,    (UINT_PTR)IDM_CLOSE_TAB, (LPCSTR)sCloseTab);
            AppendMenuA(hfile, MF_SEPARATOR, 0,                        (LPCSTR)STDLIB_GVP);
            AppendMenuA(hfile, MF_STRING,    (UINT_PTR)IDM_EXIT,      (LPCSTR)sExit);
            AppendMenuA(hedit, MF_STRING,    (UINT_PTR)IDM_UNDO,      (LPCSTR)sUndo);
            AppendMenuA(hedit, MF_SEPARATOR, 0,                        (LPCSTR)STDLIB_GVP);
            AppendMenuA(hedit, MF_STRING,    (UINT_PTR)IDM_CUT,       (LPCSTR)sCut);
            AppendMenuA(hedit, MF_STRING,    (UINT_PTR)IDM_COPY,      (LPCSTR)sCopy);
            AppendMenuA(hedit, MF_STRING,    (UINT_PTR)IDM_PASTE,     (LPCSTR)sPaste);
            AppendMenuA(hedit, MF_SEPARATOR, 0,                        (LPCSTR)STDLIB_GVP);
            AppendMenuA(hedit, MF_STRING,    (UINT_PTR)IDM_SELECTALL, (LPCSTR)sSel);
            AppendMenuA(hview, MF_STRING,    (UINT_PTR)IDM_SPLIT_VERT,  (LPCSTR)sSplitV);
            AppendMenuA(hview, MF_STRING,    (UINT_PTR)IDM_CLOSE_PANE,  (LPCSTR)sClosePane);
            AppendMenuA(hhelp, MF_STRING,    (UINT_PTR)IDM_LANG_GUIDE,  (LPCSTR)sLangGuide);
            AppendMenuA(hhelp, MF_STRING,    (UINT_PTR)IDM_ABOUT,       (LPCSTR)sAbout);
            AppendMenuA(hmenu, MF_POPUP, (UINT_PTR)hfile, (LPCSTR)mFile);
            AppendMenuA(hmenu, MF_POPUP, (UINT_PTR)hedit, (LPCSTR)mEdit);
            AppendMenuA(hmenu, MF_POPUP, (UINT_PTR)hview, (LPCSTR)mView);
            AppendMenuA(hmenu, MF_POPUP, (UINT_PTR)hhelp, (LPCSTR)mHelp);
            SetMenu(hwnd, hmenu);

            DWORD dark = 1;
            DwmSetWindowAttribute(hwnd, DWMWA_DARK, (void*)@dark, (DWORD)(sizeof(DWORD) / 8));

            g_font_size = 19;
            noopstr font_face = "Consolas";
            g_font = CreateFontA(
                g_font_size, 0, 0, 0, FW_NORMAL, 0, 0, 0,
                ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                DEFAULT_QUALITY, FIXED_PITCH | FF_MODERN, (LPCSTR)font_face);

            HDC hdc_tmp = GetDC(hwnd);
            SelectObject(hdc_tmp, g_font);
            TEXTMETRIC tm;
            GetTextMetricsA(hdc_tmp, (void*)@tm);
            g_char_w = (int)tm.tmAveCharWidth;
            g_char_h = (int)tm.tmHeight;
            ReleaseDC(hwnd, hdc_tmp);

            g_brush_bg     = CreateSolidBrush((DWORD)CLR_BG);
            g_brush_lineno = CreateSolidBrush((DWORD)CLR_LINENO_BG);
            g_brush_sel    = CreateSolidBrush((DWORD)CLR_SEL);

            // Initialise first pane
            g_pane_count   = 1;
            g_focused_pane = 0;
            pane_init(@g_panes[0]);

            layout_panes(hwnd);
            update_vscroll_pane(hwnd, focused_pane());
            return 0;
        }
        case (WM_ERASEBKGND)
        {
            return 1;
        }
        case (WM_PAINT)
        {
            editor_paint(hwnd);
            return 0;
        }
        case (WM_SIZE)
        {
            layout_panes(hwnd);
            int si2 = 0;
            while (si2 < g_pane_count)
            {
                int sj2 = 0;
                while (sj2 < g_panes[si2].tab_count)
                {
                    clamp_scroll_tab(@g_panes[si2].tabs[sj2]);
                    sj2++;
                };
                si2++;
            };
            update_vscroll_pane(hwnd, focused_pane());
            InvalidateRect(hwnd, (RECT*)0, false);
            return 0;
        }
        case (WM_SETFOCUS)
        {
            focused_pane().caret_on = 1;
            InvalidateRect(hwnd, (RECT*)0, false);
            return 0;
        }
        case (WM_KILLFOCUS)
        {
            focused_pane().caret_on = 0;
            InvalidateRect(hwnd, (RECT*)0, false);
            return 0;
        }
        case (WM_LBUTTONDOWN)
        {
            mx = (int)(lParam & 0xFFFF);
            my = (int)((lParam >> 16) & 0xFFFF);
            SetFocus(hwnd);

            // Check for split bar drag
            int split_idx = hit_test_split_bar(mx);
            if (split_idx >= 0)
            {
                g_drag_split   = true;
                g_drag_pane    = split_idx;
                g_drag_start_x = mx;
                g_drag_orig_w  = g_panes[split_idx].w;
                SetCapture(hwnd);
                return 0;
            };

            // Hit test pane / tab
            int tab_out;
            int pane_idx = hit_test_pane(mx, my, @tab_out);
            if (pane_idx >= 0)
            {
                g_focused_pane = pane_idx;
                fp = @g_panes[pane_idx];
                if (tab_out >= 0)
                {
                    // Tab click -- switch active tab
                    fp.active_tab = tab_out;
                    update_title(hwnd);
                    update_vscroll_pane(hwnd, fp);
                    InvalidateRect(hwnd, (RECT*)0, false);
                }
                else
                {
                    // Body click
                    editor_click(hwnd, fp, mx, my, false);
                    fp.mouse_selecting = 1;
                    SetCapture(hwnd);
                };
            };
            return 0;
        }
        case (WM_LBUTTONDBLCLK)
        {
            mx = (int)(lParam & 0xFFFF);
            my = (int)((lParam >> 16) & 0xFFFF);
            int tab_out2;
            int pane_idx2 = hit_test_pane(mx, my, @tab_out2);
            if (pane_idx2 >= 0 & tab_out2 < 0)
            {
                g_focused_pane = pane_idx2;
                fp = @g_panes[pane_idx2];
                editor_click(hwnd, fp, mx, my, false);
                select_word_at(hwnd, fp, active_tab(fp).cursor);
            };
            return 0;
        }
        case (WM_LBUTTONUP)
        {
            if (g_drag_split)
            {
                g_drag_split = false;
            };
            focused_pane().mouse_selecting = 0;
            ReleaseCapture();
            return 0;
        }
        case (WM_MOUSEMOVE)
        {
            mx = (int)(lParam & 0xFFFF);
            my = (int)((lParam >> 16) & 0xFFFF);
            if (g_drag_split)
            {
                int dx    = mx - g_drag_start_x;
                int new_w = g_drag_orig_w + dx;
                int min_w = 80;
                if (new_w < min_w) { new_w = min_w; };
                // Also clamp so right pane has min width
                int right_pane = g_drag_pane + 1;
                RECT rcm;
                GetClientRect(hwnd, @rcm);
                int total_w   = rcm.right - rcm.left;
                int dividers  = g_pane_count - 1;
                int available = total_w - dividers * SPLIT_BAR_W;
                // Recompute right pane new width
                int sum_rest = 0;
                int ri = 0;
                while (ri < g_pane_count)
                {
                    if (ri != g_drag_pane & ri != right_pane) { sum_rest += g_panes[ri].w; };
                    ri++;
                };
                int right_w = available - new_w - sum_rest;
                if (right_w < min_w) { new_w = available - sum_rest - min_w; };
                g_panes[g_drag_pane].w = new_w;
                layout_panes(hwnd);
                InvalidateRect(hwnd, (RECT*)0, false);
                return 0;
            };
            fp = focused_pane();
            if (fp.mouse_selecting)
            {
                editor_click(hwnd, fp, mx, my, true);
            };
            return 0;
        }
        case (WM_MOUSEWHEEL)
        {
            delta = (int)((short)((wParam >> 16) & 0xFFFF));
            ctrl  = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
            fp = focused_pane();
            ft = active_tab(fp);
            if (ctrl)
            {
                if (delta > 0) { FluxIDE::g_font_size += 1; }
                else           { g_font_size -= 1; };
                if (g_font_size < 6)  { g_font_size = 6; };
                if (g_font_size > 72) { g_font_size = 72; };
                recreate_font(hwnd);
            }
            else
            {
                if (delta > 0) { ft.scroll_line -= 3; }
                else           { ft.scroll_line += 3; };
                clamp_scroll_tab(ft);
                update_vscroll_pane(hwnd, fp);
                InvalidateRect(hwnd, (RECT*)0, false);
            };
            return 0;
        }
        case (WM_VSCROLL)
        {
            fp = focused_pane();
            ft = active_tab(fp);
            action = (int)(wParam & 0xFFFF);
            switch (action)
            {
                case (SB_LINEUP)    { ft.scroll_line--; }
                case (SB_LINEDOWN)  { ft.scroll_line++; }
                case (SB_PAGEUP)    { ft.scroll_line -= 10; }
                case (SB_PAGEDOWN)  { ft.scroll_line += 10; }
                case (SB_THUMBTRACK)
                {
                    si.cbSize = (UINT)(sizeof(SCROLLINFO) / 8);
                    si.fMask  = SIF_TRACKPOS;
                    GetScrollInfo(hwnd, SB_VERT, (void*)@si);
                    ft.scroll_line = si.nTrackPos;
                }
                default {};
            };
            clamp_scroll_tab(ft);
            update_vscroll_pane(hwnd, fp);
            InvalidateRect(hwnd, (RECT*)0, false);
            return 0;
        }
        case (WM_HSCROLL)
        {
            fp = focused_pane();
            ft = active_tab(fp);
            action = (int)(wParam & 0xFFFF);
            switch (action)
            {
                case (SB_LINELEFT)   { ft.scroll_col--; }
                case (SB_LINERIGHT)  { ft.scroll_col++; }
                case (SB_PAGELEFT)   { ft.scroll_col -= 10; }
                case (SB_PAGERIGHT)  { ft.scroll_col += 10; }
                case (SB_THUMBTRACK)
                {
                    si.cbSize = (UINT)(sizeof(SCROLLINFO) / 8);
                    si.fMask  = SIF_TRACKPOS;
                    GetScrollInfo(hwnd, SB_HORZ, (void*)@si);
                    ft.scroll_col = si.nTrackPos;
                }
                default {};
            };
            clamp_scroll_tab(ft);
            InvalidateRect(hwnd, (RECT*)0, false);
            return 0;
        }
        case (WM_KEYDOWN)
        {
            vk    = (int)wParam;
            ctrl  = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
            shift = (GetAsyncKeyState(VK_SHIFT)   & 0x8000) != 0;
            fp = focused_pane();
            ft = active_tab(fp);

            switch (vk)
            {
                case (VK_TAB)
                {
                    if (tab_sel_has(ft)) { tab_sel_delete(ft, hwnd); };
                    editor_insert(hwnd, fp, (byte)32);
                    editor_insert(hwnd, fp, (byte)32);
                    editor_insert(hwnd, fp, (byte)32);
                    editor_insert(hwnd, fp, (byte)32);
                }
                case (VK_LEFT)  { cursor_move_left(hwnd, fp, shift);  InvalidateRect(hwnd, (RECT*)0, false); }
                case (VK_RIGHT) { cursor_move_right(hwnd, fp, shift); InvalidateRect(hwnd, (RECT*)0, false); }
                case (VK_UP)    { cursor_move_up(hwnd, fp, shift);    InvalidateRect(hwnd, (RECT*)0, false); }
                case (VK_DOWN)  { cursor_move_down(hwnd, fp, shift);  InvalidateRect(hwnd, (RECT*)0, false); }
                case (VK_HOME)  { cursor_home(hwnd, fp, shift);       InvalidateRect(hwnd, (RECT*)0, false); }
                case (VK_END)   { cursor_end(hwnd, fp, shift);        InvalidateRect(hwnd, (RECT*)0, false); }
                case (VK_PRIOR) { cursor_page_up(hwnd, fp);           InvalidateRect(hwnd, (RECT*)0, false); }
                case (VK_NEXT)  { cursor_page_down(hwnd, fp);         InvalidateRect(hwnd, (RECT*)0, false); }
                case (VK_BACK)
                {
                    if (ctrl) { editor_delete_word(hwnd, fp); }
                    else      { editor_backspace(hwnd, fp); };
                }
                case (VK_DELETE) { editor_delete(hwnd, fp); }
                case (VK_RETURN) { editor_newline(hwnd, fp); }
                default
                {
                    if (ctrl)
                    {
                        switch (vk)
                        {
                            case (0x41)
                            {
                                // Ctrl+A: select all
                                ft.sel_anchor = 0;
                                ft.cursor     = gb_len(@ft.gb);
                                InvalidateRect(hwnd, (RECT*)0, false);
                            }
                            case (0x43) { clipboard_copy(hwnd); InvalidateRect(hwnd, (RECT*)0, false); }
                            case (0x58)
                            {
                                clipboard_copy(hwnd);
                                if (tab_sel_has(ft)) { tab_sel_delete(ft, hwnd); update_vscroll_pane(hwnd, fp); InvalidateRect(hwnd, (RECT*)0, false); };
                            }
                            case (0x56) { clipboard_paste(hwnd); }
                            case (0x53)
                            {
                                if (shift) { do_save_tab(hwnd, ft, true); }
                                else       { do_save_tab(hwnd, ft, false); };
                            }
                            case (0x4F) { do_open_tab(hwnd, fp); }
                            case (0x4E) { do_new_tab(hwnd, fp); }
                            case (0x57)
                            {
                                // Ctrl+W: close current tab
                                if (ft.modified)
                                {
                                    r = ask_save(hwnd);
                                    if (r == IDCANCEL) { return 0; };
                                    if (r == IDYES)    { do_save_tab(hwnd, ft, false); };
                                };
                                pane_close_tab(fp, fp.active_tab);
                                update_title(hwnd);
                                update_vscroll_pane(hwnd, fp);
                                InvalidateRect(hwnd, (RECT*)0, false);
                            }
                            case (0xDC)
                            {
                                // Ctrl+\: split vertically
                                add_pane(hwnd);
                                InvalidateRect(hwnd, (RECT*)0, false);
                            }
                            case (0x09)
                            {
                                // Ctrl+Tab: cycle tabs in focused pane
                                fp.active_tab = (fp.active_tab + 1) % fp.tab_count;
                                update_title(hwnd);
                                update_vscroll_pane(hwnd, fp);
                                InvalidateRect(hwnd, (RECT*)0, false);
                            }
                            default {};
                        };
                    };
                };
            };
            return 0;
        }
        case (WM_CHAR)
        {
            ch = (int)wParam;
            fp = focused_pane();
            if (ch >= 32 & ch != 127)
            {
                editor_insert(hwnd, fp, (byte)ch);
            };
            return 0;
        }
        case (WM_APP_LOAD_EXAMPLE)
        {
            byte* src = (byte*)lParam;
            if (src == (byte*)0) { return 0; };
            fp = focused_pane();
            // Load into a new tab
            pane_new_tab(fp);
            EditorTab* nt = active_tab(fp);
            int ei = 0;
            while (src[ei] != (byte)0)
            {
                gb_insert(@nt.gb, ei, src[ei]);
                ei++;
            };
            nt.cursor      = 0;
            nt.sel_anchor  = 0;
            nt.scroll_line = 0;
            nt.scroll_col  = 0;
            nt.filename[0] = (byte)0;
            nt.modified    = true;
            li_rebuild(@nt.li, @nt.gb);
            update_title(hwnd);
            update_vscroll_pane(hwnd, fp);
            InvalidateRect(hwnd, (RECT*)0, false);
            return 0;
        }
        case (WM_COMMAND)
        {
            lo = (int)(wParam & 0xFFFF);
            fp = focused_pane();
            ft = active_tab(fp);
            switch (lo)
            {
                case (IDM_NEW_TAB)   { do_new_tab(hwnd, fp); }
                case (IDM_SAVE)      { do_save_tab(hwnd, ft, false); }
                case (IDM_SAVEAS)    { do_save_tab(hwnd, ft, true); }
                case (IDM_CLOSE_TAB)
                {
                    if (ft.modified)
                    {
                        r = ask_save(hwnd);
                        if (r == IDCANCEL) { return 0; };
                        if (r == IDYES)    { do_save_tab(hwnd, ft, false); };
                    };
                    pane_close_tab(fp, fp.active_tab);
                    update_title(hwnd);
                    update_vscroll_pane(hwnd, fp);
                    InvalidateRect(hwnd, (RECT*)0, false);
                }
                case (IDM_CUT)
                {
                    clipboard_copy(hwnd);
                    if (tab_sel_has(ft)) { tab_sel_delete(ft, hwnd); update_vscroll_pane(hwnd, fp); InvalidateRect(hwnd, (RECT*)0, false); };
                }
                case (IDM_COPY)      { clipboard_copy(hwnd); InvalidateRect(hwnd, (RECT*)0, false); }
                case (IDM_PASTE)     { clipboard_paste(hwnd); }
                case (IDM_SELECTALL)
                {
                    ft.sel_anchor = 0;
                    ft.cursor     = gb_len(@ft.gb);
                    InvalidateRect(hwnd, (RECT*)0, false);
                }
                case (IDM_OPEN)      { do_open_tab(hwnd, fp); }
                case (IDM_SPLIT_VERT)
                {
                    add_pane(hwnd);
                    InvalidateRect(hwnd, (RECT*)0, false);
                }
                case (IDM_CLOSE_PANE)
                {
                    remove_pane(hwnd, g_focused_pane);
                    InvalidateRect(hwnd, (RECT*)0, false);
                }
                case (IDM_LANG_GUIDE) { do_lang_guide(hwnd); }
                case (IDM_ABOUT)
                {
                    noopstr amsg = "Flux IDE\nWritten in Flux.\nAuthor: Karac V. Thweatt",
                            acap = "About";
                    MessageBoxA(hwnd, (LPCSTR)amsg, (LPCSTR)acap, 0);
                }
                case (IDM_UNDO) {}  // placeholder
                case (IDM_EXIT)
                {
                    // Save-check all modified tabs in all panes
                    int ei2 = 0;
                    bool cancel_exit = false;
                    while (ei2 < g_pane_count & !cancel_exit)
                    {
                        int ej2 = 0;
                        while (ej2 < g_panes[ei2].tab_count & !cancel_exit)
                        {
                            EditorTab* et = @g_panes[ei2].tabs[ej2];
                            if (et.modified)
                            {
                                g_focused_pane = ei2;
                                g_panes[ei2].active_tab = ej2;
                                update_title(hwnd);
                                r = ask_save(hwnd);
                                if (r == IDCANCEL) { cancel_exit = true; }
                                elif (r == IDYES) { do_save_tab(hwnd, et, false); };
                            };
                            ej2++;
                        };
                        ei2++;
                    };
                    if (!cancel_exit) { DestroyWindow(hwnd); PostQuitMessage(0); };
                }
                default {};
            };
            return 0;
        }
        case (WM_CLOSE)
        {
            // Same multi-tab save logic as exit
            int ei3 = 0;
            bool cancel_close = false;
            while (ei3 < g_pane_count & !cancel_close)
            {
                int ej3 = 0;
                while (ej3 < g_panes[ei3].tab_count & !cancel_close)
                {
                    EditorTab* et3 = @g_panes[ei3].tabs[ej3];
                    if (et3.modified)
                    {
                        g_focused_pane = ei3;
                        g_panes[ei3].active_tab = ej3;
                        update_title(hwnd);
                        r = ask_save(hwnd);
                        if (r == IDCANCEL) { cancel_close = true; }
                        elif (r == IDYES) { do_save_tab(hwnd, et3, false); };
                    };
                    ej3++;
                };
                ei3++;
            };
            if (!cancel_close) { DestroyWindow(hwnd); PostQuitMessage(0); };
            return 0;
        }
        case (WM_DESTROY)
        {
            int di = 0;
            while (di < g_pane_count)
            {
                pane_free(@g_panes[di]);
                di++;
            };
            DeleteObject((HDC)g_font);
            DeleteObject((HDC)g_brush_bg);
            DeleteObject((HDC)g_brush_lineno);
            DeleteObject((HDC)g_brush_sel);
            PostQuitMessage(0);
            return 0;
        }
        default
        {
            return DefWindowProcA(hwnd, msg, wParam, lParam);
        };
    };

    return DefWindowProcA(hwnd, msg, wParam, lParam);
};

// ============================================================================
// ENTRY POINT
// ============================================================================

def main() -> int
{
    FreeConsole();
    HINSTANCE hinstance = GetModuleHandleA((LPCSTR)0);
    noopstr cls = "FluxIDE",
            ttl = "Flux IDE - Untitled";

    WNDCLASSEXA wc;
    wc.cbSize        = (UINT)(sizeof(WNDCLASSEXA) / 8);
    wc.style         = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
    wc.lpfnWndProc   = (WNDPROC)@EditorWndProc;
    wc.cbClsExtra    = 0;
    wc.cbWndExtra    = 0;
    wc.hInstance     = hinstance;
    wc.hIcon         = LoadIconA((HINSTANCE)0, (LPCSTR)32512);
    wc.hCursor       = LoadCursorA((HINSTANCE)0, (LPCSTR)32512);
    wc.hbrBackground = (HBRUSH)0;
    wc.lpszMenuName  = (LPCSTR)0;
    wc.lpszClassName = (LPCSTR)cls;
    wc.hIconSm       = (HICON)0;
    RegisterClassExA(@wc);

    HWND hwnd = CreateWindowExA(
        0, (LPCSTR)cls, (LPCSTR)ttl,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL,
        CW_USEDEFAULT, CW_USEDEFAULT, 1280, 800,
        (HWND)0, (HMENU)0, hinstance, STDLIB_GVP);

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);

    MSG msg;
    while (GetMessageA(@msg, (HWND)0, 0, 0))
    {
        if (msg.message == WM_CHAR & msg.wParam == 0x7F)
        {
            // Swallow DEL char that Ctrl+Backspace produces
        }
        else
        {
            TranslateMessage(@msg);
            DispatchMessageA(@msg);
        };
    };

    return int(msg.wParam);
};

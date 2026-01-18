//+------------------------------------------------------------------+
//|                                                  UI_Theme.mqh     |
//|                           MuseraTradeAssistant (project shell)    |
//|                                  (c) 2026, Musera Isaac          |
//|                                                                  |
//|  UI palette / theme helper used by UI_App and tab modules.        |
//|                                                                  |
//|  Design goals:                                                    |
//|   - Keep this file usable early in the project (minimal deps).    |
//|   - Provide stable color/font contracts for all UI modules.       |
//|   - Allow a theme switch later (from state / presets / UI).       |
//|                                                                  |
//|  NOTE: This file does NOT assume TA_State fields exist for theme. |
//|        It currently selects theme using a Terminal GlobalVariable |
//|        (see UI_THEME_GV_KEY). You can later wire it to TA_State.  |
//+------------------------------------------------------------------+
#property strict

#ifndef __MUSERA_UI_THEME_MQH__
#define __MUSERA_UI_THEME_MQH__

// Forward declarations (avoid hard dependency order)
class TA_State;
struct TA_Context;

// ------------------------------- Theme IDs -------------------------------
// Keep IDs stable because they can be stored in presets / global vars.
enum ENUM_UI_THEME_ID
{
   UI_THEME_DARK_PRO  = 0,
   UI_THEME_LIGHT_PRO = 1
};

// Where we store the selected theme (until you wire it to TA_State).
// This is a Terminal Global Variable key.
#define UI_THEME_GV_KEY "MuseraTA.ThemeId"

// ------------------------------- Palette ---------------------------------
struct UI_Palette
{
   // Panel chrome
   color panel_bg;
   color panel_border;

   // Header
   color header_bg;
   color header_text;

   // Text
   color text;
   color text_muted;
   color value_text;

   // Accents
   color accent;
   color good;
   color bad;
   color warn;

   // Buttons
   color btn_bg;
   color btn_border;
   color btn_text;

   // Tab strip (optional)
   color tab_bg;
   color tab_active_bg;
   color tab_text;
   color tab_active_text;

   // Session table / list styling (optional)
   color table_header_bg;
   color table_header_text;
   color row_a;
   color row_b;
   color row_open_bg;
   color row_closed_bg;

   // Font
   string font;
   int    font_size;
   int    font_size_small;
};

// -------------------------- Internal builders ----------------------------
UI_Palette UI_BuildThemeDarkPro()
{
   UI_Palette p;

   // A dark, marketplace-friendly theme.
   p.panel_bg         = (color)0x1E1E1E; // RGB(30,30,30)
   p.panel_border     = (color)0x3C3C3C; // RGB(60,60,60)

   p.header_bg        = (color)0x2D2D2D; // RGB(45,45,45)
   p.header_text      = clrWhite;

   p.text             = clrGainsboro;
   p.text_muted       = clrSilver;
   p.value_text       = clrWhite;

   p.accent           = clrDodgerBlue;
   p.good             = clrLimeGreen;
   p.bad              = clrTomato;
   p.warn             = clrOrange;

   p.btn_bg           = (color)0x2E6DEB; // a vivid blue
   p.btn_border       = (color)0x1C4FB8;
   p.btn_text         = clrWhite;

   p.tab_bg           = (color)0x252525;
   p.tab_active_bg    = (color)0x333333;
   p.tab_text         = clrSilver;
   p.tab_active_text  = clrWhite;

   p.table_header_bg   = (color)0x2D2D2D;
   p.table_header_text = clrWhite;
   p.row_a            = (color)0x1F1F1F;
   p.row_b            = (color)0x242424;
   p.row_open_bg      = (color)0x1E3A2A;
   p.row_closed_bg    = (color)0x3A1E1E;

   p.font             = "Arial";
   p.font_size        = 10;
   p.font_size_small  = 9;

   return p;
}

UI_Palette UI_BuildThemeLightPro()
{
   UI_Palette p;

   // Light Pro theme (clean, bright, marketplace-friendly screenshots)
   p.panel_bg         = clrWhite;
   p.panel_border     = clrGainsboro;

   p.header_bg        = clrDarkSlateGray;
   p.header_text      = clrWhite;

   p.text             = clrDimGray;
   p.text_muted       = clrSlateGray;
   p.value_text       = clrBlack;

   p.accent           = clrDodgerBlue;
   p.good             = clrSeaGreen;
   p.bad              = clrCrimson;
   p.warn             = clrDarkOrange;

   p.btn_bg           = clrDodgerBlue;
   p.btn_border       = clrRoyalBlue;
   p.btn_text         = clrWhite;

   p.tab_bg           = clrWhiteSmoke;
   p.tab_active_bg    = clrWhite;
   p.tab_text         = clrDimGray;
   p.tab_active_text  = clrBlack;

   p.table_header_bg   = clrDarkSlateGray;
   p.table_header_text = clrWhite;
   p.row_a            = clrWhiteSmoke;
   p.row_b            = clrWhite;
   p.row_open_bg      = clrPaleGreen;
   p.row_closed_bg    = clrLightCoral;

   p.font             = "Arial";
   p.font_size        = 10;
   p.font_size_small  = 9;

   return p;
}

// --------------------------- Theme selection -----------------------------
int UI_ReadThemeId()
{
   // Uses a Terminal Global Variable so it survives restarts.
   // (If missing/invalid, defaults to Dark Pro.)
   if(!GlobalVariableCheck(UI_THEME_GV_KEY))
      return (int)UI_THEME_DARK_PRO;

   double v = GlobalVariableGet(UI_THEME_GV_KEY);
   int id = (int)MathRound(v);
   if(id != (int)UI_THEME_DARK_PRO && id != (int)UI_THEME_LIGHT_PRO)
      id = (int)UI_THEME_DARK_PRO;

   return id;
}

void UI_WriteThemeId(const int id)
{
   int safe = id;
   if(safe != (int)UI_THEME_DARK_PRO && safe != (int)UI_THEME_LIGHT_PRO)
      safe = (int)UI_THEME_DARK_PRO;

   GlobalVariableSet(UI_THEME_GV_KEY, (double)safe);
}

UI_Palette UI_GetThemeById(const int id)
{
   if(id == (int)UI_THEME_LIGHT_PRO)
      return UI_BuildThemeLightPro();
   return UI_BuildThemeDarkPro();
}

// Contract used by UI_App.mqh
UI_Palette UI_GetTheme(const TA_State &/*st*/)
{
   // Currently: use global-variable selection.
   // Later: replace with something like: st.ui_theme_id
   return UI_GetThemeById(UI_ReadThemeId());
}

string UI_ThemeName(const int id)
{
   if(id == (int)UI_THEME_LIGHT_PRO) return "Light Pro";
   return "Dark Pro";
}

// ------------------------------- Wrapper ---------------------------------
class UI_Theme
{
private:
   int       m_id;
   UI_Palette m_p;

public:
   UI_Theme(void) : m_id((int)UI_THEME_DARK_PRO)
   {
      m_p = UI_GetThemeById(m_id);
   }

   // Update palette from (future) TA_State.
   void UpdateFromState(const TA_State &st)
   {
      m_p = UI_GetTheme(st);
      m_id = UI_ReadThemeId(); // keep in sync with current selector
   }

   // Explicit selection (e.g. from Settings tab).
   void SetThemeId(const int id, const bool persist=true)
   {
      m_id = (id == (int)UI_THEME_LIGHT_PRO ? (int)UI_THEME_LIGHT_PRO : (int)UI_THEME_DARK_PRO);
      m_p  = UI_GetThemeById(m_id);
      if(persist) UI_WriteThemeId(m_id);
   }

   int ThemeId(void) const { return m_id; }
   string Name(void) const { return UI_ThemeName(m_id); }

   UI_Palette Palette(void) const { return m_p; }

   // Commonly used colors (convenience)
   color PanelBg(void) const { return m_p.panel_bg; }
   color PanelBorder(void) const { return m_p.panel_border; }
   color HeaderBg(void) const { return m_p.header_bg; }
   color HeaderText(void) const { return m_p.header_text; }

   color Text(void) const { return m_p.text; }
   color TextMuted(void) const { return m_p.text_muted; }
   color ValueText(void) const { return m_p.value_text; }

   color ButtonBg(void) const { return m_p.btn_bg; }
   color ButtonBorder(void) const { return m_p.btn_border; }
   color ButtonText(void) const { return m_p.btn_text; }

   string Font(void) const { return m_p.font; }
   int FontSize(void) const { return m_p.font_size; }
   int FontSizeSmall(void) const { return m_p.font_size_small; }
};

#endif // __MUSERA_UI_THEME_MQH__

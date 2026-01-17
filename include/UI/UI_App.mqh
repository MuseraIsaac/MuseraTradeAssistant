//+------------------------------------------------------------------+
//|                                                   UI_App.mqh     |
//|                         MuseraTradeAssistant (UI root controller)|
//|                                  (c) 2026, Musera Isaac         |
//|                                                                  |
//|  Location (required):                                            |
//|    MQL5\Experts\MuseraTradeAssistant\include\UI\UI_App.mqh        |
//|                                                                  |
//|  Purpose:                                                        |
//|    - Owns the main panel (background + header + tab bar).         |
//|    - Routes events to the active tab implementation.              |
//|    - Provides sync hooks between TA_State <-> UI.                 |
//|                                                                  |
//|  Notes:                                                          |
//|    - This file is part of a multi-include project. It expects     |
//|      project types/enums from TA_*.mqh and tab classes from       |
//|      UI_*.mqh to exist.                                           |
//+------------------------------------------------------------------+
#ifndef __MUSERA_TA_UI_APP_MQH__
#define __MUSERA_TA_UI_APP_MQH__

// --- core deps (paths are relative to include\UI\) ---
#include "../TA_Constants.mqh"
#include "../TA_Types.mqh"
#include "../TA_Utils.mqh"

// --- UI deps (same folder) ---
#include "UI_Theme.mqh"
#include "UI_Tabs.mqh"
#include "UI_TradeTab.mqh"
#include "UI_CloseTab.mqh"
#include "UI_TrailingTab.mqh"
#include "UI_BE_Tab.mqh"
#include "UI_SettingsTab.mqh"
#include "UI_InfoTab.mqh"

//+------------------------------------------------------------------+
//| UI_App                                                           |
//+------------------------------------------------------------------+
class UI_App
{
private:
   long    m_chart_id;
   string  m_prefix;        // object name prefix
   int     m_x, m_y, m_w, m_h;
   bool    m_created;

   // Panel objects
   string  m_obj_bg;
   string  m_obj_hdr;
   string  m_obj_title;
   string  m_obj_btn_min;
   string  m_obj_btn_lock;

   // Tabs controller + tab implementations
   UI_Theme        m_theme;
   UI_Tabs         m_tabs;
   UI_TradeTab     m_tab_trade;
   UI_CloseTab     m_tab_close;
   UI_TrailingTab  m_tab_trail;
   UI_BE_Tab       m_tab_be;
   UI_SettingsTab  m_tab_settings;
   UI_InfoTab      m_tab_info;

   // ---------- low-level object helpers ----------
   bool CreateRectLabel(const string name, const int x, const int y, const int w, const int h,
                        const color bg, const color border,
                        const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER,
                        const bool selectable=false, const bool back=false)
   {
      if(ObjectFind(m_chart_id, name) < 0)
      {
         if(!ObjectCreate(m_chart_id, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
            return false;
      }
      ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, corner);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, border);
      ObjectSetInteger(m_chart_id, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BACK, back);
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, selectable);
      ObjectSetInteger(m_chart_id, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart_id, name, OBJPROP_ZORDER, 0);
      return true;
   }

   bool CreateLabel(const string name, const string text, const int x, const int y,
                    const color clr, const string font, const int fsize,
                    const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER,
                    const bool back=false)
   {
      if(ObjectFind(m_chart_id, name) < 0)
      {
         if(!ObjectCreate(m_chart_id, name, OBJ_LABEL, 0, 0, 0))
            return false;
      }
      ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, corner);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(m_chart_id,  name, OBJPROP_TEXT, text);
      ObjectSetString(m_chart_id,  name, OBJPROP_FONT, font);
      ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, fsize);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BACK, back);
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart_id, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart_id, name, OBJPROP_ZORDER, 1);
      return true;
   }

   bool CreateButton(const string name, const string text, const int x, const int y, const int w, const int h,
                     const color bg, const color fg,
                     const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER,
                     const bool back=false)
   {
      if(ObjectFind(m_chart_id, name) < 0)
      {
         if(!ObjectCreate(m_chart_id, name, OBJ_BUTTON, 0, 0, 0))
            return false;
      }
      ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, corner);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart_id, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YSIZE, h);
      ObjectSetString(m_chart_id,  name, OBJPROP_TEXT, text);
      ObjectSetString(m_chart_id,  name, OBJPROP_FONT, TA_UI_FONT_MAIN);
      ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, TA_UI_FONT_SIZE);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, fg);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BACK, back);
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart_id, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart_id, name, OBJPROP_ZORDER, 2);
      return true;
   }

   void DeleteObj(const string name)
   {
      if(ObjectFind(m_chart_id, name) >= 0)
         ObjectDelete(m_chart_id, name);
   }

   void MoveBaseObjects()
   {
      // Keep the background and header aligned.
      ObjectSetInteger(m_chart_id, m_obj_bg,  OBJPROP_XDISTANCE, m_x);
      ObjectSetInteger(m_chart_id, m_obj_bg,  OBJPROP_YDISTANCE, m_y);
      ObjectSetInteger(m_chart_id, m_obj_bg,  OBJPROP_XSIZE, m_w);
      ObjectSetInteger(m_chart_id, m_obj_bg,  OBJPROP_YSIZE, m_h);

      ObjectSetInteger(m_chart_id, m_obj_hdr, OBJPROP_XDISTANCE, m_x);
      ObjectSetInteger(m_chart_id, m_obj_hdr, OBJPROP_YDISTANCE, m_y);
      ObjectSetInteger(m_chart_id, m_obj_hdr, OBJPROP_XSIZE, m_w);
      ObjectSetInteger(m_chart_id, m_obj_hdr, OBJPROP_YSIZE, TA_UI_HEADER_H);

      ObjectSetInteger(m_chart_id, m_obj_title, OBJPROP_XDISTANCE, m_x + 8);
      ObjectSetInteger(m_chart_id, m_obj_title, OBJPROP_YDISTANCE, m_y + 4);

      ObjectSetInteger(m_chart_id, m_obj_btn_min, OBJPROP_XDISTANCE, m_x + m_w - 22);
      ObjectSetInteger(m_chart_id, m_obj_btn_min, OBJPROP_YDISTANCE, m_y + 2);

      ObjectSetInteger(m_chart_id, m_obj_btn_lock, OBJPROP_XDISTANCE, m_x + m_w - 44);
      ObjectSetInteger(m_chart_id, m_obj_btn_lock, OBJPROP_YDISTANCE, m_y + 2);
   }

   void LayoutChildren(const TA_Context &ctx, TA_State &st)
   {
      // Tabs bar lives directly under header.
      int tabs_x = m_x + 6;
      int tabs_y = m_y + TA_UI_HEADER_H + 6;
      int tabs_w = m_w - 12;
      int tabs_h = TA_UI_TAB_H;

      m_tabs.Layout(ctx, st, tabs_x, tabs_y, tabs_w, tabs_h);

      // Content rect below tabs.
      int content_x = m_x + 6;
      int content_y = tabs_y + tabs_h + 6;
      int content_w = m_w - 12;
      int content_h = (st.ui_minimized ? 0 : (m_h - (content_y - m_y) - 6));

      // When minimized, tabs remain visible; content is hidden by tabs themselves.
      m_tab_trade.Layout(ctx, st, content_x, content_y, content_w, content_h);
      m_tab_close.Layout(ctx, st, content_x, content_y, content_w, content_h);
      m_tab_trail.Layout(ctx, st, content_x, content_y, content_w, content_h);
      m_tab_be.Layout(ctx, st, content_x, content_y, content_w, content_h);
      m_tab_settings.Layout(ctx, st, content_x, content_y, content_w, content_h);
      m_tab_info.Layout(ctx, st, content_x, content_y, content_w, content_h);
   }

   void ApplyThemeToChrome(const TA_Context &ctx, const TA_State &st)
   {
      // The theme implementation can map colors based on st flags.
      // UI_Theme is expected to provide a full color palette.
      m_theme.SyncFromState(ctx, st);
      const UI_Palette &p = m_theme.Palette();

      // Chrome objects
      ObjectSetInteger(m_chart_id, m_obj_bg,  OBJPROP_BGCOLOR, p.panel_bg);
      ObjectSetInteger(m_chart_id, m_obj_bg,  OBJPROP_COLOR,   p.panel_border);

      ObjectSetInteger(m_chart_id, m_obj_hdr, OBJPROP_BGCOLOR, p.header_bg);
      ObjectSetInteger(m_chart_id, m_obj_hdr, OBJPROP_COLOR,   p.header_bg);

      ObjectSetInteger(m_chart_id, m_obj_title, OBJPROP_COLOR, p.header_text);

      // Buttons
      ObjectSetInteger(m_chart_id, m_obj_btn_min,  OBJPROP_BGCOLOR, p.btn_bg);
      ObjectSetInteger(m_chart_id, m_obj_btn_min,  OBJPROP_COLOR,   p.btn_text);
      ObjectSetInteger(m_chart_id, m_obj_btn_lock, OBJPROP_BGCOLOR, p.btn_bg);
      ObjectSetInteger(m_chart_id, m_obj_btn_lock, OBJPROP_COLOR,   p.btn_text);
   }

   void RenderActiveTab(const TA_Context &ctx, TA_State &st)
   {
      // Tabs are responsible for hiding/showing their own objects.
      // Only the active tab should render its content.
      m_tab_trade.SetVisible(st.ui_active_tab == TA_TAB_TRADE && !st.ui_minimized);
      m_tab_close.SetVisible(st.ui_active_tab == TA_TAB_CLOSE && !st.ui_minimized);
      m_tab_trail.SetVisible(st.ui_active_tab == TA_TAB_TRAILING && !st.ui_minimized);
      m_tab_be.SetVisible(st.ui_active_tab == TA_TAB_BE && !st.ui_minimized);
      m_tab_settings.SetVisible(st.ui_active_tab == TA_TAB_SETTINGS && !st.ui_minimized);
      m_tab_info.SetVisible(st.ui_active_tab == TA_TAB_INFO && !st.ui_minimized);

      if(st.ui_minimized)
         return;

      switch(st.ui_active_tab)
      {
         case TA_TAB_TRADE:    m_tab_trade.OnTimer(ctx, st);    break;
         case TA_TAB_CLOSE:    m_tab_close.OnTimer(ctx, st);    break;
         case TA_TAB_TRAILING: m_tab_trail.OnTimer(ctx, st);    break;
         case TA_TAB_BE:       m_tab_be.OnTimer(ctx, st);       break;
         case TA_TAB_SETTINGS: m_tab_settings.OnTimer(ctx, st); break;
         case TA_TAB_INFO:     m_tab_info.OnTimer(ctx, st);     break;
         default:              m_tab_trade.OnTimer(ctx, st);    break;
      }
   }

   bool IsMine(const string obj) const
   {
      return (StringFind(obj, m_prefix) == 0);
   }

public:
   UI_App() : m_chart_id(0), m_prefix(""), m_x(0), m_y(0), m_w(0), m_h(0), m_created(false) {}

   bool Create(const TA_Context &ctx, const int x, const int y, const int w, const int h)
   {
      m_chart_id = ctx.chart_id;
      m_prefix   = string(TA_UI_PREFIX) + "APP_";
      m_x = x; m_y = y; m_w = w; m_h = h;

      m_obj_bg      = m_prefix + "BG";
      m_obj_hdr     = m_prefix + "HDR";
      m_obj_title   = m_prefix + "TITLE";
      m_obj_btn_min = m_prefix + "BTN_MIN";
      m_obj_btn_lock= m_prefix + "BTN_LOCK";

      // Fallback colors if theme isn't ready yet
      const color fallback_panel_bg     = (color)0x1E1E1E;
      const color fallback_panel_border = (color)0x3A3A3A;
      const color fallback_hdr_bg       = (color)0x2B2B2B;
      const color fallback_hdr_text     = clrWhiteSmoke;
      const color fallback_btn_bg       = (color)0x3C3C3C;
      const color fallback_btn_text     = clrWhite;

      // Base chrome
      if(!CreateRectLabel(m_obj_bg, m_x, m_y, m_w, m_h, fallback_panel_bg, fallback_panel_border, CORNER_LEFT_UPPER, false, false))
         return false;

      // Header is selectable to allow manual drag; we will listen to OBJECT_CHANGE.
      if(!CreateRectLabel(m_obj_hdr, m_x, m_y, m_w, TA_UI_HEADER_H, fallback_hdr_bg, fallback_hdr_bg, CORNER_LEFT_UPPER, true, false))
         return false;

      if(!CreateLabel(m_obj_title, "Musera Trade Assistant", m_x+8, m_y+4, fallback_hdr_text, TA_UI_FONT_BOLD, TA_UI_FONT_SIZE_TITLE))
         return false;

      if(!CreateButton(m_obj_btn_min, "-", m_x+m_w-22, m_y+2, 18, 16, fallback_btn_bg, fallback_btn_text))
         return false;

      if(!CreateButton(m_obj_btn_lock, "L", m_x+m_w-44, m_y+2, 18, 16, fallback_btn_bg, fallback_btn_text))
         return false;

      // Create children
      if(!m_tabs.Create(ctx, m_prefix + "TABS_"))
         return false;

      // Tabs create their content objects and keep them hidden when not active.
      if(!m_tab_trade.Create(ctx, m_prefix + "TRADE_"))      return false;
      if(!m_tab_close.Create(ctx, m_prefix + "CLOSE_"))      return false;
      if(!m_tab_trail.Create(ctx, m_prefix + "TRAIL_"))      return false;
      if(!m_tab_be.Create(ctx, m_prefix + "BE_"))            return false;
      if(!m_tab_settings.Create(ctx, m_prefix + "SET_"))     return false;
      if(!m_tab_info.Create(ctx, m_prefix + "INFO_"))        return false;

      m_created = true;
      return true;
   }

   void Destroy()
   {
      if(!m_created) return;
      m_tab_trade.Destroy();
      m_tab_close.Destroy();
      m_tab_trail.Destroy();
      m_tab_be.Destroy();
      m_tab_settings.Destroy();
      m_tab_info.Destroy();
      m_tabs.Destroy();

      DeleteObj(m_obj_btn_lock);
      DeleteObj(m_obj_btn_min);
      DeleteObj(m_obj_title);
      DeleteObj(m_obj_hdr);
      DeleteObj(m_obj_bg);
      m_created = false;
   }

   void SyncFromState(const TA_Context &ctx, TA_State &st)
   {
      if(!m_created) return;
      ApplyThemeToChrome(ctx, st);
      LayoutChildren(ctx, st);
      m_tabs.SyncFromState(ctx, st);

      // Push state into every tab (tabs decide what to read).
      m_tab_trade.SyncFromState(ctx, st);
      m_tab_close.SyncFromState(ctx, st);
      m_tab_trail.SyncFromState(ctx, st);
      m_tab_be.SyncFromState(ctx, st);
      m_tab_settings.SyncFromState(ctx, st);
      m_tab_info.SyncFromState(ctx, st);

      // Update lock button text
      ObjectSetString(m_chart_id, m_obj_btn_lock, OBJPROP_TEXT, (st.ui_lock_panel ? "U" : "L"));
      ObjectSetString(m_chart_id, m_obj_btn_min,  OBJPROP_TEXT, (st.ui_minimized ? "+" : "-"));
   }

   void Layout(const TA_Context &ctx, TA_State &st, const int x, const int y, const int w, const int h)
   {
      if(!m_created) return;
      m_x=x; m_y=y; m_w=w; m_h=h;
      MoveBaseObjects();
      LayoutChildren(ctx, st);
   }

   void OnTimer(const TA_Context &ctx, TA_State &st)
   {
      if(!m_created) return;

      // Apply theme (cheap) so UI reacts to theme changes immediately.
      ApplyThemeToChrome(ctx, st);

      // Ensure objects are drawn in front (TA_Utils helper).
      TA_ChartEnsureObjectsForeground(m_chart_id);

      // Re-layout if minimized state changes (or if something moved us).
      MoveBaseObjects();
      LayoutChildren(ctx, st);

      // Tabs bar always updates.
      m_tabs.OnTimer(ctx, st);

      // Active tab renders content.
      RenderActiveTab(ctx, st);
   }

   void OnChartEvent(const TA_Context &ctx, TA_State &st, const int id,
                     const long &lparam, const double &dparam, const string &sparam)
   {
      if(!m_created) return;

      // Manual drag support: if user drags the header, we reposition everything.
      if(id == CHARTEVENT_OBJECT_CHANGE && sparam == m_obj_hdr)
      {
         if(!st.ui_lock_panel)
         {
            m_x = (int)ObjectGetInteger(m_chart_id, m_obj_hdr, OBJPROP_XDISTANCE);
            m_y = (int)ObjectGetInteger(m_chart_id, m_obj_hdr, OBJPROP_YDISTANCE);
            MoveBaseObjects();
            LayoutChildren(ctx, st);
         }
         else
         {
            // Restore header position when locked.
            MoveBaseObjects();
         }
         return;
      }

      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         if(sparam == m_obj_btn_min)
         {
            st.ui_minimized = !st.ui_minimized;
            SyncFromState(ctx, st);
            return;
         }
         if(sparam == m_obj_btn_lock)
         {
            st.ui_lock_panel = !st.ui_lock_panel;
            SyncFromState(ctx, st);
            return;
         }
      }

      // Tabs bar handles clicks + active-tab switching.
      m_tabs.OnChartEvent(ctx, st, id, lparam, dparam, sparam);

      // Route the event to active tab (even if minimized, to allow e.g. dropdown collapse).
      switch(st.ui_active_tab)
      {
         case TA_TAB_TRADE:    m_tab_trade.OnChartEvent(ctx, st, id, lparam, dparam, sparam);    break;
         case TA_TAB_CLOSE:    m_tab_close.OnChartEvent(ctx, st, id, lparam, dparam, sparam);    break;
         case TA_TAB_TRAILING: m_tab_trail.OnChartEvent(ctx, st, id, lparam, dparam, sparam);    break;
         case TA_TAB_BE:       m_tab_be.OnChartEvent(ctx, st, id, lparam, dparam, sparam);       break;
         case TA_TAB_SETTINGS: m_tab_settings.OnChartEvent(ctx, st, id, lparam, dparam, sparam); break;
         case TA_TAB_INFO:     m_tab_info.OnChartEvent(ctx, st, id, lparam, dparam, sparam);     break;
         default:              m_tab_trade.OnChartEvent(ctx, st, id, lparam, dparam, sparam);    break;
      }
   }
};

#endif // __MUSERA_TA_UI_APP_MQH__

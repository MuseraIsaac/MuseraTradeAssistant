//+------------------------------------------------------------------+
//|                                               UI_Tabs.mqh         |
//|                              (c) 2026, Musera Isaac               |
//|  Tab header controller for MuseraTradeAssistant UI.                |
//|                                                                   |
//|  Responsibilities:                                                 |
//|   - Create and manage the top tab strip (buttons)                  |
//|   - Switch TA_State.ui_active_tab on click                          |
//|   - Keep tab button styles in-sync with active tab                  |
//|                                                                   |
//|  Notes:                                                            |
//|   - This file is designed to be included by UI_App.mqh.             |
//|   - It assumes TA_State defines:                                    |
//|       ENUM_TA_APP_TAB ui_active_tab;                                |
//|     and that the enum values exist:                                 |
//|       TA_TAB_TRADE, TA_TAB_CLOSE, TA_TAB_TRAIL,                     |
//|       TA_TAB_BE, TA_TAB_SETTINGS, TA_TAB_INFO                       |
//+------------------------------------------------------------------+
#ifndef __MTA_UI_TABS_MQH__
#define __MTA_UI_TABS_MQH__

// Forward declarations (actual tab classes live in their own includes)
class UI_TradeTab;
class UI_CloseTab;
class UI_TrailingTab;
class UI_BE_Tab;
class UI_SettingsTab;
class UI_InfoTab;

class UI_Tabs
{
private:
   string m_prefix;
   string m_obj_bg;

   enum { TAB_COUNT = 6 };
   ENUM_TA_APP_TAB m_tabs[TAB_COUNT];
   string          m_labels[TAB_COUNT];
   string          m_btns[TAB_COUNT];

   int  m_x, m_y, m_w, m_h;
   bool m_created;
   ENUM_TA_APP_TAB m_last_active;

private:
   // -------------------- helpers --------------------
   bool ObjExists(const long chart_id, const string name) const
   {
      return (ObjectFind(chart_id, name) >= 0);
   }

   void SafeDelete(const long chart_id, const string name) const
   {
      if(ObjExists(chart_id, name))
         ObjectDelete(chart_id, name);
   }

   void ApplyButtonStyle(const long chart_id, const string btn_name, const bool active) const
   {
      // Basic, theme-agnostic styling (UI_Theme may override elsewhere).
      // Active tab stands out; inactive tabs are neutral.
      const color bg_active   = (color)clrDodgerBlue;
      const color bg_inactive = (color)clrDimGray;
      const color br_active   = (color)clrRoyalBlue;
      const color br_inactive = (color)clrGray;
      const color tx_active   = (color)clrWhite;
      const color tx_inactive = (color)clrWhiteSmoke;

      ObjectSetInteger(chart_id, btn_name, OBJPROP_BGCOLOR,      active ? bg_active   : bg_inactive);
      ObjectSetInteger(chart_id, btn_name, OBJPROP_BORDER_COLOR, active ? br_active   : br_inactive);
      ObjectSetInteger(chart_id, btn_name, OBJPROP_COLOR,        active ? tx_active   : tx_inactive);

      // Keep consistent look
      ObjectSetString(chart_id,  btn_name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(chart_id, btn_name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(chart_id, btn_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(chart_id, btn_name, OBJPROP_BACK, false);
      ObjectSetInteger(chart_id, btn_name, OBJPROP_SELECTABLE, false);
   }

   void EnsureBackground(const long chart_id)
   {
      if(ObjExists(chart_id, m_obj_bg))
         return;

      ObjectCreate(chart_id, m_obj_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_BACK, false);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_HIDDEN, true);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_COLOR, (color)clrGray);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_BGCOLOR, (color)clrSlateGray);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   }

   void EnsureButtons(const long chart_id)
   {
      for(int i=0; i<TAB_COUNT; i++)
      {
         if(!ObjExists(chart_id, m_btns[i]))
         {
            ObjectCreate(chart_id, m_btns[i], OBJ_BUTTON, 0, 0, 0);
            ObjectSetInteger(chart_id, m_btns[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(chart_id, m_btns[i], OBJPROP_BACK, false);
            ObjectSetInteger(chart_id, m_btns[i], OBJPROP_HIDDEN, true);
            ObjectSetInteger(chart_id, m_btns[i], OBJPROP_SELECTABLE, false);

            // Text
            ObjectSetString(chart_id, m_btns[i], OBJPROP_TEXT, m_labels[i]);

            // Default size/pos (Layout will set real values)
            ObjectSetInteger(chart_id, m_btns[i], OBJPROP_XDISTANCE, 0);
            ObjectSetInteger(chart_id, m_btns[i], OBJPROP_YDISTANCE, 0);
            ObjectSetInteger(chart_id, m_btns[i], OBJPROP_XSIZE, 10);
            ObjectSetInteger(chart_id, m_btns[i], OBJPROP_YSIZE, 10);
         }
      }
   }

   void UpdateStyles(const long chart_id, const ENUM_TA_APP_TAB active)
   {
      for(int i=0; i<TAB_COUNT; i++)
         ApplyButtonStyle(chart_id, m_btns[i], (m_tabs[i] == active));

      // Background border color slightly follows active state for visual coherence
      EnsureBackground(chart_id);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_BGCOLOR, (color)clrSlateGray);
   }

public:
   UI_Tabs()
   {
      m_prefix      = "";
      m_obj_bg      = "";
      m_x = m_y = m_w = m_h = 0;
      m_created     = false;
      m_last_active = (ENUM_TA_APP_TAB)0;
   }

   bool Create(const TA_Context &ctx, const string prefix)
   {
      m_prefix = prefix;
      m_obj_bg = m_prefix + "BG";

      // Define tab order & labels (must match ENUM_TA_APP_TAB values used in TA_State)
      m_tabs[0]   = TA_TAB_TRADE;    m_labels[0] = "Trade";
      m_tabs[1]   = TA_TAB_CLOSE;    m_labels[1] = "Close";
      m_tabs[2]   = TA_TAB_TRAIL;    m_labels[2] = "Trail";
      m_tabs[3]   = TA_TAB_BE;       m_labels[3] = "B/E";
      m_tabs[4]   = TA_TAB_SETTINGS; m_labels[4] = "Settings";
      m_tabs[5]   = TA_TAB_INFO;     m_labels[5] = "Info";

      for(int i=0; i<TAB_COUNT; i++)
         m_btns[i] = m_prefix + "BTN_" + IntegerToString((int)m_tabs[i]);

      const long chart_id = (long)ctx.chart_id;

      EnsureBackground(chart_id);
      EnsureButtons(chart_id);

      m_created = true;
      return true;
   }

   void Destroy(const TA_Context &ctx)
   {
      if(!m_created) return;

      const long chart_id = (long)ctx.chart_id;

      for(int i=0; i<TAB_COUNT; i++)
         SafeDelete(chart_id, m_btns[i]);

      SafeDelete(chart_id, m_obj_bg);

      m_created = false;
   }

   void Layout(const TA_Context &ctx, const TA_State &st, const int x, const int y, const int w, const int h)
   {
      if(!m_created) return;

      m_x = x; m_y = y; m_w = w; m_h = h;

      const long chart_id = (long)ctx.chart_id;

      EnsureBackground(chart_id);
      EnsureButtons(chart_id);

      // Background
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_XDISTANCE, m_x);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_YDISTANCE, m_y);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_XSIZE,     m_w);
      ObjectSetInteger(chart_id, m_obj_bg, OBJPROP_YSIZE,     m_h);

      // Buttons (equal widths, with small gaps)
      const int gap = 2;
      const int total_gap = gap * (TAB_COUNT - 1);
      int bw = (m_w - total_gap) / TAB_COUNT;
      if(bw < 28) bw = 28; // minimum clickable width

      int bx = m_x;
      for(int i=0; i<TAB_COUNT; i++)
      {
         ObjectSetInteger(chart_id, m_btns[i], OBJPROP_XDISTANCE, bx);
         ObjectSetInteger(chart_id, m_btns[i], OBJPROP_YDISTANCE, m_y);
         ObjectSetInteger(chart_id, m_btns[i], OBJPROP_XSIZE,     bw);
         ObjectSetInteger(chart_id, m_btns[i], OBJPROP_YSIZE,     m_h);

         bx += bw + gap;
      }

      UpdateStyles(chart_id, st.ui_active_tab);
      m_last_active = st.ui_active_tab;
   }

   void SyncFromState(const TA_Context &ctx, const TA_State &st)
   {
      if(!m_created) return;

      const long chart_id = (long)ctx.chart_id;

      // If user changed active tab through hotkeys or other means, reflect it
      if(st.ui_active_tab != m_last_active)
      {
         UpdateStyles(chart_id, st.ui_active_tab);
         m_last_active = st.ui_active_tab;
      }
   }

   void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      // Light work: only update styles if needed
      SyncFromState(ctx, st);
   }

   void OnChartEvent(const TA_Context &ctx, TA_State &st,
                     const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(!m_created) return;
      if(id != CHARTEVENT_OBJECT_CLICK) return;

      // Tab button click
      for(int i=0; i<TAB_COUNT; i++)
      {
         if(sparam == m_btns[i])
         {
            if(st.ui_active_tab != m_tabs[i])
            {
               st.ui_active_tab = m_tabs[i];

               const long chart_id = (long)ctx.chart_id;
               UpdateStyles(chart_id, st.ui_active_tab);
               m_last_active = st.ui_active_tab;
            }
            return;
         }
      }
   }
};

#endif // __MTA_UI_TABS_MQH__
//+------------------------------------------------------------------+

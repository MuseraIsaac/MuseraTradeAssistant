//+------------------------------------------------------------------+
//|                                            UI_CloseTab.mqh       |
//|  Close/cleanup actions tab: close positions / delete pendings.   |
//|  Part of: MuseraTradeAssistant project.                          |
//+------------------------------------------------------------------+
#property strict

#ifndef __UI_CLOSETAB_MQH__
#define __UI_CLOSETAB_MQH__

#include "../TA_Types.mqh"
#include "../TA_State.mqh"
#include "../TA_Enums.mqh"
#include "UI_Theme.mqh"

// Provided by main EA

class UI_CloseTab
{
private:
   string   m_prefix;
   UI_Theme m_theme;
   int      m_x, m_y, m_w, m_h;
   bool     m_created;

   // Object names
   string N(const string id) const { return m_prefix + "close_" + id; }

   void Btn(const string id, const string text, const int x, const int y, const int w, const int h)
   {
      const string name = N(id);
      if(!ObjectFind(0, name))
      {
         ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_RAISED);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetString (0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, m_theme.ButtonText);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, m_theme.ButtonBg);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, m_theme.ButtonBorder);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_theme.FontSize);
      ObjectSetString (0, name, OBJPROP_FONT, m_theme.Font);
   }

   bool ButtonHit(const int id, const string &sparam, const string objname)
   {
      if(id != CHARTEVENT_OBJECT_CLICK)
         return false;
      return (sparam == objname);
   }

public:
   UI_CloseTab(): m_x(0), m_y(0), m_w(0), m_h(0), m_created(false) {}

   void Init(const string prefix, const UI_Theme &theme)
   {
      m_prefix = prefix;
      m_theme  = theme;
   }

   bool Create(const int x, const int y, const int w, const int h)
   {
      m_x = x; m_y = y; m_w = w; m_h = h;

      // Layout: 2 columns of buttons
      const int pad = 8;
      const int bw  = (w - pad*3) / 2;
      const int bh  = 22;
      int cx1 = x + pad;
      int cx2 = x + pad*2 + bw;
      int cy  = y + pad;

      Btn("all",        "Close All",        cx1, cy, bw, bh);
      Btn("pend",       "Delete Pendings",  cx2, cy, bw, bh);
      cy += bh + pad;

      Btn("buy",        "Close Buys",       cx1, cy, bw, bh);
      Btn("sell",       "Close Sells",      cx2, cy, bw, bh);
      cy += bh + pad;

      Btn("profit",     "Close Profitable", cx1, cy, bw, bh);
      Btn("loss",       "Close Losing",     cx2, cy, bw, bh);
      cy += bh + pad;

      Btn("allpend",    "Close+Delete",     cx1, cy, bw*2 + pad, bh);

      m_created = true;
      return true;
   }

   void Destroy()
   {
      if(!m_created) return;
      ObjectDelete(0, N("all"));
      ObjectDelete(0, N("pend"));
      ObjectDelete(0, N("buy"));
      ObjectDelete(0, N("sell"));
      ObjectDelete(0, N("profit"));
      ObjectDelete(0, N("loss"));
      ObjectDelete(0, N("allpend"));
      m_created = false;
   }

   void Show(const bool v)
   {
      if(!m_created) return;
      ObjectSetInteger(0, N("all"),     OBJPROP_HIDDEN, !v);
      ObjectSetInteger(0, N("pend"),    OBJPROP_HIDDEN, !v);
      ObjectSetInteger(0, N("buy"),     OBJPROP_HIDDEN, !v);
      ObjectSetInteger(0, N("sell"),    OBJPROP_HIDDEN, !v);
      ObjectSetInteger(0, N("profit"),  OBJPROP_HIDDEN, !v);
      ObjectSetInteger(0, N("loss"),    OBJPROP_HIDDEN, !v);
      ObjectSetInteger(0, N("allpend"), OBJPROP_HIDDEN, !v);
   }

   void OnTimer(const TA_Context &ctx, const TA_State &st) { (void)ctx; (void)st; }

   void OnChartEvent(const TA_Context &ctx, const TA_State &st, const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      (void)ctx; (void)st; (void)lparam; (void)dparam;
      if(!m_created) return;

      // enum values expected by TA_PositionManager::ExecuteCloseCommand():
      // 1 close all, 2 close buys, 3 close sells, 4 close profitable, 5 close losing, 6 delete pendings, 7 close all + delete pendings

      if(ButtonHit(id, sparam, N("all")))
         TA_OnUI_CloseCommand((ENUM_TA_CLOSE_CMD)1);
      else if(ButtonHit(id, sparam, N("buy")))
         TA_OnUI_CloseCommand((ENUM_TA_CLOSE_CMD)2);
      else if(ButtonHit(id, sparam, N("sell")))
         TA_OnUI_CloseCommand((ENUM_TA_CLOSE_CMD)3);
      else if(ButtonHit(id, sparam, N("profit")))
         TA_OnUI_CloseCommand((ENUM_TA_CLOSE_CMD)4);
      else if(ButtonHit(id, sparam, N("loss")))
         TA_OnUI_CloseCommand((ENUM_TA_CLOSE_CMD)5);
      else if(ButtonHit(id, sparam, N("pend")))
         TA_OnUI_CloseCommand((ENUM_TA_CLOSE_CMD)6);
      else if(ButtonHit(id, sparam, N("allpend")))
         TA_OnUI_CloseCommand((ENUM_TA_CLOSE_CMD)7);
   }

   void SyncFromState(const TA_Context &ctx, const TA_State &st) { (void)ctx; (void)st; }
};

#endif // __UI_CLOSETAB_MQH__

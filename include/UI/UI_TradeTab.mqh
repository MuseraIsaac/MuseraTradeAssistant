//+------------------------------------------------------------------+
//|                                                   UI_TradeTab.mqh |
//|                     Trade Assistant / Trade Manager - Trade Tab    |
//|                                  (c) 2026, Musera Isaac            |
//|                                                                      |
//|  Purpose: UI elements for the "Trade" tab (Buy/Sell + basic inputs). |
//|  Notes:                                                             |
//|   - This module is intentionally "plain MQL5 objects" (OBJ_*).       |
//|   - It is designed to be driven from OnTimer (tickless UI).          |
//|   - It calls the EA-level wrapper callbacks declared below.          |
//+------------------------------------------------------------------+
#property strict

#ifndef __MUSERA_TA_UI_TRADETAB_MQH__
#define __MUSERA_TA_UI_TRADETAB_MQH__

#include "../TA_Constants.mqh"
#include "../TA_Enums.mqh"
#include "../TA_Types.mqh"
#include "../TA_State.mqh"
#include "UI_Theme.mqh"

// -------------------------------------------------------------------
// Forward declarations (implemented in the main EA file).
// These are used to perform actions directly from UI events.
// -------------------------------------------------------------------

//+------------------------------------------------------------------+
//| UI_TradeTab                                                        |
//+------------------------------------------------------------------+
class UI_TradeTab
{
private:
   long   m_chart;
   string m_prefix;

   int    m_x, m_y, m_w, m_h;
   bool   m_visible;

   // Cached input (not stored in TA_State)
   string m_preset_name;

   // Object names
   string m_bg;

   string m_lbl_symbol;
   string m_lbl_price;
   string m_lbl_spread;

   string m_btn_buy;
   string m_btn_sell;

   string m_lbl_risk;
   string m_btn_riskmode;
   string m_ed_risk;

   string m_lbl_lots;
   string m_ed_lots;

   string m_lbl_sl;
   string m_ed_sl;
   string m_lbl_tp;
   string m_ed_tp;

   string m_btn_be;
   string m_btn_partials;

   // TP partials (simple quick controls)
   string m_btn_tp1;
   string m_ed_tp1_rr;
   string m_ed_tp1_pct;

   string m_btn_tp2;
   string m_ed_tp2_rr;
   string m_ed_tp2_pct;

   string m_btn_tp3;
   string m_ed_tp3_rr;
   string m_ed_tp3_pct;

   // Presets quick bar
   string m_lbl_preset;
   string m_ed_preset;
   string m_btn_save;
   string m_btn_load;

   // Registry of created objects (for hide/show/destroy)
   string m_objs[];
   int    m_obj_count;

private:
   void AddObj(const string name)
   {
      int n = ArraySize(m_objs);
      ArrayResize(m_objs, n+1);
      m_objs[n] = name;
      m_obj_count = n+1;
   }

   bool ObjExists(const string name) const
   {
      return (ObjectFind(m_chart, name) >= 0);
   }

   void SetHiddenAll(const bool hidden)
   {
      for(int i=0;i<m_obj_count;i++)
      {
         string n = m_objs[i];
         if(ObjectFind(m_chart, n) >= 0)
            ObjectSetInteger(m_chart, n, OBJPROP_HIDDEN, hidden);
      }
   }

   void SetCommon(const string name)
   {
      // Keep UI above candles (EA also sets CHART_FOREGROUND=false).
      ObjectSetInteger(m_chart, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chart, name, OBJPROP_ZORDER, 0);
   }

   bool EnsureRectLabel(const string name,int x,int y,int w,int h,color bg,color border)
   {
      if(!ObjExists(name))
      {
         if(!ObjectCreate(m_chart, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
            return false;
         AddObj(name);
      }
      ObjectSetInteger(m_chart, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(m_chart, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(m_chart, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, border);
      ObjectSetInteger(m_chart, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chart, name, OBJPROP_WIDTH, 1);
      SetCommon(name);
      return true;
   }

   bool EnsureLabel(const string name,int x,int y,const string txt,color c,int fsz=9,const string font="Arial")
   {
      if(!ObjExists(name))
      {
         if(!ObjectCreate(m_chart, name, OBJ_LABEL, 0, 0, 0))
            return false;
         AddObj(name);
      }
      ObjectSetInteger(m_chart, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(m_chart,  name, OBJPROP_TEXT, txt);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, c);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, fsz);
      ObjectSetString(m_chart,  name, OBJPROP_FONT, font);
      SetCommon(name);
      return true;
   }

   bool EnsureButton(const string name,int x,int y,int w,int h,const string txt,color bg,color fg)
   {
      if(!ObjExists(name))
      {
         if(!ObjectCreate(m_chart, name, OBJ_BUTTON, 0, 0, 0))
            return false;
         AddObj(name);
      }
      ObjectSetInteger(m_chart, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(m_chart, name, OBJPROP_YSIZE, h);
      ObjectSetString(m_chart,  name, OBJPROP_TEXT, txt);
      ObjectSetInteger(m_chart, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, fg);
      ObjectSetInteger(m_chart, name, OBJPROP_BORDER_COLOR, fg);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(m_chart,  name, OBJPROP_FONT, "Arial");
      // Buttons must be clickable:
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(m_chart, name, OBJPROP_HIDDEN, !m_visible);
      ObjectSetInteger(m_chart, name, OBJPROP_ZORDER, 0);
      ObjectSetInteger(m_chart, name, OBJPROP_BACK, false);
      return true;
   }

   bool EnsureEdit(const string name,int x,int y,int w,int h,const string txt,color bg,color fg)
   {
      if(!ObjExists(name))
      {
         if(!ObjectCreate(m_chart, name, OBJ_EDIT, 0, 0, 0))
            return false;
         AddObj(name);
      }
      ObjectSetInteger(m_chart, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(m_chart, name, OBJPROP_YSIZE, h);
      ObjectSetString(m_chart,  name, OBJPROP_TEXT, txt);
      ObjectSetInteger(m_chart, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, fg);
      ObjectSetInteger(m_chart, name, OBJPROP_BORDER_COLOR, fg);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(m_chart,  name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(m_chart, name, OBJPROP_READONLY, false);
      ObjectSetInteger(m_chart, name, OBJPROP_HIDDEN, !m_visible);
      ObjectSetInteger(m_chart, name, OBJPROP_ZORDER, 0);
      ObjectSetInteger(m_chart, name, OBJPROP_BACK, false);
      return true;
   }

   string RiskModeToText(const ENUM_TA_RISK_MODE rm) const
   {
      switch(rm)
      {
         case TA_RISK_PERCENT:    return "Risk: %";
         case TA_RISK_MONEY:      return "Risk: $";
         case TA_RISK_FIXED_LOTS: return "Risk: Lots";
      }
      return "Risk";
   }

   string OnOff(const bool v) const { return (v ? "ON" : "OFF"); }

   double ReadDouble(const string obj,const double def=0.0) const
   {
      if(ObjectFind(m_chart, obj) < 0) return def;
      string s = ObjectGetString(m_chart, obj, OBJPROP_TEXT);
      StringTrimLeft(s); StringTrimRight(s);
      if(s=="") return def;
      return StringToDouble(s);
   }

   string ReadString(const string obj,const string def="") const
   {
      if(ObjectFind(m_chart, obj) < 0) return def;
      string s = ObjectGetString(m_chart, obj, OBJPROP_TEXT);
      StringTrimLeft(s); StringTrimRight(s);
      return s;
   }

public:
   UI_TradeTab() : m_chart(0), m_prefix(""), m_x(0), m_y(0), m_w(0), m_h(0), m_visible(false), m_preset_name("")
   {
      ArrayResize(m_objs,0);
      m_obj_count = 0;
   }

   bool Create(const TA_Context &ctx,const string &prefix)
   {
      m_chart  = ctx.chart_id;
      m_prefix = prefix;
      m_visible = true;

      m_bg         = m_prefix + "BG";

      m_lbl_symbol = m_prefix + "LBL_SYMBOL";
      m_lbl_price  = m_prefix + "LBL_PRICE";
      m_lbl_spread = m_prefix + "LBL_SPREAD";

      m_btn_buy    = m_prefix + "BTN_BUY";
      m_btn_sell   = m_prefix + "BTN_SELL";

      m_lbl_risk   = m_prefix + "LBL_RISK";
      m_btn_riskmode = m_prefix + "BTN_RISKMODE";
      m_ed_risk    = m_prefix + "ED_RISK";

      m_lbl_lots   = m_prefix + "LBL_LOTS";
      m_ed_lots    = m_prefix + "ED_LOTS";

      m_lbl_sl     = m_prefix + "LBL_SL";
      m_ed_sl      = m_prefix + "ED_SL";
      m_lbl_tp     = m_prefix + "LBL_TP";
      m_ed_tp      = m_prefix + "ED_TP";

      m_btn_be     = m_prefix + "BTN_BE";
      m_btn_partials = m_prefix + "BTN_PARTIALS";

      m_btn_tp1    = m_prefix + "BTN_TP1";
      m_ed_tp1_rr  = m_prefix + "ED_TP1_RR";
      m_ed_tp1_pct = m_prefix + "ED_TP1_PCT";

      m_btn_tp2    = m_prefix + "BTN_TP2";
      m_ed_tp2_rr  = m_prefix + "ED_TP2_RR";
      m_ed_tp2_pct = m_prefix + "ED_TP2_PCT";

      m_btn_tp3    = m_prefix + "BTN_TP3";
      m_ed_tp3_rr  = m_prefix + "ED_TP3_RR";
      m_ed_tp3_pct = m_prefix + "ED_TP3_PCT";

      m_lbl_preset = m_prefix + "LBL_PRESET";
      m_ed_preset  = m_prefix + "ED_PRESET";
      m_btn_save   = m_prefix + "BTN_SAVE";
      m_btn_load   = m_prefix + "BTN_LOAD";

      // Create objects with placeholder layout (real positions done in Layout()).
      EnsureRectLabel(m_bg, 0,0, 10,10, clrBlack, clrDimGray);

      EnsureLabel(m_lbl_symbol, 0,0, "Symbol:", clrWhiteSmoke, 9);
      EnsureLabel(m_lbl_price,  0,0, "Price:",  clrWhiteSmoke, 9);
      EnsureLabel(m_lbl_spread, 0,0, "Spread:", clrWhiteSmoke, 9);

      EnsureButton(m_btn_buy,  0,0, 10,10, "BUY",  clrSeaGreen, clrWhite);
      EnsureButton(m_btn_sell, 0,0, 10,10, "SELL", clrCrimson,  clrWhite);

      EnsureLabel(m_lbl_risk, 0,0, "Risk input", clrWhiteSmoke, 9);
      EnsureButton(m_btn_riskmode,0,0,10,10,"Risk: %", clrSlateGray, clrWhite);
      EnsureEdit(m_ed_risk,0,0,10,10,"1.0", clrBlack, clrWhite);

      EnsureLabel(m_lbl_lots,0,0,"Lots", clrWhiteSmoke, 9);
      EnsureEdit(m_ed_lots,0,0,10,10,"0.10", clrBlack, clrWhite);

      EnsureLabel(m_lbl_sl,0,0,"SL (pips)", clrWhiteSmoke, 9);
      EnsureEdit(m_ed_sl,0,0,10,10,"20", clrBlack, clrWhite);
      EnsureLabel(m_lbl_tp,0,0,"TP (pips)", clrWhiteSmoke, 9);
      EnsureEdit(m_ed_tp,0,0,10,10,"40", clrBlack, clrWhite);

      EnsureButton(m_btn_be,0,0,10,10,"BreakEven: OFF", clrDarkSlateGray, clrWhite);
      EnsureButton(m_btn_partials,0,0,10,10,"Partials: OFF", clrDarkSlateGray, clrWhite);

      // Partials: toggle + RR + % close
      EnsureButton(m_btn_tp1,0,0,10,10,"TP1: OFF", clrSlateGray, clrWhite);
      EnsureEdit(m_ed_tp1_rr,0,0,10,10,"1.0", clrBlack, clrWhite);
      EnsureEdit(m_ed_tp1_pct,0,0,10,10,"33", clrBlack, clrWhite);

      EnsureButton(m_btn_tp2,0,0,10,10,"TP2: OFF", clrSlateGray, clrWhite);
      EnsureEdit(m_ed_tp2_rr,0,0,10,10,"2.0", clrBlack, clrWhite);
      EnsureEdit(m_ed_tp2_pct,0,0,10,10,"33", clrBlack, clrWhite);

      EnsureButton(m_btn_tp3,0,0,10,10,"TP3: OFF", clrSlateGray, clrWhite);
      EnsureEdit(m_ed_tp3_rr,0,0,10,10,"3.0", clrBlack, clrWhite);
      EnsureEdit(m_ed_tp3_pct,0,0,10,10,"34", clrBlack, clrWhite);

      // Presets
      EnsureLabel(m_lbl_preset,0,0,"Preset", clrWhiteSmoke, 9);
      EnsureEdit(m_ed_preset,0,0,10,10,"", clrBlack, clrWhite);
      EnsureButton(m_btn_save,0,0,10,10,"Save", clrDodgerBlue, clrWhite);
      EnsureButton(m_btn_load,0,0,10,10,"Load", clrDodgerBlue, clrWhite);

      return true;
   }

   void Destroy()
   {
      for(int i=0;i<m_obj_count;i++)
      {
         string n = m_objs[i];
         if(ObjectFind(m_chart, n) >= 0)
            ObjectDelete(m_chart, n);
      }
      ArrayResize(m_objs,0);
      m_obj_count = 0;
   }

   void SetVisible(const bool visible)
   {
      m_visible = visible;
      SetHiddenAll(!visible);
   }

   void Layout(const TA_Context &ctx, TA_State &st, const int x,const int y,const int w,const int h)
   {
      m_x=x; m_y=y; m_w=w; m_h=h;

      const int pad = 8;
      const int row = 20;
      const int btnH = 24;
      const int edH  = 20;

      // Colors (fallback). If UI_Theme later provides palette, you can swap these.
      color bg = clrBlack;
      color border = clrDimGray;

      EnsureRectLabel(m_bg, m_x, m_y, m_w, m_h, bg, border);

      int cx = m_x + pad;
      int cy = m_y + pad;

      // Header info
      EnsureLabel(m_lbl_symbol, cx, cy, "Symbol:", clrWhiteSmoke, 9); cy += row;
      EnsureLabel(m_lbl_price,  cx, cy, "Price:",  clrWhiteSmoke, 9); cy += row;
      EnsureLabel(m_lbl_spread, cx, cy, "Spread:", clrWhiteSmoke, 9); cy += row + 4;

      // Buy/Sell row
      int btnW = (m_w - pad*3)/2;
      EnsureButton(m_btn_buy,  cx,           cy, btnW, btnH, "BUY",  clrSeaGreen, clrWhite);
      EnsureButton(m_btn_sell, cx+btnW+pad,  cy, btnW, btnH, "SELL", clrCrimson,  clrWhite);
      cy += btnH + 10;

      // Risk mode + value
      EnsureLabel(m_lbl_risk, cx, cy, "Risk", clrWhiteSmoke, 9);
      EnsureButton(m_btn_riskmode, cx+60, cy-2, 90, btnH, "Risk", clrSlateGray, clrWhite);
      EnsureEdit(m_ed_risk, cx+60+90+pad, cy-2, m_w - (pad*3 + 60 + 90), edH, ObjectGetString(m_chart,m_ed_risk,OBJPROP_TEXT), clrBlack, clrWhite);
      cy += row + 4;

      // Lots (shown always; core can ignore depending on risk mode)
      EnsureLabel(m_lbl_lots, cx, cy, "Lots", clrWhiteSmoke, 9);
      EnsureEdit(m_ed_lots, cx+60, cy-2, 90, edH, ObjectGetString(m_chart,m_ed_lots,OBJPROP_TEXT), clrBlack, clrWhite);
      cy += row + 4;

      // SL/TP
      EnsureLabel(m_lbl_sl, cx, cy, "SL (pips)", clrWhiteSmoke, 9);
      EnsureEdit(m_ed_sl, cx+60, cy-2, 90, edH, ObjectGetString(m_chart,m_ed_sl,OBJPROP_TEXT), clrBlack, clrWhite);
      cy += row;

      EnsureLabel(m_lbl_tp, cx, cy, "TP (pips)", clrWhiteSmoke, 9);
      EnsureEdit(m_ed_tp, cx+60, cy-2, 90, edH, ObjectGetString(m_chart,m_ed_tp,OBJPROP_TEXT), clrBlack, clrWhite);
      cy += row + 8;

      // Toggles
      EnsureButton(m_btn_be, cx, cy, btnW, btnH, "BreakEven", clrDarkSlateGray, clrWhite);
      EnsureButton(m_btn_partials, cx+btnW+pad, cy, btnW, btnH, "Partials", clrDarkSlateGray, clrWhite);
      cy += btnH + 10;

      // Partials grid
      int col1 = cx;
      int col2 = cx + btnW + pad;

      // TP1 row
      EnsureButton(m_btn_tp1, col1, cy, btnW, btnH, "TP1", clrSlateGray, clrWhite);
      EnsureEdit(m_ed_tp1_rr, col2, cy, (btnW-pad)/2, edH, ObjectGetString(m_chart,m_ed_tp1_rr,OBJPROP_TEXT), clrBlack, clrWhite);
      EnsureEdit(m_ed_tp1_pct, col2+(btnW-pad)/2+pad, cy, (btnW-pad)/2, edH, ObjectGetString(m_chart,m_ed_tp1_pct,OBJPROP_TEXT), clrBlack, clrWhite);
      cy += row + 4;

      // TP2 row
      EnsureButton(m_btn_tp2, col1, cy, btnW, btnH, "TP2", clrSlateGray, clrWhite);
      EnsureEdit(m_ed_tp2_rr, col2, cy, (btnW-pad)/2, edH, ObjectGetString(m_chart,m_ed_tp2_rr,OBJPROP_TEXT), clrBlack, clrWhite);
      EnsureEdit(m_ed_tp2_pct, col2+(btnW-pad)/2+pad, cy, (btnW-pad)/2, edH, ObjectGetString(m_chart,m_ed_tp2_pct,OBJPROP_TEXT), clrBlack, clrWhite);
      cy += row + 4;

      // TP3 row
      EnsureButton(m_btn_tp3, col1, cy, btnW, btnH, "TP3", clrSlateGray, clrWhite);
      EnsureEdit(m_ed_tp3_rr, col2, cy, (btnW-pad)/2, edH, ObjectGetString(m_chart,m_ed_tp3_rr,OBJPROP_TEXT), clrBlack, clrWhite);
      EnsureEdit(m_ed_tp3_pct, col2+(btnW-pad)/2+pad, cy, (btnW-pad)/2, edH, ObjectGetString(m_chart,m_ed_tp3_pct,OBJPROP_TEXT), clrBlack, clrWhite);
      cy += row + 10;

      // Presets quick row
      EnsureLabel(m_lbl_preset, cx, cy, "Preset", clrWhiteSmoke, 9);
      EnsureEdit(m_ed_preset, cx+60, cy-2, 120, edH, ObjectGetString(m_chart,m_ed_preset,OBJPROP_TEXT), clrBlack, clrWhite);
      EnsureButton(m_btn_save, cx+60+120+pad, cy-2, 55, btnH, "Save", clrDodgerBlue, clrWhite);
      EnsureButton(m_btn_load, cx+60+120+pad+55+pad, cy-2, 55, btnH, "Load", clrDodgerBlue, clrWhite);

      SetVisible(m_visible);
   }

   void SyncFromState(const TA_Context &ctx, TA_State &st)
   {
      // If hidden, avoid touching objects too much (but keep safe).
      if(!m_visible) return;

      // Update top info
      string sym = ctx.symbol;
      EnsureLabel(m_lbl_symbol, ObjectGetInteger(m_chart,m_lbl_symbol,OBJPROP_XDISTANCE),
                              ObjectGetInteger(m_chart,m_lbl_symbol,OBJPROP_YDISTANCE),
                              "Symbol: " + sym, clrWhiteSmoke, 9);

      double bid = 0.0, ask = 0.0;
      SymbolInfoDouble(sym, SYMBOL_BID, bid);
      SymbolInfoDouble(sym, SYMBOL_ASK, ask);
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      EnsureLabel(m_lbl_price, ObjectGetInteger(m_chart,m_lbl_price,OBJPROP_XDISTANCE),
                             ObjectGetInteger(m_chart,m_lbl_price,OBJPROP_YDISTANCE),
                             "Price: " + DoubleToString(bid,digits) + " / " + DoubleToString(ask,digits),
                             clrWhiteSmoke, 9);

      double spread_points = (ask-bid) / SymbolInfoDouble(sym, SYMBOL_POINT);
      EnsureLabel(m_lbl_spread, ObjectGetInteger(m_chart,m_lbl_spread,OBJPROP_XDISTANCE),
                              ObjectGetInteger(m_chart,m_lbl_spread,OBJPROP_YDISTANCE),
                              "Spread: " + DoubleToString(spread_points,1) + " pts",
                              clrWhiteSmoke, 9);

      // Risk mode
      ObjectSetString(m_chart, m_btn_riskmode, OBJPROP_TEXT, RiskModeToText(st.risk_mode));

      // Risk value / lots edit (keep user edits; only refresh if empty)
      if(st.risk_mode == TA_RISK_FIXED_LOTS)
      {
         ObjectSetInteger(m_chart, m_ed_risk, OBJPROP_HIDDEN, true);
         ObjectSetInteger(m_chart, m_lbl_risk, OBJPROP_HIDDEN, true);

         ObjectSetInteger(m_chart, m_lbl_lots, OBJPROP_HIDDEN, false);
         ObjectSetInteger(m_chart, m_ed_lots,  OBJPROP_HIDDEN, false);

         if(ReadString(m_ed_lots,"") == "")
            ObjectSetString(m_chart, m_ed_lots, OBJPROP_TEXT, DoubleToString(st.fixed_lots,2));
      }
      else
      {
         ObjectSetInteger(m_chart, m_ed_risk, OBJPROP_HIDDEN, false);
         ObjectSetInteger(m_chart, m_lbl_risk, OBJPROP_HIDDEN, false);

         ObjectSetInteger(m_chart, m_lbl_lots, OBJPROP_HIDDEN, false);
         ObjectSetInteger(m_chart, m_ed_lots,  OBJPROP_HIDDEN, false);

         if(ReadString(m_ed_risk,"") == "")
            ObjectSetString(m_chart, m_ed_risk, OBJPROP_TEXT, DoubleToString(st.risk_value,2));
         if(ReadString(m_ed_lots,"") == "")
            ObjectSetString(m_chart, m_ed_lots, OBJPROP_TEXT, DoubleToString(st.fixed_lots,2));
      }

      // SL/TP (default pips)
      if(ReadString(m_ed_sl,"") == "")
         ObjectSetString(m_chart, m_ed_sl, OBJPROP_TEXT, DoubleToString(st.sl_pips,1));
      if(ReadString(m_ed_tp,"") == "")
         ObjectSetString(m_chart, m_ed_tp, OBJPROP_TEXT, DoubleToString(st.tp_pips,1));

      // Toggles
      ObjectSetString(m_chart, m_btn_be, OBJPROP_TEXT, "BreakEven: " + OnOff(st.be_enabled));
      ObjectSetString(m_chart, m_btn_partials, OBJPROP_TEXT, "Partials: " + OnOff(st.tp_partials_enabled));

      ObjectSetString(m_chart, m_btn_tp1, OBJPROP_TEXT, "TP1: " + OnOff(st.tp1_enabled));
      ObjectSetString(m_chart, m_btn_tp2, OBJPROP_TEXT, "TP2: " + OnOff(st.tp2_enabled));
      ObjectSetString(m_chart, m_btn_tp3, OBJPROP_TEXT, "TP3: " + OnOff(st.tp3_enabled));
   }

   void OnTimer(const TA_Context &ctx, TA_State &st)
   {
      // Keep it light: update live labels only.
      if(!m_visible) return;
      SyncFromState(ctx, st);
   }

   void OnChartEvent(const TA_Context &ctx, TA_State &st,
                     const int id, const long &lparam, const double &dparam, const string &sparam)
   {

      if(!m_visible) return;

      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         if(sparam == m_btn_buy)
         {
            TA_OnUI_PlaceMarket(true);
            return;
         }
         if(sparam == m_btn_sell)
         {
            TA_OnUI_PlaceMarket(false);
            return;
         }
         if(sparam == m_btn_riskmode)
         {
            // cycle risk mode
            if(st.risk_mode == TA_RISK_PERCENT) st.risk_mode = TA_RISK_MONEY;
            else if(st.risk_mode == TA_RISK_MONEY) st.risk_mode = TA_RISK_FIXED_LOTS;
            else st.risk_mode = TA_RISK_PERCENT;
            return;
         }
         if(sparam == m_btn_be)
         {
            st.be_enabled = !st.be_enabled;
            TA_OnUI_ToggleBreakEven(st.be_enabled);
            return;
         }
         if(sparam == m_btn_partials)
         {
            st.tp_partials_enabled = !st.tp_partials_enabled;
            TA_OnUI_TogglePartials(st.tp_partials_enabled);
            return;
         }

         // TP toggles
         if(sparam == m_btn_tp1) { st.tp1_enabled = !st.tp1_enabled; return; }
         if(sparam == m_btn_tp2) { st.tp2_enabled = !st.tp2_enabled; return; }
         if(sparam == m_btn_tp3) { st.tp3_enabled = !st.tp3_enabled; return; }

         // Presets
         if(sparam == m_btn_save)
         {
            string p = ReadString(m_ed_preset, m_preset_name);
            m_preset_name = p;
            if(p != "") TA_OnUI_SavePreset(p);
            return;
         }
         if(sparam == m_btn_load)
         {
            string p = ReadString(m_ed_preset, m_preset_name);
            m_preset_name = p;
            if(p != "") TA_OnUI_LoadPreset(p);
            return;
         }
      }

      if(id == CHARTEVENT_OBJECT_ENDEDIT)
      {
         // Risk value
         if(sparam == m_ed_risk)
         {
            double v = ReadDouble(m_ed_risk, st.risk_value);
            if(v < 0) v = 0;
            st.risk_value = v;
            return;
         }

         // Lots
         if(sparam == m_ed_lots)
         {
            double v = ReadDouble(m_ed_lots, st.fixed_lots);
            if(v < 0) v = 0;
            st.fixed_lots = v;
            return;
         }

         // SL/TP pips
         if(sparam == m_ed_sl)
         {
            double v = ReadDouble(m_ed_sl, st.sl_pips);
            if(v < 0) v = 0;
            st.sl_mode  = TA_SL_PIPS;
            st.sl_pips  = v;
            st.sl_value = v;
            return;
         }
         if(sparam == m_ed_tp)
         {
            double v = ReadDouble(m_ed_tp, st.tp_pips);
            if(v < 0) v = 0;
            st.tp_mode  = TA_TP_PIPS;
            st.tp_pips  = v;
            st.tp_value = v;
            return;
         }

         // TP partials RR/PCT
         if(sparam == m_ed_tp1_rr)  { st.tp1_rr = ReadDouble(m_ed_tp1_rr, st.tp1_rr); return; }
         if(sparam == m_ed_tp2_rr)  { st.tp2_rr = ReadDouble(m_ed_tp2_rr, st.tp2_rr); return; }
         if(sparam == m_ed_tp3_rr)  { st.tp3_rr = ReadDouble(m_ed_tp3_rr, st.tp3_rr); return; }

         if(sparam == m_ed_tp1_pct)
         {
            double v = ReadDouble(m_ed_tp1_pct, st.tp1_close_pct);
            if(v < 0) v = 0; if(v > 100) v = 100;
            st.tp1_close_pct = v;
            return;
         }
         if(sparam == m_ed_tp2_pct)
         {
            double v = ReadDouble(m_ed_tp2_pct, st.tp2_close_pct);
            if(v < 0) v = 0; if(v > 100) v = 100;
            st.tp2_close_pct = v;
            return;
         }
         if(sparam == m_ed_tp3_pct)
         {
            double v = ReadDouble(m_ed_tp3_pct, st.tp3_close_pct);
            if(v < 0) v = 0; if(v > 100) v = 100;
            st.tp3_close_pct = v;
            return;
         }

         if(sparam == m_ed_preset)
         {
            m_preset_name = ReadString(m_ed_preset, m_preset_name);
            return;
         }
      }
   }
};

#endif // __MUSERA_TA_UI_TRADETAB_MQH__

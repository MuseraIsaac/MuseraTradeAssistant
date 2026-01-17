//+------------------------------------------------------------------+
//|                                           UI_TrailingTab.mqh      |
//|                      (c) 2026, Musera Isaac                       |
//|  Trailing settings tab: enable/disable, mode dropdown, parameters. |
//|                                                                    |
//|  Part of: MuseraTradeAssistant (project shell)                     |
//+------------------------------------------------------------------+
#ifndef __MUSERA_UI_TRAILINGTAB_MQH__
#define __MUSERA_UI_TRAILINGTAB_MQH__

#include "../TA_Constants.mqh"
#include "../TA_Enums.mqh"
#include "../TA_Types.mqh"
#include "../TA_State.mqh"
#include "UI_Theme.mqh"

// Implemented in main EA. Called when mode changes.

//+------------------------------------------------------------------+
//| UI_TrailingTab                                                    |
//+------------------------------------------------------------------+
class UI_TrailingTab
{
private:
   long   m_chart;
   string m_prefix;
   bool   m_created;
   bool   m_visible;

   int    m_x, m_y, m_w, m_h;

   // Objects registry for easy hide/destroy
   string m_objs[128];
   int    m_obj_count;

   // Base panel
   string m_bg;
   string m_title;

   // Common controls
   string m_btn_enable;
   string m_btn_profit;
   string m_lbl_mode;
   string m_btn_mode;        // opens dropdown (popup)
   string m_ed_minint;
   string m_lbl_minint;

   // Popup dropdown
   bool   m_popup;
   string m_popup_bg;
   string m_mode_opt[8];

   // Mode params (Pips)
   string m_lbl_pips_dist, m_ed_pips_dist;
   string m_lbl_pips_step, m_ed_pips_step;

   // Fractals
   string m_lbl_fr_left,  m_ed_fr_left;
   string m_lbl_fr_right, m_ed_fr_right;
   string m_lbl_fr_buf,   m_ed_fr_buf;

   // MA
   string m_lbl_ma_period, m_ed_ma_period;
   string m_lbl_ma_method, m_btn_ma_method;
   string m_lbl_ma_price,  m_btn_ma_price;
   string m_lbl_ma_buf,    m_ed_ma_buf;

   // SAR
   string m_lbl_sar_step, m_ed_sar_step;
   string m_lbl_sar_max,  m_ed_sar_max;
   string m_lbl_sar_buf,  m_ed_sar_buf;

   // ATR
   string m_lbl_atr_period, m_ed_atr_period;
   string m_lbl_atr_mult,   m_ed_atr_mult;
   string m_lbl_atr_buf,    m_ed_atr_buf;

   // High/Low
   string m_lbl_hl_look, m_ed_hl_look;
   string m_lbl_hl_buf,  m_ed_hl_buf;

   // Partial-close trailing (mode)
   string m_btn_pc_enable;
   string m_lbl_pc_everyr,   m_ed_pc_everyr;
   string m_lbl_pc_closepct, m_ed_pc_closepct;

private:
   void AddObj(const string name)
   {
      int n = m_obj_count;
      if(n >= (int)ArraySize(m_objs)) return;
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
      ObjectSetInteger(m_chart, name, OBJPROP_WIDTH, 1);
      SetCommon(name);
      return true;
   }

   bool EnsureLabel(const string name,int x,int y,int w,int h,const string text,color c,int fsize=9)
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
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, fsize);
      ObjectSetString(m_chart, name, OBJPROP_FONT, "Arial");
      ObjectSetString(m_chart, name, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, c);
      SetCommon(name);
      return true;
   }

   bool EnsureButton(const string name,int x,int y,int w,int h,const string text,color bg,color fg,int fsize=9)
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
      ObjectSetInteger(m_chart, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, fg);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, fsize);
      ObjectSetString(m_chart, name, OBJPROP_FONT, "Arial");
      ObjectSetString(m_chart, name, OBJPROP_TEXT, text);
      SetCommon(name);
      return true;
   }

   bool EnsureEdit(const string name,int x,int y,int w,int h,const string text,color bg,color fg,int fsize=9)
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
      ObjectSetInteger(m_chart, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, fg);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, fsize);
      ObjectSetString(m_chart, name, OBJPROP_FONT, "Arial");
      ObjectSetString(m_chart, name, OBJPROP_TEXT, text);
      SetCommon(name);
      return true;
   }

   string OnOff(const bool v) const { return (v ? "ON" : "OFF"); }

   // ----- enum label helpers -----
   string ModeName(const ENUM_TA_TRAIL_MODE m) const
   {
      switch(m)
      {
         case TA_TRAIL_NONE:          return "None";
         case TA_TRAIL_PIPS:          return "Pips";
         case TA_TRAIL_FRACTALS:      return "Fractals";
         case TA_TRAIL_MA:            return "Moving Avg";
         case TA_TRAIL_SAR:           return "Parabolic SAR";
         case TA_TRAIL_ATR:           return "ATR";
         case TA_TRAIL_PARTIAL_CLOSE: return "Partial Close";
         case TA_TRAIL_HIGHLOW_BAR:   return "High/Low";
         default:                     return "Unknown";
      }
   }

   ENUM_MA_METHOD NextMAMethod(const ENUM_MA_METHOD cur) const
   {
      const ENUM_MA_METHOD arr[4] = { MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA };
      int idx=0;
      for(int i=0;i<4;i++) if(arr[i]==cur) { idx=i; break; }
      idx = (idx+1) % 4;
      return arr[idx];
   }

   string MAMethodName(const ENUM_MA_METHOD m) const
   {
      switch(m)
      {
         case MODE_SMA:  return "SMA";
         case MODE_EMA:  return "EMA";
         case MODE_SMMA: return "SMMA";
         case MODE_LWMA: return "LWMA";
         default:        return "MA";
      }
   }

   ENUM_APPLIED_PRICE NextAppliedPrice(const ENUM_APPLIED_PRICE cur) const
   {
      const ENUM_APPLIED_PRICE arr[7] =
      { PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED };
      int idx=0;
      for(int i=0;i<7;i++) if(arr[i]==cur) { idx=i; break; }
      idx = (idx+1) % 7;
      return arr[idx];
   }

   string PriceName(const ENUM_APPLIED_PRICE p) const
   {
      switch(p)
      {
         case PRICE_CLOSE:    return "Close";
         case PRICE_OPEN:     return "Open";
         case PRICE_HIGH:     return "High";
         case PRICE_LOW:      return "Low";
         case PRICE_MEDIAN:   return "Median";
         case PRICE_TYPICAL:  return "Typical";
         case PRICE_WEIGHTED: return "Weighted";
         default:             return "Price";
      }
   }

   double ReadDouble(const string obj, const double fallback) const
   {
      if(ObjectFind(m_chart, obj) < 0) return fallback;
      string s = ObjectGetString(m_chart, obj, OBJPROP_TEXT);
      if(s=="") return fallback;
      double v = StringToDouble(s);
      return v;
   }

   int ReadInt(const string obj, const int fallback) const
   {
      if(ObjectFind(m_chart, obj) < 0) return fallback;
      string s = ObjectGetString(m_chart, obj, OBJPROP_TEXT);
      if(s=="") return fallback;
      int v = (int)StringToInteger(s);
      return v;
   }

   void PopupShow(const bool show)
   {
      m_popup = show;
      if(ObjectFind(m_chart, m_popup_bg) >= 0)
         ObjectSetInteger(m_chart, m_popup_bg, OBJPROP_HIDDEN, !show);
      for(int i=0;i<8;i++)
      {
         if(ObjectFind(m_chart, m_mode_opt[i]) >= 0)
            ObjectSetInteger(m_chart, m_mode_opt[i], OBJPROP_HIDDEN, !show);
      }
   }

   void HideAllModeParamWidgets()
   {
      // Hide everything; Layout/SyncFromState will unhide the right group
      const string groups[] =
      {
         m_lbl_pips_dist, m_ed_pips_dist, m_lbl_pips_step, m_ed_pips_step,
         m_lbl_fr_left, m_ed_fr_left, m_lbl_fr_right, m_ed_fr_right, m_lbl_fr_buf, m_ed_fr_buf,
         m_lbl_ma_period, m_ed_ma_period, m_lbl_ma_method, m_btn_ma_method, m_lbl_ma_price, m_btn_ma_price, m_lbl_ma_buf, m_ed_ma_buf,
         m_lbl_sar_step, m_ed_sar_step, m_lbl_sar_max, m_ed_sar_max, m_lbl_sar_buf, m_ed_sar_buf,
         m_lbl_atr_period, m_ed_atr_period, m_lbl_atr_mult, m_ed_atr_mult, m_lbl_atr_buf, m_ed_atr_buf,
         m_lbl_hl_look, m_ed_hl_look, m_lbl_hl_buf, m_ed_hl_buf,
         m_btn_pc_enable, m_lbl_pc_everyr, m_ed_pc_everyr, m_lbl_pc_closepct, m_ed_pc_closepct
      };

      for(int i=0;i<(int)ArraySize(groups);i++)
      {
         if(groups[i]=="" ) continue;
         if(ObjectFind(m_chart, groups[i]) >= 0)
            ObjectSetInteger(m_chart, groups[i], OBJPROP_HIDDEN, true);
      }
   }

   void UnhideParam(const string name)
   {
      if(name=="" ) return;
      if(ObjectFind(m_chart, name) >= 0)
         ObjectSetInteger(m_chart, name, OBJPROP_HIDDEN, false);
   }

   void UpdateModeParamVisibility(const ENUM_TA_TRAIL_MODE mode)
   {
      HideAllModeParamWidgets();

      if(mode == TA_TRAIL_PIPS)
      {
         UnhideParam(m_lbl_pips_dist); UnhideParam(m_ed_pips_dist);
         UnhideParam(m_lbl_pips_step); UnhideParam(m_ed_pips_step);
      }
      else if(mode == TA_TRAIL_FRACTALS)
      {
         UnhideParam(m_lbl_fr_left);  UnhideParam(m_ed_fr_left);
         UnhideParam(m_lbl_fr_right); UnhideParam(m_ed_fr_right);
         UnhideParam(m_lbl_fr_buf);   UnhideParam(m_ed_fr_buf);
      }
      else if(mode == TA_TRAIL_MA)
      {
         UnhideParam(m_lbl_ma_period); UnhideParam(m_ed_ma_period);
         UnhideParam(m_lbl_ma_method); UnhideParam(m_btn_ma_method);
         UnhideParam(m_lbl_ma_price);  UnhideParam(m_btn_ma_price);
         UnhideParam(m_lbl_ma_buf);    UnhideParam(m_ed_ma_buf);
      }
      else if(mode == TA_TRAIL_SAR)
      {
         UnhideParam(m_lbl_sar_step); UnhideParam(m_ed_sar_step);
         UnhideParam(m_lbl_sar_max);  UnhideParam(m_ed_sar_max);
         UnhideParam(m_lbl_sar_buf);  UnhideParam(m_ed_sar_buf);
      }
      else if(mode == TA_TRAIL_ATR)
      {
         UnhideParam(m_lbl_atr_period); UnhideParam(m_ed_atr_period);
         UnhideParam(m_lbl_atr_mult);   UnhideParam(m_ed_atr_mult);
         UnhideParam(m_lbl_atr_buf);    UnhideParam(m_ed_atr_buf);
      }
      else if(mode == TA_TRAIL_HIGHLOW_BAR)
      {
         UnhideParam(m_lbl_hl_look); UnhideParam(m_ed_hl_look);
         UnhideParam(m_lbl_hl_buf);  UnhideParam(m_ed_hl_buf);
      }
      else if(mode == TA_TRAIL_PARTIAL_CLOSE)
      {
         UnhideParam(m_btn_pc_enable);
         UnhideParam(m_lbl_pc_everyr);   UnhideParam(m_ed_pc_everyr);
         UnhideParam(m_lbl_pc_closepct); UnhideParam(m_ed_pc_closepct);
      }
   }

public:
   UI_TrailingTab()
   {
      m_chart   = 0;
      m_prefix  = "TAUI_TRAIL_";
      m_created = false;
      m_visible = true;
      m_x=m_y=0; m_w=m_h=0;
      m_obj_count = 0;
      m_popup = false;
   }

   bool IsCreated() const { return m_created; }

   bool Create(const TA_Context &ctx, const string prefix)
   {
      m_chart = ctx.chart_id;
      m_prefix = prefix;
      m_obj_count = 0;
      m_popup = false;

      m_bg          = m_prefix + "bg";
      m_title       = m_prefix + "title";

      m_btn_enable  = m_prefix + "btn_enable";
      m_btn_profit  = m_prefix + "btn_profit";
      m_lbl_mode    = m_prefix + "lbl_mode";
      m_btn_mode    = m_prefix + "btn_mode";
      m_lbl_minint  = m_prefix + "lbl_minint";
      m_ed_minint   = m_prefix + "ed_minint";

      m_popup_bg    = m_prefix + "popup_bg";
      const string opt_suffix[8] = {"opt_none","opt_pips","opt_fr","opt_ma","opt_sar","opt_atr","opt_pc","opt_hl"};
      for(int i=0;i<8;i++) m_mode_opt[i] = m_prefix + opt_suffix[i];

      m_lbl_pips_dist = m_prefix + "lbl_pips_dist";
      m_ed_pips_dist  = m_prefix + "ed_pips_dist";
      m_lbl_pips_step = m_prefix + "lbl_pips_step";
      m_ed_pips_step  = m_prefix + "ed_pips_step";

      m_lbl_fr_left   = m_prefix + "lbl_fr_left";
      m_ed_fr_left    = m_prefix + "ed_fr_left";
      m_lbl_fr_right  = m_prefix + "lbl_fr_right";
      m_ed_fr_right   = m_prefix + "ed_fr_right";
      m_lbl_fr_buf    = m_prefix + "lbl_fr_buf";
      m_ed_fr_buf     = m_prefix + "ed_fr_buf";

      m_lbl_ma_period = m_prefix + "lbl_ma_period";
      m_ed_ma_period  = m_prefix + "ed_ma_period";
      m_lbl_ma_method = m_prefix + "lbl_ma_method";
      m_btn_ma_method = m_prefix + "btn_ma_method";
      m_lbl_ma_price  = m_prefix + "lbl_ma_price";
      m_btn_ma_price  = m_prefix + "btn_ma_price";
      m_lbl_ma_buf    = m_prefix + "lbl_ma_buf";
      m_ed_ma_buf     = m_prefix + "ed_ma_buf";

      m_lbl_sar_step  = m_prefix + "lbl_sar_step";
      m_ed_sar_step   = m_prefix + "ed_sar_step";
      m_lbl_sar_max   = m_prefix + "lbl_sar_max";
      m_ed_sar_max    = m_prefix + "ed_sar_max";
      m_lbl_sar_buf   = m_prefix + "lbl_sar_buf";
      m_ed_sar_buf    = m_prefix + "ed_sar_buf";

      m_lbl_atr_period = m_prefix + "lbl_atr_period";
      m_ed_atr_period  = m_prefix + "ed_atr_period";
      m_lbl_atr_mult   = m_prefix + "lbl_atr_mult";
      m_ed_atr_mult    = m_prefix + "ed_atr_mult";
      m_lbl_atr_buf    = m_prefix + "lbl_atr_buf";
      m_ed_atr_buf     = m_prefix + "ed_atr_buf";

      m_lbl_hl_look  = m_prefix + "lbl_hl_look";
      m_ed_hl_look   = m_prefix + "ed_hl_look";
      m_lbl_hl_buf   = m_prefix + "lbl_hl_buf";
      m_ed_hl_buf    = m_prefix + "ed_hl_buf";

      m_btn_pc_enable  = m_prefix + "btn_pc_enable";
      m_lbl_pc_everyr  = m_prefix + "lbl_pc_everyr";
      m_ed_pc_everyr   = m_prefix + "ed_pc_everyr";
      m_lbl_pc_closepct= m_prefix + "lbl_pc_closepct";
      m_ed_pc_closepct = m_prefix + "ed_pc_closepct";

      // Create minimal objects now (layout later)
      if(!EnsureRectLabel(m_bg, 0,0,10,10, clrBlack, clrDimGray)) return false;
      EnsureLabel(m_title, 0,0,10,10, "Trailing", clrWhite, 10);

      EnsureButton(m_btn_enable, 0,0,10,18, "Trailing: OFF", clrDimGray, clrWhite, 9);
      EnsureButton(m_btn_profit, 0,0,10,18, "Only profit: OFF", clrDimGray, clrWhite, 9);

      EnsureLabel(m_lbl_mode, 0,0,10,10, "Mode:", clrSilver, 9);
      EnsureButton(m_btn_mode, 0,0,10,18, "None ▼", clrDarkSlateGray, clrWhite, 9);

      EnsureLabel(m_lbl_minint, 0,0,10,10, "Min interval (ms):", clrSilver, 9);
      EnsureEdit(m_ed_minint, 0,0,10,18, "0", clrWhite, clrBlack, 9);

      // Popup objects (hidden by default)
      EnsureRectLabel(m_popup_bg, 0,0,10,10, clrBlack, clrDimGray);
      for(int i=0;i<8;i++)
         EnsureButton(m_mode_opt[i], 0,0,10,18, "opt", clrBlack, clrWhite, 9);

      // Params (create now; hidden by default)
      EnsureLabel(m_lbl_pips_dist,0,0,10,10,"Distance (pips):",clrSilver,9);
      EnsureEdit(m_ed_pips_dist,0,0,10,18,"0",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_pips_step,0,0,10,10,"Step (pips):",clrSilver,9);
      EnsureEdit(m_ed_pips_step,0,0,10,18,"0",clrWhite,clrBlack,9);

      EnsureLabel(m_lbl_fr_left,0,0,10,10,"Left bars:",clrSilver,9);
      EnsureEdit(m_ed_fr_left,0,0,10,18,"2",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_fr_right,0,0,10,10,"Right bars:",clrSilver,9);
      EnsureEdit(m_ed_fr_right,0,0,10,18,"2",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_fr_buf,0,0,10,10,"Buffer (pips):",clrSilver,9);
      EnsureEdit(m_ed_fr_buf,0,0,10,18,"0",clrWhite,clrBlack,9);

      EnsureLabel(m_lbl_ma_period,0,0,10,10,"MA period:",clrSilver,9);
      EnsureEdit(m_ed_ma_period,0,0,10,18,"20",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_ma_method,0,0,10,10,"MA method:",clrSilver,9);
      EnsureButton(m_btn_ma_method,0,0,10,18,"SMA",clrDarkSlateGray,clrWhite,9);
      EnsureLabel(m_lbl_ma_price,0,0,10,10,"Applied price:",clrSilver,9);
      EnsureButton(m_btn_ma_price,0,0,10,18,"Close",clrDarkSlateGray,clrWhite,9);
      EnsureLabel(m_lbl_ma_buf,0,0,10,10,"Buffer (pips):",clrSilver,9);
      EnsureEdit(m_ed_ma_buf,0,0,10,18,"0",clrWhite,clrBlack,9);

      EnsureLabel(m_lbl_sar_step,0,0,10,10,"SAR step:",clrSilver,9);
      EnsureEdit(m_ed_sar_step,0,0,10,18,"0.02",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_sar_max,0,0,10,10,"SAR max:",clrSilver,9);
      EnsureEdit(m_ed_sar_max,0,0,10,18,"0.2",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_sar_buf,0,0,10,10,"Buffer (pips):",clrSilver,9);
      EnsureEdit(m_ed_sar_buf,0,0,10,18,"0",clrWhite,clrBlack,9);

      EnsureLabel(m_lbl_atr_period,0,0,10,10,"ATR period:",clrSilver,9);
      EnsureEdit(m_ed_atr_period,0,0,10,18,"14",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_atr_mult,0,0,10,10,"Multiplier:",clrSilver,9);
      EnsureEdit(m_ed_atr_mult,0,0,10,18,"2.0",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_atr_buf,0,0,10,10,"Buffer (pips):",clrSilver,9);
      EnsureEdit(m_ed_atr_buf,0,0,10,18,"0",clrWhite,clrBlack,9);

      EnsureLabel(m_lbl_hl_look,0,0,10,10,"Lookback bars:",clrSilver,9);
      EnsureEdit(m_ed_hl_look,0,0,10,18,"20",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_hl_buf,0,0,10,10,"Buffer (pips):",clrSilver,9);
      EnsureEdit(m_ed_hl_buf,0,0,10,18,"0",clrWhite,clrBlack,9);

      EnsureButton(m_btn_pc_enable,0,0,10,18,"Partial trail: OFF",clrDimGray,clrWhite,9);
      EnsureLabel(m_lbl_pc_everyr,0,0,10,10,"Every R:",clrSilver,9);
      EnsureEdit(m_ed_pc_everyr,0,0,10,18,"1.0",clrWhite,clrBlack,9);
      EnsureLabel(m_lbl_pc_closepct,0,0,10,10,"Close %:",clrSilver,9);
      EnsureEdit(m_ed_pc_closepct,0,0,10,18,"25",clrWhite,clrBlack,9);

      // Hide popup + params by default
      PopupShow(false);
      HideAllModeParamWidgets();

      m_created = true;
      m_visible = true;
      return true;
   }

   void Destroy()
   {
      if(!m_created) return;

      for(int i=0;i<m_obj_count;i++)
      {
         string n = m_objs[i];
         if(ObjectFind(m_chart, n) >= 0)
            ObjectDelete(m_chart, n);
      }

      m_obj_count = 0;
      m_created = false;
      m_popup = false;
   }

   void SetVisible(const bool v)
   {
      m_visible = v;
      SetHiddenAll(!v);

      // if we hide the tab, also hide popup
      if(!v) PopupShow(false);
   }

   // Called by UI_App whenever the tab area changes
   void Layout(const TA_Context &ctx, const TA_State &st, const int x, const int y, const int w, const int h)
   {
      if(!m_created) return;

      m_x=x; m_y=y; m_w=w; m_h=h;

      const int pad = 8;
      const int rowh = 18;
      const int edh = 18;
      const int btnh = 18;
      const int gap = 6;

      int cx = x + pad;
      int cy = y + pad;
      int cw = w - pad*2;

      EnsureRectLabel(m_bg, x, y, w, h, clrBlack, clrDimGray);

      EnsureLabel(m_title, cx, cy, cw, rowh, "Trailing", clrWhite, 10);
      cy += rowh + gap;

      int half = (cw - gap)/2;
      EnsureButton(m_btn_enable, cx, cy, half, btnh, "Trailing: " + OnOff(st.trailing_enabled), clrDarkSlateGray, clrWhite, 9);
      EnsureButton(m_btn_profit, cx + half + gap, cy, half, btnh, "Only profit: " + OnOff(st.trailing_only_profit), clrDarkSlateGray, clrWhite, 9);
      cy += btnh + gap;

      // Mode row
      EnsureLabel(m_lbl_mode, cx, cy+2, 50, rowh, "Mode:", clrSilver, 9);
      EnsureButton(m_btn_mode, cx+55, cy, cw-55, btnh, ModeName(st.trailing_mode) + " ▼", clrDarkSlateGray, clrWhite, 9);
      cy += btnh + gap;

      // Min interval
      EnsureLabel(m_lbl_minint, cx, cy+2, 130, rowh, "Min interval (ms):", clrSilver, 9);
      EnsureEdit(m_ed_minint, cx+135, cy, 70, edh, IntegerToString(st.trailing_min_interval_ms), clrWhite, clrBlack, 9);
      cy += edh + gap;

      // Popup dropdown below mode button
      int px = cx+55;
      int py = (y + pad + rowh + gap) + (btnh + gap); // roughly under mode row
      // Actually place it under the mode button row (cx+55, cy after mode row)
      py = y + pad + rowh + gap + btnh + gap; // after enable row
      py = py + btnh + gap; // after mode row start, so popup starts below mode row
      int pw = cw-55;
      int ph = (btnh)*8 + 4;
      EnsureRectLabel(m_popup_bg, px, py, pw, ph, clrBlack, clrDimGray);

      const ENUM_TA_TRAIL_MODE modes[8] =
      { TA_TRAIL_NONE, TA_TRAIL_PIPS, TA_TRAIL_FRACTALS, TA_TRAIL_MA, TA_TRAIL_SAR, TA_TRAIL_ATR, TA_TRAIL_PARTIAL_CLOSE, TA_TRAIL_HIGHLOW_BAR };

      for(int i=0;i<8;i++)
      {
         int oy = py + 2 + i*btnh;
         EnsureButton(m_mode_opt[i], px+2, oy, pw-4, btnh, ModeName(modes[i]), clrBlack, clrWhite, 9);
      }

      // Params start below min interval
      int py0 = cy;

      // Shared two-column for most params
      int leftw = 140;
      int edw   = 70;

      // Pips (2 rows)
      EnsureLabel(m_lbl_pips_dist, cx, py0+2, leftw, rowh, "Distance (pips):", clrSilver, 9);
      EnsureEdit(m_ed_pips_dist,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_pips_distance,1), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_pips_step, cx, py0+2, leftw, rowh, "Step (pips):", clrSilver, 9);
      EnsureEdit(m_ed_pips_step,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_pips_step,1), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      // Fractals (3 rows)
      EnsureLabel(m_lbl_fr_left, cx, py0+2, leftw, rowh, "Left bars:", clrSilver, 9);
      EnsureEdit(m_ed_fr_left,  cx+leftw, py0, edw, edh, IntegerToString(st.trail_fractal_left), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_fr_right, cx, py0+2, leftw, rowh, "Right bars:", clrSilver, 9);
      EnsureEdit(m_ed_fr_right,  cx+leftw, py0, edw, edh, IntegerToString(st.trail_fractal_right), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_fr_buf, cx, py0+2, leftw, rowh, "Buffer (pips):", clrSilver, 9);
      EnsureEdit(m_ed_fr_buf,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_fractal_buffer_pips,1), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      // MA (4 rows)
      EnsureLabel(m_lbl_ma_period, cx, py0+2, leftw, rowh, "MA period:", clrSilver, 9);
      EnsureEdit(m_ed_ma_period,  cx+leftw, py0, edw, edh, IntegerToString(st.trail_ma_period), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_ma_method, cx, py0+2, leftw, rowh, "MA method:", clrSilver, 9);
      EnsureButton(m_btn_ma_method, cx+leftw, py0, edw, btnh, MAMethodName(st.trail_ma_method), clrDarkSlateGray, clrWhite, 9);
      py0 += btnh + gap;

      EnsureLabel(m_lbl_ma_price, cx, py0+2, leftw, rowh, "Applied price:", clrSilver, 9);
      EnsureButton(m_btn_ma_price, cx+leftw, py0, edw, btnh, PriceName(st.trail_ma_price), clrDarkSlateGray, clrWhite, 9);
      py0 += btnh + gap;

      EnsureLabel(m_lbl_ma_buf, cx, py0+2, leftw, rowh, "Buffer (pips):", clrSilver, 9);
      EnsureEdit(m_ed_ma_buf,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_ma_buffer_pips,1), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      // SAR (3 rows)
      EnsureLabel(m_lbl_sar_step, cx, py0+2, leftw, rowh, "SAR step:", clrSilver, 9);
      EnsureEdit(m_ed_sar_step,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_sar_step,2), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_sar_max, cx, py0+2, leftw, rowh, "SAR max:", clrSilver, 9);
      EnsureEdit(m_ed_sar_max,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_sar_max,2), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_sar_buf, cx, py0+2, leftw, rowh, "Buffer (pips):", clrSilver, 9);
      EnsureEdit(m_ed_sar_buf,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_sar_buffer_pips,1), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      // ATR (3 rows)
      EnsureLabel(m_lbl_atr_period, cx, py0+2, leftw, rowh, "ATR period:", clrSilver, 9);
      EnsureEdit(m_ed_atr_period,  cx+leftw, py0, edw, edh, IntegerToString(st.trail_atr_period), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_atr_mult, cx, py0+2, leftw, rowh, "Multiplier:", clrSilver, 9);
      EnsureEdit(m_ed_atr_mult,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_atr_mult,2), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_atr_buf, cx, py0+2, leftw, rowh, "Buffer (pips):", clrSilver, 9);
      EnsureEdit(m_ed_atr_buf,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_atr_buffer_pips,1), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      // High/Low (2 rows)
      EnsureLabel(m_lbl_hl_look, cx, py0+2, leftw, rowh, "Lookback bars:", clrSilver, 9);
      EnsureEdit(m_ed_hl_look,  cx+leftw, py0, edw, edh, IntegerToString(st.trail_highlow_lookback), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_hl_buf, cx, py0+2, leftw, rowh, "Buffer (pips):", clrSilver, 9);
      EnsureEdit(m_ed_hl_buf,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_highlow_buffer_pips,1), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      // Partial-close trailing (3 rows inc toggle)
      EnsureButton(m_btn_pc_enable, cx, py0, cw, btnh, "Partial trail: " + OnOff(st.trail_partial_enable), clrDarkSlateGray, clrWhite, 9);
      py0 += btnh + gap;

      EnsureLabel(m_lbl_pc_everyr, cx, py0+2, leftw, rowh, "Every R:", clrSilver, 9);
      EnsureEdit(m_ed_pc_everyr,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_partial_every_r,2), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      EnsureLabel(m_lbl_pc_closepct, cx, py0+2, leftw, rowh, "Close %:", clrSilver, 9);
      EnsureEdit(m_ed_pc_closepct,  cx+leftw, py0, edw, edh, DoubleToString(st.trail_partial_close_pct,1), clrWhite, clrBlack, 9);
      py0 += edh + gap;

      // Now hide/show the correct group
      UpdateModeParamVisibility(st.trailing_mode);

      // Popup must reflect current m_popup
      PopupShow(m_popup && m_visible);

      // Respect overall visibility
      SetHiddenAll(!m_visible);
   }

   void SyncFromState(const TA_Context &ctx, const TA_State &st)
   {
      if(!m_created) return;

      if(ObjectFind(m_chart, m_btn_enable) >= 0)
         ObjectSetString(m_chart, m_btn_enable, OBJPROP_TEXT, "Trailing: " + OnOff(st.trailing_enabled));
      if(ObjectFind(m_chart, m_btn_profit) >= 0)
         ObjectSetString(m_chart, m_btn_profit, OBJPROP_TEXT, "Only profit: " + OnOff(st.trailing_only_profit));

      if(ObjectFind(m_chart, m_btn_mode) >= 0)
         ObjectSetString(m_chart, m_btn_mode, OBJPROP_TEXT, ModeName(st.trailing_mode) + " ▼");

      if(ObjectFind(m_chart, m_ed_minint) >= 0)
         ObjectSetString(m_chart, m_ed_minint, OBJPROP_TEXT, IntegerToString(st.trailing_min_interval_ms));

      // Mode params
      if(ObjectFind(m_chart, m_ed_pips_dist) >= 0) ObjectSetString(m_chart, m_ed_pips_dist, OBJPROP_TEXT, DoubleToString(st.trail_pips_distance,1));
      if(ObjectFind(m_chart, m_ed_pips_step) >= 0) ObjectSetString(m_chart, m_ed_pips_step, OBJPROP_TEXT, DoubleToString(st.trail_pips_step,1));

      if(ObjectFind(m_chart, m_ed_fr_left)  >= 0) ObjectSetString(m_chart, m_ed_fr_left,  OBJPROP_TEXT, IntegerToString(st.trail_fractal_left));
      if(ObjectFind(m_chart, m_ed_fr_right) >= 0) ObjectSetString(m_chart, m_ed_fr_right, OBJPROP_TEXT, IntegerToString(st.trail_fractal_right));
      if(ObjectFind(m_chart, m_ed_fr_buf)   >= 0) ObjectSetString(m_chart, m_ed_fr_buf,   OBJPROP_TEXT, DoubleToString(st.trail_fractal_buffer_pips,1));

      if(ObjectFind(m_chart, m_ed_ma_period) >= 0) ObjectSetString(m_chart, m_ed_ma_period, OBJPROP_TEXT, IntegerToString(st.trail_ma_period));
      if(ObjectFind(m_chart, m_btn_ma_method)>= 0) ObjectSetString(m_chart, m_btn_ma_method,OBJPROP_TEXT, MAMethodName(st.trail_ma_method));
      if(ObjectFind(m_chart, m_btn_ma_price) >= 0) ObjectSetString(m_chart, m_btn_ma_price, OBJPROP_TEXT, PriceName(st.trail_ma_price));
      if(ObjectFind(m_chart, m_ed_ma_buf)    >= 0) ObjectSetString(m_chart, m_ed_ma_buf,    OBJPROP_TEXT, DoubleToString(st.trail_ma_buffer_pips,1));

      if(ObjectFind(m_chart, m_ed_sar_step) >= 0) ObjectSetString(m_chart, m_ed_sar_step, OBJPROP_TEXT, DoubleToString(st.trail_sar_step,2));
      if(ObjectFind(m_chart, m_ed_sar_max)  >= 0) ObjectSetString(m_chart, m_ed_sar_max,  OBJPROP_TEXT, DoubleToString(st.trail_sar_max,2));
      if(ObjectFind(m_chart, m_ed_sar_buf)  >= 0) ObjectSetString(m_chart, m_ed_sar_buf,  OBJPROP_TEXT, DoubleToString(st.trail_sar_buffer_pips,1));

      if(ObjectFind(m_chart, m_ed_atr_period) >= 0) ObjectSetString(m_chart, m_ed_atr_period, OBJPROP_TEXT, IntegerToString(st.trail_atr_period));
      if(ObjectFind(m_chart, m_ed_atr_mult)   >= 0) ObjectSetString(m_chart, m_ed_atr_mult,   OBJPROP_TEXT, DoubleToString(st.trail_atr_mult,2));
      if(ObjectFind(m_chart, m_ed_atr_buf)    >= 0) ObjectSetString(m_chart, m_ed_atr_buf,    OBJPROP_TEXT, DoubleToString(st.trail_atr_buffer_pips,1));

      if(ObjectFind(m_chart, m_ed_hl_look) >= 0) ObjectSetString(m_chart, m_ed_hl_look, OBJPROP_TEXT, IntegerToString(st.trail_highlow_lookback));
      if(ObjectFind(m_chart, m_ed_hl_buf)  >= 0) ObjectSetString(m_chart, m_ed_hl_buf,  OBJPROP_TEXT, DoubleToString(st.trail_highlow_buffer_pips,1));

      if(ObjectFind(m_chart, m_btn_pc_enable) >= 0) ObjectSetString(m_chart, m_btn_pc_enable, OBJPROP_TEXT, "Partial trail: " + OnOff(st.trail_partial_enable));
      if(ObjectFind(m_chart, m_ed_pc_everyr)  >= 0) ObjectSetString(m_chart, m_ed_pc_everyr,  OBJPROP_TEXT, DoubleToString(st.trail_partial_every_r,2));
      if(ObjectFind(m_chart, m_ed_pc_closepct)>= 0) ObjectSetString(m_chart, m_ed_pc_closepct,OBJPROP_TEXT, DoubleToString(st.trail_partial_close_pct,1));

      UpdateModeParamVisibility(st.trailing_mode);
   }

   void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      if(!m_created || !m_visible) return;

      // Keep mode label consistent
      if(ObjectFind(m_chart, m_btn_mode) >= 0)
      {
         string want = ModeName(st.trailing_mode) + " ▼";
         string cur  = ObjectGetString(m_chart, m_btn_mode, OBJPROP_TEXT);
         if(cur != want) ObjectSetString(m_chart, m_btn_mode, OBJPROP_TEXT, want);
      }

      // If popup is open, keep it open; otherwise make sure it's hidden
      PopupShow(m_popup);
      UpdateModeParamVisibility(st.trailing_mode);
   }

   void OnChartEvent(const TA_Context &ctx, TA_State &st,
                     const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(!m_created || !m_visible) return;

      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         // Toggle buttons
         if(sparam == m_btn_enable)
         {
            st.trailing_enabled = !st.trailing_enabled;
            SyncFromState(ctx, st);
            return;
         }
         if(sparam == m_btn_profit)
         {
            st.trailing_only_profit = !st.trailing_only_profit;
            SyncFromState(ctx, st);
            return;
         }

         // Dropdown open/close
         if(sparam == m_btn_mode)
         {
            m_popup = !m_popup;
            PopupShow(m_popup);
            return;
         }

         // Mode selection options
         const ENUM_TA_TRAIL_MODE modes[8] =
         { TA_TRAIL_NONE, TA_TRAIL_PIPS, TA_TRAIL_FRACTALS, TA_TRAIL_MA, TA_TRAIL_SAR, TA_TRAIL_ATR, TA_TRAIL_PARTIAL_CLOSE, TA_TRAIL_HIGHLOW_BAR };

         for(int i=0;i<8;i++)
         {
            if(sparam == m_mode_opt[i])
            {
               m_popup = false;
               PopupShow(false);

               st.trailing_mode = modes[i];
               TA_OnUI_SetTrailingMode(st.trailing_mode); // also syncs trailing wrapper
               SyncFromState(ctx, st);
               return;
            }
         }

         // MA method / price cycles
         if(sparam == m_btn_ma_method)
         {
            st.trail_ma_method = NextMAMethod(st.trail_ma_method);
            SyncFromState(ctx, st);
            return;
         }
         if(sparam == m_btn_ma_price)
         {
            st.trail_ma_price = NextAppliedPrice(st.trail_ma_price);
            SyncFromState(ctx, st);
            return;
         }

         // Partial-close trailing toggle
         if(sparam == m_btn_pc_enable)
         {
            st.trail_partial_enable = !st.trail_partial_enable;
            SyncFromState(ctx, st);
            return;
         }

         // Click outside popup should close it (simple heuristic: any click on our tab bg/title closes)
         if(m_popup && (sparam == m_bg || sparam == m_title))
         {
            m_popup = false;
            PopupShow(false);
            return;
         }
      }

      if(id == CHARTEVENT_OBJECT_ENDEDIT)
      {
         // Common
         if(sparam == m_ed_minint)
         {
            int v = ReadInt(m_ed_minint, st.trailing_min_interval_ms);
            if(v < 0) v = 0;
            st.trailing_min_interval_ms = v;
            SyncFromState(ctx, st);
            return;
         }

         // Pips
         if(sparam == m_ed_pips_dist)
         {
            double v = ReadDouble(m_ed_pips_dist, st.trail_pips_distance);
            if(v < 0) v = 0;
            st.trail_pips_distance = v;
            return;
         }
         if(sparam == m_ed_pips_step)
         {
            double v = ReadDouble(m_ed_pips_step, st.trail_pips_step);
            if(v < 0) v = 0;
            st.trail_pips_step = v;
            return;
         }

         // Fractals
         if(sparam == m_ed_fr_left)
         {
            int v = ReadInt(m_ed_fr_left, st.trail_fractal_left);
            if(v < 1) v = 1;
            st.trail_fractal_left = v;
            return;
         }
         if(sparam == m_ed_fr_right)
         {
            int v = ReadInt(m_ed_fr_right, st.trail_fractal_right);
            if(v < 1) v = 1;
            st.trail_fractal_right = v;
            return;
         }
         if(sparam == m_ed_fr_buf)
         {
            double v = ReadDouble(m_ed_fr_buf, st.trail_fractal_buffer_pips);
            if(v < 0) v = 0;
            st.trail_fractal_buffer_pips = v;
            return;
         }

         // MA
         if(sparam == m_ed_ma_period)
         {
            int v = ReadInt(m_ed_ma_period, st.trail_ma_period);
            if(v < 1) v = 1;
            st.trail_ma_period = v;
            return;
         }
         if(sparam == m_ed_ma_buf)
         {
            double v = ReadDouble(m_ed_ma_buf, st.trail_ma_buffer_pips);
            if(v < 0) v = 0;
            st.trail_ma_buffer_pips = v;
            return;
         }

         // SAR
         if(sparam == m_ed_sar_step)
         {
            double v = ReadDouble(m_ed_sar_step, st.trail_sar_step);
            if(v < 0) v = 0;
            st.trail_sar_step = v;
            return;
         }
         if(sparam == m_ed_sar_max)
         {
            double v = ReadDouble(m_ed_sar_max, st.trail_sar_max);
            if(v < 0) v = 0;
            st.trail_sar_max = v;
            return;
         }
         if(sparam == m_ed_sar_buf)
         {
            double v = ReadDouble(m_ed_sar_buf, st.trail_sar_buffer_pips);
            if(v < 0) v = 0;
            st.trail_sar_buffer_pips = v;
            return;
         }

         // ATR
         if(sparam == m_ed_atr_period)
         {
            int v = ReadInt(m_ed_atr_period, st.trail_atr_period);
            if(v < 1) v = 1;
            st.trail_atr_period = v;
            return;
         }
         if(sparam == m_ed_atr_mult)
         {
            double v = ReadDouble(m_ed_atr_mult, st.trail_atr_mult);
            if(v < 0) v = 0;
            st.trail_atr_mult = v;
            return;
         }
         if(sparam == m_ed_atr_buf)
         {
            double v = ReadDouble(m_ed_atr_buf, st.trail_atr_buffer_pips);
            if(v < 0) v = 0;
            st.trail_atr_buffer_pips = v;
            return;
         }

         // High/Low
         if(sparam == m_ed_hl_look)
         {
            int v = ReadInt(m_ed_hl_look, st.trail_highlow_lookback);
            if(v < 1) v = 1;
            st.trail_highlow_lookback = v;
            return;
         }
         if(sparam == m_ed_hl_buf)
         {
            double v = ReadDouble(m_ed_hl_buf, st.trail_highlow_buffer_pips);
            if(v < 0) v = 0;
            st.trail_highlow_buffer_pips = v;
            return;
         }

         // Partial-close trailing params
         if(sparam == m_ed_pc_everyr)
         {
            double v = ReadDouble(m_ed_pc_everyr, st.trail_partial_every_r);
            if(v < 0.01) v = 0.01;
            st.trail_partial_every_r = v;
            return;
         }
         if(sparam == m_ed_pc_closepct)
         {
            double v = ReadDouble(m_ed_pc_closepct, st.trail_partial_close_pct);
            if(v < 0) v = 0;
            if(v > 100) v = 100;
            st.trail_partial_close_pct = v;
            return;
         }
      }
   }
};

#endif // __MUSERA_UI_TRAILINGTAB_MQH__
//+------------------------------------------------------------------+

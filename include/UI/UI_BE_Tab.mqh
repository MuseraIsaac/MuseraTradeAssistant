//+------------------------------------------------------------------+
//|                                                UI_BE_Tab.mqh      |
//|                         MuseraTradeAssistant (project shell)      |
//|                                  (c) 2026, Musera Isaac          |
//|  Break-Even settings tab UI.                                      |
//|                                                                  |
//|  NOTE: This file is part of a multi-file project. It depends on   |
//|  other project includes under:                                    |
//|   MQL5\Experts\MuseraTradeAssistant\include\...                    |
//|  It is expected NOT to compile until those includes are present.  |
//+------------------------------------------------------------------+
#property strict
#ifndef __MUSERA_UI_BE_TAB_MQH__
#define __MUSERA_UI_BE_TAB_MQH__

// --- project types/state (expected to exist in your project) ---
#include "../TA_Types.mqh"
#include "../TA_State.mqh"
#include "../TA_Enums.mqh"
#include "UI_Theme.mqh"

// Callback implemented in MuseraTradeAssistant.mq5 (see your project shell)

//+------------------------------------------------------------------+
//| UI_BE_Tab                                                         |
//+------------------------------------------------------------------+
class UI_BE_Tab
{
private:
   long   m_chart;
   string m_prefix;
   bool   m_visible;

   int    m_x, m_y, m_w, m_h;

   string m_objs[]; // created objects for easy cleanup

   // Object names
   string m_bg;
   string m_title;

   string m_btn_enable;
   string m_btn_mode;

   string m_lbl_trigger;
   string m_ed_trigger;

   string m_lbl_plus;
   string m_ed_plus;

   string m_btn_once;
   string m_btn_after_tp1_be;

   string m_help;

private:
   // ----- housekeeping -----
   string Name(const string id) const { return m_prefix + id; }

   bool ObjExists(const string name) const
   {
      return (ObjectFind(m_chart, name) >= 0);
   }

   void AddObj(const string name)
   {
      int n = ArraySize(m_objs);
      ArrayResize(m_objs, n + 1);
      m_objs[n] = name;
   }

   void SetCommon(const string name)
   {
      // Keep UI in front (EA also sets CHART_FOREGROUND=false)
      ObjectSetInteger(m_chart, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chart, name, OBJPROP_HIDDEN, !m_visible);
      ObjectSetInteger(m_chart, name, OBJPROP_ZORDER, 0);
   }

   // ----- creation helpers -----
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

   bool EnsureLabel(const string name,int x,int y,int w,int h,const string text,color c,int fsize=9,ENUM_ALIGN_MODE align=ALIGN_LEFT)
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
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, c);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, fsize);
      ObjectSetInteger(m_chart, name, OBJPROP_ALIGN, align);
      ObjectSetString(m_chart, name, OBJPROP_FONT, "Arial");
      ObjectSetString(m_chart, name, OBJPROP_TEXT, text);
      SetCommon(name);
      return true;
   }

   bool EnsureButton(const string name,int x,int y,int w,int h,const string text,color bg,color border,color fg,int fsize=9)
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
      ObjectSetInteger(m_chart, name, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, fg);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, fsize);
      ObjectSetString(m_chart, name, OBJPROP_FONT, "Arial");
      ObjectSetString(m_chart, name, OBJPROP_TEXT, text);

      SetCommon(name);
      return true;
   }

   bool EnsureEdit(const string name,int x,int y,int w,int h,const string text,color bg,color border,color fg,int fsize=9)
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
      ObjectSetInteger(m_chart, name, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, fg);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, fsize);
      ObjectSetString(m_chart, name, OBJPROP_FONT, "Arial");
      ObjectSetString(m_chart, name, OBJPROP_TEXT, text);

      SetCommon(name);
      return true;
   }

   string OnOff(const bool v) const { return (v ? "ON" : "OFF"); }
   string YesNo(const bool v) const { return (v ? "YES" : "NO"); }

   string ModeName(const ENUM_TA_BE_MODE m) const
   {
      switch(m)
      {
         case TA_BE_AT_R:      return "R";
         case TA_BE_AT_POINTS: return "Points";
         default:              return "Points";
      }
   }

   ENUM_TA_BE_MODE NextMode(const ENUM_TA_BE_MODE m) const
   {
      if(m == TA_BE_AT_R)      return TA_BE_AT_POINTS;
      if(m == TA_BE_AT_POINTS) return TA_BE_AT_R;
      return TA_BE_AT_POINTS;
   }

   double ParseD(const string s, const double def) const
   {
      string t = s;
      StringTrimLeft(t); StringTrimRight(t);
      if(t=="") return def;
      return StringToDouble(t);
   }

public:
   UI_BE_Tab():m_chart(0),m_prefix(""),m_visible(false),m_x(0),m_y(0),m_w(0),m_h(0) {}

   bool Create(const TA_Context &ctx,const string &prefix)
   {
      m_chart  = (long)ctx.chart_id;
      m_prefix = prefix + "be_";
      m_visible = false;

      m_bg              = Name("bg");
      m_title           = Name("title");

      m_btn_enable      = Name("btn_enable");
      m_btn_mode        = Name("btn_mode");

      m_lbl_trigger     = Name("lbl_trigger");
      m_ed_trigger      = Name("ed_trigger");

      m_lbl_plus        = Name("lbl_plus");
      m_ed_plus         = Name("ed_plus");

      m_btn_once        = Name("btn_once");
      m_btn_after_tp1_be= Name("btn_after_tp1_be");

      m_help            = Name("help");

      // Create minimal objects now; positions set later in Layout()
      // Use neutral colors; UI_Theme may later override.
      if(!EnsureRectLabel(m_bg, 0, 0, 10, 10, clrBlack, clrDimGray)) return false;
      if(!EnsureLabel(m_title, 0, 0, 10, 10, "Break-Even", clrWhite, 10)) return false;

      if(!EnsureButton(m_btn_enable, 0, 0, 10, 10, "BE: OFF", clrDimGray, clrGray, clrWhite, 9)) return false;
      if(!EnsureButton(m_btn_mode,   0, 0, 10, 10, "Mode: Points", clrDimGray, clrGray, clrWhite, 9)) return false;

      if(!EnsureLabel(m_lbl_trigger, 0, 0, 10, 10, "Trigger:", clrWhite, 9)) return false;
      if(!EnsureEdit (m_ed_trigger,  0, 0, 10, 10, "0", clrWhite, clrGray, clrBlack, 9)) return false;

      if(!EnsureLabel(m_lbl_plus,    0, 0, 10, 10, "Plus (pts):", clrWhite, 9)) return false;
      if(!EnsureEdit (m_ed_plus,     0, 0, 10, 10, "0", clrWhite, clrGray, clrBlack, 9)) return false;

      if(!EnsureButton(m_btn_once,   0, 0, 10, 10, "Once: YES", clrDimGray, clrGray, clrWhite, 9)) return false;

      // Optional synergy toggle (exists in TA_State)
      if(!EnsureButton(m_btn_after_tp1_be, 0, 0, 10, 10, "After TP1 -> Move SL to BE: OFF", clrDimGray, clrGray, clrWhite, 8)) return false;

      if(!EnsureLabel(m_help, 0, 0, 10, 10,
         "Tip: Trigger can be in R or points (depends on Mode). 'Plus' adds extra points beyond BE.",
         clrSilver, 8)) return false;

      return true;
   }

   void Destroy()
   {
      for(int i=ArraySize(m_objs)-1; i>=0; --i)
      {
         ObjectDelete(m_chart, m_objs[i]);
      }
      ArrayResize(m_objs, 0);
   }

   void Layout(const TA_Context &ctx,const TA_State &st,int x,int y,int w,int h)
   {
      m_x=x; m_y=y; m_w=w; m_h=h;

      const int pad = 10;
      const int row_h = 22;
      const int btn_h = 20;
      const int label_w = 140;
      const int edit_w  = 90;

      int cx = x + pad;
      int cy = y + pad;

      EnsureRectLabel(m_bg, x, y, w, h, clrBlack, clrDimGray);
      EnsureLabel(m_title,  cx, cy, w - 2*pad, row_h, "Break-Even", clrWhite, 10);

      cy += row_h + 6;
      EnsureButton(m_btn_enable, cx, cy, 100, btn_h,
                   "BE: " + OnOff(st.be_enabled),
                   (st.be_enabled?clrSeaGreen:clrDimGray), clrGray, clrWhite, 9);

      EnsureButton(m_btn_mode, cx + 110, cy, 140, btn_h,
                   "Mode: " + ModeName(st.be_mode),
                   clrDimGray, clrGray, clrWhite, 9);

      cy += btn_h + 10;

      // Trigger row
      string trig_lbl = (st.be_mode==TA_BE_AT_R ? "Trigger (R):" : "Trigger (pts):");
      EnsureLabel(m_lbl_trigger, cx, cy+2, label_w, row_h, trig_lbl, clrWhite, 9);

      string trig_val = (st.be_mode==TA_BE_AT_R ? DoubleToString(st.be_at_r, 2) : DoubleToString(st.be_at_points, 0));
      EnsureEdit(m_ed_trigger,  cx + label_w, cy, edit_w, btn_h, trig_val, clrWhite, clrGray, clrBlack, 9);

      cy += btn_h + 8;

      // Plus row
      EnsureLabel(m_lbl_plus, cx, cy+2, label_w, row_h, "Plus (pts):", clrWhite, 9);
      EnsureEdit(m_ed_plus,  cx + label_w, cy, edit_w, btn_h, DoubleToString(st.be_plus_points, 0), clrWhite, clrGray, clrBlack, 9);

      cy += btn_h + 10;

      EnsureButton(m_btn_once, cx, cy, 120, btn_h,
                   "Once: " + YesNo(st.be_once),
                   clrDimGray, clrGray, clrWhite, 9);

      cy += btn_h + 10;

      EnsureButton(m_btn_after_tp1_be, cx, cy, w - 2*pad, btn_h,
                   "After TP1 -> Move SL to BE: " + OnOff(st.tp_move_sl_to_be_after_tp1),
                   clrDimGray, clrGray, clrWhite, 8);

      cy += btn_h + 10;

      // Help (wrap manually by limiting width, label itself doesn't wrap; keep it short)
      EnsureLabel(m_help, cx, cy, w - 2*pad, row_h*2,
                  "Trigger can be in R or points (Mode). 'Plus' adds points beyond BE.",
                  clrSilver, 8);

      // keep visibility state
      SetVisible(m_visible);
   }

   void SetVisible(const bool v)
   {
      m_visible = v;
      for(int i=0;i<ArraySize(m_objs);++i)
      {
         if(ObjectFind(m_chart, m_objs[i]) >= 0)
            ObjectSetInteger(m_chart, m_objs[i], OBJPROP_HIDDEN, !m_visible);
      }
   }

   void SyncFromState(const TA_Context &ctx,const TA_State &st)
   {
      // Update texts; avoid heavy Layout() here
      if(ObjectFind(m_chart, m_btn_enable) >= 0)
         ObjectSetString(m_chart, m_btn_enable, OBJPROP_TEXT, "BE: " + OnOff(st.be_enabled));

      if(ObjectFind(m_chart, m_btn_mode) >= 0)
         ObjectSetString(m_chart, m_btn_mode, OBJPROP_TEXT, "Mode: " + ModeName(st.be_mode));

      if(ObjectFind(m_chart, m_lbl_trigger) >= 0)
      {
         string trig_lbl = (st.be_mode==TA_BE_AT_R ? "Trigger (R):" : "Trigger (pts):");
         ObjectSetString(m_chart, m_lbl_trigger, OBJPROP_TEXT, trig_lbl);
      }

      if(ObjectFind(m_chart, m_ed_trigger) >= 0)
      {
         string trig_val = (st.be_mode==TA_BE_AT_R ? DoubleToString(st.be_at_r, 2) : DoubleToString(st.be_at_points, 0));
         ObjectSetString(m_chart, m_ed_trigger, OBJPROP_TEXT, trig_val);
      }

      if(ObjectFind(m_chart, m_ed_plus) >= 0)
         ObjectSetString(m_chart, m_ed_plus, OBJPROP_TEXT, DoubleToString(st.be_plus_points, 0));

      if(ObjectFind(m_chart, m_btn_once) >= 0)
         ObjectSetString(m_chart, m_btn_once, OBJPROP_TEXT, "Once: " + YesNo(st.be_once));

      if(ObjectFind(m_chart, m_btn_after_tp1_be) >= 0)
         ObjectSetString(m_chart, m_btn_after_tp1_be, OBJPROP_TEXT, "After TP1 -> Move SL to BE: " + OnOff(st.tp_move_sl_to_be_after_tp1));
   }

   void OnTimer(const TA_Context &ctx,TA_State &st)
   {
      // Keep UI in sync (in case state changed via preset load / hotkeys)
      SyncFromState(ctx, st);
   }

   void OnChartEvent(const TA_Context &ctx,TA_State &st,const int id,const long &lparam,const double &dparam,const string &sparam)
   {
      if(!m_visible) return;

      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         if(sparam == m_btn_enable)
         {
            st.be_enabled = !st.be_enabled;
            TA_OnUI_ToggleBreakEven(st.be_enabled);
            SyncFromState(ctx, st);
            return;
         }
         if(sparam == m_btn_mode)
         {
            st.be_mode = NextMode(st.be_mode);
            // Sync BE engine without changing enabled state
            TA_OnUI_ToggleBreakEven(st.be_enabled);
            SyncFromState(ctx, st);
            return;
         }
         if(sparam == m_btn_once)
         {
            st.be_once = !st.be_once;
            TA_OnUI_ToggleBreakEven(st.be_enabled);
            SyncFromState(ctx, st);
            return;
         }
         if(sparam == m_btn_after_tp1_be)
         {
            st.tp_move_sl_to_be_after_tp1 = !st.tp_move_sl_to_be_after_tp1;
            // This affects partial-close logic; keep here so preset captures it.
            SyncFromState(ctx, st);
            return;
         }
      }

      if(id == CHARTEVENT_OBJECT_ENDEDIT || id == CHARTEVENT_OBJECT_CHANGE)
      {
         if(sparam == m_ed_trigger)
         {
            string t = ObjectGetString(m_chart, m_ed_trigger, OBJPROP_TEXT);
            double v = ParseD(t, 0.0);
            if(v < 0.0) v = 0.0;

            if(st.be_mode == TA_BE_AT_R)
               st.be_at_r = v;
            else
               st.be_at_points = v;

            TA_OnUI_ToggleBreakEven(st.be_enabled);
            SyncFromState(ctx, st);
            return;
         }
         if(sparam == m_ed_plus)
         {
            string t = ObjectGetString(m_chart, m_ed_plus, OBJPROP_TEXT);
            double v = ParseD(t, 0.0);
            if(v < 0.0) v = 0.0;
            st.be_plus_points = v;

            TA_OnUI_ToggleBreakEven(st.be_enabled);
            SyncFromState(ctx, st);
            return;
         }
      }
   }
};

#endif // __MUSERA_UI_BE_TAB_MQH__

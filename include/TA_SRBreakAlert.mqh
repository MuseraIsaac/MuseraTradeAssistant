//+------------------------------------------------------------------+
//|                                                    TA_SRBreakAlert.mqh |
//|                                  (c) 2026, Musera Isaac               |
//|  Support/Resistance Break Alert module (project include).             |
//|                                                                       |
//|  Expected location (relative to MQL5\Data Folder):                    |
//|    MQL5\Experts\MuseraTradeAssistant\include\TA_SRBreakAlert.mqh       |
//|                                                                       |
//|  Notes:                                                               |
//|  - Scans chart objects (HLINE + TREND by default).                    |
//|  - Alerts when last CLOSED candle crosses the line (with buffer).     |
//|  - Uses optional cooldown per line to avoid spam.                     |
//|  - Configuration is expected to come from TA_State fields.            |
//|                                                                       |
//|  This file is part of a multi-include project and may not compile     |
//|  in isolation until other includes/types exist.                       |
//+------------------------------------------------------------------+
#ifndef __TA_SRBREAKALERT_MQH__
#define __TA_SRBREAKALERT_MQH__

// Core project dependencies (expected to exist in your include folder)
#include "TA_Constants.mqh"
#include "TA_Types.mqh"
#include "TA_State.mqh"

// (Optional) helpers; keep this include if you have shared utils.
//#include "TA_Utils.mqh"

// --------------------------- Expected TA_State fields ---------------------------
// Your TA_State is expected to provide (at minimum) the following members:
//
//  bool   sr_alert_enabled;         // master toggle
//  string sr_object_prefix;         // e.g. "SR_" (empty => monitor all eligible lines)
//  bool   sr_monitor_all;           // if true, ignores prefix filter (optional)
//  bool   sr_use_close;             // true => use last closed candle close; false => use Bid/Ask
//  int    sr_break_buffer_points;   // buffer in points around line to confirm break
//  int    sr_cooldown_seconds;      // minimum seconds between alerts for the same line
//
//  bool   sr_alert_popup;           // Alert()
//  bool   sr_alert_push;            // SendNotification()
//  bool   sr_alert_sound;           // PlaySound()
//  string sr_alert_sound_file;      // sound file name under Terminal\Sounds\ (or full path)
//  bool   sr_alert_log;             // Print()
// -----------------------------------------------------------------------------

class TA_SRBreakAlert
{
private:
   bool     m_inited;
   string   m_prefix;
   bool     m_monitor_all;
   bool     m_use_close;

   int      m_buffer_points;
   int      m_cooldown_seconds;

   bool     m_popup;
   bool     m_push;
   bool     m_sound;
   bool     m_log;
   string   m_sound_file;

   string   m_names[];
   int      m_sides[];        // -1 below, 0 near, +1 above
   datetime m_last_alert[];

private:
   int FindIndex(const string name) const
   {
      int n = ArraySize(m_names);
      for(int i=0;i<n;i++)
         if(m_names[i] == name)
            return i;
      return -1;
   }

   bool StartsWith(const string s, const string prefix) const
   {
      if(prefix == "") return true;
      return (StringFind(s, prefix, 0) == 0);
   }

   // Returns EMPTY_VALUE if cannot evaluate
   double LinePriceAtTime(const long chart_id, const string obj_name, const datetime t) const
   {
      if(ObjectFind(chart_id, obj_name) < 0)
         return EMPTY_VALUE;

      int type = (int)ObjectGetInteger(chart_id, obj_name, OBJPROP_TYPE);

      if(type == OBJ_HLINE)
      {
         return ObjectGetDouble(chart_id, obj_name, OBJPROP_PRICE);
      }
      if(type == OBJ_TREND)
      {
         // Trend line value at time (chart API)
         return ObjectGetValueByTime(chart_id, obj_name, t, 0);
      }

      return EMPTY_VALUE;
   }

   bool IsEligibleObject(const long chart_id, const string obj_name) const
   {
      if(ObjectFind(chart_id, obj_name) < 0)
         return false;

      int type = (int)ObjectGetInteger(chart_id, obj_name, OBJPROP_TYPE);
      if(type != OBJ_HLINE && type != OBJ_TREND)
         return false;

      if(m_monitor_all)
         return true;

      return StartsWith(obj_name, m_prefix);
   }

   int SideOfPrice(const double price, const double line_price) const
   {
      if(line_price == EMPTY_VALUE) return 0;

      double thr = (double)m_buffer_points * _Point;
      double d   = price - line_price;

      if(d >  thr) return +1;
      if(d < -thr) return -1;
      return 0;
   }

   bool CooldownOk(const datetime now, const datetime last_alert) const
   {
      if(m_cooldown_seconds <= 0) return true;
      if(last_alert == 0) return true;
      return ((now - last_alert) >= m_cooldown_seconds);
   }

   void FireAlert(const string symbol,
                  const string obj_name,
                  const int direction, // +1 up, -1 down
                  const double line_price,
                  const double ref_price,
                  const datetime tnow) const
   {
      string dir = (direction > 0 ? "BREAK UP" : "BREAK DOWN");
      string msg = StringFormat("%s %s: %s | line=%.5f price=%.5f",
                                symbol, dir, obj_name, line_price, ref_price);

      if(m_log)   Print(msg);
      if(m_popup) Alert(msg);
      if(m_push)  SendNotification(msg);
      if(m_sound && m_sound_file != "")
         PlaySound(m_sound_file);
   }

public:
   TA_SRBreakAlert()
   {
      m_inited = false;

      m_prefix = "SR_";
      m_monitor_all = false;
      m_use_close = true;

      m_buffer_points = 20;
      m_cooldown_seconds = 60;

      m_popup = false;
      m_push  = false;
      m_sound = false;
      m_log   = true;
      m_sound_file = "";

      ArrayResize(m_names, 0);
      ArrayResize(m_sides, 0);
      ArrayResize(m_last_alert, 0);
   }

   bool Init(const TA_Context &ctx, const TA_State &state)
   {
      SyncConfig(ctx, state);

      ArrayResize(m_names, 0);
      ArrayResize(m_sides, 0);
      ArrayResize(m_last_alert, 0);

      m_inited = true;
      return true;
   }

   void SyncConfig(const TA_Context &ctx, const TA_State &state)
   {
      // Read config from TA_State. If you haven't added these fields yet,
      // the project will not compile until TA_State is updated (expected).
      m_prefix          = state.sr_object_prefix;
      m_monitor_all     = state.sr_monitor_all;
      m_use_close       = state.sr_use_close;

      m_buffer_points   = state.sr_break_buffer_points;
      m_cooldown_seconds= state.sr_cooldown_seconds;

      m_popup           = state.sr_alert_popup;
      m_push            = state.sr_alert_push;
      m_sound           = state.sr_alert_sound;
      m_sound_file      = state.sr_alert_sound_file;
      m_log             = state.sr_alert_log;

      // Basic sane defaults if user left empty/zero.
      if(m_prefix == "") m_prefix = "SR_";
      if(m_buffer_points < 0) m_buffer_points = 0;
      if(m_cooldown_seconds < 0) m_cooldown_seconds = 0;
   }

   void OnTimer(const TA_Context &ctx, const TA_State &state)
   {
      if(!m_inited) return;

      // Keep config live (preset loads / UI changes can update state).
      SyncConfig(ctx, state);

      if(!state.sr_alert_enabled)
         return;

      long chart_id = (long)ctx.chart_id;

      // Reference price for break detection:
      // - Prefer last CLOSED candle close (stable), shift=1.
      // - Or current Bid/Ask (faster, noisier).
      datetime t_ref = 0;
      double   p_ref = 0.0;

      if(m_use_close)
      {
         t_ref = iTime(ctx.symbol, PERIOD_CURRENT, 1);
         p_ref = iClose(ctx.symbol, PERIOD_CURRENT, 1);
      }
      else
      {
         t_ref = TimeCurrent();
         if(SymbolInfoInteger(ctx.symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL)
         {
            // Use Bid as reference; callers can decide.
            p_ref = SymbolInfoDouble(ctx.symbol, SYMBOL_BID);
         }
         else
         {
            p_ref = SymbolInfoDouble(ctx.symbol, SYMBOL_BID);
         }
      }

      if(p_ref <= 0.0 || t_ref <= 0)
         return;

      datetime t_now = TimeCurrent();

      // Gather eligible objects and rebuild internal arrays (keeps it simple & robust)
      string   new_names[];
      int      new_sides[];
      datetime new_last_alert[];

      ArrayResize(new_names, 0);
      ArrayResize(new_sides, 0);
      ArrayResize(new_last_alert, 0);

      int total = ObjectsTotal(chart_id, -1, -1);
      for(int i=0;i<total;i++)
      {
         string obj = ObjectName(chart_id, i, -1, -1);
         if(obj == "") continue;

         if(!IsEligibleObject(chart_id, obj))
            continue;

         double line_price = LinePriceAtTime(chart_id, obj, t_ref);
         if(line_price == EMPTY_VALUE) continue;

         int side = SideOfPrice(p_ref, line_price);

         int old = FindIndex(obj);
         int old_side = 0;
         datetime old_last = 0;

         if(old >= 0)
         {
            old_side = m_sides[old];
            old_last = m_last_alert[old];
         }
         else
         {
            // first time seeing this object: initialize side, no alert
            old_side = side;
            old_last = 0;
         }

         // Detect cross: require both sides non-zero and changed
         if(old >= 0 && old_side != 0 && side != 0 && side != old_side)
         {
            if(CooldownOk(t_now, old_last))
            {
               int direction = side; // +1 up (now above), -1 down (now below)
               FireAlert(ctx.symbol, obj, direction, line_price, p_ref, t_now);
               old_last = t_now;
            }
         }

         // Persist
         int n = ArraySize(new_names);
         ArrayResize(new_names, n+1);
         ArrayResize(new_sides, n+1);
         ArrayResize(new_last_alert, n+1);

         new_names[n] = obj;
         new_sides[n] = side;
         new_last_alert[n] = old_last;
      }

      m_names = new_names;
      m_sides = new_sides;
      m_last_alert = new_last_alert;
   }

   // Optional hooks (not required by the shell, but safe if called)
   void OnChartEvent(const TA_Context &ctx, const TA_State &state,
                     const int id, const long &lparam,
                     const double &dparam, const string &sparam)
   {
   }

   void OnTradeTransaction(const TA_Context &ctx, const TA_State &state,
                           const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {
   }
};

#endif // __TA_SRBREAKALERT_MQH__

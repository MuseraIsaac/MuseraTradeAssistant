//+------------------------------------------------------------------+
//|                                                   TA_State.mqh   |
//|                      MuseraTradeAssistant (project include)      |
//|                                  (c) 2026, Musera Isaac          |
//+------------------------------------------------------------------+
//  Runtime + user configuration state ("single source of truth").
//
//  TA_Persistence expects:
//    bool Serialize(string &out_text) const;
//    bool Deserialize(const string &in_text);
//
//  This file intentionally holds configuration only (no heavy UI logic).
//+------------------------------------------------------------------+
#property strict

#ifndef __TA_STATE_MQH__
#define __TA_STATE_MQH__

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"

// ------------------------------------------------------------------
// Compatibility aliases (older modules may still reference these)
// ------------------------------------------------------------------
#ifndef TA_RISK_PERCENT
   #define TA_RISK_PERCENT TA_RISK_BALANCE_PCT
#endif
#ifndef TA_RISK_BALANCE
   #define TA_RISK_BALANCE TA_RISK_BALANCE_PCT
#endif
#ifndef TA_RISK_EQUITY
   #define TA_RISK_EQUITY  TA_RISK_EQUITY_PCT
#endif

#ifndef TA_RISK_BASIS_BALANCE
   #define TA_RISK_BASIS_BALANCE TA_BASIS_BALANCE
#endif
#ifndef TA_RISK_BASIS_EQUITY
   #define TA_RISK_BASIS_EQUITY  TA_BASIS_EQUITY
#endif
#ifndef TA_RISK_BASIS_FREE_MG
   #define TA_RISK_BASIS_FREE_MG TA_BASIS_FREE_MG
#endif

// ------------------------------------------------------------------
// Extra types used by some modules (RR/partials). Guard to avoid clashes.
// ------------------------------------------------------------------
#ifndef __TA_TARGET_TYPE_DEFINED__
#define __TA_TARGET_TYPE_DEFINED__
// How a target is expressed in partial TP ladder.
enum TA_TargetType
{
   TA_TARGET_POINTS = 0,
   TA_TARGET_R      = 1,
   TA_TARGET_PRICE  = 2
};
#endif

struct TA_TPLevel
{
   bool         enabled;
   TA_TargetType type;
   double       target;        // points / R / price (based on type)
   double       close_percent;  // percent of initial volume to close at this level

   void Reset()
   {
      enabled = false;
      type = TA_TARGET_R;
      target = 0.0;
      close_percent = 0.0;
   }
};

//+------------------------------------------------------------------+
//| TA_State                                                         |
//+------------------------------------------------------------------+
class TA_State
{
public:
   // ---------------- UI ----------------
   ENUM_TA_APP_TAB ui_active_tab;
   bool            ui_minimized;
   bool            ui_lock_panel;
   bool            ui_show_debug;
   int             ui_theme_id;         // optional theme selector

   // ---------------- General trade ----------------
   ENUM_TA_ORDER_KIND order_kind;
   int                deviation_points;
   string             order_comment;
   bool               allow_multiple_entries;

   // ---------------- Risk & sizing ----------------
   ENUM_TA_RISK_MODE   risk_mode;   // canonical
   ENUM_TA_RISK_BASIS  risk_basis;  // canonical
   double              fixed_lots;  // canonical (when risk_mode=fixed)
   double              risk_value;  // canonical (% or money depending on risk_mode)
   double              max_lot_cap; // 0 = no cap
   bool                round_to_step;

   // Legacy fields expected by some modules (kept in sync by Sanitize/SyncLegacy)
   ENUM_TA_RISK_BASIS  risk_base;   // alias of risk_basis
   double              fixed_lot;   // alias of fixed_lots
   double              risk_percent;
   double              risk_money;

   // ---------------- SL/TP & RR ----------------
   ENUM_TA_SL_MODE sl_mode;
   ENUM_TA_TP_MODE tp_mode;
   double sl_price;
   double tp_price;
   bool   sl_enabled;
   bool   tp_enabled;
   int    slippage_points;
   int    sl_points;
   int    tp_points;
   double rr_target;
   bool   tp_from_rr;
   bool   sl_required;

   // ---------------- Partial TPs ----------------
   bool                  tp_partials_enabled;
   ENUM_TA_PARTIAL_SCHEMA tp_partials_schema;
   ENUM_TA_PARTIAL_TRIGGER tp_partials_trigger;
   ENUM_TA_PARTIALS_MODE tp_partials_mode;

   // New style partial config
   TA_TPLevel tp_levels[TA_MAX_TP_LEVELS];

   // Legacy partial config (used by older UI/widgets)
   double tp1_at_r;
   double tp2_at_r;
   double tp3_at_r;
   int    tp1_at_points;
   int    tp2_at_points;
   int    tp3_at_points;
   double tp1_close_pct;
   double tp2_close_pct;
   double tp3_close_pct;

   // Convenience (also used by some earlier implementations)
   bool   tp_move_sl_to_be_after_tp1;
   bool   tp_start_trailing_after_tp1;

   // ---------------- Break-even ----------------
   bool            be_enabled;
   ENUM_TA_BE_MODE be_mode;
   double          be_at_r;
   int             be_at_points;
   int             be_plus_points;
   int             be_lock_points;
   int             be_offset_points;
   bool            be_once;

   // ---------------- Trailing ----------------
   bool              trailing_enabled;
   ENUM_TA_TRAIL_MODE trailing_mode;
   ENUM_TA_TRAIL_SCOPE trailing_scope;
   bool              trailing_only_profit;
   int               trailing_min_interval_ms;
   double            trailing_start_profit_pips;

   // common trailing params
   int    trail_start_points;
   int    trail_step_points;
   int    trail_distance_points;

   // Pips-based trailing (Trail_Pips)
   double trail_pips_distance;
   double trail_pips_step;
   double trail_pips_start;
   bool   trail_pips_only_profit;

   // ATR/MA/SAR extras (used by trailing modules)
   int    trail_atr_period;
   double trail_atr_mult;
   double trail_atr_buffer_pips;

   int             trail_ma_period;
   ENUM_MA_METHOD  trail_ma_method;
   ENUM_APPLIED_PRICE trail_ma_price;
   int             trail_ma_shift;
   double          trail_ma_buffer_pips;

   double trail_sar_step;
   double trail_sar_max;
   double trail_sar_buffer_pips;

   int    trail_hl_bars_back;
   int    trail_hl_lookback_bars;
   double trail_hl_buffer_pips;

   int    trail_fractal_left;
   int    trail_fractal_right;
   double trail_fractal_buffer_pips;

   bool   trail_partial_enabled;
   double trail_partial_every_r;
   double trail_partial_close_pct;

   // ---------------- OCO / Virtual orders ----------------
   ENUM_TA_OCO_MODE oco_mode;
   bool             vorders_enabled;
   bool             vorders_virtual_sl_tp;
   bool             vorders_virtual_pending;
   int              vorders_poll_ms;

   // ---------------- Time rules ----------------
   ENUM_TA_TIME_RULE time_rule;
   bool allow_mon;
   bool allow_tue;
   bool allow_wed;
   bool allow_thu;
   bool allow_fri;
   bool allow_sat;
   bool allow_sun;

   int session_start_hour;
   int session_start_min;
   int session_end_hour;
   int session_end_min;

   int utc_offset_seconds;

   // ---------------- Notifications ----------------
   ENUM_TA_NOTIFY_CHANNEL notify_channel;
   bool   notify_on_trade;
   bool   notify_on_error;
   bool   notify_use_sound;
   string notify_sound_ok;
   string notify_sound_error;
   string notify_prefix;

   // ---------------- Presets bookkeeping ----------------
   string current_preset_name;

   // ---------------- Constructor-like reset ----------------
   void Reset()
   {
      ui_active_tab = TA_TAB_TRADE;
      ui_minimized = false;
      ui_lock_panel = false;
      ui_show_debug = false;
      ui_theme_id = 0;

      order_kind = TA_ORDER_MARKET;
      deviation_points = TA_DFLT_DEVIATION_POINTS;
      slippage_points = deviation_points;
      order_comment = TA_PROJECT_SHORT;
      allow_multiple_entries = true;

      risk_mode = TA_RISK_BALANCE_PCT;
      risk_basis = TA_BASIS_BALANCE;
      fixed_lots = 0.10;
      risk_value = TA_DFLT_RISK_PERCENT;
      max_lot_cap = 0.0;
      round_to_step = true;

      risk_base = risk_basis;
      fixed_lot = fixed_lots;
      risk_percent = TA_DFLT_RISK_PERCENT;
      risk_money = TA_DFLT_RISK_MONEY;

      sl_mode = TA_SL_POINTS;
      tp_mode = TA_TP_POINTS;
      sl_price = 0.0;
      tp_price = 0.0;
      sl_enabled = false;
      tp_enabled = false;
      sl_points = 0;
      tp_points = 0;
      rr_target = TA_DFLT_RR;
      tp_from_rr = false;
      sl_required = true;

      tp_partials_enabled = false;
      tp_partials_schema = TA_PARTIAL_OFF;
      tp_partials_trigger = TA_PARTIAL_TRIGGER_BY_R;
      tp_partials_mode = TA_PARTIALS_BY_R;
      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
         tp_levels[i].Reset();
      tp1_at_r = TA_DFLT_TP1_R;
      tp2_at_r = TA_DFLT_TP2_R;
      tp3_at_r = TA_DFLT_TP3_R;
      tp1_at_points = 0;
      tp2_at_points = 0;
      tp3_at_points = 0;
      tp1_close_pct = TA_DFLT_TP1_CLOSE_PCT;
      tp2_close_pct = TA_DFLT_TP2_CLOSE_PCT;
      tp3_close_pct = TA_DFLT_TP3_CLOSE_PCT;

      tp_move_sl_to_be_after_tp1 = false;
      tp_start_trailing_after_tp1 = false;

      be_enabled = false;
      be_mode = TA_BE_OFF;
      be_at_r = TA_DFLT_BE_TRIGGER_R;
      be_at_points = 0;
      be_plus_points = 0;
      be_lock_points = 0;
      be_offset_points = 0;
      be_once = true;

      trailing_enabled = false;
      trailing_mode = TA_TRAIL_NONE;
      trailing_scope = TA_TRAIL_SCOPE_CURRENT_SYMBOL;
      trailing_only_profit = true;
      trailing_min_interval_ms = 250;
      trailing_start_profit_pips = 0.0;

      trail_start_points = 0;
      trail_step_points = (int)MathRound(TA_DFLT_TRAIL_STEP_PIPS * 10.0);
      trail_distance_points = (int)MathRound(TA_DFLT_TRAIL_DIST_PIPS * 10.0);

      trail_pips_distance = TA_DFLT_TRAIL_DIST_PIPS;
      trail_pips_step = TA_DFLT_TRAIL_STEP_PIPS;
      trail_pips_start = 0.0;
      trail_pips_only_profit = true;

      trail_atr_period = TA_DFLT_ATR_PERIOD;
      trail_atr_mult = TA_DFLT_ATR_MULT;
      trail_atr_buffer_pips = 0.0;

      trail_ma_period = TA_DFLT_MA_PERIOD;
      trail_ma_method = (ENUM_MA_METHOD)TA_DFLT_MA_METHOD;
      trail_ma_price = PRICE_CLOSE;
      trail_ma_shift = 0;
      trail_ma_buffer_pips = 0.0;

      trail_sar_step = 0.02;
      trail_sar_max = 0.2;
      trail_sar_buffer_pips = 0.0;

      trail_hl_bars_back = 1;
      trail_hl_lookback_bars = 1;
      trail_hl_buffer_pips = 0.0;

      trail_fractal_left = 2;
      trail_fractal_right = 2;
      trail_fractal_buffer_pips = 0.0;

      trail_partial_enabled = false;
      trail_partial_every_r = 1.0;
      trail_partial_close_pct = 25.0;

      oco_mode = TA_OCO_OFF;
      vorders_enabled = false;
      vorders_virtual_sl_tp = false;
      vorders_virtual_pending = false;
      vorders_poll_ms = 250;

      time_rule = TA_TIME_ALWAYS;
      allow_mon = allow_tue = allow_wed = allow_thu = allow_fri = true;
      allow_sat = allow_sun = false;
      session_start_hour = 0;
      session_start_min = 0;
      session_end_hour = 23;
      session_end_min = 59;
      utc_offset_seconds = 0;

      notify_channel = TA_NOTIFY_PRINT;
      notify_on_trade = true;
      notify_on_error = true;
      notify_use_sound = false;
      notify_sound_ok = TA_SOUND_NOTIFY_FILE;
      notify_sound_error = TA_SOUND_ERROR_FILE;
      notify_prefix = TA_PROJECT_SHORT;

      current_preset_name = "";
   }

   // Initialize defaults with symbol-aware conversions.
   void InitDefaults(const TA_Context &ctx)
   {
      Reset();

      string sym = (ctx.symbol == "" ? _Symbol : ctx.symbol);

      // Default lots: at least min lot, but not exceeding max.
      double vmin = TA_VolumeMin(sym);
      if(vmin <= 0.0) vmin = 0.01;
      fixed_lots = TA_NormalizeVolume(sym, MathMax(0.10, vmin));
      fixed_lot  = fixed_lots;

      // SL/TP defaults from constants (pips -> points)
      sl_points = (int)MathRound(TA_PriceToPoints(sym, TA_PipsToPrice(sym, TA_DFLT_SL_PIPS)));
      tp_points = (int)MathRound(TA_PriceToPoints(sym, TA_PipsToPrice(sym, TA_DFLT_TP_PIPS)));
      sl_mode = (sl_points > 0 ? TA_SL_POINTS : TA_SL_NONE);
      tp_mode = (tp_points > 0 ? TA_TP_POINTS : TA_TP_NONE);
      sl_enabled = (sl_points > 0);
      tp_enabled = (tp_points > 0);

      // Partial defaults (disabled)
      tp_levels[0].enabled = true;
      tp_levels[0].type = TA_TARGET_R;
      tp_levels[0].target = TA_DFLT_TP1_R;
      tp_levels[0].close_percent = TA_DFLT_TP1_CLOSE_PCT;

      tp_levels[1].enabled = true;
      tp_levels[1].type = TA_TARGET_R;
      tp_levels[1].target = TA_DFLT_TP2_R;
      tp_levels[1].close_percent = TA_DFLT_TP2_CLOSE_PCT;

      tp_levels[2].enabled = true;
      tp_levels[2].type = TA_TARGET_R;
      tp_levels[2].target = TA_DFLT_TP3_R;
      tp_levels[2].close_percent = TA_DFLT_TP3_CLOSE_PCT;

      tp1_at_r = TA_DFLT_TP1_R;
      tp2_at_r = TA_DFLT_TP2_R;
      tp3_at_r = TA_DFLT_TP3_R;
      tp1_close_pct = TA_DFLT_TP1_CLOSE_PCT;
      tp2_close_pct = TA_DFLT_TP2_CLOSE_PCT;
      tp3_close_pct = TA_DFLT_TP3_CLOSE_PCT;

      // BE points default based on 10 pips
      be_at_points = (int)MathRound(TA_PriceToPoints(sym, TA_PipsToPrice(sym, 10.0)));
      be_lock_points = be_plus_points;
      be_offset_points = be_plus_points;

      Sanitize(sym);
   }

   // Keep values in safe ranges; also sync legacy fields.
   void Sanitize(const string sym)
   {
      deviation_points = (int)TA_Clamp((double)deviation_points, 0.0, 1000.0);

      fixed_lots = TA_NormalizeVolume(sym, fixed_lots);
      if(max_lot_cap < 0.0) max_lot_cap = 0.0;

      if(sl_points < 0) sl_points = 0;
      if(tp_points < 0) tp_points = 0;

      rr_target = TA_Clamp(rr_target, 0.0, 1000.0);
      risk_value = TA_Clamp(risk_value, 0.0, 1e12);

      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
      {
         tp_levels[i].close_percent = TA_Clamp(tp_levels[i].close_percent, 0.0, 100.0);
         if(!TA_IsFinite(tp_levels[i].target)) tp_levels[i].target = 0.0;
      }

      tp1_close_pct = TA_Clamp(tp1_close_pct, 0.0, 100.0);
      tp2_close_pct = TA_Clamp(tp2_close_pct, 0.0, 100.0);
      tp3_close_pct = TA_Clamp(tp3_close_pct, 0.0, 100.0);

      if(sl_price < 0.0 || !TA_IsFinite(sl_price)) sl_price = 0.0;
      if(tp_price < 0.0 || !TA_IsFinite(tp_price)) tp_price = 0.0;

      if(slippage_points < 0) slippage_points = 0;

      if(be_lock_points < 0) be_lock_points = 0;
      if(be_offset_points < 0) be_offset_points = 0;

      if(trailing_min_interval_ms < 0) trailing_min_interval_ms = 0;
      if(trailing_start_profit_pips < 0.0) trailing_start_profit_pips = 0.0;

      if(trail_pips_distance < 0.0) trail_pips_distance = 0.0;
      if(trail_pips_step < 0.0) trail_pips_step = 0.0;
      if(trail_pips_start < 0.0) trail_pips_start = 0.0;

      if(trail_atr_period < 1) trail_atr_period = 1;
      if(trail_atr_mult < 0.0) trail_atr_mult = 0.0;
      if(trail_atr_buffer_pips < 0.0) trail_atr_buffer_pips = 0.0;

      if(trail_ma_period < 1) trail_ma_period = 1;
      if(trail_ma_shift < 0) trail_ma_shift = 0;
      if(trail_ma_buffer_pips < 0.0) trail_ma_buffer_pips = 0.0;

      if(trail_sar_step < 0.0) trail_sar_step = 0.0;
      if(trail_sar_max < 0.0) trail_sar_max = 0.0;
      if(trail_sar_buffer_pips < 0.0) trail_sar_buffer_pips = 0.0;

      if(trail_hl_bars_back < 1) trail_hl_bars_back = 1;
      if(trail_hl_lookback_bars < 1) trail_hl_lookback_bars = 1;
      if(trail_hl_buffer_pips < 0.0) trail_hl_buffer_pips = 0.0;

      if(trail_fractal_left < 1) trail_fractal_left = 1;
      if(trail_fractal_right < 1) trail_fractal_right = 1;
      if(trail_fractal_buffer_pips < 0.0) trail_fractal_buffer_pips = 0.0;

      if(trail_partial_every_r < 0.0) trail_partial_every_r = 0.0;
      if(trail_partial_close_pct < 0.0) trail_partial_close_pct = 0.0;
      if(trail_partial_close_pct > 100.0) trail_partial_close_pct = 100.0;

      // Sync legacy
      SyncLegacy();
   }

   void SyncLegacy()
   {
      risk_base = risk_basis;
      fixed_lot = fixed_lots;

      // Provide convenient legacy split fields
      risk_percent = 0.0;
      risk_money   = 0.0;

      if(risk_mode == TA_RISK_FIXED_LOT)
      {
         // leave percent/money as 0
      }
      else if(risk_mode == TA_RISK_MONEY)
      {
         risk_money = risk_value;
      }
      else
      {
         // both % modes
         risk_percent = risk_value;
      }

      slippage_points = deviation_points;
      tp_from_rr = (tp_mode == TA_TP_RR);
      sl_required = (sl_mode != TA_SL_NONE);
      sl_enabled = (sl_mode != TA_SL_NONE) &&
                   ((sl_mode == TA_SL_POINTS && sl_points > 0) ||
                    (sl_mode == TA_SL_PRICE && sl_price > 0.0));
      tp_enabled = (tp_mode != TA_TP_NONE) &&
                   ((tp_mode == TA_TP_POINTS && tp_points > 0) ||
                    (tp_mode == TA_TP_PRICE && tp_price > 0.0) ||
                    (tp_mode == TA_TP_RR && rr_target > 0.0));

      tp_partials_mode = (tp_partials_trigger == TA_PARTIAL_TRIGGER_BY_R
                          ? TA_PARTIALS_BY_R
                          : TA_PARTIALS_BY_POINTS);

      // Legacy partials mirror tp_levels when available
      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
      {
         if(!tp_levels[i].enabled)
            continue;

         if(i == 0)
         {
            tp1_close_pct = tp_levels[i].close_percent;
            if(tp_levels[i].type == TA_TARGET_R) tp1_at_r = tp_levels[i].target;
            else if(tp_levels[i].type == TA_TARGET_POINTS) tp1_at_points = (int)MathRound(tp_levels[i].target);
         }
         else if(i == 1)
         {
            tp2_close_pct = tp_levels[i].close_percent;
            if(tp_levels[i].type == TA_TARGET_R) tp2_at_r = tp_levels[i].target;
            else if(tp_levels[i].type == TA_TARGET_POINTS) tp2_at_points = (int)MathRound(tp_levels[i].target);
         }
         else if(i == 2)
         {
            tp3_close_pct = tp_levels[i].close_percent;
            if(tp_levels[i].type == TA_TARGET_R) tp3_at_r = tp_levels[i].target;
            else if(tp_levels[i].type == TA_TARGET_POINTS) tp3_at_points = (int)MathRound(tp_levels[i].target);
         }
      }

      be_lock_points = be_plus_points;
      be_offset_points = be_plus_points;
   }

   // ---------------- Serialization ----------------
   bool Serialize(string &out_text) const
   {
      out_text = "";

      // Basic scalars
      out_text += "ui_active_tab=" + IntegerToString((int)ui_active_tab) + "\n";
      out_text += "ui_minimized=" + IntegerToString(ui_minimized?1:0) + "\n";
      out_text += "ui_lock_panel=" + IntegerToString(ui_lock_panel?1:0) + "\n";
      out_text += "ui_show_debug=" + IntegerToString(ui_show_debug?1:0) + "\n";
      out_text += "ui_theme_id=" + IntegerToString(ui_theme_id) + "\n";

      out_text += "order_kind=" + IntegerToString((int)order_kind) + "\n";
      out_text += "deviation_points=" + IntegerToString(deviation_points) + "\n";
      out_text += "slippage_points=" + IntegerToString(slippage_points) + "\n";
      out_text += "order_comment=" + order_comment + "\n";
      out_text += "allow_multiple_entries=" + IntegerToString(allow_multiple_entries?1:0) + "\n";

      out_text += "risk_mode=" + IntegerToString((int)risk_mode) + "\n";
      out_text += "risk_basis=" + IntegerToString((int)risk_basis) + "\n";
      out_text += "fixed_lots=" + DoubleToString(fixed_lots, 8) + "\n";
      out_text += "risk_value=" + DoubleToString(risk_value, 8) + "\n";
      out_text += "max_lot_cap=" + DoubleToString(max_lot_cap, 8) + "\n";
      out_text += "round_to_step=" + IntegerToString(round_to_step?1:0) + "\n";

      out_text += "sl_mode=" + IntegerToString((int)sl_mode) + "\n";
      out_text += "tp_mode=" + IntegerToString((int)tp_mode) + "\n";
      out_text += "sl_price=" + DoubleToString(sl_price, 8) + "\n";
      out_text += "tp_price=" + DoubleToString(tp_price, 8) + "\n";
      out_text += "sl_enabled=" + IntegerToString(sl_enabled?1:0) + "\n";
      out_text += "tp_enabled=" + IntegerToString(tp_enabled?1:0) + "\n";
      out_text += "sl_points=" + IntegerToString(sl_points) + "\n";
      out_text += "tp_points=" + IntegerToString(tp_points) + "\n";
      out_text += "rr_target=" + DoubleToString(rr_target, 8) + "\n";
      out_text += "tp_from_rr=" + IntegerToString(tp_from_rr?1:0) + "\n";
      out_text += "sl_required=" + IntegerToString(sl_required?1:0) + "\n";

      out_text += "tp_partials_enabled=" + IntegerToString(tp_partials_enabled?1:0) + "\n";
      out_text += "tp_partials_schema=" + IntegerToString((int)tp_partials_schema) + "\n";
      out_text += "tp_partials_trigger=" + IntegerToString((int)tp_partials_trigger) + "\n";
      out_text += "tp_partials_mode=" + IntegerToString((int)tp_partials_mode) + "\n";
      out_text += "tp_move_sl_to_be_after_tp1=" + IntegerToString(tp_move_sl_to_be_after_tp1?1:0) + "\n";
      out_text += "tp_start_trailing_after_tp1=" + IntegerToString(tp_start_trailing_after_tp1?1:0) + "\n";
      out_text += "tp1_at_r=" + DoubleToString(tp1_at_r, 8) + "\n";
      out_text += "tp2_at_r=" + DoubleToString(tp2_at_r, 8) + "\n";
      out_text += "tp3_at_r=" + DoubleToString(tp3_at_r, 8) + "\n";
      out_text += "tp1_at_points=" + IntegerToString(tp1_at_points) + "\n";
      out_text += "tp2_at_points=" + IntegerToString(tp2_at_points) + "\n";
      out_text += "tp3_at_points=" + IntegerToString(tp3_at_points) + "\n";
      out_text += "tp1_close_pct=" + DoubleToString(tp1_close_pct, 8) + "\n";
      out_text += "tp2_close_pct=" + DoubleToString(tp2_close_pct, 8) + "\n";
      out_text += "tp3_close_pct=" + DoubleToString(tp3_close_pct, 8) + "\n";

      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
      {
         out_text += "tp_level_"+IntegerToString(i)+"_enabled=" + IntegerToString(tp_levels[i].enabled?1:0) + "\n";
         out_text += "tp_level_"+IntegerToString(i)+"_type=" + IntegerToString((int)tp_levels[i].type) + "\n";
         out_text += "tp_level_"+IntegerToString(i)+"_target=" + DoubleToString(tp_levels[i].target, 8) + "\n";
         out_text += "tp_level_"+IntegerToString(i)+"_close_percent=" + DoubleToString(tp_levels[i].close_percent, 8) + "\n";
      }

      out_text += "be_enabled=" + IntegerToString(be_enabled?1:0) + "\n";
      out_text += "be_mode=" + IntegerToString((int)be_mode) + "\n";
      out_text += "be_at_r=" + DoubleToString(be_at_r, 8) + "\n";
      out_text += "be_at_points=" + IntegerToString(be_at_points) + "\n";
      out_text += "be_plus_points=" + IntegerToString(be_plus_points) + "\n";
      out_text += "be_lock_points=" + IntegerToString(be_lock_points) + "\n";
      out_text += "be_offset_points=" + IntegerToString(be_offset_points) + "\n";
      out_text += "be_once=" + IntegerToString(be_once?1:0) + "\n";

      out_text += "trailing_enabled=" + IntegerToString(trailing_enabled?1:0) + "\n";
      out_text += "trailing_mode=" + IntegerToString((int)trailing_mode) + "\n";
      out_text += "trailing_scope=" + IntegerToString((int)trailing_scope) + "\n";
      out_text += "trailing_only_profit=" + IntegerToString(trailing_only_profit?1:0) + "\n";
      out_text += "trailing_min_interval_ms=" + IntegerToString(trailing_min_interval_ms) + "\n";
      out_text += "trailing_start_profit_pips=" + DoubleToString(trailing_start_profit_pips, 8) + "\n";
      out_text += "trail_start_points=" + IntegerToString(trail_start_points) + "\n";
      out_text += "trail_step_points=" + IntegerToString(trail_step_points) + "\n";
      out_text += "trail_distance_points=" + IntegerToString(trail_distance_points) + "\n";
      out_text += "trail_pips_distance=" + DoubleToString(trail_pips_distance, 8) + "\n";
      out_text += "trail_pips_step=" + DoubleToString(trail_pips_step, 8) + "\n";
      out_text += "trail_pips_start=" + DoubleToString(trail_pips_start, 8) + "\n";
      out_text += "trail_pips_only_profit=" + IntegerToString(trail_pips_only_profit?1:0) + "\n";
      out_text += "trail_atr_period=" + IntegerToString(trail_atr_period) + "\n";
      out_text += "trail_atr_mult=" + DoubleToString(trail_atr_mult, 8) + "\n";
      out_text += "trail_atr_buffer_pips=" + DoubleToString(trail_atr_buffer_pips, 8) + "\n";
      out_text += "trail_ma_period=" + IntegerToString(trail_ma_period) + "\n";
      out_text += "trail_ma_method=" + IntegerToString((int)trail_ma_method) + "\n";
      out_text += "trail_ma_price=" + IntegerToString((int)trail_ma_price) + "\n";
      out_text += "trail_ma_shift=" + IntegerToString(trail_ma_shift) + "\n";
      out_text += "trail_ma_buffer_pips=" + DoubleToString(trail_ma_buffer_pips, 8) + "\n";
      out_text += "trail_sar_step=" + DoubleToString(trail_sar_step, 8) + "\n";
      out_text += "trail_sar_max=" + DoubleToString(trail_sar_max, 8) + "\n";
      out_text += "trail_sar_buffer_pips=" + DoubleToString(trail_sar_buffer_pips, 8) + "\n";
      out_text += "trail_hl_bars_back=" + IntegerToString(trail_hl_bars_back) + "\n";
      out_text += "trail_hl_lookback_bars=" + IntegerToString(trail_hl_lookback_bars) + "\n";
      out_text += "trail_hl_buffer_pips=" + DoubleToString(trail_hl_buffer_pips, 8) + "\n";
      out_text += "trail_fractal_left=" + IntegerToString(trail_fractal_left) + "\n";
      out_text += "trail_fractal_right=" + IntegerToString(trail_fractal_right) + "\n";
      out_text += "trail_fractal_buffer_pips=" + DoubleToString(trail_fractal_buffer_pips, 8) + "\n";
      out_text += "trail_partial_enabled=" + IntegerToString(trail_partial_enabled?1:0) + "\n";
      out_text += "trail_partial_every_r=" + DoubleToString(trail_partial_every_r, 8) + "\n";
      out_text += "trail_partial_close_pct=" + DoubleToString(trail_partial_close_pct, 8) + "\n";

      out_text += "oco_mode=" + IntegerToString((int)oco_mode) + "\n";
      out_text += "vorders_enabled=" + IntegerToString(vorders_enabled?1:0) + "\n";
      out_text += "vorders_virtual_sl_tp=" + IntegerToString(vorders_virtual_sl_tp?1:0) + "\n";
      out_text += "vorders_virtual_pending=" + IntegerToString(vorders_virtual_pending?1:0) + "\n";
      out_text += "vorders_poll_ms=" + IntegerToString(vorders_poll_ms) + "\n";

      out_text += "time_rule=" + IntegerToString((int)time_rule) + "\n";
      out_text += "allow_mon=" + IntegerToString(allow_mon?1:0) + "\n";
      out_text += "allow_tue=" + IntegerToString(allow_tue?1:0) + "\n";
      out_text += "allow_wed=" + IntegerToString(allow_wed?1:0) + "\n";
      out_text += "allow_thu=" + IntegerToString(allow_thu?1:0) + "\n";
      out_text += "allow_fri=" + IntegerToString(allow_fri?1:0) + "\n";
      out_text += "allow_sat=" + IntegerToString(allow_sat?1:0) + "\n";
      out_text += "allow_sun=" + IntegerToString(allow_sun?1:0) + "\n";
      out_text += "session_start_hour=" + IntegerToString(session_start_hour) + "\n";
      out_text += "session_start_min=" + IntegerToString(session_start_min) + "\n";
      out_text += "session_end_hour=" + IntegerToString(session_end_hour) + "\n";
      out_text += "session_end_min=" + IntegerToString(session_end_min) + "\n";
      out_text += "utc_offset_seconds=" + IntegerToString(utc_offset_seconds) + "\n";

      out_text += "notify_channel=" + IntegerToString((int)notify_channel) + "\n";
      out_text += "notify_on_trade=" + IntegerToString(notify_on_trade?1:0) + "\n";
      out_text += "notify_on_error=" + IntegerToString(notify_on_error?1:0) + "\n";
      out_text += "notify_use_sound=" + IntegerToString(notify_use_sound?1:0) + "\n";
      out_text += "notify_sound_ok=" + notify_sound_ok + "\n";
      out_text += "notify_sound_error=" + notify_sound_error + "\n";
      out_text += "notify_prefix=" + notify_prefix + "\n";

      out_text += "current_preset_name=" + current_preset_name + "\n";
      return true;
   }

   bool Deserialize(const string &in_text)
   {
      // Keep current values if something is missing.
      string lines[];
      string text = in_text;
      StringReplace(text, "\r", "");
      int n = StringSplit(text, '\n', lines);
      for(int i=0;i<n;i++)
      {
         string ln = TA_Trim(lines[i]);
         if(ln == "" || StringGetCharacter(ln,0) == '#')
            continue;

         int eq = StringFind(ln, "=");
         if(eq <= 0) continue;

         string k = TA_Trim(StringSubstr(ln, 0, eq));
         string v = TA_Trim(StringSubstr(ln, eq+1));

         // scalar ints/bools
         if(k=="ui_active_tab") ui_active_tab=(ENUM_TA_APP_TAB)StringToInteger(v);
         else if(k=="ui_minimized") ui_minimized=(StringToInteger(v)!=0);
         else if(k=="ui_lock_panel") ui_lock_panel=(StringToInteger(v)!=0);
         else if(k=="ui_show_debug") ui_show_debug=(StringToInteger(v)!=0);
         else if(k=="ui_theme_id") ui_theme_id=(int)StringToInteger(v);

         else if(k=="order_kind") order_kind=(ENUM_TA_ORDER_KIND)StringToInteger(v);
         else if(k=="deviation_points") deviation_points=(int)StringToInteger(v);
         else if(k=="slippage_points") slippage_points=(int)StringToInteger(v);
         else if(k=="order_comment") order_comment=v;
         else if(k=="allow_multiple_entries") allow_multiple_entries=(StringToInteger(v)!=0);

         else if(k=="risk_mode") risk_mode=(ENUM_TA_RISK_MODE)StringToInteger(v);
         else if(k=="risk_basis") risk_basis=(ENUM_TA_RISK_BASIS)StringToInteger(v);
         else if(k=="fixed_lots") fixed_lots=StringToDouble(v);
         else if(k=="risk_value") risk_value=StringToDouble(v);
         else if(k=="max_lot_cap") max_lot_cap=StringToDouble(v);
         else if(k=="round_to_step") round_to_step=(StringToInteger(v)!=0);

         else if(k=="sl_mode") sl_mode=(ENUM_TA_SL_MODE)StringToInteger(v);
         else if(k=="tp_mode") tp_mode=(ENUM_TA_TP_MODE)StringToInteger(v);
         else if(k=="sl_price") sl_price=StringToDouble(v);
         else if(k=="tp_price") tp_price=StringToDouble(v);
         else if(k=="sl_enabled") sl_enabled=(StringToInteger(v)!=0);
         else if(k=="tp_enabled") tp_enabled=(StringToInteger(v)!=0);
         else if(k=="sl_points") sl_points=(int)StringToInteger(v);
         else if(k=="tp_points") tp_points=(int)StringToInteger(v);
         else if(k=="rr_target") rr_target=StringToDouble(v);
         else if(k=="tp_from_rr") tp_from_rr=(StringToInteger(v)!=0);
         else if(k=="sl_required") sl_required=(StringToInteger(v)!=0);

         else if(k=="tp_partials_enabled") tp_partials_enabled=(StringToInteger(v)!=0);
         else if(k=="tp_partials_schema") tp_partials_schema=(ENUM_TA_PARTIAL_SCHEMA)StringToInteger(v);
         else if(k=="tp_partials_trigger") tp_partials_trigger=(ENUM_TA_PARTIAL_TRIGGER)StringToInteger(v);
         else if(k=="tp_partials_mode") tp_partials_mode=(ENUM_TA_PARTIALS_MODE)StringToInteger(v);
         else if(k=="tp_move_sl_to_be_after_tp1") tp_move_sl_to_be_after_tp1=(StringToInteger(v)!=0);
         else if(k=="tp_start_trailing_after_tp1") tp_start_trailing_after_tp1=(StringToInteger(v)!=0);
         else if(k=="tp1_at_r") tp1_at_r=StringToDouble(v);
         else if(k=="tp2_at_r") tp2_at_r=StringToDouble(v);
         else if(k=="tp3_at_r") tp3_at_r=StringToDouble(v);
         else if(k=="tp1_at_points") tp1_at_points=(int)StringToInteger(v);
         else if(k=="tp2_at_points") tp2_at_points=(int)StringToInteger(v);
         else if(k=="tp3_at_points") tp3_at_points=(int)StringToInteger(v);
         else if(k=="tp1_close_pct") tp1_close_pct=StringToDouble(v);
         else if(k=="tp2_close_pct") tp2_close_pct=StringToDouble(v);
         else if(k=="tp3_close_pct") tp3_close_pct=StringToDouble(v);

         else if(k=="be_enabled") be_enabled=(StringToInteger(v)!=0);
         else if(k=="be_mode") be_mode=(ENUM_TA_BE_MODE)StringToInteger(v);
         else if(k=="be_at_r") be_at_r=StringToDouble(v);
         else if(k=="be_at_points") be_at_points=(int)StringToInteger(v);
         else if(k=="be_plus_points") be_plus_points=(int)StringToInteger(v);
         else if(k=="be_lock_points") be_lock_points=(int)StringToInteger(v);
         else if(k=="be_offset_points") be_offset_points=(int)StringToInteger(v);
         else if(k=="be_once") be_once=(StringToInteger(v)!=0);

         else if(k=="trailing_enabled") trailing_enabled=(StringToInteger(v)!=0);
         else if(k=="trailing_mode") trailing_mode=(ENUM_TA_TRAIL_MODE)StringToInteger(v);
         else if(k=="trailing_scope") trailing_scope=(ENUM_TA_TRAIL_SCOPE)StringToInteger(v);
         else if(k=="trailing_only_profit") trailing_only_profit=(StringToInteger(v)!=0);
         else if(k=="trailing_min_interval_ms") trailing_min_interval_ms=(int)StringToInteger(v);
         else if(k=="trailing_start_profit_pips") trailing_start_profit_pips=StringToDouble(v);
         else if(k=="trail_start_points") trail_start_points=(int)StringToInteger(v);
         else if(k=="trail_step_points") trail_step_points=(int)StringToInteger(v);
         else if(k=="trail_distance_points") trail_distance_points=(int)StringToInteger(v);
         else if(k=="trail_pips_distance") trail_pips_distance=StringToDouble(v);
         else if(k=="trail_pips_step") trail_pips_step=StringToDouble(v);
         else if(k=="trail_pips_start") trail_pips_start=StringToDouble(v);
         else if(k=="trail_pips_only_profit") trail_pips_only_profit=(StringToInteger(v)!=0);
         else if(k=="trail_atr_period") trail_atr_period=(int)StringToInteger(v);
         else if(k=="trail_atr_mult") trail_atr_mult=StringToDouble(v);
         else if(k=="trail_atr_buffer_pips") trail_atr_buffer_pips=StringToDouble(v);
         else if(k=="trail_ma_period") trail_ma_period=(int)StringToInteger(v);
         else if(k=="trail_ma_method") trail_ma_method=(ENUM_MA_METHOD)StringToInteger(v);
         else if(k=="trail_ma_price") trail_ma_price=(ENUM_APPLIED_PRICE)StringToInteger(v);
         else if(k=="trail_ma_shift") trail_ma_shift=(int)StringToInteger(v);
         else if(k=="trail_ma_buffer_pips") trail_ma_buffer_pips=StringToDouble(v);
         else if(k=="trail_sar_step") trail_sar_step=StringToDouble(v);
         else if(k=="trail_sar_max") trail_sar_max=StringToDouble(v);
         else if(k=="trail_sar_buffer_pips") trail_sar_buffer_pips=StringToDouble(v);
         else if(k=="trail_hl_bars_back") trail_hl_bars_back=(int)StringToInteger(v);
         else if(k=="trail_hl_lookback_bars") trail_hl_lookback_bars=(int)StringToInteger(v);
         else if(k=="trail_hl_buffer_pips") trail_hl_buffer_pips=StringToDouble(v);
         else if(k=="trail_fractal_left") trail_fractal_left=(int)StringToInteger(v);
         else if(k=="trail_fractal_right") trail_fractal_right=(int)StringToInteger(v);
         else if(k=="trail_fractal_buffer_pips") trail_fractal_buffer_pips=StringToDouble(v);
         else if(k=="trail_partial_enabled") trail_partial_enabled=(StringToInteger(v)!=0);
         else if(k=="trail_partial_every_r") trail_partial_every_r=StringToDouble(v);
         else if(k=="trail_partial_close_pct") trail_partial_close_pct=StringToDouble(v);

         else if(k=="oco_mode") oco_mode=(ENUM_TA_OCO_MODE)StringToInteger(v);
         else if(k=="vorders_enabled") vorders_enabled=(StringToInteger(v)!=0);
         else if(k=="vorders_virtual_sl_tp") vorders_virtual_sl_tp=(StringToInteger(v)!=0);
         else if(k=="vorders_virtual_pending") vorders_virtual_pending=(StringToInteger(v)!=0);
         else if(k=="vorders_poll_ms") vorders_poll_ms=(int)StringToInteger(v);

         else if(k=="time_rule") time_rule=(ENUM_TA_TIME_RULE)StringToInteger(v);
         else if(k=="allow_mon") allow_mon=(StringToInteger(v)!=0);
         else if(k=="allow_tue") allow_tue=(StringToInteger(v)!=0);
         else if(k=="allow_wed") allow_wed=(StringToInteger(v)!=0);
         else if(k=="allow_thu") allow_thu=(StringToInteger(v)!=0);
         else if(k=="allow_fri") allow_fri=(StringToInteger(v)!=0);
         else if(k=="allow_sat") allow_sat=(StringToInteger(v)!=0);
         else if(k=="allow_sun") allow_sun=(StringToInteger(v)!=0);
         else if(k=="session_start_hour") session_start_hour=(int)StringToInteger(v);
         else if(k=="session_start_min") session_start_min=(int)StringToInteger(v);
         else if(k=="session_end_hour") session_end_hour=(int)StringToInteger(v);
         else if(k=="session_end_min") session_end_min=(int)StringToInteger(v);
         else if(k=="utc_offset_seconds") utc_offset_seconds=(int)StringToInteger(v);

         else if(k=="notify_channel") notify_channel=(ENUM_TA_NOTIFY_CHANNEL)StringToInteger(v);
         else if(k=="notify_on_trade") notify_on_trade=(StringToInteger(v)!=0);
         else if(k=="notify_on_error") notify_on_error=(StringToInteger(v)!=0);
         else if(k=="notify_use_sound") notify_use_sound=(StringToInteger(v)!=0);
         else if(k=="notify_sound_ok") notify_sound_ok=v;
         else if(k=="notify_sound_error") notify_sound_error=v;
         else if(k=="notify_prefix") notify_prefix=v;

         else if(k=="current_preset_name") current_preset_name=v;

         // tp level fields
         else if(StringFind(k, "tp_level_") == 0)
         {
            // tp_level_<i>_<field>
            string rest = StringSubstr(k, 9);
            int us = StringFind(rest, "_");
            if(us > 0)
            {
               int idx = (int)StringToInteger(StringSubstr(rest, 0, us));
               string fld = StringSubstr(rest, us+1);
               if(idx>=0 && idx<TA_MAX_TP_LEVELS)
               {
                  if(fld=="enabled") tp_levels[idx].enabled = (StringToInteger(v)!=0);
                  else if(fld=="type") tp_levels[idx].type = (TA_TargetType)StringToInteger(v);
                  else if(fld=="target") tp_levels[idx].target = StringToDouble(v);
                  else if(fld=="close_percent") tp_levels[idx].close_percent = StringToDouble(v);
               }
            }
         }
      }

      // Keep legacy fields consistent
      SyncLegacy();
      return true;
   }
};

#endif // __TA_STATE_MQH__
//+------------------------------------------------------------------+

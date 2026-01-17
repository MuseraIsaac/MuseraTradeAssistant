//+------------------------------------------------------------------+
//|                                             TA_BrokerRules.mqh   |
//|                      MuseraTradeAssistant (project include)      |
//|                                  (c) 2026, Musera Isaac          |
//+------------------------------------------------------------------+
//  Broker & symbol constraints helper.
//
//  Path (expected):
//  MQL5\Experts\MuseraTradeAssistant\include\TA_BrokerRules.mqh
//
//  Responsibilities:
//   - Read broker/symbol constraints (volume min/max/step, stops/freeze level, tick size/value, etc)
//   - Provide normalization helpers (price/volume)
//   - Provide validation helpers for SL/TP distances for market/pending orders
//
//  Notes:
//   - This module is intentionally self-contained and safe to include widely.
//   - It is designed to be used from TA_State / TA_OrderBuilder / managers.
//+------------------------------------------------------------------+
#property strict

#ifndef __TA_BROKERRULES_MQH__
#define __TA_BROKERRULES_MQH__

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"

//---------------------------- Internal helpers ----------------------------//
bool TA__IsBuyType(const ENUM_ORDER_TYPE t)
{
   return (t == ORDER_TYPE_BUY ||
           t == ORDER_TYPE_BUY_LIMIT ||
           t == ORDER_TYPE_BUY_STOP ||
           t == ORDER_TYPE_BUY_STOP_LIMIT);
}

bool TA__IsSellType(const ENUM_ORDER_TYPE t)
{
   return (t == ORDER_TYPE_SELL ||
           t == ORDER_TYPE_SELL_LIMIT ||
           t == ORDER_TYPE_SELL_STOP ||
           t == ORDER_TYPE_SELL_STOP_LIMIT);
}

//---------------------------- TA_BrokerRules ----------------------------//
class TA_BrokerRules
{
private:
   string m_symbol;
   bool   m_ready;

   int    m_digits;
   double m_point;

   double m_tick_size;
   double m_tick_value;
   double m_contract_size;

   double m_lot_min;
   double m_lot_max;
   double m_lot_step;

   int    m_stops_level_points;   // SYMBOL_TRADE_STOPS_LEVEL (points)
   int    m_freeze_level_points;  // SYMBOL_TRADE_FREEZE_LEVEL (points)

public:
   TA_BrokerRules()
   {
      m_symbol             = "";
      m_ready              = false;
      m_digits             = 0;
      m_point              = 0.0;
      m_tick_size          = 0.0;
      m_tick_value         = 0.0;
      m_contract_size      = 0.0;
      m_lot_min            = 0.0;
      m_lot_max            = 0.0;
      m_lot_step           = 0.0;
      m_stops_level_points = 0;
      m_freeze_level_points= 0;
   }

   bool Init(const TA_Context &ctx)
   {
      m_symbol = ctx.symbol;
      return Refresh();
   }

   bool Refresh()
   {
      if(m_symbol == "")
         m_symbol = _Symbol;

      if(!SymbolInfoInteger(m_symbol, SYMBOL_SELECT))
         SymbolSelect(m_symbol, true);

      m_digits        = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_point         = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      m_tick_size     = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      if(m_tick_size <= 0.0) m_tick_size = m_point;

      m_tick_value    = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      m_contract_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);

      m_lot_min       = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      m_lot_max       = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      m_lot_step      = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

      m_stops_level_points  = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      m_freeze_level_points = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);

      // Minimal sanity
      if(m_point <= 0.0)  m_point = 0.00001;
      if(m_digits < 0)    m_digits = 5;
      if(m_lot_min <= 0.0) m_lot_min = 0.01;
      if(m_lot_max <= 0.0) m_lot_max = m_lot_min;
      if(m_lot_step <= 0.0) m_lot_step = m_lot_min;

      m_ready = true;
      return true;
   }

   // ---------------- Getters ----------------
   bool   Ready() const              { return m_ready; }
   string Symbol() const             { return m_symbol; }

   int    Digits() const             { return m_digits; }
   double Point() const              { return m_point; }
   double TickSize() const           { return m_tick_size; }
   double TickValue() const          { return m_tick_value; }
   double ContractSize() const       { return m_contract_size; }

   double LotMin() const             { return m_lot_min; }
   double LotMax() const             { return m_lot_max; }
   double LotStep() const            { return m_lot_step; }

   int    StopsLevelPoints() const   { return m_stops_level_points; }
   int    FreezeLevelPoints() const  { return m_freeze_level_points; }

   double StopsLevelPrice() const    { return (double)m_stops_level_points * m_point; }
   double FreezeLevelPrice() const   { return (double)m_freeze_level_points * m_point; }

   // ---------------- Normalization ----------------
   double NormalizePrice(const double price) const
   {
      return NormalizeDouble(price, m_digits);
   }

   double ClampLots(double lots) const
   {
      if(!TA_IsFinite(lots)) lots = m_lot_min;
      lots = TA_Clamp(lots, m_lot_min, m_lot_max);
      return lots;
   }

   double NormalizeLots(double lots) const
   {
      // Delegate to shared helper (keeps rounding behavior consistent).
      return TA_NormalizeVolume(m_symbol, lots);
   }

   // ---------------- Validation helpers ----------------
   int MinStopsPointsForEntry() const
   {
      // Stops level is the hard minimum for SL/TP placement.
      // Freeze level is a restriction for modifications near the price.
      // For safety in a UI tool we consider the max.
      int p = m_stops_level_points;
      if(m_freeze_level_points > p)
         p = m_freeze_level_points;
      if(p < 0) p = 0;
      return p;
   }

   double MinStopsPriceForEntry() const
   {
      return (double)MinStopsPointsForEntry() * m_point;
   }

   // Validate SL/TP relative positioning + min distance.
   bool ValidateSLTP(const double entry_price,
                     const double sl,
                     const double tp,
                     const ENUM_ORDER_TYPE order_type,
                     string &err) const
   {
      err = "";

      if(!m_ready)
      {
         err = "Broker rules not initialized";
         return false;
      }

      // If SL/TP are 0, treat as not set (valid).
      const bool has_sl = (sl > 0.0);
      const bool has_tp = (tp > 0.0);

      if(!has_sl && !has_tp)
         return true;

      const bool is_buy  = TA__IsBuyType(order_type);
      const bool is_sell = TA__IsSellType(order_type);

      if(!is_buy && !is_sell)
      {
         err = "Unsupported order type";
         return false;
      }

      const double min_dist = MinStopsPriceForEntry();

      if(is_buy)
      {
         if(has_sl)
         {
            if(!(sl < entry_price))
            {
               err = "For BUY, SL must be below entry";
               return false;
            }
            if((entry_price - sl) < min_dist)
            {
               err = "For BUY, SL is too close (min " + DoubleToString(min_dist, m_digits) + ")";
               return false;
            }
         }
         if(has_tp)
         {
            if(!(tp > entry_price))
            {
               err = "For BUY, TP must be above entry";
               return false;
            }
            if((tp - entry_price) < min_dist)
            {
               err = "For BUY, TP is too close (min " + DoubleToString(min_dist, m_digits) + ")";
               return false;
            }
         }
      }
      else // sell
      {
         if(has_sl)
         {
            if(!(sl > entry_price))
            {
               err = "For SELL, SL must be above entry";
               return false;
            }
            if((sl - entry_price) < min_dist)
            {
               err = "For SELL, SL is too close (min " + DoubleToString(min_dist, m_digits) + ")";
               return false;
            }
         }
         if(has_tp)
         {
            if(!(tp < entry_price))
            {
               err = "For SELL, TP must be below entry";
               return false;
            }
            if((entry_price - tp) < min_dist)
            {
               err = "For SELL, TP is too close (min " + DoubleToString(min_dist, m_digits) + ")";
               return false;
            }
         }
      }

      return true;
   }

   // Adjust SL/TP outward if too close. Useful when user drags lines.
   // Returns true if (possibly adjusted) values are valid, false if it cannot repair.
   bool EnsureStopsDistance(double &sl,
                            double &tp,
                            const ENUM_ORDER_TYPE order_type,
                            const double entry_price) const
   {
      string err;
      if(ValidateSLTP(entry_price, sl, tp, order_type, err))
      {
         sl = (sl > 0.0 ? NormalizePrice(sl) : 0.0);
         tp = (tp > 0.0 ? NormalizePrice(tp) : 0.0);
         return true;
      }

      const bool is_buy  = TA__IsBuyType(order_type);
      const bool is_sell = TA__IsSellType(order_type);
      if(!is_buy && !is_sell) return false;

      const double min_dist = MinStopsPriceForEntry();

      // Only repair "too close" situations. If direction is wrong, do not guess.
      if(is_buy)
      {
         if(sl > 0.0 && sl >= entry_price) return false;
         if(tp > 0.0 && tp <= entry_price) return false;

         if(sl > 0.0 && (entry_price - sl) < min_dist)
            sl = entry_price - min_dist;

         if(tp > 0.0 && (tp - entry_price) < min_dist)
            tp = entry_price + min_dist;
      }
      else
      {
         if(sl > 0.0 && sl <= entry_price) return false;
         if(tp > 0.0 && tp >= entry_price) return false;

         if(sl > 0.0 && (sl - entry_price) < min_dist)
            sl = entry_price + min_dist;

         if(tp > 0.0 && (entry_price - tp) < min_dist)
            tp = entry_price - min_dist;
      }

      // Normalize and validate again
      sl = (sl > 0.0 ? NormalizePrice(sl) : 0.0);
      tp = (tp > 0.0 ? NormalizePrice(tp) : 0.0);

      return ValidateSLTP(entry_price, sl, tp, order_type, err);
   }

   // Quick checks
   bool IsTradeAllowed() const
   {
      // Terminal & EA setting checks:
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false;
      if(!MQLInfoInteger(MQL_TRADE_ALLOWED))          return false;

      // Symbol trade mode check:
      long mode = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
      if(mode == SYMBOL_TRADE_MODE_DISABLED) return false;

      return true;
   }
};

#endif // __TA_BROKERRULES_MQH__

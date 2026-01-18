//+------------------------------------------------------------------+
//|                                           TA_Breakeven.mqh        |
//|                                  (c) 2026, Musera Isaac           |
//|  Break-even manager for MuseraTradeAssistant.                      |
//|                                                                    |
//|  Moves SL to Entry +/- BE_Offset once price reaches a trigger.     |
//|  Trigger modes:                                                    |
//|    - By R-multiple (profit >= R * initial_risk)                    |
//|    - By points (profit >= trigger_points)                          |
//|                                                                    |
//|  Expected TA_State fields (define in TA_State.mqh):                |
//|    bool   be_enabled;                                              |
//|    ENUM_TA_BE_MODE be_mode;        // TA_BE_AT_R / TA_BE_AT_POINTS |
//|    double be_at_r;                   // e.g. 1.0 = at 1R           |
//|    int    be_at_points;              // trigger in points          |
//|    int    be_plus_points;            // new SL offset in points    |
//|    bool   be_once;                   // apply only once per pos    |
//|                                                                    |
//|  Notes:                                                           |
//|   - This module tracks tickets registered by the EA (post entry).  |
//|   - It intentionally depends on other project includes.            |
//+------------------------------------------------------------------+
#ifndef __TA_BREAKEVEN_MQH__
#define __TA_BREAKEVEN_MQH__

#include <Trade/Trade.mqh>

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"

#ifndef TA_BE_MAX_TRACK
#define TA_BE_MAX_TRACK 128
#endif

// A small epsilon to avoid re-sending identical SL values
#ifndef TA_BE_PRICE_EPS
#define TA_BE_PRICE_EPS  (1e-10)
#endif

//+------------------------------------------------------------------+
//| Break-even manager                                                 |
//+------------------------------------------------------------------+
class TA_Breakeven
{
private:
   struct BE_Item
   {
      ulong     ticket;
      string    symbol;
      long      pos_type;       // POSITION_TYPE_BUY / POSITION_TYPE_SELL
      double    entry_price;    // POSITION_PRICE_OPEN
      double    risk_points;    // abs(entry - initial_sl) in points (0 if unknown)
      bool      fired;          // break-even already applied
      datetime  ts_registered;
   };

   BE_Item m_items[TA_BE_MAX_TRACK];
   int     m_count;

   // Cached broker symbol info (for current chart symbol)
   string  m_symbol;
   int     m_digits;
   double  m_point;

public:
   TA_Breakeven() : m_count(0), m_symbol(""), m_digits(0), m_point(0.0) {}

   // Initialize with current state and broker settings
   bool Init(const TA_Context &ctx, const TA_State &state, const TA_BrokerRules &broker)
   {

      m_symbol = ctx.symbol;
      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      // Clear tracked items
      Clear();
      return true;
   }

   // Called when user changes BE settings (from UI / preset load)
   void SyncConfig(const TA_Context &ctx, const TA_State &state)
   {
      // If BE is disabled, drop all tracked items.
      if(!state.be_enabled)
      {
         Clear();
         return;
      }

      // If symbol changed, refresh cached symbol info.
      if(m_symbol != ctx.symbol)
      {
         m_symbol = ctx.symbol;
         m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
         m_point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      }
   }

   // Register a position ticket to be managed by BE
   bool RegisterPosition(const ulong ticket, const TA_Context &ctx, const TA_State &state)
   {
      if(!state.be_enabled) return false;

      // Already tracked?
      const int idx = Find(ticket);
      if(idx >= 0) return true;

      if(m_count >= TA_BE_MAX_TRACK)
      {
         TA_LogWarn("TA_Breakeven: track list full, cannot register ticket=" + (string)ticket);
         return false;
      }

      if(!PositionSelectByTicket(ticket))
      {
         TA_LogWarn("TA_Breakeven: PositionSelectByTicket failed, ticket=" + (string)ticket);
         return false;
      }

      BE_Item item;
      item.ticket        = ticket;
      item.symbol        = PositionGetString(POSITION_SYMBOL);
      item.pos_type      = (long)PositionGetInteger(POSITION_TYPE);
      item.entry_price   = PositionGetDouble(POSITION_PRICE_OPEN);
      item.risk_points   = 0.0;
      item.fired         = false;
      item.ts_registered = TimeCurrent();

      // Snapshot initial risk if SL exists
      const double sl = PositionGetDouble(POSITION_SL);
      if(sl > 0.0)
         item.risk_points = (double)TA_PriceToPoints(item.symbol, MathAbs(item.entry_price - sl));

      m_items[m_count++] = item;

      TA_LogInfo("BE registered: ticket=" + (string)ticket + " sym=" + item.symbol);
      return true;
   }

   // Unregister a tracked ticket
   void UnregisterPosition(const ulong ticket)
   {
      const int idx = Find(ticket);
      if(idx < 0) return;
      RemoveAt(idx);
   }

   // Main processing (recommended from OnTimer)
   void OnTimer(const TA_Context &ctx, const TA_State &state)
   {
      if(!state.be_enabled) return;
      if(m_count <= 0)      return;

      // Iterate backwards in case we remove items
      for(int i=m_count-1; i>=0; --i)
      {
         const ulong ticket = m_items[i].ticket;

         if(!PositionSelectByTicket(ticket))
         {
            // Position no longer exists (closed)
            RemoveAt(i);
            continue;
         }

         // Symbol changed? keep updated per item
         const string sym = PositionGetString(POSITION_SYMBOL);
         const long   type = (long)PositionGetInteger(POSITION_TYPE);

         // If the position moved to another symbol unexpectedly, we still handle it.
         const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         const double sl    = PositionGetDouble(POSITION_SL);
         const double tp    = PositionGetDouble(POSITION_TP);

         // If risk points missing and SL exists now, snapshot it
         if(m_items[i].risk_points <= 0.0 && sl > 0.0)
            m_items[i].risk_points = (double)TA_PriceToPoints(sym, MathAbs(entry - sl));

         // If BE already fired and be_once is true, we can stop tracking
         if(m_items[i].fired && state.be_once)
         {
            RemoveAt(i);
            continue;
         }

         if(m_items[i].fired && !state.be_once)
         {
            // If not "once", we still do nothing after first fire (by design).
            // Users who want BE to re-apply can reset by toggling BE or preset load.
            continue;
         }

         double profit_points = 0.0;
         if(!GetProfitPoints(sym, type, entry, profit_points))
            continue;

         double trigger_points = 0.0;
         if(!GetTriggerPoints(sym, state, m_items[i].risk_points, trigger_points))
            continue;

         if(profit_points + 1e-6 < trigger_points)
            continue; // not yet at trigger

         // Compute desired SL at break-even (+offset in points)
         double desired_sl = 0.0;
         if(!ComputeDesiredSL(sym, type, entry, state.be_plus_points, desired_sl))
            continue;

         // If current SL already better/equal, skip
         if(!IsImprovement(type, sl, desired_sl))
         {
            m_items[i].fired = true; // treat as done (already at/above BE)
            continue;
         }

         // Broker stop/freeze validation relative to current price
         if(!ValidateStopDistance(sym, type, desired_sl))
            continue;

         // Send SLTP modification
         if(ModifySLTP(ticket, sym, desired_sl, tp, ctx.magic))
         {
            m_items[i].fired = true;
            TA_LogInfo("BE applied: ticket=" + (string)ticket + " SL=" + DoubleToString(desired_sl, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)));
         }
      }
   }

   // Optional: use for faster response if you call it from OnTick
   void OnTick(const TA_Context &ctx, const TA_State &state)
   {
      // Intentionally empty. You can route OnTick to OnTimer logic if desired.
   }

   // Trade transactions hook (lightweight cleanup)
   void OnTradeTransaction(const TA_Context &ctx,
                           const TA_State &state,
                           const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {

      // If a position is closed, it will disappear from PositionSelectByTicket()
      // and will be removed on next OnTimer().
      // Still, we can proactively remove on DEAL for speed.
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      {
         // trans.position is valid for deal adds
         if(trans.position > 0)
         {
            // If the deal closed the position, POSITION_VOLUME becomes 0 (not always reliable here).
            // We'll just let OnTimer verify existence; this is safe no-op.
         }
      }
   }

   // Chart event hook (no-op for now)
   void OnChartEvent(const TA_Context &ctx,
                     const TA_State &state,
                     const int id,
                     const long &lparam,
                     const double &dparam,
                     const string &sparam)
   {
   }

private:
   void Clear()
   {
      m_count = 0;
      // no need to zero m_items (m_count defines active range)
   }

   int Find(const ulong ticket) const
   {
      for(int i=0; i<m_count; ++i)
         if(m_items[i].ticket == ticket)
            return i;
      return -1;
   }

   void RemoveAt(const int idx)
   {
      if(idx < 0 || idx >= m_count) return;
      for(int i=idx; i<m_count-1; ++i)
         m_items[i] = m_items[i+1];
      m_count--;
   }

   // Calculate profit in points from entry to current price (Bid/Ask)
   bool GetProfitPoints(const string sym, const long pos_type, const double entry, double &out_points) const
   {
      double bid=0.0, ask=0.0;
      if(!SymbolInfoDouble(sym, SYMBOL_BID, bid) || !SymbolInfoDouble(sym, SYMBOL_ASK, ask))
         return false;

      double diff = 0.0;
      if(pos_type == POSITION_TYPE_BUY)
         diff = bid - entry;
      else if(pos_type == POSITION_TYPE_SELL)
         diff = entry - ask;
      else
         return false;

      out_points = (double)TA_PriceToPoints(sym, diff);
      return true;
   }

   // Decide trigger points based on selected mode
   bool GetTriggerPoints(const string sym, const TA_State &state, const double risk_points, double &out_trigger_points) const
   {
      if(state.be_mode == TA_BE_AT_POINTS)
      {
         out_trigger_points = (double)MathMax(0, state.be_at_points);
         return true;
      }

      // TA_BE_AT_R
      if(risk_points <= 0.0)
      {
         TA_LogWarn("TA_Breakeven: cannot use R-mode without initial SL (risk_points=0). sym=" + sym);
         return false;
      }

      const double r = state.be_at_r;
      if(r <= 0.0)
      {
         out_trigger_points = 0.0;
         return true;
      }

      out_trigger_points = risk_points * r;
      return true;
   }

   // Compute BE SL price (entry +/- offset points)
   bool ComputeDesiredSL(const string sym, const long pos_type, const double entry, const int plus_points, double &out_sl) const
   {
      const double px_off = TA_PointsToPrice(sym, plus_points);

      if(pos_type == POSITION_TYPE_BUY)
         out_sl = entry + px_off;
      else if(pos_type == POSITION_TYPE_SELL)
         out_sl = entry - px_off;
      else
         return false;

      out_sl = TA_NormalizePrice(sym, out_sl);
      return true;
   }

   // Determine if desired SL is an improvement compared to current SL
   bool IsImprovement(const long pos_type, const double current_sl, const double desired_sl) const
   {
      if(current_sl <= 0.0)
         return true;

      if(pos_type == POSITION_TYPE_BUY)
         return (desired_sl > current_sl + TA_BE_PRICE_EPS);
      if(pos_type == POSITION_TYPE_SELL)
         return (desired_sl < current_sl - TA_BE_PRICE_EPS);

      return false;
   }

   // Check broker min stop distance & freeze relative to current Bid/Ask
   bool ValidateStopDistance(const string sym, const long pos_type, const double desired_sl) const
   {
      const int stops_level  = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
      const int freeze_level = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
      const int min_level    = (int)MathMax(stops_level, freeze_level);

      if(min_level <= 0) return true;

      const double point = SymbolInfoDouble(sym, SYMBOL_POINT);

      double bid=0.0, ask=0.0;
      if(!SymbolInfoDouble(sym, SYMBOL_BID, bid) || !SymbolInfoDouble(sym, SYMBOL_ASK, ask))
         return false;

      if(pos_type == POSITION_TYPE_BUY)
      {
         // SL must be below Bid by at least min_level points
         const double dist_points = (bid - desired_sl) / point;
         if(dist_points < (double)min_level)
         {
            TA_LogWarn("TA_Breakeven: desired SL too close for BUY. min=" + (string)min_level + " dist=" + DoubleToString(dist_points,1));
            return false;
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         // SL must be above Ask by at least min_level points
         const double dist_points = (desired_sl - ask) / point;
         if(dist_points < (double)min_level)
         {
            TA_LogWarn("TA_Breakeven: desired SL too close for SELL. min=" + (string)min_level + " dist=" + DoubleToString(dist_points,1));
            return false;
         }
      }
      return true;
   }

   // Send SL/TP modification using TRADE_ACTION_SLTP (ticket-based, works in hedging/netting)
   bool ModifySLTP(const ulong ticket,
                   const string sym,
                   const double new_sl,
                   const double keep_tp,
                   const ulong magic)
   {
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      req.action   = TRADE_ACTION_SLTP;
      req.position = ticket;
      req.symbol   = sym;
      req.sl       = TA_NormalizePrice(sym, new_sl);
      req.tp       = keep_tp; // keep existing TP
      req.magic    = magic;

      const bool ok = OrderSend(req, res);
      if(!ok)
      {
         TA_LogError("TA_Breakeven: OrderSend(SLTP) failed. ticket=" + (string)ticket + " err=" + (string)GetLastError());
         return false;
      }

      // Accept "DONE" and common success codes
      if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL)
         return true;

      TA_LogWarn("TA_Breakeven: SLTP retcode=" + (string)res.retcode + " comment=" + res.comment);
      return false;
   }
};

#endif // __TA_BREAKEVEN_MQH__

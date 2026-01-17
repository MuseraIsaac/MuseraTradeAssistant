//+------------------------------------------------------------------+
//|                                         trailing/Trail_Pips.mqh   |
//|                                  (c) 2026, Musera Isaac           |
//|  Fixed-distance (pips) trailing stop strategy for                  |
//|  MuseraTradeAssistant.                                             |
//|                                                                    |
//|  Logic (high level):                                               |
//|   - After price moves in your favor by StartPips, begin trailing   |
//|   - Keep SL DistPips behind current price                          |
//|   - Only update if SL changes by at least StepPips                 |
//|   - Optional: only trail once SL is in profit (OnlyProfit=true)    |
//|                                                                    |
//|  Expected TA_State fields (define in TA_State.mqh):                |
//|    double trail_pips_distance;     // SL distance (pips)           |
//|    double trail_pips_step;         // min SL update step (pips)    |
//|    double trail_pips_start;        // start trailing after (pips)  |
//|    bool   trail_pips_only_profit;  // require SL beyond entry?     |
//+------------------------------------------------------------------+
#property strict

#ifndef __MUSERA_TA_TRAIL_PIPS_MQH__
#define __MUSERA_TA_TRAIL_PIPS_MQH__

#include "Trail_Base.mqh"

// Forward declarations
struct TA_Context;
class TA_State;
class TA_BrokerRules;

//+------------------------------------------------------------------+
//| Trail_Pips                                                        |
//+------------------------------------------------------------------+
class Trail_Pips : public Trail_Base
{
private:
   ulong  m_magic;
   string m_symbol;

   // Strategy parameters (in pips)
   double m_dist_pips;
   double m_step_pips;
   double m_start_pips;
   bool   m_only_profit;

   // Symbol info
   int    m_digits;
   double m_point;
   double m_pip;              // 1 pip in price units
   double m_stops_level_px;   // min stop distance in price units (if provided by broker)
   double m_freeze_level_px;  // freeze distance in price units

   // Managed position tickets
   ulong  m_tickets[];

public:
   Trail_Pips() : Trail_Base("Pips")
   {
      m_magic          = 0;
      m_symbol         = "";
      m_dist_pips      = 20;
      m_step_pips      = 1;
      m_start_pips     = 0;
      m_only_profit    = true;

      m_digits         = 0;
      m_point          = 0.0;
      m_pip            = 0.0;
      m_stops_level_px = 0.0;
      m_freeze_level_px= 0.0;

      ArrayResize(m_tickets, 0);
   }

   // Called once after EA init (or when symbol changes).
   virtual bool Init(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &br)
   {
      m_magic  = (ulong)ctx.magic;
      m_symbol = (string)ctx.symbol;

      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      // 5/3-digit FX symbols typically use pip = point*10
      if(m_digits==3 || m_digits==5)
         m_pip = m_point * 10.0;
      else
         m_pip = m_point;

      // These are in points; convert to price
      long stops_pts  = 0;
      long freeze_pts = 0;
      SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL, stops_pts);
      SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze_pts);

      m_stops_level_px  = (double)stops_pts  * m_point;
      m_freeze_level_px = (double)freeze_pts * m_point;

      SyncConfig(ctx, st);
      return true;
   }

   virtual void Reset()
   {
      ArrayResize(m_tickets, 0);
   }

   virtual void SyncConfig(const TA_Context &ctx, const TA_State &st)
   {
      // Read config from TA_State (define these fields in TA_State.mqh)
      m_dist_pips   = st.trail_pips_distance;
      m_step_pips   = st.trail_pips_step;
      m_start_pips  = st.trail_pips_start;
      m_only_profit = st.trail_pips_only_profit;

      // Guardrails / defaults
      if(m_dist_pips <= 0)  m_dist_pips  = 20;
      if(m_step_pips <= 0)  m_step_pips  = 1;
      if(m_start_pips <  0) m_start_pips = 0;
   }

   virtual void RegisterPosition(const ulong position_ticket, const TA_Context &ctx, const TA_State &st)
   {
      if(position_ticket == 0) return;
      if(FindTicket(position_ticket) >= 0) return;

      const int n = ArraySize(m_tickets);
      ArrayResize(m_tickets, n+1);
      m_tickets[n] = position_ticket;
   }

   virtual void UnregisterPosition(const ulong position_ticket)
   {
      const int idx = FindTicket(position_ticket);
      if(idx < 0) return;

      const int n = ArraySize(m_tickets);
      for(int i=idx; i<n-1; i++)
         m_tickets[i] = m_tickets[i+1];
      ArrayResize(m_tickets, n-1);
   }

   virtual void OnTradeTransaction(const TA_Context &ctx, const TA_State &st,
                                   const MqlTradeTransaction &trans,
                                   const MqlTradeRequest &request,
                                   const MqlTradeResult &result)
   {
      // If a position is closed, unregister it (defensive).
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      {
         // When a closing deal is added, position may disappear quickly.
         // We'll also prune in OnTimer().
      }
   }

   virtual void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      // Keep symbol/magic updated if needed
      m_magic  = (ulong)ctx.magic;
      m_symbol = (string)ctx.symbol;

      // Iterate backwards so we can remove invalid tickets in-place
      for(int i = ArraySize(m_tickets)-1; i >= 0; i--)
      {
         const ulong ticket = m_tickets[i];

         if(!PositionSelectByTicket(ticket))
         {
            RemoveAt(i);
            continue;
         }

         // Only manage positions on this chart symbol & matching magic
         const string sym = (string)PositionGetString(POSITION_SYMBOL);
         if(sym != m_symbol)
            continue;

         const long magic = (long)PositionGetInteger(POSITION_MAGIC);
         if((ulong)magic != m_magic)
            continue;

         const long   type = (long)PositionGetInteger(POSITION_TYPE);
         const double open = (double)PositionGetDouble(POSITION_PRICE_OPEN);
         const double cur_sl = (double)PositionGetDouble(POSITION_SL);

         const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
         const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);

         const bool is_buy = (type == POSITION_TYPE_BUY);

         // Use closing-side price for trailing reference
         const double px = (is_buy ? bid : ask);

         // How far price has moved in our favor (pips)
         const double move_pips = (is_buy ? (px - open)/m_pip : (open - px)/m_pip);
         if(move_pips < m_start_pips)
            continue;

         // Desired SL: keep DistPips behind price
         double new_sl = (is_buy ? (px - m_dist_pips*m_pip) : (px + m_dist_pips*m_pip));

         // Optional: only set SL beyond entry (lock profit) before trailing further
         if(m_only_profit)
         {
            if(is_buy && new_sl <= open)  continue;
            if(!is_buy && new_sl >= open) continue;
         }

         // Respect broker min stop distance (stops level)
         if(m_stops_level_px > 0.0)
         {
            if(is_buy)
            {
               const double min_sl = px - m_stops_level_px;
               if(new_sl > min_sl) new_sl = min_sl; // keep distance
            }
            else
            {
               const double max_sl = px + m_stops_level_px;
               if(new_sl < max_sl) new_sl = max_sl;
            }
         }

         // If freeze level exists, avoid modifying when too close to current price
         if(m_freeze_level_px > 0.0)
         {
            if(MathAbs(px - new_sl) < m_freeze_level_px)
               continue;
         }

         // Step logic: only move SL forward by at least StepPips
         const double step_px = m_step_pips * m_pip;

         if(cur_sl > 0.0)
         {
            if(is_buy)
            {
               // Buy SL only moves up (increase)
               if(new_sl <= cur_sl + step_px)
                  continue;
            }
            else
            {
               // Sell SL only moves down (decrease)
               if(new_sl >= cur_sl - step_px)
                  continue;
            }
         }
         else
         {
            // If no SL, still require it to be valid distance (already handled)
         }

         // Normalize and send
         string err;
         if(!ModifySL(ticket, m_magic, new_sl, err))
         {
            // Don't spam logs; print only when something meaningful fails
            Print("Trail_Pips ModifySL failed: ticket=", (string)ticket, " err=", err);
         }
      }
   }

private:
   int FindTicket(const ulong ticket) const
   {
      const int n = ArraySize(m_tickets);
      for(int i=0; i<n; i++)
         if(m_tickets[i] == ticket)
            return i;
      return -1;
   }

   void RemoveAt(const int idx)
   {
      const int n = ArraySize(m_tickets);
      if(idx < 0 || idx >= n) return;

      for(int i=idx; i<n-1; i++)
         m_tickets[i] = m_tickets[i+1];

      ArrayResize(m_tickets, n-1);
   }
};

#endif // __MUSERA_TA_TRAIL_PIPS_MQH__

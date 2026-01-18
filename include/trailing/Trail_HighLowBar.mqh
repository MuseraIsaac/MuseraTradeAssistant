//+------------------------------------------------------------------+
//|                                         Trail_HighLowBar.mqh      |
//|                                  (c) 2026, Musera Isaac           |
//|  Trailing strategy: High/Low of last N closed bars (+ buffer).    |
//|                                                                  |
//|  Contract (expected fields in TA_State):                          |
//|    - int    trail_hl_lookback_bars   (>=1)                        |
//|    - double trail_hl_buffer_pips     (>=0)                        |
//|    - int    trailing_min_interval_ms (cooldown between modifies)  |
//|                                                                  |
//|  BUY : SL -> (min Low over closed bars [1..N]) - buffer           |
//|  SELL: SL -> (max High over closed bars [1..N]) + buffer          |
//+------------------------------------------------------------------+
#property strict

#ifndef __MUSERA_TA_TRAIL_HIGHLOWBAR_MQH__
#define __MUSERA_TA_TRAIL_HIGHLOWBAR_MQH__

#include "Trail_Base.mqh"
#include "../TA_Utils.mqh"

class Trail_HighLowBar : public Trail_Base
{
private:
   ulong  m_last_ms;
   ulong  m_tickets[];

   void AddTicket(const ulong t)
   {
      // Avoid duplicates
      for(int i=0;i<ArraySize(m_tickets);i++)
         if(m_tickets[i]==t) return;
      int n=ArraySize(m_tickets);
      ArrayResize(m_tickets,n+1);
      m_tickets[n]=t;
   }

   void RemoveTicketIndex(const int idx)
   {
      int n=ArraySize(m_tickets);
      if(idx<0 || idx>=n) return;
      for(int i=idx;i<n-1;i++)
         m_tickets[i]=m_tickets[i+1];
      ArrayResize(m_tickets,n-1);
   }

   bool GetLowHighRange(const string sym,
                        const ENUM_TIMEFRAMES tf,
                        const int lookback,
                        double &out_low,
                        double &out_high) const
   {
      out_low  = 0.0;
      out_high = 0.0;

      int n = lookback;
      if(n < 1) n = 1;

      // Closed bars only: shift=1
      double lows[];
      double highs[];
      ArraySetAsSeries(lows,  true);
      ArraySetAsSeries(highs, true);

      int c1 = CopyLow(sym,  tf, 1, n, lows);
      int c2 = CopyHigh(sym, tf, 1, n, highs);
      if(c1 <= 0 || c2 <= 0) return false;

      int cnt = MathMin(c1, c2);
      double lo = lows[0];
      double hi = highs[0];

      for(int i=1; i<cnt; i++)
      {
         if(lows[i]  < lo) lo = lows[i];
         if(highs[i] > hi) hi = highs[i];
      }

      out_low  = lo;
      out_high = hi;
      return true;
   }

   void ManageTicket(const ulong ticket, const TA_Context &ctx, const TA_State &st)
   {
      if(!PositionSelectByTicket(ticket))
         return;

      const string sym = (string)PositionGetString(POSITION_SYMBOL);
      if(sym=="") return;

      // Keep it scoped to this strategy's context symbol if provided
      if(ctx.symbol!="" && sym!=ctx.symbol)
         return;

      const long pos_type = (long)PositionGetInteger(POSITION_TYPE);
      const double sl_cur = PositionGetDouble(POSITION_SL);
      const double tp_cur = PositionGetDouble(POSITION_TP);

      double bid=0.0, ask=0.0;
      if(!SymbolInfoDouble(sym, SYMBOL_BID, bid)) return;
      if(!SymbolInfoDouble(sym, SYMBOL_ASK, ask)) return;

      int lookback = st.trail_hl_lookback_bars;
      if(lookback < 1) lookback = 1;

      const double buffer = MathMax(0.0, TA_PipsToPrice(sym, st.trail_hl_buffer_pips));

      double lo=0.0, hi=0.0;
      if(!GetLowHighRange(sym, PERIOD_CURRENT, lookback, lo, hi))
         return;

      const double pt = TA_Point(sym);

      double sl_new = 0.0;
      if(pos_type == POSITION_TYPE_BUY)
      {
         sl_new = TA_NormalizePrice(sym, lo - buffer);
         if(sl_new >= (bid - pt)) return; // must be below price
         if(sl_cur > 0.0 && sl_new <= (sl_cur + pt*0.5)) return; // tighten only
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         sl_new = TA_NormalizePrice(sym, hi + buffer);
         if(sl_new <= (ask + pt)) return; // must be above price
         if(sl_cur > 0.0 && sl_new >= (sl_cur - pt*0.5)) return; // tighten only
      }
      else return;

      string err="";
      ModifySLTP(ticket, ctx.magic, sl_new, tp_cur, err);
   }

public:
   Trail_HighLowBar() : Trail_Base("High/Low Bar"), m_last_ms(0)
   {
      ArrayResize(m_tickets,0);
   }

   virtual void Reset() override
   {
      m_last_ms = 0;
   }

   virtual void RegisterPosition(const ulong position_ticket, const TA_Context &ctx, const TA_State &st) override
   {
      AddTicket(position_ticket);
   }

   virtual void UnregisterPosition(const ulong position_ticket) override
   {
      for(int i=ArraySize(m_tickets)-1;i>=0;--i)
         if(m_tickets[i]==position_ticket)
         {
            RemoveTicketIndex(i);
            return;
         }
   }

   virtual void ClearAll() override
   {
      ArrayResize(m_tickets,0);
   }

   virtual void OnTimer(const TA_Context &ctx, const TA_State &st) override
   {
      if(ArraySize(m_tickets)<=0)
         return;

      const ulong now = GetTickCount64();
      if(st.trailing_min_interval_ms > 0 && (now - m_last_ms) < (ulong)st.trailing_min_interval_ms)
         return;

      for(int i=ArraySize(m_tickets)-1;i>=0;--i)
      {
         const ulong t=m_tickets[i];
         if(!PositionSelectByTicket(t))
         {
            RemoveTicketIndex(i);
            continue;
         }
         ManageTicket(t, ctx, st);
      }

      m_last_ms = now;
   }
};

#endif // __MUSERA_TA_TRAIL_HIGHLOWBAR_MQH__

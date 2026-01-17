//+------------------------------------------------------------------+
//|                                         trailing/Trail_ATR.mqh    |
//|                                  (c) 2026, Musera Isaac          |
//|  ATR-based trailing stop strategy for MuseraTradeAssistant.       |
//|                                                                  |
//|  Uses iATR() to compute volatility distance and trails SL:        |
//|    BUY : SL = Bid - ATR(period)*mult - buffer(pips)              |
//|    SELL: SL = Ask + ATR(period)*mult + buffer(pips)              |
//|                                                                  |
//|  Respects broker StopLevel/FreezeLevel and global trailing guards |
//|  (start profit pips, only-profit, min interval).                 |
//+------------------------------------------------------------------+
#ifndef __MUSERA_TA_TRAIL_ATR_MQH__
#define __MUSERA_TA_TRAIL_ATR_MQH__

#include "Trail_Base.mqh"

class Trail_ATR : public Trail_Base
{
private:
   string m_symbol;
   ulong  m_magic;
   int    m_digits;
   double m_point;
   double m_pip;

   double m_stops_level_px;
   double m_freeze_level_px;

   // ATR config
   int    m_atr_handle;
   int    m_period;
   double m_mult;
   double m_buffer_pips;

   // tracking
   ulong  m_tickets[];
   int    m_last_ms[];

private:
   int  IndexOfTicket(const ulong ticket) const
   {
      const int n = ArraySize(m_tickets);
      for(int i=0;i<n;i++) if(m_tickets[i]==ticket) return i;
      return -1;
   }

   void RemoveAt(const int idx)
   {
      const int n = ArraySize(m_tickets);
      if(idx<0 || idx>=n) return;
      for(int i=idx;i<n-1;i++)
      {
         m_tickets[i]=m_tickets[i+1];
         m_last_ms[i]=m_last_ms[i+1];
      }
      ArrayResize(m_tickets, n-1);
      ArrayResize(m_last_ms, n-1);
   }

   void ReleaseHandle()
   {
      if(m_atr_handle!=INVALID_HANDLE)
      {
         IndicatorRelease(m_atr_handle);
         m_atr_handle=INVALID_HANDLE;
      }
   }

   bool EnsureHandle()
   {
      if(m_atr_handle!=INVALID_HANDLE)
         return true;

      // Use chart timeframe (PERIOD_CURRENT) to match the user's view.
      m_atr_handle = iATR(m_symbol, PERIOD_CURRENT, m_period);
      if(m_atr_handle==INVALID_HANDLE)
      {
         Print("Trail_ATR: failed to create iATR handle. err=", GetLastError());
         return false;
      }
      return true;
   }

   bool GetATR(double &atr_out)
   {
      atr_out = 0.0;
      if(!EnsureHandle())
         return false;

      double buf[];
      ArraySetAsSeries(buf,true);

      // Prefer last closed bar (shift=1) to avoid noisy intra-bar ATR changes.
      int copied = CopyBuffer(m_atr_handle, 0, 1, 1, buf);
      if(copied<1)
         copied = CopyBuffer(m_atr_handle, 0, 0, 1, buf);

      if(copied<1)
      {
         const int err = GetLastError();
         // History may not be ready yet; do not hard-fail.
         Print("Trail_ATR: CopyBuffer failed. err=", err);
         return false;
      }

      atr_out = buf[0];
      return (atr_out>0.0);
   }

public:
   Trail_ATR() :
      Trail_Base("ATR"),
      m_symbol(""),
      m_magic(0),
      m_digits(0),
      m_point(0.0),
      m_pip(0.0),
      m_stops_level_px(0.0),
      m_freeze_level_px(0.0),
      m_atr_handle(INVALID_HANDLE),
      m_period(14),
      m_mult(2.0),
      m_buffer_pips(0.0)
   {
      ArrayResize(m_tickets,0);
      ArrayResize(m_last_ms,0);
   }

   virtual ~Trail_ATR()
   {
      ReleaseHandle();
   }

   virtual bool Init(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &br)
   {
      (void)br;
      m_symbol = ctx.symbol;
      m_magic  = ctx.magic;

      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_pip    = TA_PipSize(m_symbol);

      m_stops_level_px  = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL)  * m_point;
      m_freeze_level_px = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL) * m_point;

      SyncConfig(ctx, st);
      return true;
   }

   virtual void Reset()
   {
      ArrayResize(m_tickets,0);
      ArrayResize(m_last_ms,0);
   }

   virtual void SyncConfig(const TA_Context &ctx, const TA_State &st)
   {
      (void)ctx;

      const int    new_period  = MathMax(2, st.trail_atr_period);
      const double new_mult    = (st.trail_atr_mult<=0.0 ? 2.0 : st.trail_atr_mult);
      const double new_buffer  = MathMax(0.0, st.trail_atr_buffer_pips);

      const bool period_changed = (new_period != m_period);

      m_period      = new_period;
      m_mult        = new_mult;
      m_buffer_pips = new_buffer;

      if(period_changed)
         ReleaseHandle(); // recreate with new period
   }

   virtual void RegisterPosition(const ulong ticket, const TA_Context &ctx, const TA_State &st)
   {
      (void)ctx; (void)st;
      if(ticket==0) return;
      if(IndexOfTicket(ticket)>=0) return;

      const int n = ArraySize(m_tickets);
      ArrayResize(m_tickets, n+1);
      ArrayResize(m_last_ms, n+1);
      m_tickets[n] = ticket;
      m_last_ms[n] = 0;
   }

   virtual void UnregisterPosition(const ulong ticket)
   {
      const int idx = IndexOfTicket(ticket);
      if(idx>=0) RemoveAt(idx);
   }

   virtual void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      if(ArraySize(m_tickets)==0)
         return;

      SyncConfig(ctx, st);

      double atr = 0.0;
      if(!GetATR(atr))
         return;

      const double buffer_px = TA_PipsToPrice(m_symbol, m_buffer_pips);
      const double min_dist  = MathMax(m_stops_level_px, m_freeze_level_px);
      const double dist      = atr * m_mult + buffer_px;

      const double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

      const int now_ms = (int)GetTickCount();

      for(int i=0; i<ArraySize(m_tickets); i++)
      {
         const ulong ticket = m_tickets[i];

         if(st.trailing_min_interval_ms>0)
         {
            if(m_last_ms[i]!=0 && (now_ms - m_last_ms[i]) < st.trailing_min_interval_ms)
               continue;
         }

         if(!PositionSelectByTicket(ticket))
         {
            RemoveAt(i); i--; continue;
         }

         const string psym = PositionGetString(POSITION_SYMBOL);
         if(psym != m_symbol)
         {
            // This strategy is symbol-scoped; unregister tickets from other symbols.
            RemoveAt(i); i--; continue;
         }

         const long   ptype = (long)PositionGetInteger(POSITION_TYPE);
         const double open  = PositionGetDouble(POSITION_PRICE_OPEN);
         const double curSL = PositionGetDouble(POSITION_SL);

         // Optional global guard: start trailing only after X pips profit.
         if(st.trailing_start_profit_pips > 0.0)
         {
            double profit_pips = 0.0;
            if(ptype==POSITION_TYPE_BUY)
               profit_pips = (bid - open) / m_pip;
            else if(ptype==POSITION_TYPE_SELL)
               profit_pips = (open - ask) / m_pip;

            if(profit_pips < st.trailing_start_profit_pips)
               continue;
         }

         if(ptype == POSITION_TYPE_BUY)
         {
            double newSL = bid - dist;

            // Must satisfy broker minimum distance from market.
            const double maxSL = bid - min_dist;
            newSL = MathMin(newSL, maxSL);

            // Safety: keep SL below current price.
            if(newSL >= bid - m_point)
               continue;

            newSL = TA_PriceNormalize(m_symbol, newSL);

            // Only-profit: never trail below (or to) entry.
            if(st.trailing_only_profit && newSL <= open)
               continue;

            // Improve-only (BUY: SL must go up).
            if(curSL > 0.0 && newSL <= curSL + m_point)
               continue;

            string err;
            if(ModifySL(ticket, m_magic, newSL, err))
            {
               m_last_ms[i] = now_ms;
            }
            else
            {
               // Don't spam errors; print once per failed attempt.
               Print("Trail_ATR: ModifySL failed ticket=", (long)ticket, " ", err);
            }
         }
         else if(ptype == POSITION_TYPE_SELL)
         {
            double newSL = ask + dist;

            // Must satisfy broker minimum distance from market.
            const double minSL = ask + min_dist;
            newSL = MathMax(newSL, minSL);

            // Safety: keep SL above current price.
            if(newSL <= ask + m_point)
               continue;

            newSL = TA_PriceNormalize(m_symbol, newSL);

            // Only-profit: never trail above (or to) entry for sells.
            if(st.trailing_only_profit && newSL >= open)
               continue;

            // Improve-only (SELL: SL must go down).
            if(curSL > 0.0 && newSL >= curSL - m_point)
               continue;

            string err;
            if(ModifySL(ticket, m_magic, newSL, err))
            {
               m_last_ms[i] = now_ms;
            }
            else
            {
               Print("Trail_ATR: ModifySL failed ticket=", (long)ticket, " ", err);
            }
         }
      }
   }
};

#endif // __MUSERA_TA_TRAIL_ATR_MQH__

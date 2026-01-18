#ifndef __MUSERA_TA_TRAIL_SAR_MQH__
#define __MUSERA_TA_TRAIL_SAR_MQH__

//+------------------------------------------------------------------+
//|                         Trail_SAR.mqh                             |
//|   Parabolic SAR trailing strategy                                 |
//|                                                                  |
//|   Expected TA_State fields used by this module:                   |
//|     - double trail_sar_step;         // SAR step (e.g., 0.02)     |
//|     - double trail_sar_max;          // SAR max  (e.g., 0.20)     |
//|     - double trail_sar_buffer_pips;  // extra distance from SAR   |
//|     - bool   trailing_only_profit;   // don't lock a loss         |
//|                                                                  |
//|   Notes:                                                         |
//|     - Tickless: use OnTimer() driven by EA timer.                |
//|     - This module trails positions registered via RegisterPosition().|
//+------------------------------------------------------------------+

#include "Trail_Base.mqh"

class Trail_SAR : public Trail_Base
{
private:
   string          m_symbol;
   ulong           m_magic;
   ENUM_TIMEFRAMES m_tf;

   int             m_digits;
   double          m_point;
   double          m_pip;

   // Broker constraints (converted to price distance)
   double          m_stops_level_px;
   double          m_freeze_level_px;
   double          m_min_dist_px;

   // SAR
   int             m_sar_handle;
   double          m_sar_step;
   double          m_sar_max;
   double          m_buffer_px;

   ulong           m_tickets[];

private:
   bool TicketExists(const ulong ticket) const
   {
      for(int i=0;i<ArraySize(m_tickets);++i)
         if(m_tickets[i]==ticket) return true;
      return false;
   }

   void AddTicket(const ulong ticket)
   {
      if(ticket==0 || TicketExists(ticket)) return;
      const int n=ArraySize(m_tickets);
      ArrayResize(m_tickets,n+1);
      m_tickets[n]=ticket;
   }

   void RemoveTicketIndex(const int idx)
   {
      const int n=ArraySize(m_tickets);
      if(idx<0 || idx>=n) return;
      for(int i=idx;i<n-1;++i)
         m_tickets[i]=m_tickets[i+1];
      ArrayResize(m_tickets,n-1);
   }

   void RefreshSymbolCache()
   {
      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(m_point<=0.0) m_point=_Point;
      m_pip    = (m_digits==3 || m_digits==5) ? (m_point*10.0) : m_point;

      const int stops_pts  = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const int freeze_pts = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      m_stops_level_px  = MathMax(0,stops_pts)  * m_point;
      m_freeze_level_px = MathMax(0,freeze_pts) * m_point;
      m_min_dist_px     = MathMax(m_stops_level_px, m_freeze_level_px);
   }

   bool EnsureHandle(const TA_Context &ctx, const TA_State &st)
   {
      const string sym = ctx.symbol;
      const ENUM_TIMEFRAMES tf = (ctx.tf==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)Period() : ctx.tf);

      // Symbol/timeframe change => rebuild handle + cache
      if(sym=="") return false;
      if(m_symbol!=sym)
      {
         m_symbol=sym;
         RefreshSymbolCache();
         if(m_sar_handle!=INVALID_HANDLE)
         {
            IndicatorRelease(m_sar_handle);
            m_sar_handle=INVALID_HANDLE;
         }
      }
      if(m_tf!=tf)
      {
         m_tf=tf;
         if(m_sar_handle!=INVALID_HANDLE)
         {
            IndicatorRelease(m_sar_handle);
            m_sar_handle=INVALID_HANDLE;
         }
      }

      // Parameter change => rebuild handle
      const double step = st.trail_sar_step;
      const double mx   = st.trail_sar_max;

      const bool params_changed = (MathAbs(m_sar_step-step) > 1e-10) || (MathAbs(m_sar_max-mx) > 1e-10);
      if(params_changed && m_sar_handle!=INVALID_HANDLE)
      {
         IndicatorRelease(m_sar_handle);
         m_sar_handle=INVALID_HANDLE;
      }

      // Create if needed
      if(m_sar_handle==INVALID_HANDLE)
      {
         m_sar_step = step;
         m_sar_max  = mx;
         m_sar_handle = iSAR(m_symbol, m_tf, m_sar_step, m_sar_max);
         if(m_sar_handle==INVALID_HANDLE)
            return false;
      }

      // Buffer can be updated without rebuilding handle
      m_buffer_px = st.trail_sar_buffer_pips * m_pip;
      return true;
   }

   bool SarValue(const int shift, double &value)
   {
      value = 0.0;
      if(m_sar_handle==INVALID_HANDLE)
         return false;

      double buf[1];
      if(CopyBuffer(m_sar_handle, 0, shift, 1, buf) != 1)
         return false;

      value = buf[0];
      if(value==EMPTY_VALUE || value==0.0)
         return false;

      return true;
   }

   void TrailOne(const ulong ticket, const TA_State &st, const double bid, const double ask)
   {
      if(!PositionSelectByTicket(ticket))
         return;

      const long type      = PositionGetInteger(POSITION_TYPE);
      const double open_px = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl  = PositionGetDouble(POSITION_SL);

      double sar=0.0;
      if(!SarValue(0, sar))
         return;

      // Build target SL around SAR with buffer
      double new_sl = 0.0;
      if(type==POSITION_TYPE_BUY)
      {
         new_sl = sar - m_buffer_px;

         // enforce min distance from price (stops/freeze)
         const double max_sl = bid - m_min_dist_px;
         if(max_sl<=0.0) return;
         if(new_sl > max_sl) new_sl = max_sl;

         // keep it sensible
         if(new_sl >= bid) return;

         new_sl = NormalizeDouble(new_sl, m_digits);

         // Only move in favorable direction
         if(cur_sl>0.0 && new_sl <= cur_sl + (m_point*0.5))
            return;

         // Optional: don't lock a loss
         if(st.trailing_only_profit && new_sl < open_px)
            return;
      }
      else if(type==POSITION_TYPE_SELL)
      {
         new_sl = sar + m_buffer_px;

         const double min_sl = ask + m_min_dist_px;
         if(new_sl < min_sl) new_sl = min_sl;

         if(new_sl <= ask) return;

         new_sl = NormalizeDouble(new_sl, m_digits);

         if(cur_sl>0.0 && new_sl >= cur_sl - (m_point*0.5))
            return;

         if(st.trailing_only_profit && new_sl > open_px)
            return;
      }
      else
      {
         return;
      }

      // Apply modification
      string err="";
      if(!ModifySL(ticket, m_magic, new_sl, err))
      {
         // keep quiet in production; prints help during development
         if(err!="") Print("[Trail_SAR] ModifySL failed: ", err);
      }
   }

public:
   Trail_SAR()
   {
      m_symbol="";
      m_magic=0;
      m_tf=PERIOD_CURRENT;
      m_digits=0;
      m_point=0.0;
      m_pip=0.0;
      m_stops_level_px=0.0;
      m_freeze_level_px=0.0;
      m_min_dist_px=0.0;
      m_sar_handle=INVALID_HANDLE;
      m_sar_step=0.0;
      m_sar_max=0.0;
      m_buffer_px=0.0;
      ArrayResize(m_tickets,0);
   }

   virtual string Name() const override { return "SAR"; }

   virtual bool Init(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &br) override
   {
      m_symbol = ctx.symbol;
      m_magic  = ctx.magic;
      m_tf     = (ctx.tf==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)Period() : ctx.tf);

      RefreshSymbolCache();

      // Prepare handle (if fails, we'll retry in OnTimer)
      if(!EnsureHandle(ctx, st))
         Print("Trail_SAR: iSAR handle not ready yet.");

      return true;
   }

   virtual void Deinit() override
   {
      if(m_sar_handle!=INVALID_HANDLE)
      {
         IndicatorRelease(m_sar_handle);
         m_sar_handle=INVALID_HANDLE;
      }
      ArrayResize(m_tickets,0);
   }

   virtual void RegisterPosition(const ulong ticket, const TA_Context &ctx, const TA_State &st) override
   {
      AddTicket(ticket);
   }

   virtual void UnregisterPosition(const ulong ticket) override
   {
      for(int i=ArraySize(m_tickets)-1;i>=0;--i)
      {
         if(m_tickets[i]==ticket)
         {
            RemoveTicketIndex(i);
            return;
         }
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

      // Keep up with magic (rarely changes) and handle/config
      m_magic = ctx.magic;
      if(!EnsureHandle(ctx, st))
         return;

      double bid=0.0, ask=0.0;
      if(!SymbolInfoDouble(m_symbol, SYMBOL_BID, bid) || !SymbolInfoDouble(m_symbol, SYMBOL_ASK, ask))
         return;

      for(int i=ArraySize(m_tickets)-1;i>=0;--i)
      {
         const ulong ticket=m_tickets[i];
         if(!PositionSelectByTicket(ticket))
         {
            RemoveTicketIndex(i);
            continue;
         }

         const string psym = PositionGetString(POSITION_SYMBOL);
         if(psym!=m_symbol)
            continue;

         const ulong pmagic=(ulong)PositionGetInteger(POSITION_MAGIC);
         if(pmagic!=m_magic)
            continue;

         TrailOne(ticket, st, bid, ask);
      }
   }

   virtual void OnTradeTransaction(const TA_Context &ctx, const TA_State &st,
                                   const MqlTradeTransaction &trans,
                                   const MqlTradeRequest &request,
                                   const MqlTradeResult &result) override
   {
      // No-op (positions are pruned in OnTimer)
   }

   virtual void OnChartEvent(const TA_Context &ctx, const TA_State &st,
                             const int id, const long &lparam,
                             const double &dparam, const string &sparam) override
   {
      // No interactive objects for this trailing mode.
   }
};

#endif // __MUSERA_TA_TRAIL_SAR_MQH__

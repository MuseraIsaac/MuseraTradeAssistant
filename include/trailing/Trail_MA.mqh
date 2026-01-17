//+------------------------------------------------------------------+
//|                                          Trail_MA.mqh             |
//|                 MuseraTradeAssistant - Trailing Stop Strategy     |
//|                                  (c) 2026, Musera Isaac           |
//|                                                                  |
//|  MA-based trailing: sets SL to Moving Average +/- buffer (pips).  |
//|  - BUY: SL = MA - buffer                                          |
//|  - SELL: SL = MA + buffer                                         |
//|                                                                  |
//|  Depends on project types/state provided by:                      |
//|    include/TA_Types.mqh, include/TA_State.mqh, include/TA_Utils.mqh|
//|                                                                  |
//|  Expected TA_State fields:                                        |
//|    int              trail_ma_period;                              |
//|    int              trail_ma_shift;   // bar shift (0=current,1=prev)
//|    ENUM_MA_METHOD   trail_ma_method;                              |
//|    ENUM_APPLIED_PRICE trail_ma_price;                             |
//|    double           trail_ma_buffer_pips;                         |
//+------------------------------------------------------------------+
#ifndef __MUSERA_TA_TRAIL_MA_MQH__
#define __MUSERA_TA_TRAIL_MA_MQH__

#include "Trail_Base.mqh"

// Forward declarations from project includes
struct TA_Context;
struct TA_State;
class TA_BrokerRules;

//+------------------------------------------------------------------+
//| Trail_MA                                                          |
//+------------------------------------------------------------------+
class Trail_MA : public Trail_Base
{
private:
   string  m_symbol;
   ulong   m_magic;
   int     m_digits;
   double  m_point;
   double  m_pip;

   // Broker constraints (price distance)
   double  m_stops_level_px;
   double  m_freeze_level_px;

   // Indicator handle
   int     m_ma_handle;
   bool    m_ready;

   // Cached config
   int              m_period;
   int              m_bar_shift;
   ENUM_MA_METHOD   m_method;
   ENUM_APPLIED_PRICE m_price;
   double           m_buffer_pips;

   // Tracked positions
   ulong   m_tickets[];
   long    m_last_ms[];      // last successful modify time (ms)

private:
   int  IndexOfTicket(const ulong ticket) const
   {
      for(int i=0;i<ArraySize(m_tickets);i++)
         if(m_tickets[i]==ticket) return i;
      return -1;
   }

   void RemoveAt(const int idx)
   {
      if(idx<0) return;
      const int n = ArraySize(m_tickets);
      if(idx>=n) return;

      for(int i=idx;i<n-1;i++)
      {
         m_tickets[i]=m_tickets[i+1];
         m_last_ms[i]=m_last_ms[i+1];
      }
      ArrayResize(m_tickets, n-1);
      ArrayResize(m_last_ms, n-1);
   }

   void ResetHandle()
   {
      if(m_ma_handle!=INVALID_HANDLE)
      {
         IndicatorRelease(m_ma_handle);
         m_ma_handle=INVALID_HANDLE;
      }
      m_ready=false;
   }

   bool EnsureHandle(const TA_Context &ctx)
   {
      if(m_ma_handle!=INVALID_HANDLE)
         return true;

      // MA handle uses chart timeframe from ctx.tf
      m_ma_handle = iMA(ctx.symbol, (ENUM_TIMEFRAMES)ctx.tf, m_period, 0, m_method, m_price);
      m_ready = (m_ma_handle!=INVALID_HANDLE);
      return m_ready;
   }

   bool GetMAValue(const TA_Context &ctx, double &out_ma)
   {
      out_ma = 0.0;
      if(!EnsureHandle(ctx)) return false;

      double buf[1];
      ArraySetAsSeries(buf, true);

      // Copy MA at bar shift (0=current bar, 1=previous bar, etc.)
      const int copied = CopyBuffer(m_ma_handle, 0, m_bar_shift, 1, buf);
      if(copied!=1) return false;

      out_ma = buf[0];
      return (out_ma>0.0);
   }

public:
   Trail_MA():
      m_symbol(""),
      m_magic(0),
      m_digits(0),
      m_point(0.0),
      m_pip(0.0),
      m_stops_level_px(0.0),
      m_freeze_level_px(0.0),
      m_ma_handle(INVALID_HANDLE),
      m_ready(false),
      m_period(50),
      m_bar_shift(1),
      m_method(MODE_EMA),
      m_price(PRICE_CLOSE),
      m_buffer_pips(2.0)
   {}

   bool Init(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &br)
   {
      m_symbol = ctx.symbol;
      m_magic  = ctx.magic;

      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_pip    = TA_PipSize(m_symbol);

      // Stops/freeze in PRICE (not points)
      m_stops_level_px  = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL)  * m_point;
      m_freeze_level_px = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL) * m_point;

      ArrayResize(m_tickets,0);
      ArrayResize(m_last_ms,0);

      SyncConfig(ctx, st);
      return true;
   }

   void Shutdown()
   {
      ResetHandle();
      ArrayResize(m_tickets,0);
      ArrayResize(m_last_ms,0);
   }

   void SyncConfig(const TA_Context &ctx, const TA_State &st)
   {
      const int new_period    = (st.trail_ma_period<=0 ? 50 : st.trail_ma_period);
      const int new_bar_shift = (st.trail_ma_shift<0  ? 0  : st.trail_ma_shift);
      const ENUM_MA_METHOD new_method = st.trail_ma_method;
      const ENUM_APPLIED_PRICE new_price = st.trail_ma_price;
      const double new_buffer = (st.trail_ma_buffer_pips<0.0 ? 0.0 : st.trail_ma_buffer_pips);

      const bool changed =
         (new_period!=m_period) ||
         (new_bar_shift!=m_bar_shift) ||
         (new_method!=m_method) ||
         (new_price!=m_price) ||
         (MathAbs(new_buffer - m_buffer_pips) > 1e-9);

      m_period      = new_period;
      m_bar_shift   = new_bar_shift;
      m_method      = new_method;
      m_price       = new_price;
      m_buffer_pips = new_buffer;

      if(changed)
      {
         // Recreate handle with new settings
         ResetHandle();
         EnsureHandle(ctx);
      }
   }

   void RegisterPosition(const ulong ticket, const TA_Context &ctx, const TA_State &st)
   {
      if(ticket==0) return;

      const int idx = IndexOfTicket(ticket);
      if(idx>=0)
      {
         m_last_ms[idx] = (long)GetTickCount();
         return;
      }

      const int n = ArraySize(m_tickets);
      ArrayResize(m_tickets, n+1);
      ArrayResize(m_last_ms, n+1);
      m_tickets[n] = ticket;
      m_last_ms[n] = 0;
   }

   void UnregisterPosition(const ulong ticket)
   {
      const int idx = IndexOfTicket(ticket);
      if(idx>=0) RemoveAt(idx);
   }

   // Called by wrapper periodically (tickless OnTimer mode recommended)
   void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      if(ArraySize(m_tickets)==0) return;

      // Keep config fresh if user changed settings via UI
      SyncConfig(ctx, st);
      if(!m_ready && !EnsureHandle(ctx)) return;

      double ma = 0.0;
      if(!GetMAValue(ctx, ma)) return;

      const string sym = ctx.symbol;
      const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);

      // Minimum broker distance from current price for SL
      const double min_dist = MathMax(m_stops_level_px, m_freeze_level_px);
      const double buffer_px = TA_PipsToPrice(sym, m_buffer_pips);

      for(int i=ArraySize(m_tickets)-1; i>=0; i--)
      {
         const ulong ticket = m_tickets[i];

         if(!PositionSelectByTicket(ticket))
         {
            RemoveAt(i);
            continue;
         }

         if((string)PositionGetString(POSITION_SYMBOL) != sym)
            continue; // only manage chart symbol (simple model)

         const long type = (long)PositionGetInteger(POSITION_TYPE); // buy/sell
         const double cur_sl = (double)PositionGetDouble(POSITION_SL);

         double candidate = 0.0;

         if(type==POSITION_TYPE_BUY)
         {
            candidate = ma - buffer_px;
            if(candidate<=0.0) continue;

            // Clamp to broker min distance: SL must be <= bid - min_dist
            const double max_sl = bid - min_dist;
            if(max_sl<=0.0) continue;
            if(candidate > max_sl) candidate = max_sl;

            // Improve only (do not loosen)
            if(cur_sl>0.0 && candidate <= cur_sl) continue;
         }
         else if(type==POSITION_TYPE_SELL)
         {
            candidate = ma + buffer_px;
            if(candidate<=0.0) continue;

            // Clamp: SL must be >= ask + min_dist
            const double min_sl = ask + min_dist;
            if(candidate < min_sl) candidate = min_sl;

            // Improve only for SELL means SL must move DOWN (smaller)
            if(cur_sl>0.0 && candidate >= cur_sl) continue;
         }
         else
         {
            continue;
         }

         candidate = NormalizeDouble(candidate, m_digits);

         if(cur_sl>0.0 && NearlyEqualPrice(sym, cur_sl, candidate, 0.5))
            continue;

         string err;
         if(!ModifySL(ticket, m_magic, candidate, err))
         {
            // If broker rejects often due to freeze, leave it and retry next timer
            // (error can be logged by wrapper if desired)
            continue;
         }

         m_last_ms[i] = (long)GetTickCount();
      }
   }

   void OnTradeTransaction(const TA_Context &ctx, const TA_State &st,
                           const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {
      // Optional: could auto-unregister on close events. Not required; OnTimer prunes.
      (void)ctx; (void)st; (void)trans; (void)request; (void)result;
   }
};

#endif // __MUSERA_TA_TRAIL_MA_MQH__

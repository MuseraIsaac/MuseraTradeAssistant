//+------------------------------------------------------------------+
//|                                     trailing/Trail_Fractals.mqh  |
//|                        Part of: MuseraTradeAssistant (MT5)        |
//|                                  (c) 2026, Musera Isaac          |
//|                                                                  |
//|  Fractal-based trailing stop strategy.                            |
//|  - BUY: SL trails below the most recent confirmed swing-low       |
//|  - SELL: SL trails above the most recent confirmed swing-high     |
//|                                                                  |
//|  Uses TA_State fields:                                            |
//|    - trail_fractal_left                                           |
//|    - trail_fractal_right                                          |
//|    - trail_fractal_buffer_pips                                    |
//+------------------------------------------------------------------+
#property strict

#ifndef __MUSERA_TA_TRAIL_FRACTALS_MQH__
#define __MUSERA_TA_TRAIL_FRACTALS_MQH__

#include "Trail_Base.mqh"

class Trail_Fractals : public Trail_Base
{
private:
   struct STrailedPos
   {
      ulong    ticket;
      datetime last_fractal_time;
      double   last_sl;
   };

   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;
   STrailedPos     m_pos[];
   bool            m_inited;

public:
   Trail_Fractals() : Trail_Base("Fractals"), m_symbol(""), m_tf(PERIOD_CURRENT), m_inited(false)
   {
      ArrayResize(m_pos, 0);
   }

   bool Init(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &br)
   {
      m_symbol = (ctx.symbol == "" ? _Symbol : ctx.symbol);
      m_tf     = (ENUM_TIMEFRAMES)Period(); // use chart timeframe
      m_inited = true;
      return true;
   }

   void Reset()
   {
      ArrayResize(m_pos, 0);
   }

   // Register a position ticket to be managed by this trailing strategy
   bool Register(const ulong position_ticket)
   {
      if(position_ticket == 0) return false;
      if(FindIndex(position_ticket) >= 0) return true;

      int n = ArraySize(m_pos);
      ArrayResize(m_pos, n + 1);
      m_pos[n].ticket            = position_ticket;
      m_pos[n].last_fractal_time = 0;
      m_pos[n].last_sl           = 0.0;
      return true;
   }

   void Unregister(const ulong position_ticket)
   {
      int idx = FindIndex(position_ticket);
      if(idx < 0) return;

      int n = ArraySize(m_pos);
      for(int i = idx; i < n - 1; i++)
         m_pos[i] = m_pos[i + 1];
      ArrayResize(m_pos, n - 1);
   }

   void OnTimer(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &br)
   {
      if(!m_inited) return;
      if(!st.trailing_enabled) return;

      // Reasonable default scan depth (you can make this an input later)
      const int lookback = 600;

      for(int i = ArraySize(m_pos) - 1; i >= 0; i--)
      {
         const ulong ticket = m_pos[i].ticket;

         if(!PositionSelectByTicket(ticket))
         {
            Unregister(ticket);
            continue;
         }

         // Respect magic (only manage positions opened by this assistant)
         const long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
         if((ulong)pos_magic != ctx.magic)
            continue;

         const string sym  = PositionGetString(POSITION_SYMBOL);
         const long   type = (long)PositionGetInteger(POSITION_TYPE);
         double cur_sl     = PositionGetDouble(POSITION_SL);

         double bid = 0.0, ask = 0.0;
         SymbolInfoDouble(sym, SYMBOL_BID, bid);
         SymbolInfoDouble(sym, SYMBOL_ASK, ask);
         if(bid <= 0.0 || ask <= 0.0)
            continue;

         const int left  = MathMax(1, st.trail_fractal_left);
         const int right = MathMax(1, st.trail_fractal_right);

         double   frac_price = 0.0;
         datetime frac_time  = 0;
         bool     found      = false;

         if(type == POSITION_TYPE_BUY)
            found = FindRecentFractal(sym, m_tf, /*want_high=*/false, left, right, lookback, frac_price, frac_time);
         else if(type == POSITION_TYPE_SELL)
            found = FindRecentFractal(sym, m_tf, /*want_high=*/true, left, right, lookback, frac_price, frac_time);
         else
            continue;

         if(!found || frac_price <= 0.0)
            continue;

         const double pip    = SymbolPipSize(sym);
         const double buffer = MathMax(0.0, st.trail_fractal_buffer_pips) * pip;

         double new_sl = 0.0;
         if(type == POSITION_TYPE_BUY)
            new_sl = frac_price - buffer;
         else
            new_sl = frac_price + buffer;

         // Broker distance constraints
         const double min_dist = MathMax(GetStopsLevelPx(sym), GetFreezeLevelPx(sym));

         if(type == POSITION_TYPE_BUY)
         {
            // SL must be below Bid
            const double max_sl = bid - min_dist;
            if(new_sl > max_sl) new_sl = max_sl;

            if(new_sl <= 0.0)
               continue;

            // Improve only
            const double step = MathMax(SymbolPoint(sym), pip * 0.10);
            if(cur_sl > 0.0 && new_sl <= cur_sl + step)
               continue;
         }
         else // SELL
         {
            // SL must be above Ask
            const double min_sl = ask + min_dist;
            if(new_sl < min_sl) new_sl = min_sl;

            if(new_sl <= 0.0)
               continue;

            // Improve only (move SL down for sells)
            const double step = MathMax(SymbolPoint(sym), pip * 0.10);
            if(cur_sl > 0.0 && new_sl >= cur_sl - step)
               continue;
         }

         // Normalize
         const int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
         new_sl = NormalizeDouble(new_sl, digits);

         // Avoid repeated identical modifications
         if(m_pos[i].last_fractal_time == frac_time && PriceEquals(sym, new_sl, m_pos[i].last_sl))
            continue;

         string err = "";
         if(!ModifySL(ticket, ctx.magic, new_sl, err))
            continue;

         m_pos[i].last_fractal_time = frac_time;
         m_pos[i].last_sl           = new_sl;
      }
   }

private:
   int FindIndex(const ulong ticket) const
   {
      const int n = ArraySize(m_pos);
      for(int i = 0; i < n; i++)
         if(m_pos[i].ticket == ticket)
            return i;
      return -1;
   }

   double SymbolPoint(const string sym) const
   {
      return SymbolInfoDouble(sym, SYMBOL_POINT);
   }

   double SymbolPipSize(const string sym) const
   {
      const int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      const double pt  = SymbolPoint(sym);
      if(digits == 3 || digits == 5) return pt * 10.0;
      return pt;
   }

   double GetStopsLevelPx(const string sym) const
   {
      const int lvl_pts = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
      return (double)lvl_pts * SymbolPoint(sym);
   }

   double GetFreezeLevelPx(const string sym) const
   {
      const int lvl_pts = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
      return (double)lvl_pts * SymbolPoint(sym);
   }

   bool PriceEquals(const string sym, const double a, const double b) const
   {
      const double tol = MathMax(SymbolPoint(sym), SymbolPipSize(sym) * 0.05);
      return (MathAbs(a - b) <= tol);
   }

   // Scans recent bars and returns the most recent confirmed fractal (swing high/low)
   // want_high=false => swing LOW
   // want_high=true  => swing HIGH
   bool FindRecentFractal(const string sym,
                          const ENUM_TIMEFRAMES tf,
                          const bool want_high,
                          const int left,
                          const int right,
                          const int lookback,
                          double &out_price,
                          datetime &out_time) const
   {
      out_price = 0.0;
      out_time  = 0;

      const int need = lookback + left + right + 10;
      MqlRates rates[];
      const int copied = CopyRates(sym, tf, 0, need, rates);
      if(copied <= left + right + 2)
         return false;

      // We need i+left < copied and i-right >= 0; most recent => start at i=right
      const int max_i = MathMin(copied - left - 1, lookback + right);

      for(int i = right; i <= max_i; i++)
      {
         const double v = want_high ? rates[i].high : rates[i].low;
         if(v <= 0.0)
            continue;

         bool ok = true;

         // Compare with bars closer to current (right side)
         for(int r = 1; r <= right && ok; r++)
         {
            const double n = want_high ? rates[i - r].high : rates[i - r].low;
            if(want_high)
            {
               if(v <= n) ok = false;
            }
            else
            {
               if(v >= n) ok = false;
            }
         }

         // Compare with bars further back (left side)
         for(int l = 1; l <= left && ok; l++)
         {
            const double n = want_high ? rates[i + l].high : rates[i + l].low;
            if(want_high)
            {
               if(v <= n) ok = false;
            }
            else
            {
               if(v >= n) ok = false;
            }
         }

         if(ok)
         {
            out_price = v;
            out_time  = rates[i].time;
            return true;
         }
      }

      return false;
   }
};

#endif // __MUSERA_TA_TRAIL_FRACTALS_MQH__

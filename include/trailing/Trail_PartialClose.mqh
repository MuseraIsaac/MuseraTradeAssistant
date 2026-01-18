//+------------------------------------------------------------------+
//|                                           Trail_PartialClose.mqh  |
//|                                  (c) 2026, Musera Isaac           |
//|  Trailing mode: closes a % of position at each +R step            |
//|                                                                   |
//|  Depends on project types: TA_Context, TA_State (forward declared) |
//|  and Trail_Base interface.                                        |
//+------------------------------------------------------------------+
#ifndef __TA_TRAIL_PARTIALCLOSE_MQH__
#define __TA_TRAIL_PARTIALCLOSE_MQH__

#include "Trail_Base.mqh"

// Forward declarations (defined in project includes)
struct TA_Context;
struct TA_State;

//+------------------------------------------------------------------+
//| Trail_PartialClose                                                |
//| - Registers a position and captures initial entry & SL to compute R|
//| - Every time profit reaches N*R, closes a % of current volume       |
//| - Uses st.trail_partial_every_r and st.trail_partial_close_pct      |
//| - Requires position to have an SL at registration time              |
//+------------------------------------------------------------------+
class Trail_PartialClose : public Trail_Base
{
private:
   struct PCItem
   {
      ulong  ticket;
      double entry_price;
      double sl0_price;
      double risk_points;      // initial risk in points
      double next_r_target;    // next R multiple to trigger
      uint   last_action_ms;   // GetTickCount() at last action
      bool   active;
   };

   PCItem m_items[];

private:
   int FindIndex(const ulong ticket) const
   {
      int n = ArraySize(m_items);
      for(int i=0;i<n;i++)
         if(m_items[i].ticket == ticket)
            return i;
      return -1;
   }

   void RemoveIndex(const int idx)
   {
      if(idx < 0) return;
      int n = ArraySize(m_items);
      if(idx >= n) return;
      ArrayRemove(m_items, idx, 1);
   }

   static int VolumeDigits(const double step)
   {
      // Determine decimals based on volume step (e.g., 0.01 -> 2)
      double s = step;
      int d = 0;
      while(d < 8 && s > 0.0 && s < 1.0 - 1e-12)
      {
         s *= 10.0;
         d++;
      }
      return d;
   }

   static double NormalizeVolumeToStep(const string symbol, double vol)
   {
      double vmin = 0.0, vmax = 0.0, vstep = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN,  vmin))  vmin = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX,  vmax))  vmax = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP, vstep)) vstep = 0.0;

      if(vstep <= 0.0)
      {
         // Fallback: use min as step; if still 0, return as-is
         vstep = (vmin > 0.0 ? vmin : 0.0);
      }

      if(vstep > 0.0)
      {
         int steps = (int)MathFloor((vol + 1e-12) / vstep);
         vol = steps * vstep;
         vol = NormalizeDouble(vol, VolumeDigits(vstep));
      }

      if(vmin > 0.0 && vol < vmin) vol = vmin;
      if(vmax > 0.0 && vol > vmax) vol = vmax;

      return vol;
   }

   static bool SendPartialCloseDeal(const string symbol,
                                   const ulong ticket,
                                   const long pos_type,
                                   const double volume,
                                   const int deviation_points,
                                   const ulong magic,
                                   string &err)
   {
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      req.action   = TRADE_ACTION_DEAL;
      req.symbol   = symbol;
      req.position = ticket;
      req.magic    = magic;
      req.volume   = volume;
      req.deviation= deviation_points;
      req.comment  = "TA PartialClose";

      if(pos_type == POSITION_TYPE_BUY)
      {
         req.type  = ORDER_TYPE_SELL;
         req.price = SymbolInfoDouble(symbol, SYMBOL_BID);
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         req.type  = ORDER_TYPE_BUY;
         req.price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      }
      else
      {
         err = "Unknown position type";
         return false;
      }

      if(!OrderSend(req, res))
      {
         err = "OrderSend failed (transport). code=" + (string)GetLastError();
         return false;
      }

      if(res.retcode != TRADE_RETCODE_DONE &&
         res.retcode != TRADE_RETCODE_DONE_PARTIAL &&
         res.retcode != TRADE_RETCODE_PLACED)
      {
         err = "retcode=" + (string)res.retcode + " " + res.comment;
         return false;
      }

      return true;
   }

public:
   Trail_PartialClose()
   {
      SetName("PartialClose");
   }

   virtual bool Init(const TA_Context &ctx, const TA_State &st)
   {
      (void)ctx; (void)st;
      Reset();
      return true;
   }

   virtual void Reset()
   {
      ArrayResize(m_items, 0);
   }

   virtual void SyncConfig(const TA_Context &ctx, const TA_State &st)
   {
      (void)ctx; (void)st;
      // No cached config here; it reads from state on every timer call.
   }

   virtual bool RegisterPosition(const TA_Context &ctx, const TA_State &st, const ulong ticket)
   {
      (void)st;

      if(ticket == 0)
         return false;

      if(!PositionSelectByTicket(ticket))
         return false;

      string sym = (string)PositionGetString(POSITION_SYMBOL);
      if(sym != (string)ctx.symbol)
      {
         // Keep it strict: this strategy manages only the EA chart symbol
         return false;
      }

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl0   = PositionGetDouble(POSITION_SL);

      if(sl0 == 0.0)
      {
         // Cannot compute R without an initial stop loss.
         Print("Trail_PartialClose: ticket=", (string)ticket, " has no SL; cannot compute R.");
         return false;
      }

      double pt = 0.0;
      if(!SymbolInfoDouble(sym, SYMBOL_POINT, pt) || pt <= 0.0)
         pt = _Point;

      double risk_pts = MathAbs(entry - sl0) / pt;
      if(risk_pts < 0.5)
      {
         Print("Trail_PartialClose: ticket=", (string)ticket, " risk too small; skip.");
         return false;
      }

      double step_r = (double)st.trail_partial_every_r;
      if(step_r <= 0.0) step_r = 1.0;

      int idx = FindIndex(ticket);
      if(idx < 0)
      {
         PCItem it;
         it.ticket         = ticket;
         it.entry_price    = entry;
         it.sl0_price      = sl0;
         it.risk_points    = risk_pts;
         it.next_r_target  = step_r;
         it.last_action_ms = 0;
         it.active         = true;

         int n = ArraySize(m_items);
         ArrayResize(m_items, n + 1);
         m_items[n] = it;
      }
      else
      {
         // Update captured baseline if re-registering (e.g., after restart)
         m_items[idx].entry_price   = entry;
         m_items[idx].sl0_price     = sl0;
         m_items[idx].risk_points   = risk_pts;
         m_items[idx].next_r_target = step_r;
         m_items[idx].active        = true;
      }

      return true;
   }

   virtual void UnregisterPosition(const TA_Context &ctx, const TA_State &st, const ulong ticket)
   {
      (void)ctx; (void)st;
      int idx = FindIndex(ticket);
      if(idx >= 0)
         RemoveIndex(idx);
   }

   virtual void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      if(!st.trail_partial_enabled)
         return;

      double every_r = (double)st.trail_partial_every_r;
      if(every_r <= 0.0)
         return;

      double close_pct = (double)st.trail_partial_close_pct;
      if(close_pct <= 0.0)
         return;

      string sym = (string)ctx.symbol;

      double pt = 0.0;
      if(!SymbolInfoDouble(sym, SYMBOL_POINT, pt) || pt <= 0.0)
         pt = _Point;

      double vmin = 0.0;
      SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN, vmin);

      uint now_ms = GetTickCount();
      int n = ArraySize(m_items);
      for(int i=n-1; i>=0; i--)
      {
         if(!m_items[i].active)
            continue;

         ulong ticket = m_items[i].ticket;

         if(!PositionSelectByTicket(ticket))
         {
            RemoveIndex(i);
            continue;
         }

         string psym = (string)PositionGetString(POSITION_SYMBOL);
         if(psym != sym)
         {
            RemoveIndex(i);
            continue;
         }

         long pos_type = (long)PositionGetInteger(POSITION_TYPE);
         double entry  = m_items[i].entry_price;
         double risk_pts = m_items[i].risk_points;
         if(risk_pts <= 0.0)
         {
            RemoveIndex(i);
            continue;
         }

         // Profit movement in points
         double price = 0.0;
         if(pos_type == POSITION_TYPE_BUY)
            price = SymbolInfoDouble(sym, SYMBOL_BID);
         else if(pos_type == POSITION_TYPE_SELL)
            price = SymbolInfoDouble(sym, SYMBOL_ASK);
         else
         {
            RemoveIndex(i);
            continue;
         }

         double move_pts = (pos_type == POSITION_TYPE_BUY ? (price - entry) : (entry - price)) / pt;
         if(move_pts <= 0.0)
            continue;

         // Optional global profit gating
         if(st.trailing_start_profit_pips > 0.0)
         {
            // "pips" here is interpreted as points * 10^?; project utils may define pip conversion.
            // We treat it as "points" equivalent for safety. Adjust in TA_Utils if you want.
            if(move_pts < (double)st.trailing_start_profit_pips)
               continue;
         }

         double r = move_pts / risk_pts;
         if(r + 1e-9 < m_items[i].next_r_target)
            continue;

         // Rate-limit
         int min_ms = (int)st.trailing_min_interval_ms;
         if(min_ms > 0 && m_items[i].last_action_ms != 0)
         {
            uint elapsed = (uint)(now_ms - m_items[i].last_action_ms);
            if(elapsed < (uint)min_ms)
               continue;
         }

         double vol = PositionGetDouble(POSITION_VOLUME);
         if(vol <= 0.0)
         {
            RemoveIndex(i);
            continue;
         }

         // Compute close volume
         double close_vol = vol * (close_pct / 100.0);
         close_vol = NormalizeVolumeToStep(sym, close_vol);

         if(close_vol <= 0.0)
            continue;

         // If remaining would fall below min volume, close all.
         if(vmin > 0.0 && (vol - close_vol) > 0.0 && (vol - close_vol) < vmin)
            close_vol = vol;

         if(close_vol > vol)
            close_vol = vol;

         // Execute partial close
         string err = "";
         if(!SendPartialCloseDeal(sym, ticket, pos_type, close_vol, (int)st.deviation_points, (ulong)ctx.magic, err))
         {
            Print("Trail_PartialClose CloseDeal failed: ticket=", (string)ticket, " err=", err);
            // do not advance next target; allow retry later
            m_items[i].last_action_ms = now_ms;
            continue;
         }

         m_items[i].last_action_ms = now_ms;
         m_items[i].next_r_target += every_r;

         // If position fully closed, remove on next loop
         if(!PositionSelectByTicket(ticket))
            RemoveIndex(i);
      }
   }

   virtual void OnTick(const TA_Context &ctx, const TA_State &st)
   {
      (void)ctx; (void)st;
      // Intentionally tick-light; core loop runs on timer.
   }

   virtual void OnChartEvent(const TA_Context &ctx, const TA_State &st,
                             const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      (void)ctx; (void)st; (void)id; (void)lparam; (void)dparam; (void)sparam;
      // No chart interactions for this strategy.
   }

   virtual void OnTradeTransaction(const TA_Context &ctx, const TA_State &st,
                                   const MqlTradeTransaction &trans,
                                   const MqlTradeRequest &request,
                                   const MqlTradeResult &result)
   {
      (void)ctx; (void)st; (void)trans; (void)request; (void)result;
      // Optional: could remove tickets on POSITION closed; timer cleanup is sufficient.
   }
};

#endif // __TA_TRAIL_PARTIALCLOSE_MQH__
//+------------------------------------------------------------------+

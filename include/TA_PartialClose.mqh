//+------------------------------------------------------------------+
//|                                         TA_PartialClose.mqh      |
//|                         TP1/TP2/TP3 partial close manager        |
//|                                  (c) 2026, Musera Isaac          |
//+------------------------------------------------------------------+
#property strict
#ifndef __TA_PARTIAL_CLOSE_MQH__
#define __TA_PARTIAL_CLOSE_MQH__

#include <Trade/Trade.mqh>

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"
#include "TA_BrokerRules.mqh"

class TA_PartialClose
{
private:
   enum { TA_PC_MAX_TRACK = 48 };

   struct TA_PC_Track
   {
      ulong  ticket;
      string symbol;
      long   type;          // POSITION_TYPE_BUY / POSITION_TYPE_SELL
      double entry_price;
      double init_volume;

      // Snapshot of settings at registration time
      ENUM_TA_PARTIALS_MODE   mode;
      ENUM_TA_PARTIAL_TRIGGER trigger;

      double at_r[3];        // RR target for TP1/2/3
      int    at_points[3];   // points target for TP1/2/3
      double close_pct[3];   // percent volume to close at TP1/2/3

      bool   fired[3];
      ulong  last_attempt_ms;
   };

   TA_PC_Track    m_items[TA_PC_MAX_TRACK];
   int            m_count;

   TA_Context     m_ctx;
   TA_BrokerRules m_br;

private:
   static bool IsBuy(const long pos_type) { return (pos_type == POSITION_TYPE_BUY); }

   int Find(const ulong ticket) const
   {
      for(int i=0;i<m_count;i++)
         if(m_items[i].ticket == ticket) return i;
      return -1;
   }

   void RemoveAt(const int idx)
   {
      if(idx < 0 || idx >= m_count) return;
      for(int i=idx; i<m_count-1; i++)
         m_items[i] = m_items[i+1];
      m_count--;
   }

   bool GetPosSnapshot(const ulong ticket, string &sym, long &type, double &entry, double &vol, double &sl) const
   {
      if(!PositionSelectByTicket(ticket))
         return false;

      sym   = PositionGetString(POSITION_SYMBOL);
      type  = (long)PositionGetInteger(POSITION_TYPE);
      entry = PositionGetDouble(POSITION_PRICE_OPEN);
      vol   = PositionGetDouble(POSITION_VOLUME);
      sl    = PositionGetDouble(POSITION_SL);
      return true;
   }

   double CloseSidePrice(const string sym, const bool is_buy) const
   {
      // For BUY positions, close is SELL at BID.
      // For SELL positions, close is BUY at ASK.
      return is_buy ? SymbolInfoDouble(sym, SYMBOL_BID)
                    : SymbolInfoDouble(sym, SYMBOL_ASK);
   }

   bool Crossed(const bool is_buy, const double cur_price, const double level_price) const
   {
      if(is_buy) return (cur_price >= level_price);
      return (cur_price <= level_price);
   }

   double CandleClose(const string sym, const ENUM_TIMEFRAMES tf) const
   {
      ENUM_TIMEFRAMES use_tf = tf;
      if(use_tf == PERIOD_CURRENT)
         use_tf = (ENUM_TIMEFRAMES)Period();

      double c = iClose(sym, use_tf, 1);
      if(c == 0.0)
         c = iClose(sym, use_tf, 0);
      return c;
   }

   int RPoints(const string sym, const double entry, const double sl_price, const TA_State &st) const
   {
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(point <= 0.0) point = _Point;

      if(sl_price > 0.0)
      {
         double dist = MathAbs(entry - sl_price);
         int pts = (int)MathRound(dist / point);
         return MathMax(pts, 0);
      }

      // Fallback: configured SL distance in points
      if(st.sl_points > 0)
         return st.sl_points;

      return 0;
   }

   bool TargetPrice(const TA_PC_Track &t, const TA_State &st, const int stage, const double pos_sl, double &out_price) const
   {
      out_price = 0.0;
      if(stage < 0 || stage > 2) return false;

      double point = SymbolInfoDouble(t.symbol, SYMBOL_POINT);
      if(point <= 0.0) point = _Point;

      const bool is_buy = IsBuy(t.type);
      const double dir  = is_buy ? 1.0 : -1.0;

      if(t.mode == TA_PARTIALS_BY_R)
      {
         int r_pts = RPoints(t.symbol, t.entry_price, pos_sl, st);
         if(r_pts <= 0) return false;
         out_price = t.entry_price + dir * ((double)r_pts * point) * t.at_r[stage];
         return true;
      }
      if(t.mode == TA_PARTIALS_BY_POINTS)
      {
         if(t.at_points[stage] <= 0) return false;
         out_price = t.entry_price + dir * ((double)t.at_points[stage] * point);
         return true;
      }

      // Unknown schema: best-effort treat as RR
      int r_pts = RPoints(t.symbol, t.entry_price, pos_sl, st);
      if(r_pts <= 0) return false;
      out_price = t.entry_price + dir * ((double)r_pts * point) * t.at_r[stage];
      return true;
   }

   bool RetOk(const uint rc) const
   {
      return (rc == TRADE_RETCODE_DONE ||
              rc == TRADE_RETCODE_DONE_PARTIAL ||
              rc == TRADE_RETCODE_PLACED ||
              rc == TRADE_RETCODE_NO_CHANGES);
   }

   bool SendPartialClose(const TA_PC_Track &t, const double volume, const int stage, uint &retcode, string &errmsg) const
   {
      retcode = 0;
      errmsg  = "";

      if(volume <= 0.0)
      {
         errmsg = "volume<=0";
         return false;
      }
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      {
         errmsg = "trade not allowed";
         return false;
      }

      const bool is_buy = IsBuy(t.type);

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      req.action   = TRADE_ACTION_DEAL;
      req.symbol   = t.symbol;
      req.magic    = (uint)m_ctx.magic;
      req.position = t.ticket; // hedging-safe
      req.volume   = volume;
      req.type     = is_buy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      req.price    = CloseSidePrice(t.symbol, is_buy);
      req.deviation = 20;
      req.type_time = ORDER_TIME_GTC;
      req.type_filling = (ENUM_ORDER_TYPE_FILLING)SymbolInfoInteger(t.symbol, SYMBOL_FILLING_MODE);
      req.comment  = "TA-Partial#" + IntegerToString(stage+1);

      if(!OrderSend(req, res))
      {
         errmsg = "OrderSend failed. LastError=" + IntegerToString(GetLastError());
         retcode = res.retcode;
         return false;
      }

      retcode = res.retcode;
      if(!RetOk(res.retcode))
      {
         errmsg = "retcode=" + IntegerToString((int)res.retcode);
         return false;
      }

      return true;
   }

   bool TryStage(TA_PC_Track &t, const TA_State &st, const int stage)
   {
      if(stage < 0 || stage > 2) return false;
      if(t.fired[stage]) return false;

      // throttle
      ulong now_ms = (ulong)(GetMicrosecondCount() / 1000);
      if(t.last_attempt_ms != 0 && (now_ms - t.last_attempt_ms) < 150)
         return false;

      string sym;
      long   type;
      double entry, vol, sl;
      if(!GetPosSnapshot(t.ticket, sym, type, entry, vol, sl))
         return false;

      t.symbol      = sym;
      t.type        = type;
      t.entry_price = entry;

      double level = 0.0;
      if(!TargetPrice(t, st, stage, sl, level))
         return false;

      const bool is_buy = IsBuy(t.type);
      bool hit = false;

      if(t.trigger == TA_PARTIAL_TRIGGER_CLOSE)
      {
         double c = CandleClose(t.symbol, m_ctx.tf);
         hit = Crossed(is_buy, c, level);
      }
      else
      {
         double cur = CloseSidePrice(t.symbol, is_buy);
         hit = Crossed(is_buy, cur, level);
      }

      if(!hit) return false;

      double want = t.init_volume * (t.close_pct[stage] / 100.0);
      if(want <= 0.0)
      {
         t.fired[stage] = true;
         return true;
      }

      double close_vol = MathMin(want, vol);
      close_vol = m_br.NormalizeLots(close_vol);

      // Avoid leaving dust: if remainder < min lot, close full.
      double rem = m_br.NormalizeLots(vol - close_vol);
      if(rem > 0.0 && rem < m_br.lot_min)
         close_vol = vol;

      if(close_vol < m_br.lot_min)
      {
         if(vol >= m_br.lot_min)
            close_vol = vol;
         else
            return false;
      }

      uint rc; string em;
      t.last_attempt_ms = now_ms;

      if(!SendPartialClose(t, close_vol, stage, rc, em))
         return false;

      t.fired[stage] = true;
      return true;
   }

   void PurgeMissing()
   {
      for(int i=m_count-1; i>=0; i--)
      {
         if(!PositionSelectByTicket(m_items[i].ticket))
            RemoveAt(i);
      }
   }


public:
   TA_PartialClose(): m_count(0) {}

   bool Init(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &br)
   {
      m_ctx = ctx;
      m_br  = br;
      m_count = 0;
      return true;
   }

   void SyncConfig(const TA_Context &ctx, const TA_State &st)
   {
      m_ctx = ctx;
   }

   // Snapshot current partial settings and start tracking this position.
   void RegisterPosition(const ulong position_ticket, const TA_Context &ctx, const TA_State &st)
   {
      m_ctx = ctx;
      if(!st.tp_partials_enabled) return;
      if(position_ticket == 0) return;
      if(Find(position_ticket) >= 0) return;
      if(m_count >= TA_PC_MAX_TRACK) return;

      string sym; long type; double entry, vol, sl;
      if(!GetPosSnapshot(position_ticket, sym, type, entry, vol, sl)) return;

      ZeroMemory(m_items[m_count]);

      m_items[m_count].ticket      = position_ticket;
      m_items[m_count].symbol      = sym;
      m_items[m_count].type        = type;
      m_items[m_count].entry_price = entry;
      m_items[m_count].init_volume = vol;

      m_items[m_count].mode    = st.tp_partials_mode;
      m_items[m_count].trigger = st.tp_partials_trigger;

      m_items[m_count].at_r[0] = st.tp1_at_r; m_items[m_count].at_r[1] = st.tp2_at_r; m_items[m_count].at_r[2] = st.tp3_at_r;
      m_items[m_count].at_points[0] = st.tp1_at_points; m_items[m_count].at_points[1] = st.tp2_at_points; m_items[m_count].at_points[2] = st.tp3_at_points;
      m_items[m_count].close_pct[0] = st.tp1_close_pct; m_items[m_count].close_pct[1] = st.tp2_close_pct; m_items[m_count].close_pct[2] = st.tp3_close_pct;

      m_items[m_count].fired[0] = false; m_items[m_count].fired[1] = false; m_items[m_count].fired[2] = false;
      m_items[m_count].last_attempt_ms = 0;

      m_count++;
   }

   void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      m_ctx = ctx;
      if(!st.tp_partials_enabled)
      {
         PurgeMissing();
         return;
      }

      PurgeMissing();

      for(int i=0; i<m_count; i++)
      {
         TryStage(m_items[i], st, 0);
         TryStage(m_items[i], st, 1);
         TryStage(m_items[i], st, 2);

         if(m_items[i].fired[0] && m_items[i].fired[1] && m_items[i].fired[2])
         {
            RemoveAt(i);
            i--;
         }
      }
   }

   void OnTradeTransaction(const TA_Context &ctx, const TA_State &st,
                           const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {

      // Conservative cleanup on position/deal changes.
      if(trans.type == TRADE_TRANSACTION_POSITION ||
         trans.type == TRADE_TRANSACTION_POSITION_CLOSED ||
         trans.type == TRADE_TRANSACTION_DEAL_ADD ||
         trans.type == TRADE_TRANSACTION_DEAL_UPDATE ||
         trans.type == TRADE_TRANSACTION_DEAL_DELETE)
      {
         PurgeMissing();
      }
   }

   void OnChartEvent(const TA_Context &ctx, const TA_State &st,
                     const int id, const long &lparam, const double &dparam, const string &sparam)
   {
   }
};

#endif // __TA_PARTIAL_CLOSE_MQH__

//+------------------------------------------------------------------+
//|                                           TA_VirtualOrders.mqh   |
//|                      MuseraTradeAssistant (project include)      |
//|                                  (c) 2026, Musera Isaac          |
//+------------------------------------------------------------------+
//  Virtual orders engine:
//   - Virtual SL/TP: store SL/TP locally, optionally clear broker SL/TP,
//     and close positions when price crosses the virtual levels.
//   - Virtual Pending: store pending plans locally and execute a MARKET
//     entry when the trigger level is reached.
//
//  Expected location (inside MT5 Data Folder):
//   MQL5/Experts/MuseraTradeAssistant/include/TA_VirtualOrders.mqh
//
//  This module is intentionally designed to depend on other project includes.
//  It is ok if your project does not compile until all includes exist.

//---------------------------- include guard -----------------------------
#ifndef __MUSERA_TA_VIRTUALORDERS_MQH__
#define __MUSERA_TA_VIRTUALORDERS_MQH__

#include <Trade/Trade.mqh>

// Project includes (expected to exist in the same include folder)
#include "TA_Types.mqh"
#include "TA_State.mqh"
#include "TA_Utils.mqh"

//---------------------------- helpers -----------------------------
bool TA_VO_IsBuyPending(const ENUM_ORDER_TYPE t)
{
   return (t==ORDER_TYPE_BUY_LIMIT || t==ORDER_TYPE_BUY_STOP || t==ORDER_TYPE_BUY_STOP_LIMIT);
}
bool TA_VO_IsSellPending(const ENUM_ORDER_TYPE t)
{
   return (t==ORDER_TYPE_SELL_LIMIT || t==ORDER_TYPE_SELL_STOP || t==ORDER_TYPE_SELL_STOP_LIMIT);
}
bool TA_VO_IsPendingType(const ENUM_ORDER_TYPE t)
{
   return TA_VO_IsBuyPending(t) || TA_VO_IsSellPending(t);
}

// Trigger evaluation using current BID/ASK and the stored entry (trigger) price.
bool TA_VO_Triggered(const ENUM_ORDER_TYPE t, const double entry, const double bid, const double ask)
{
   if(t==ORDER_TYPE_BUY_LIMIT)       return (ask <= entry);
   if(t==ORDER_TYPE_BUY_STOP)        return (ask >= entry);
   if(t==ORDER_TYPE_BUY_STOP_LIMIT)  return (ask >= entry); // simplified
   if(t==ORDER_TYPE_SELL_LIMIT)      return (bid >= entry);
   if(t==ORDER_TYPE_SELL_STOP)       return (bid <= entry);
   if(t==ORDER_TYPE_SELL_STOP_LIMIT) return (bid <= entry); // simplified
   return false;
}

void TA_VO_NormalizeSLTP(const string symbol, double &sl, double &tp)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(sl > 0) sl = NormalizeDouble(sl, digits);
   if(tp > 0) tp = NormalizeDouble(tp, digits);
}

// Send a TRADE_ACTION_SLTP modification by position ticket (works for hedging).
bool TA_VO_SetPositionSLTP(const string symbol,
                                 const ulong  magic,
                                 const ulong  position_ticket,
                                 double       sl,
                                 double       tp,
                                 string      &err)
{
   TA_VO_NormalizeSLTP(symbol, sl, tp);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = symbol;
   req.magic    = magic;
   req.position = position_ticket;
   req.sl       = sl;
   req.tp       = tp;

   bool ok = OrderSend(req, res);
   if(!ok)
   {
      err = "OrderSend(SLTP) failed, last_error=" + IntegerToString(_LastError);
      return false;
   }
   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      err = "SLTP retcode=" + IntegerToString((int)res.retcode);
      return false;
   }
   return true;
}

//---------------------------- TA_VirtualOrders -----------------------------
//
// Integration notes:
//  - If you want virtual SL/TP for NEW entries, your OrderExecutor should place
//    trades with broker SL/TP = 0 and call RegisterVirtualSLTP(ticket, planned_sl, planned_tp).
//  - This engine also supports "capturing" broker SL/TP of existing positions:
//    if vorders_virtual_sl_tp is enabled and a position has broker SL/TP set,
//    this engine can read & store those values, then clear broker SL/TP.
//
class TA_VirtualOrders
{
private:
   struct VSLTP
   {
      bool     active;
      ulong    position_ticket;
      double   sl;
      double   tp;
      datetime added_at;
   };

   struct VPending
   {
      bool        active;
      ulong       id;
      datetime    created_at;
      datetime    expires_at;   // 0 = never
      ulong       oco_group;    // 0 = none
      TA_OrderPlan plan;        // entry_price used as trigger
   };

   // runtime
   bool       m_inited;
   uint       m_last_ms;
   ulong      m_next_pending_id;

   TA_Context m_ctx;
   TA_State   m_state;

   CTrade     m_trade;

   VSLTP      m_sltp[];
   VPending   m_pending[];

   // ---------------- internal utils ----------------
   int FindSLTPIndex(const ulong position_ticket) const
   {
      int n = ArraySize(m_sltp);
      for(int i=0;i<n;i++)
         if(m_sltp[i].active && m_sltp[i].position_ticket==position_ticket)
            return i;
      return -1;
   }

   void RemoveSLTPByIndex(const int idx)
   {
      if(idx<0 || idx>=ArraySize(m_sltp)) return;
      m_sltp[idx].active=false;
      m_sltp[idx].position_ticket=0;
      m_sltp[idx].sl=0;
      m_sltp[idx].tp=0;
      m_sltp[idx].added_at=0;
   }

   int FindPendingIndexById(const ulong id) const
   {
      int n = ArraySize(m_pending);
      for(int i=0;i<n;i++)
         if(m_pending[i].active && m_pending[i].id==id)
            return i;
      return -1;
   }

   void RemovePendingByIndex(const int idx)
   {
      if(idx<0 || idx>=ArraySize(m_pending)) return;
      m_pending[idx].active=false;
      m_pending[idx].id=0;
      m_pending[idx].created_at=0;
      m_pending[idx].expires_at=0;
      m_pending[idx].oco_group=0;
      // plan left as-is
   }

   void CancelPendingByOCOGroup(const ulong group, const ulong except_id=0)
   {
      if(group==0) return;
      int n = ArraySize(m_pending);
      for(int i=0;i<n;i++)
      {
         if(!m_pending[i].active) continue;
         if(m_pending[i].oco_group!=group) continue;
         if(except_id!=0 && m_pending[i].id==except_id) continue;
         RemovePendingByIndex(i);
      }
   }

   bool ClosePositionTicket(const ulong ticket)
   {
      ResetLastError();
      bool ok = m_trade.PositionClose(ticket);
      if(!ok)
         Print("TA_VirtualOrders: PositionClose failed ticket=", ticket, " err=", _LastError);
      return ok;
   }

   bool CaptureAndClearBrokerStopsIfNeeded(const ulong ticket, const string symbol)
   {
      if(!m_state.vorders_enabled || !m_state.vorders_virtual_sl_tp) return false;

      // Skip if already tracked
      if(FindSLTPIndex(ticket) >= 0) return false;

      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      if(sl<=0 && tp<=0) return false; // nothing to capture

      // Store
      RegisterVirtualSLTP(ticket, sl, tp);

      // Clear broker stops
      string err;
      if(!TA_VO_SetPositionSLTP(symbol, m_ctx.magic, ticket, 0.0, 0.0, err))
      {
         Print("TA_VirtualOrders: failed clearing broker SLTP. ", err);
      }
      return true;
   }

   void ProcessVirtualSLTP()
   {
      if(!m_state.vorders_enabled) return;
      if(!m_state.vorders_virtual_sl_tp) return;

      const string symbol = m_ctx.symbol;

      double bid = 0, ask = 0;
      if(!SymbolInfoDouble(symbol, SYMBOL_BID, bid) || !SymbolInfoDouble(symbol, SYMBOL_ASK, ask))
         return;

      // For each position, capture broker SL/TP (if any), then enforce virtual SL/TP.
      for(int i=PositionsTotal()-1; i>=0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket==0) continue;
         if(!PositionSelectByTicket(ticket)) continue;

         string psym = PositionGetString(POSITION_SYMBOL);
         if(psym != symbol) continue;

         long magic = (long)PositionGetInteger(POSITION_MAGIC);
         if((ulong)magic != m_ctx.magic) continue;

         // capture broker stops (optional)
         CaptureAndClearBrokerStopsIfNeeded(ticket, psym);

         int idx = FindSLTPIndex(ticket);
         if(idx < 0) continue; // we don't know desired levels

         const long ptype = (long)PositionGetInteger(POSITION_TYPE);
         const bool is_buy = (ptype == POSITION_TYPE_BUY);

         const double vsl = m_sltp[idx].sl;
         const double vtp = m_sltp[idx].tp;

         bool need_close = false;

         if(vsl > 0)
         {
            if(is_buy && bid <= vsl) need_close = true;
            if(!is_buy && ask >= vsl) need_close = true;
         }

         if(!need_close && vtp > 0)
         {
            if(is_buy && bid >= vtp) need_close = true;
            if(!is_buy && ask <= vtp) need_close = true;
         }

         if(need_close)
         {
            if(ClosePositionTicket(ticket))
               RemoveSLTPByIndex(idx);
         }
      }

      // purge stale tracked tickets
      int n = ArraySize(m_sltp);
      for(int j=0;j<n;j++)
      {
         if(!m_sltp[j].active) continue;
         if(!PositionSelectByTicket(m_sltp[j].position_ticket))
            RemoveSLTPByIndex(j);
      }
   }

   bool ExecuteVirtualPending(const int pidx)
   {
      if(pidx<0 || pidx>=ArraySize(m_pending)) return false;
      if(!m_pending[pidx].active) return false;

      const TA_OrderPlan &plan = m_pending[pidx].plan;
      const string symbol = plan.symbol;

      const bool is_buy = TA_VO_IsBuyPending(plan.order_type);

      // planned stops
      double planned_sl = plan.planned_sl;
      double planned_tp = plan.planned_tp;

      // If using virtual SL/TP, do NOT send broker SL/TP.
      double send_sl = (m_state.vorders_virtual_sl_tp ? 0.0 : planned_sl);
      double send_tp = (m_state.vorders_virtual_sl_tp ? 0.0 : planned_tp);

      TA_VO_NormalizeSLTP(symbol, planned_sl, planned_tp);
      TA_VO_NormalizeSLTP(symbol, send_sl, send_tp);

      ResetLastError();
      bool ok = false;

      if(is_buy)
         ok = m_trade.Buy(plan.lots, symbol, 0.0, send_sl, send_tp, plan.comment);
      else
         ok = m_trade.Sell(plan.lots, symbol, 0.0, send_sl, send_tp, plan.comment);

      if(!ok)
      {
         Print("TA_VirtualOrders: virtual pending execution failed. err=", _LastError);
         return false;
      }

      // Try to infer position ticket from the resulting deal
      ulong deal = m_trade.ResultDeal();
      ulong pos_ticket = 0;

      if(deal > 0)
      {
         pos_ticket = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      }

      // Register virtual SL/TP targets if enabled
      if(m_state.vorders_virtual_sl_tp && pos_ticket>0 && (planned_sl>0 || planned_tp>0))
      {
         RegisterVirtualSLTP(pos_ticket, planned_sl, planned_tp);

         // Safety: ensure broker SL/TP is cleared (some brokers set it anyway)
         string err;
         TA_VO_SetPositionSLTP(symbol, m_ctx.magic, pos_ticket, 0.0, 0.0, err);
      }

      // If OCO: cancel siblings
      if(m_pending[pidx].oco_group != 0)
         CancelPendingByOCOGroup(m_pending[pidx].oco_group, m_pending[pidx].id);

      return true;
   }

   void ProcessVirtualPending()
   {
      if(!m_state.vorders_enabled) return;
      if(!m_state.vorders_virtual_pending) return;

      const string symbol = m_ctx.symbol;

      double bid = 0, ask = 0;
      if(!SymbolInfoDouble(symbol, SYMBOL_BID, bid) || !SymbolInfoDouble(symbol, SYMBOL_ASK, ask))
         return;

      const datetime now = TimeCurrent();

      int n = ArraySize(m_pending);
      for(int i=0;i<n;i++)
      {
         if(!m_pending[i].active) continue;

         if(m_pending[i].expires_at != 0 && now >= m_pending[i].expires_at)
         {
            RemovePendingByIndex(i);
            continue;
         }

         const TA_OrderPlan &plan = m_pending[i].plan;

         // Only handle current chart symbol for now
         if(plan.symbol != symbol) continue;

         if(!TA_VO_Triggered(plan.order_type, plan.entry_price, bid, ask))
            continue;

         // Execute and remove
         if(ExecuteVirtualPending(i))
            RemovePendingByIndex(i);
      }
   }

public:
   TA_VirtualOrders() : m_inited(false), m_last_ms(0), m_next_pending_id(1) {}

   bool Init(const TA_Context &ctx, const TA_State &state, const TA_BrokerRules &broker)
   {

      m_ctx   = ctx;
      m_state = state;

      m_trade.SetExpertMagicNumber((int)ctx.magic);
      m_trade.SetDeviationInPoints(state.default_deviation_points);

      ArrayResize(m_sltp, 0);
      ArrayResize(m_pending, 0);

      m_last_ms = 0;
      m_next_pending_id = 1;

      m_inited = true;
      return true;
   }

   void SyncConfig(const TA_Context &ctx, const TA_State &state)
   {
      m_ctx   = ctx;
      m_state = state;

      m_trade.SetExpertMagicNumber((int)ctx.magic);
      m_trade.SetDeviationInPoints(state.default_deviation_points);
   }

   // Register explicit virtual SL/TP targets for a given position ticket.
   bool RegisterVirtualSLTP(const ulong position_ticket, const double sl, const double tp)
   {
      if(position_ticket==0) return false;

      int idx = FindSLTPIndex(position_ticket);
      if(idx >= 0)
      {
         m_sltp[idx].sl = sl;
         m_sltp[idx].tp = tp;
         return true;
      }

      VSLTP item;
      item.active = true;
      item.position_ticket = position_ticket;
      item.sl = sl;
      item.tp = tp;
      item.added_at = TimeCurrent();

      int n = ArraySize(m_sltp);
      ArrayResize(m_sltp, n+1);
      m_sltp[n] = item;
      return true;
   }

   // Adds a virtual pending plan. plan.order_type MUST be a pending type and
   // plan.entry_price is used as the trigger.
   bool AddVirtualPending(const TA_OrderPlan &plan, const datetime expires_at=0, const ulong oco_group=0)
   {
      if(!m_state.vorders_enabled || !m_state.vorders_virtual_pending) return false;
      if(!TA_VO_IsPendingType(plan.order_type)) return false;
      if(plan.entry_price <= 0) return false;

      VPending p;
      p.active = true;
      p.id = m_next_pending_id++;
      p.created_at = TimeCurrent();
      p.expires_at = expires_at;
      p.oco_group  = oco_group;
      p.plan = plan;

      int n = ArraySize(m_pending);
      ArrayResize(m_pending, n+1);
      m_pending[n] = p;
      return true;
   }

   bool CancelVirtualPending(const ulong pending_id)
   {
      int idx = FindPendingIndexById(pending_id);
      if(idx < 0) return false;
      RemovePendingByIndex(idx);
      return true;
   }

   void OnTimer(const TA_Context &ctx, const TA_State &state)
   {
      if(!m_inited) return;

      // Keep latest context/config
      SyncConfig(ctx, state);

      if(!m_state.vorders_enabled) return;

      const uint poll = (uint)MathMax(50, m_state.vorders_poll_ms);
      const uint now  = (uint)GetTickCount();

      if(m_last_ms != 0 && (now - m_last_ms) < poll)
         return;
      m_last_ms = now;

      ProcessVirtualPending();
      ProcessVirtualSLTP();
   }

   void OnTradeTransaction(const TA_Context &ctx,
                           const TA_State &state,
                           const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {

      if(!m_inited) return;
      SyncConfig(ctx, state);

      // Purge SLTP mapping on position close deals (best effort)
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal > 0)
      {
         if(HistoryDealSelect(trans.deal))
         {
            long entry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
            {
               ulong pos = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
               int idx = FindSLTPIndex(pos);
               if(idx >= 0) RemoveSLTPByIndex(idx);
            }
         }
      }
   }

   void OnChartEvent(const TA_Context &ctx,
                     const TA_State &state,
                     const int id,
                     const long &lparam,
                     const double &dparam,
                     const string &sparam)
   {
      // Reserved: drag handles, on-chart virtual order lines, etc.
   }
};

#endif // __MUSERA_TA_VIRTUALORDERS_MQH__

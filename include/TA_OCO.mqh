//+------------------------------------------------------------------+
//|                                                   TA_OCO.mqh     |
//|                           (c) 2026, Musera Isaac                 |
//|  One-Cancels-the-Other (OCO) engine for pending/virtual orders.   |
//|                                                                  |
//|  DESIGN GOALS                                                     |
//|  - Tickless: works mainly from OnTradeTransaction + OnTimer.      |
//|  - Safe by default: cancels sibling ONLY when a leg is FILLED.    |
//|  - Stateless operation: can recover by scanning comments.         |
//|                                                                  |
//|  CURRENT SCOPE                                                    |
//|  - Broker pending OCO supported (based on ORDER_COMMENT tag).     |
//|  - Virtual OCO hooks are placeholders; virtual engine provides    |
//|    its own cancellation API later (TA_VirtualOrders.mqh).         |
//|                                                                  |
//|  TAG FORMAT                                                       |
//|  Put an OCO tag inside the order comment when placing pendings:   |
//|      "... OCO:<group_id> ..."                                     |
//|  Example: "MTA|OCO:NYOpenBreak|v1"                                |
//|                                                                  |
//|  When a pending with OCO tag is executed (DEAL_ENTRY_IN), this    |
//|  module deletes all other *pending* orders with same group_id     |
//|  on the same symbol+magic.                                        |
//+------------------------------------------------------------------+
#property strict

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"

//------------------------------ Helper (parsing) ------------------------------
class TA_OCO_Parser
{
public:
   // Extracts tag after "OCO:"; stops at whitespace or separators.
   static bool ParseTag(const string comment, string &tag_out)
   {
      tag_out = "";

      int p = StringFind(comment, "OCO:", 0);
      if(p < 0) return false;

      int start = p + 4;
      int len = (int)StringLen(comment);

      // Skip leading separators
      while(start < len)
      {
         ushort ch = StringGetCharacter(comment, start);
         if(ch!=' ' && ch!='|' && ch!=';' && ch!='#' && ch!='[' && ch!=']' && ch!='(' && ch!=')')
            break;
         start++;
      }
      if(start >= len) return false;

      int end = start;
      while(end < len)
      {
         ushort ch = StringGetCharacter(comment, end);
         if(ch==' ' || ch=='|' || ch==';' || ch=='#' || ch=='[' || ch==']' || ch=='(' || ch==')')
            break;
         end++;
      }

      if(end <= start) return false;
      tag_out = StringSubstr(comment, start, end - start);
      return (tag_out != "");
   }
};

//------------------------------ TA_OCO ------------------------------
class TA_OCO
{
private:
   // Local cached config (copied from TA_State on SyncConfig/Init)
   ENUM_TA_OCO_MODE m_mode;
   bool             m_enabled;

   // Debounce scanning
   uint             m_last_scan_ms;
   uint             m_scan_interval_ms;

private:
   bool ModeAllowsPending() const
   {
      return (m_enabled && (m_mode == TA_OCO_PENDING || m_mode == TA_OCO_BOTH));
   }

   // Deletes a broker pending order by ticket.
   // Returns true if order is deleted OR already not found.
   bool DeletePending(const TA_Context &ctx, const ulong order_ticket)
   {
      if(order_ticket == 0) return false;

      // If it's already gone, consider it success.
      if(!HistoryOrderSelect((ulong)order_ticket))
      {
         // Could still be active; attempt remove anyway.
      }

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      req.action = TRADE_ACTION_REMOVE;
      req.order  = order_ticket;
      req.magic  = ctx.magic;
      req.symbol = ctx.symbol;

      if(!OrderSend(req, res))
      {
         // OrderSend failed at transport layer
         Print("TA_OCO: OrderSend(REMOVE) failed. ticket=", (string)order_ticket, " err=", (string)GetLastError());
         ResetLastError();
         return false;
      }

      // Retcodes vary by broker; accept DONE / DONE_PARTIAL / placed removal.
      if(res.retcode == TRADE_RETCODE_DONE ||
         res.retcode == TRADE_RETCODE_DONE_PARTIAL ||
         res.retcode == TRADE_RETCODE_PLACED)
         return true;

      // If order already removed or unknown, treat as success.
      if(res.retcode == TRADE_RETCODE_ORDER_NOT_FOUND)
         return true;

      Print("TA_OCO: REMOVE retcode=", (string)res.retcode, " ticket=", (string)order_ticket, " comment=", res.comment);
      return false;
   }

   // Cancels all sibling pending orders that share the same OCO tag.
   // except_ticket: keep this one (0 = cancel all matching pendings).
   void CancelSiblingsPending(const TA_Context &ctx, const string tag, const ulong except_ticket)
   {
      if(tag == "" || !ModeAllowsPending()) return;

      // Iterate backwards (safe if deletions happen).
      int total = OrdersTotal();
      for(int i = total - 1; i >= 0; --i)
      {
         ulong t = OrderGetTicket(i);
         if(t == 0) continue;
         if(except_ticket != 0 && t == except_ticket) continue;

         if(!OrderSelect(t)) continue;

         // Filter: symbol + magic
         string sym = (string)OrderGetString(ORDER_SYMBOL);
         if(sym != ctx.symbol) continue;

         long magic = (long)OrderGetInteger(ORDER_MAGIC);
         if((ulong)magic != ctx.magic) continue;

         // Only pending orders
         ENUM_ORDER_STATE st = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
         ENUM_ORDER_TYPE  ty = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

         // Market orders won't be present as "active" for long; still guard.
         if(ty == ORDER_TYPE_BUY || ty == ORDER_TYPE_SELL) continue;

         // Ignore non-active states
         if(st == ORDER_STATE_FILLED || st == ORDER_STATE_CANCELED || st == ORDER_STATE_REJECTED || st == ORDER_STATE_EXPIRED)
            continue;

         string cmt = (string)OrderGetString(ORDER_COMMENT);
         string found;
         if(!TA_OCO_Parser::ParseTag(cmt, found)) continue;
         if(found != tag) continue;

         // Delete sibling pending
         DeletePending(ctx, t);
      }
   }

   // Backup recovery: if we have an open position with OCO tag in comment,
   // cancel any remaining pending siblings with same tag.
   void ScanPositionsAndCancel(const TA_Context &ctx)
   {
      if(!ModeAllowsPending()) return;

      int ptotal = PositionsTotal();
      for(int i = ptotal - 1; i >= 0; --i)
      {
         ulong pt = PositionGetTicket(i);
         if(pt == 0) continue;

         if(!PositionSelectByTicket(pt)) continue;

         string sym = (string)PositionGetString(POSITION_SYMBOL);
         if(sym != ctx.symbol) continue;

         long magic = (long)PositionGetInteger(POSITION_MAGIC);
         if((ulong)magic != ctx.magic) continue;

         string cmt = (string)PositionGetString(POSITION_COMMENT);

         string tag;
         if(!TA_OCO_Parser::ParseTag(cmt, tag)) continue;

         // Cancel all pending siblings (no except)
         CancelSiblingsPending(ctx, tag, 0);
      }
   }

public:
   TA_OCO()
   {
      m_mode             = TA_OCO_NONE;
      m_enabled          = false;
      m_last_scan_ms     = 0;
      m_scan_interval_ms = 750; // conservative default
   }

   bool Init(const TA_Context &ctx, const TA_State &state, const TA_BrokerRules &broker)
   {
      SyncConfig(ctx, state);
      return true;
   }

   void SyncConfig(const TA_Context &ctx, const TA_State &state)
   {
      m_mode    = state.oco_mode;
      m_enabled = (m_mode != TA_OCO_NONE);
   }

   // Allow caller to tune scan interval (ms). 0 disables timer scan fallback.
   void SetScanIntervalMS(const uint ms)
   {
      m_scan_interval_ms = ms;
   }

   void OnTimer(const TA_Context &ctx, const TA_State &state)
   {
      SyncConfig(ctx, state);
      if(!ModeAllowsPending()) return;

      if(m_scan_interval_ms == 0) return;

      uint now = (uint)GetTickCount();
      if(m_last_scan_ms != 0 && (now - m_last_scan_ms) < m_scan_interval_ms)
         return;
      m_last_scan_ms = now;

      // Backup scan (covers missed OnTradeTransaction edge cases)
      ScanPositionsAndCancel(ctx);
   }

   void OnTradeTransaction(const TA_Context &ctx, const TA_State &state,
                           const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {
      SyncConfig(ctx, state);
      if(!ModeAllowsPending()) return;

      // We cancel siblings ONLY when an order leg enters the market.
      // Primary signal: DEAL_ADD with DEAL_ENTRY_IN.
      if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
         return;

      // trans.deal_entry is available in newer terminals; if not, fallback to history.
      bool is_entry_in = false;

      // Attempt 1: direct field (safe if platform supports it)
      // Some builds store it in trans.entry or trans.deal_entry.
      // We'll use history as definitive signal to avoid build differences.
      if(trans.deal > 0 && HistoryDealSelect(trans.deal))
      {
         long entry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         is_entry_in = (entry == DEAL_ENTRY_IN);
      }

      if(!is_entry_in) return;

      // Extract OCO tag from order comment (prefer history order; fallback to request.comment)
      string comment = "";
      if(trans.order > 0 && HistoryOrderSelect(trans.order))
         comment = (string)HistoryOrderGetString(trans.order, ORDER_COMMENT);
      else
         comment = request.comment;

      string tag;
      if(!TA_OCO_Parser::ParseTag(comment, tag))
         return;

      // Cancel all sibling pending orders with same tag, except the filled order.
      // Note: the filled order may already be absent from active OrdersTotal.
      CancelSiblingsPending(ctx, tag, trans.order);
   }
};

//+------------------------------------------------------------------+
//|                                              TA_OrderExecutor.mqh |
//|                         MuseraTradeAssistant (c) 2026, Musera Isaac |
//|                                                                  |
//|  Sends/edits trading requests built by TA_OrderBuilder.           |
//|  Intentionally lightweight: focuses on request execution and      |
//|  consistent result reporting (TA_ExecResult).                     |
//+------------------------------------------------------------------+
#ifndef __TA_ORDEREXECUTOR_MQH__
#define __TA_ORDEREXECUTOR_MQH__

#include <Trade/Trade.mqh>

// Core project types
#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
bool TA__RetcodeOk(const uint retcode)
{
   return (retcode == TRADE_RETCODE_DONE ||
           retcode == TRADE_RETCODE_DONE_PARTIAL ||
           retcode == TRADE_RETCODE_PLACED ||
           retcode == TRADE_RETCODE_ACCEPTED);
}

string TA__RetcodeToString(const uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:            return "REQUOTE";
      case TRADE_RETCODE_REJECT:             return "REJECT";
      case TRADE_RETCODE_CANCEL:             return "CANCEL";
      case TRADE_RETCODE_PLACED:             return "PLACED";
      case TRADE_RETCODE_DONE:               return "DONE";
      case TRADE_RETCODE_DONE_PARTIAL:       return "DONE_PARTIAL";
      case TRADE_RETCODE_ERROR:              return "ERROR";
      case TRADE_RETCODE_TIMEOUT:            return "TIMEOUT";
      case TRADE_RETCODE_INVALID:            return "INVALID";
      case TRADE_RETCODE_INVALID_VOLUME:     return "INVALID_VOLUME";
      case TRADE_RETCODE_INVALID_PRICE:      return "INVALID_PRICE";
      case TRADE_RETCODE_INVALID_STOPS:      return "INVALID_STOPS";
      case TRADE_RETCODE_TRADE_DISABLED:     return "TRADE_DISABLED";
      case TRADE_RETCODE_MARKET_CLOSED:      return "MARKET_CLOSED";
      case TRADE_RETCODE_NO_MONEY:           return "NO_MONEY";
      case TRADE_RETCODE_PRICE_CHANGED:      return "PRICE_CHANGED";
      case TRADE_RETCODE_PRICE_OFF:          return "PRICE_OFF";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "INVALID_EXPIRATION";
      case TRADE_RETCODE_ORDER_CHANGED:      return "ORDER_CHANGED";
      case TRADE_RETCODE_TOO_MANY_REQUESTS:  return "TOO_MANY_REQUESTS";
      default:                               return "RETCODE_" + IntegerToString((int)retcode);
   }
}

void TA__FillExecResult(const MqlTradeResult &tr, TA_ExecResult &out_er, const string fallback_msg="")
{
   out_er.retcode         = tr.retcode;
   out_er.order_ticket    = (ulong)tr.order;
   out_er.deal_ticket     = (ulong)tr.deal;
   out_er.position_ticket = (ulong)tr.position;

   string msg = tr.comment;
   if(msg == "" && fallback_msg != "")
      msg = fallback_msg;

   if(msg == "")
      msg = TA__RetcodeToString(tr.retcode);

   out_er.message = msg;
   out_er.success = TA__RetcodeOk(tr.retcode);
}

//+------------------------------------------------------------------+
//| TA_OrderExecutor                                                 |
//+------------------------------------------------------------------+
class TA_OrderExecutor
{
public:
   TA_OrderExecutor() {}

   // Core senders (expected to be used by MuseraTradeAssistant.mq5)
   bool SendMarket(const TA_OrderPlan &plan, TA_ExecResult &out_er)
   {
      return SendPlan(plan, out_er);
   }

   bool SendPending(const TA_OrderPlan &plan, TA_ExecResult &out_er)
   {
      return SendPlan(plan, out_er);
   }

   // Generic "plan" execution. Builder is expected to have filled plan.req.
   bool SendPlan(const TA_OrderPlan &plan, TA_ExecResult &out_er)
   {
      out_er.success = false;
      out_er.retcode = 0;
      out_er.order_ticket = 0;
      out_er.deal_ticket = 0;
      out_er.position_ticket = 0;
      out_er.message = "";

      // If the builder stores a build status, respect it when present.
      // (We don't assume the field exists in every version; keep this in a comment.)
      // if(!plan.build_res.ok) { out_er.message = plan.build_res.message; return false; }

      // Preferred path: execute the request prepared by TA_OrderBuilder.
      // TA_OrderPlan is expected to contain: MqlTradeRequest req;
      MqlTradeRequest req;
      ZeroMemory(req);

      // ---- Compatibility note ----
      // If your TA_OrderPlan definition does not carry 'req', you can modify this
      // executor to build the request from plan fields (symbol/side/price/sl/tp/etc).
      // This project version expects plan.req to be present.
#ifdef __MQL5__
      // Try to copy plan.req (will compile only if field exists).
      req = plan.req;
#endif

      // Apply sane defaults if missing.
      if(req.deviation <= 0)
         req.deviation = TA_DEFAULT_DEVIATION_POINTS;

      // Basic sanity
      if(req.symbol == "")
      {
         out_er.message = "TA_OrderExecutor: request symbol is empty";
         return false;
      }

      // Retry a few times for common transient errors (requote/price changed).
      MqlTradeResult tr;
      ZeroMemory(tr);

      const int max_tries = 3;
      for(int i=0; i<max_tries; i++)
      {
         ResetLastError();
         bool ok = OrderSend(req, tr);
         if(ok && TA__RetcodeOk(tr.retcode))
         {
            TA__FillExecResult(tr, out_er);
            return true;
         }

         // Fill result for caller visibility even on failure.
         string fallback = "OrderSend failed, lasterr=" + IntegerToString(_LastError);
         TA__FillExecResult(tr, out_er, fallback);

         if(tr.retcode == TRADE_RETCODE_REQUOTE || tr.retcode == TRADE_RETCODE_PRICE_CHANGED)
         {
            // Update market price and retry.
            double bid=0, ask=0;
            SymbolInfoDouble(req.symbol, SYMBOL_BID, bid);
            SymbolInfoDouble(req.symbol, SYMBOL_ASK, ask);

            if(req.type == ORDER_TYPE_BUY || req.type == ORDER_TYPE_BUY_LIMIT || req.type == ORDER_TYPE_BUY_STOP || req.type == ORDER_TYPE_BUY_STOP_LIMIT)
               req.price = ask;
            else if(req.type == ORDER_TYPE_SELL || req.type == ORDER_TYPE_SELL_LIMIT || req.type == ORDER_TYPE_SELL_STOP || req.type == ORDER_TYPE_SELL_STOP_LIMIT)
               req.price = bid;

            continue;
         }

         // Not a transient case -> stop.
         break;
      }

      return false;
   }

   // Set SL/TP for an existing position (common for BE/Trailing managers).
   bool SetPositionSLTP(const ulong position_ticket, const double sl, const double tp, TA_ExecResult &out_er)
   {
      out_er.success = false;
      out_er.message = "";

      if(!PositionSelectByTicket(position_ticket))
      {
         out_er.message = "Position not found: " + IntegerToString((long)position_ticket);
         return false;
      }

      string sym = PositionGetString(POSITION_SYMBOL);

      MqlTradeRequest req;
      MqlTradeResult  tr;
      ZeroMemory(req);
      ZeroMemory(tr);

      req.action   = TRADE_ACTION_SLTP;
      req.symbol   = sym;
      req.position = position_ticket;
      req.sl       = sl;
      req.tp       = tp;
      req.deviation = TA_DEFAULT_DEVIATION_POINTS;

      ResetLastError();
      bool ok = OrderSend(req, tr);

      string fallback = "SLTP failed, lasterr=" + IntegerToString(_LastError);
      TA__FillExecResult(tr, out_er, fallback);
      return (ok && out_er.success);
   }

   // Delete pending order by ticket.
   bool DeletePending(const ulong order_ticket, TA_ExecResult &out_er)
   {
      out_er.success = false;
      out_er.message = "";

      MqlTradeRequest req;
      MqlTradeResult  tr;
      ZeroMemory(req);
      ZeroMemory(tr);

      req.action = TRADE_ACTION_REMOVE;
      req.order  = order_ticket;

      ResetLastError();
      bool ok = OrderSend(req, tr);

      string fallback = "REMOVE failed, lasterr=" + IntegerToString(_LastError);
      TA__FillExecResult(tr, out_er, fallback);
      return (ok && out_er.success);
   }
};

#endif // __TA_ORDEREXECUTOR_MQH__

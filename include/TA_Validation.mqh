//+------------------------------------------------------------------+
//|                                                TA_Validation.mqh  |
//|                         MuseraTradeAssistant (c) 2026, Musera Isaac |
//+------------------------------------------------------------------+
#property strict

#ifndef __TA_VALIDATION_MQH__
#define __TA_VALIDATION_MQH__

#include "TA_Types.mqh"
#include "TA_Utils.mqh"
#include "TA_BrokerRules.mqh"

inline void TA_ResetResult(TA_Result &res){ res.ok=true; res.code=0; res.message=""; }
inline bool TA_Ok(TA_Result &res){ TA_ResetResult(res); return true; }
inline bool TA_Fail(TA_Result &res,int code,const string msg){ res.ok=false; res.code=code; res.message=msg; return false; }

// Order plan validation stubs (kept minimal for compile safety).
inline bool TA_ValidateOrderPlanMarket(const TA_OrderPlan &plan, const TA_BrokerRules &br, TA_Result &out_res)
{
   TA_ResetResult(out_res);

   if(plan.symbol == "")
      return TA_Fail(out_res, TA_ERR_INVALID_PARAM, "Order plan symbol missing.");

   if(plan.volume <= 0.0)
      return TA_Fail(out_res, TA_ERR_INVALID_PARAM, "Order plan volume must be > 0.");

   if(plan.sl > 0.0 && !TA__IsFinite(plan.sl))
      return TA_Fail(out_res, TA_ERR_INVALID_PARAM, "Order plan SL invalid.");

   if(plan.tp > 0.0 && !TA__IsFinite(plan.tp))
      return TA_Fail(out_res, TA_ERR_INVALID_PARAM, "Order plan TP invalid.");

   return true;
}

inline bool TA_ValidateOrderPlanPending(const TA_OrderPlan &plan, const TA_BrokerRules &br, TA_Result &out_res)
{
   TA_ResetResult(out_res);

   if(plan.symbol == "")
      return TA_Fail(out_res, TA_ERR_INVALID_PARAM, "Order plan symbol missing.");

   if(plan.price <= 0.0 || !TA__IsFinite(plan.price))
      return TA_Fail(out_res, TA_ERR_INVALID_PARAM, "Pending price invalid.");

   return true;
}

// Current project shell does not rely on deep validation yet.
// Keep this header minimal and compilable; extend as the tool evolves.

#endif // __TA_VALIDATION_MQH__

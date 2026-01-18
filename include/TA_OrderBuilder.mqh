//+------------------------------------------------------------------+
//|                                                   TA_OrderBuilder.mqh |
//|                                  (c) 2026, Musera Isaac               |
//|  Builds validated trade plans (market/pending) from TA_State.          |
//|                                                                          |
//|  This module is intentionally lightweight and composable:                 |
//|   - Reads user config from TA_State                                      |
//|   - Queries broker constraints via TA_BrokerRules                         |
//|   - Calculates volume via TA_Risk                                        |
//|   - Calculates TP levels via TA_RR                                      |
//|   - Validates plan via TA_Validation                                     |
//|                                                                          |
//|  Used by: MuseraTradeAssistant.mq5                                        |
//+------------------------------------------------------------------+
#ifndef __TA_ORDERBUILDER_MQH__
#define __TA_ORDERBUILDER_MQH__

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"
#include "TA_Validation.mqh"
#include "TA_BrokerRules.mqh"
#include "TA_Risk.mqh"
#include "TA_RR.mqh"

// Map symbol filling mode -> request filling type
inline ENUM_ORDER_TYPE_FILLING TA__PickFilling(const string symbol)
{
   // NOTE: Brokers can reject certain filling types. We pick the symbol's preferred/allowed mode.
   const long fm = (long)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);

   // ENUM_SYMBOL_FILLING_MODE:
   //  SYMBOL_FILLING_FOK, SYMBOL_FILLING_IOC, SYMBOL_FILLING_RETURN
   if(fm == SYMBOL_FILLING_FOK)     return ORDER_FILLING_FOK;
   if(fm == SYMBOL_FILLING_IOC)     return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| TA_OrderBuilder                                                   |
//+------------------------------------------------------------------+
class TA_OrderBuilder
{
private:
   TA_Risk  m_risk;
   TA_RR    m_rr;

   void ResetPlan(TA_OrderPlan &p) const
   {
      p.action   = TA_ACTION_MARKET;
      p.symbol   = "";
      p.magic    = 0;
      p.side     = TA_SIDE_NONE;
      p.volume   = 0.0;
      p.price    = 0.0;
      p.sl       = 0.0;
      p.tp       = 0.0;
      p.deviation= 0;
      p.tp_count = 0;
      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
         p.tp_levels[i] = 0.0;

      ZeroMemory(p.req);
      ZeroMemory(p.build_res);
      p.build_res.ok = false;
      p.build_res.code = 0;
      p.build_res.message = "";
   }

   // Build SL from state (currently supports: NONE, POINTS)
   bool BuildSL(const TA_Context &ctx,
                const TA_State   &st,
                const TA_BrokerRules &br,
                const bool is_buy,
                const double entry_price,
                double &out_sl,
                TA_Result &res) const
   {
      out_sl = 0.0;

      if(st.sl_mode == TA_SL_NONE)
      {
         TA__Ok(res);
         return true;
      }

      if(st.sl_mode == TA_SL_POINTS)
      {
         if(st.sl_points <= 0)
         {
            TA__Fail(res, 1101, "SL points must be > 0.");
            return false;
         }
         const double pt = SymbolInfoDouble(ctx.symbol, SYMBOL_POINT);
         if(pt <= 0.0)
         {
            TA__Fail(res, 1102, "Symbol POINT is invalid.");
            return false;
         }
         const double raw = (is_buy ? (entry_price - st.sl_points*pt)
                                    : (entry_price + st.sl_points*pt));
         out_sl = br.NormalizePrice(raw);
         TA__Ok(res);
         return true;
      }

      // Future extension: TA_SL_ATR, TA_SL_SWING, TA_SL_CUSTOM, etc.
      TA__Fail(res, 1109, "Unsupported SL mode in TA_OrderBuilder (implement in BuildSL).");
      return false;
   }

   // Build TP levels (supports: NONE, POINTS, RR, LEVELS) via TA_RR
   bool BuildTPs(const TA_Context &ctx,
                 const TA_State   &st,
                 const TA_BrokerRules &br,
                 const bool is_buy,
                 const double entry_price,
                 const double sl_price,
                 double &out_levels[],
                 int &out_count,
                 TA_Result &res) const
   {
      out_count = 0;

      if(ArraySize(out_levels) < TA_MAX_TP_LEVELS)
         ArrayResize(out_levels, TA_MAX_TP_LEVELS);

      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
         out_levels[i] = 0.0;

      if(!m_rr.BuildTPPrices(ctx, st, br, is_buy, entry_price, sl_price, out_levels, out_count, res))
         return false;

      return true;
   }

public:
   TA_OrderBuilder() {}

   // Build a market plan (TRADE_ACTION_DEAL).
   // Returns false if validation fails (plan.build_res contains details).
   bool BuildMarketPlan(const TA_Context &ctx,
                        const TA_State   &st,
                        const bool is_buy,
                        TA_OrderPlan &out_plan)
   {
      ResetPlan(out_plan);

      TA_Result r;
      TA_BrokerRules br;
      if(!br.Init(ctx))
      {
         TA__Fail(r, 1200, "Failed to init broker rules.");
         out_plan.build_res = r;
         return false;
      }

      out_plan.action = TA_ACTION_MARKET;
      out_plan.symbol = ctx.symbol;
      out_plan.magic  = ctx.magic;
      out_plan.side   = (is_buy ? TA_SIDE_BUY : TA_SIDE_SELL);
      out_plan.deviation = (uint)MathMax(0, st.slippage_points);

      // Entry price (market): ask for buy, bid for sell.
      double entry = (is_buy ? SymbolInfoDouble(ctx.symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(ctx.symbol, SYMBOL_BID));
      if(!TA__IsFinite(entry) || entry <= 0.0)
      {
         TA__Fail(r, 1201, "Unable to read Bid/Ask for entry price.");
         out_plan.build_res = r;
         return false;
      }
      entry = br.NormalizePrice(entry);
      out_plan.price = entry;

      // SL
      double sl = 0.0;
      if(!BuildSL(ctx, st, br, is_buy, entry, sl, r))
      {
         out_plan.build_res = r;
         return false;
      }
      out_plan.sl = sl;

      // TP levels (TP1/TP2/TP3) and main TP (use last TP as order TP)
      double tps[TA_MAX_TP_LEVELS];
      int tp_count = 0;
      if(!BuildTPs(ctx, st, br, is_buy, entry, sl, tps, tp_count, r))
      {
         out_plan.build_res = r;
         return false;
      }
      out_plan.tp_count = tp_count;
      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
         out_plan.tp_levels[i] = tps[i];

      double main_tp = 0.0;
      if(tp_count > 0)
         main_tp = tps[tp_count-1];
      out_plan.tp = main_tp;

      // Risk -> volume
      double sl_dist_pts = 0.0;
      if(sl > 0.0)
      {
         const double pt = SymbolInfoDouble(ctx.symbol, SYMBOL_POINT);
         sl_dist_pts = MathAbs(entry - sl) / (pt>0.0 ? pt : 1.0);
      }

      double vol = 0.0;
      if(!m_risk.ComputeVolumeSimple(ctx, st, br, sl_dist_pts, vol, r))
      {
         out_plan.build_res = r;
         return false;
      }
      out_plan.volume = vol;

      // Build trade request (execution layer may copy/override fields as needed)
      ZeroMemory(out_plan.req);
      out_plan.req.action      = TRADE_ACTION_DEAL;
      out_plan.req.symbol      = out_plan.symbol;
      out_plan.req.magic       = out_plan.magic;
      out_plan.req.type        = (is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      out_plan.req.volume      = out_plan.volume;
      out_plan.req.price       = out_plan.price;
      out_plan.req.sl          = out_plan.sl;
      out_plan.req.tp          = out_plan.tp;
      out_plan.req.deviation   = out_plan.deviation;
      out_plan.req.type_filling= TA__PickFilling(out_plan.symbol);
      out_plan.req.type_time   = ORDER_TIME_GTC;
      out_plan.comment         = TA_PROJECT_NAME;
      out_plan.req.comment     = out_plan.comment;

      // Final validation
      TA_Result v;
      if(!TA_ValidateOrderPlanMarket(out_plan, br, v))
      {
         out_plan.build_res = v;
         return false;
      }

      TA__Ok(v);
      out_plan.build_res = v;
      return true;
   }

   // Optional: build a pending plan (TRADE_ACTION_PENDING) — provided for future extensions.
   // Current UI shell doesn't call this yet.
   bool BuildPendingPlan(const TA_Context &ctx,
                         const TA_State   &st,
                         const bool is_buy,
                         const ENUM_ORDER_TYPE pending_type,
                         const double pending_price,
                         TA_OrderPlan &out_plan)
   {
      ResetPlan(out_plan);

      TA_Result r;
      TA_BrokerRules br;
      if(!br.Init(ctx))
      {
         TA__Fail(r, 1300, "Failed to init broker rules.");
         out_plan.build_res = r;
         return false;
      }

      if(pending_price <= 0.0 || !TA__IsFinite(pending_price))
      {
         TA__Fail(r, 1301, "Pending price is invalid.");
         out_plan.build_res = r;
         return false;
      }

      out_plan.action = TA_ACTION_PENDING;
      out_plan.symbol = ctx.symbol;
      out_plan.magic  = ctx.magic;
      out_plan.side   = (is_buy ? TA_SIDE_BUY : TA_SIDE_SELL);
      out_plan.deviation = (uint)MathMax(0, st.slippage_points);
      out_plan.price = br.NormalizePrice(pending_price);

      // SL
      double sl = 0.0;
      if(!BuildSL(ctx, st, br, is_buy, out_plan.price, sl, r))
      {
         out_plan.build_res = r;
         return false;
      }
      out_plan.sl = sl;

      // TP levels
      double tps[TA_MAX_TP_LEVELS];
      int tp_count = 0;
      if(!BuildTPs(ctx, st, br, is_buy, out_plan.price, sl, tps, tp_count, r))
      {
         out_plan.build_res = r;
         return false;
      }
      out_plan.tp_count = tp_count;
      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
         out_plan.tp_levels[i] = tps[i];

      out_plan.tp = (tp_count>0 ? tps[tp_count-1] : 0.0);

      // Risk -> volume
      double sl_dist_pts = 0.0;
      if(sl > 0.0)
      {
         const double pt = SymbolInfoDouble(ctx.symbol, SYMBOL_POINT);
         sl_dist_pts = MathAbs(out_plan.price - sl) / (pt>0.0 ? pt : 1.0);
      }

      double vol = 0.0;
      if(!m_risk.ComputeVolumeSimple(ctx, st, br, sl_dist_pts, vol, r))
      {
         out_plan.build_res = r;
         return false;
      }
      out_plan.volume = vol;

      // Request
      ZeroMemory(out_plan.req);
      out_plan.req.action      = TRADE_ACTION_PENDING;
      out_plan.req.symbol      = out_plan.symbol;
      out_plan.req.magic       = out_plan.magic;
      out_plan.req.type        = pending_type; // e.g., ORDER_TYPE_BUY_LIMIT, SELL_STOP, etc.
      out_plan.req.volume      = out_plan.volume;
      out_plan.req.price       = out_plan.price;
      out_plan.req.sl          = out_plan.sl;
      out_plan.req.tp          = out_plan.tp;
      out_plan.req.deviation   = out_plan.deviation;
      out_plan.req.type_filling= TA__PickFilling(out_plan.symbol);
      out_plan.req.type_time   = ORDER_TIME_GTC;
      out_plan.comment         = TA_PROJECT_NAME;
      out_plan.req.comment     = out_plan.comment;

      // Validate pending plan
      TA_Result v;
      if(!TA_ValidateOrderPlanPending(out_plan, br, v))
      {
         out_plan.build_res = v;
         return false;
      }

      TA__Ok(v);
      out_plan.build_res = v;
      return true;
   }
};

#endif // __TA_ORDERBUILDER_MQH__

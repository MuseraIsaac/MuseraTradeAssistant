//+------------------------------------------------------------------+
//|                                                    TA_RR.mqh     |
//|                         (c) 2026, Musera Isaac                   |
//|  Risk/Reward utilities: compute TP from RR, compute RR from prices|
//|  and derive TP ladders for partial closes.                        |
//|                                                                  |
//|  Part of: MuseraTradeAssistant (project include).                 |
//+------------------------------------------------------------------+
#property strict

#ifndef __TA_RR_MQH__
#define __TA_RR_MQH__

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"
#include "TA_Validation.mqh"
#include "TA_BrokerRules.mqh"
#include "TA_State.mqh"

// ------------------------------ Local helpers (self-contained) ------------------------------
#ifndef __TA_RESULT_HELPERS_MQH__
#define __TA_RESULT_HELPERS_MQH__
inline TA_Result TA__Ok(){ TA_Result r; r.Reset(); return r; }
inline TA_Result TA__Fail(const string msg, const int code){ TA_Result r; r.ok=false; r.code=code; r.message=msg; return r; }
#endif

#ifndef __TA_RR_PRICE_HELPERS_MQH__
#define __TA_RR_PRICE_HELPERS_MQH__
inline double TA_PointsBetweenPrices(const TA_BrokerRules &br, const double p1, const double p2)
{
   const double pt = br.Point();
   if(pt <= 0.0) return 0.0;
   return MathAbs(p2 - p1) / pt;
}

inline double TA_PriceFromPoints(const TA_BrokerRules &br, const double entry_price, const double points, const bool is_buy)
{
   return (is_buy ? (entry_price + points * br.Point()) : (entry_price - points * br.Point()));
}

inline double TA_NormalizePrice(const TA_BrokerRules &br, const double price)
{
   return br.NormalizePrice(price);
}
#endif


//+------------------------------------------------------------------+
//| TA_RR: risk/reward helpers                                        |
//+------------------------------------------------------------------+
class TA_RR
  {
public:

   // Derive a single TP price from state.
   // - If state.tp_from_rr is true: uses state.rr_target and SL distance (entry<->sl)
   // - Else: uses state.tp_points
   // Returns true on success; out_tp_price may be 0 if TP is disabled.
   bool CalcTPFromState(const TA_Context &ctx,
                        const TA_State   &st,
                        const TA_BrokerRules &br,
                        const bool        is_buy,
                        const double      entry_price,
                        const double      sl_price,
                        double           &out_tp_price,
                        TA_Result        &out_res) const
     {
      out_tp_price = 0.0;
      out_res = TA__Ok();

      if(!TA__IsFinite(entry_price) || entry_price<=0.0)
      {
         out_res = TA__Fail("Entry price invalid", TA_ERR_INVALID_PARAM);
         return false;
      }

      // No TP case: if tp_points==0 and not from RR, allow TP disabled.
      if(!st.tp_from_rr)
        {
         if(st.tp_points<=0.0)
            return true;

         return CalcTPFromPoints(br, is_buy, entry_price, st.tp_points, out_tp_price, out_res);
        }

      // RR-based TP requires a valid SL.
      if(!TA__IsFinite(sl_price) || sl_price<=0.0)
      {
         out_res = TA__Fail("SL price required for RR", TA_ERR_SL_REQUIRED);
         return false;
      }

      if(st.rr_target<=0.0)
      {
         out_res = TA__Fail("RR target must be > 0", TA_ERR_INVALID_PARAM);
         return false;
      }

      return CalcTPFromRR(br, is_buy, entry_price, sl_price, st.rr_target, out_tp_price, out_res);
     }

   // Compute TP price using an RR ratio and the distance between entry and SL.
   // RR = reward / risk.
   bool CalcTPFromRR(const TA_BrokerRules &br,
                     const bool is_buy,
                     const double entry_price,
                     const double sl_price,
                     const double rr_target,
                     double &out_tp_price,
                     TA_Result &out_res) const
     {
      out_tp_price = 0.0;
      out_res = TA__Ok();

      if(rr_target<=0.0 || !TA__IsFinite(rr_target))
      {
         out_res = TA__Fail("RR target must be > 0", TA_ERR_INVALID_PARAM);
         return false;
      }
      if(entry_price<=0.0 || !TA__IsFinite(entry_price))
      {
         out_res = TA__Fail("Entry price invalid", TA_ERR_INVALID_PARAM);
         return false;
      }
      if(sl_price<=0.0 || !TA__IsFinite(sl_price))
      {
         out_res = TA__Fail("SL price invalid", TA_ERR_INVALID_PARAM);
         return false;
      }

      // Risk points from entry to SL (positive).
      double risk_points = TA_PointsBetweenPrices(br, entry_price, sl_price);
      if(risk_points<=0.0)
      {
         out_res = TA__Fail("SL distance is zero", TA_ERR_SL_REQUIRED);
         return false;
      }

      // Directional sanity: SL must be on the loss side.
      if(is_buy && sl_price>=entry_price)
      {
         out_res = TA__Fail("For BUY, SL must be below entry", TA_ERR_SL_TOO_CLOSE);
         return false;
      }
      if(!is_buy && sl_price<=entry_price)
      {
         out_res = TA__Fail("For SELL, SL must be above entry", TA_ERR_SL_TOO_CLOSE);
         return false;
      }

      double reward_points = risk_points * rr_target;
      if(reward_points<=0.0)
      {
         out_res = TA__Fail("Reward points invalid", TA_ERR_INVALID_PARAM);
         return false;
      }

      // Compute TP from reward points.
      double tp = TA_PriceFromPoints(br, entry_price, reward_points, is_buy);
      tp = TA_NormalizePrice(br, tp);

      // Must be on profit side.
      if(is_buy && tp<=entry_price)
      {
         out_res = TA__Fail("Computed TP not above entry", TA_ERR_TP_INVALID);
         return false;
      }
      if(!is_buy && tp>=entry_price)
      {
         out_res = TA__Fail("Computed TP not below entry", TA_ERR_TP_INVALID);
         return false;
      }

      // Enforce broker stops level (TP distance from current price/entry).
      if(!EnforceStopsLevelTP(br, is_buy, entry_price, tp, out_res))
         return false;

      out_tp_price = tp;
      return true;
     }

   // Compute TP price from explicit TP distance in points.
   bool CalcTPFromPoints(const TA_BrokerRules &br,
                         const bool is_buy,
                         const double entry_price,
                         const double tp_points,
                         double &out_tp_price,
                         TA_Result &out_res) const
     {
      out_tp_price = 0.0;
      out_res = TA__Ok();

      if(entry_price<=0.0 || !TA__IsFinite(entry_price))
      {
         out_res = TA__Fail("Entry price invalid", TA_ERR_INVALID_PARAM);
         return false;
      }

      if(tp_points<=0.0 || !TA__IsFinite(tp_points))
        {
         // interpret as disabled TP
         out_tp_price = 0.0;
         return true;
        }

      double tp = TA_PriceFromPoints(br, entry_price, tp_points, is_buy);
      tp = TA_NormalizePrice(br, tp);

      if(is_buy && tp<=entry_price)
      {
         out_res = TA__Fail("TP must be above entry", TA_ERR_TP_INVALID);
         return false;
      }
      if(!is_buy && tp>=entry_price)
      {
         out_res = TA__Fail("TP must be below entry", TA_ERR_TP_INVALID);
         return false;
      }

      if(!EnforceStopsLevelTP(br, is_buy, entry_price, tp, out_res))
         return false;

      out_tp_price = tp;
      return true;
     }

   // Compute RR ratio from entry, SL and TP.
   bool CalcRRFromPrices(const TA_BrokerRules &br,
                         const bool is_buy,
                         const double entry_price,
                         const double sl_price,
                         const double tp_price,
                         double &out_rr,
                         TA_Result &out_res) const
     {
      out_rr = 0.0;
      out_res = TA__Ok();

      if(entry_price<=0.0 || sl_price<=0.0 || tp_price<=0.0)
      {
         out_res = TA__Fail("Prices must be > 0", TA_ERR_INVALID_PARAM);
         return false;
      }
      if(!TA__IsFinite(entry_price) || !TA__IsFinite(sl_price) || !TA__IsFinite(tp_price))
      {
         out_res = TA__Fail("Price is NaN/INF", TA_ERR_INVALID_PARAM);
         return false;
      }

      // Directional sanity.
      if(is_buy)
        {
         if(!(sl_price<entry_price && tp_price>entry_price))
         {
            out_res = TA__Fail("For BUY, SL<entry<TP required", TA_ERR_INVALID_PARAM);
            return false;
         }
        }
      else
        {
         if(!(sl_price>entry_price && tp_price<entry_price))
         {
            out_res = TA__Fail("For SELL, TP<entry<SL required", TA_ERR_INVALID_PARAM);
            return false;
         }
        }

      double risk_points   = TA_PointsBetweenPrices(br, entry_price, sl_price);
      double reward_points = TA_PointsBetweenPrices(br, entry_price, tp_price);
      if(risk_points<=0.0 || reward_points<=0.0)
      {
         out_res = TA__Fail("Distance points invalid", TA_ERR_INVALID_PARAM);
         return false;
      }

      out_rr = reward_points / risk_points;
      if(!TA__IsFinite(out_rr) || out_rr<=0.0)
      {
         out_res = TA__Fail("RR invalid", TA_ERR_INVALID_PARAM);
         return false;
      }

      return true;
     }

   // Build TP ladder (TP1/TP2/TP3) based on current state.
   // - If partials are enabled, uses tp_levels.
   // - Otherwise returns a single TP (if enabled in state).
   bool BuildTPPrices(const TA_Context &ctx,
                      const TA_State   &st,
                      const TA_BrokerRules &br,
                      const bool is_buy,
                      const double entry_price,
                      const double sl_price,
                      double &out_prices[],
                      int &out_count,
                      TA_Result &out_res) const
     {
      out_count = 0;
      out_res = TA__Ok();

      if(ArraySize(out_prices) < TA_MAX_TP_LEVELS)
         ArrayResize(out_prices, TA_MAX_TP_LEVELS);
      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
         out_prices[i] = 0.0;

      if(st.tp_partials_enabled)
         return BuildPartialTPPrices(ctx, st, br, is_buy, entry_price, sl_price, out_prices, out_count, out_res);

      double tp = 0.0;
      if(!CalcTPFromState(ctx, st, br, is_buy, entry_price, sl_price, tp, out_res))
         return false;

      if(tp > 0.0)
      {
         out_prices[0] = tp;
         out_count = 1;
      }
      return true;
     }

   // Build an ordered list of partial TP prices from st.tp_levels.
   // - Returns prices aligned to tick size.
   // - For SELL, targets are expected to increase by magnitude (RR/points), so prices will decrease.
   // - out_prices must have at least TA_MAX_TP_LEVELS.
   bool BuildPartialTPPrices(const TA_Context &ctx,
                             const TA_State   &st,
                             const TA_BrokerRules &br,
                             const bool is_buy,
                             const double entry_price,
                             const double sl_price,
                             double &out_prices[],
                             int &out_count,
                             TA_Result &out_res) const
     {
      out_count = 0;
      out_res = TA__Ok();

      if(ArraySize(out_prices) < TA_MAX_TP_LEVELS)
         ArrayResize(out_prices, TA_MAX_TP_LEVELS);

      if(!TA__IsFinite(entry_price) || entry_price<=0.0)
      {
         out_res = TA__Fail("Entry price invalid", TA_ERR_INVALID_PARAM);
         return false;
      }

      // If any TP level uses RR, we need SL.
      // We'll compute each level depending on its type.

      for(int i=0;i<TA_MAX_TP_LEVELS;i++)
        {
         if(!st.tp_levels[i].enabled) continue;

         const TA_TargetType ttype = st.tp_levels[i].type;
         const double target = st.tp_levels[i].target;

         if(target<=0.0 || !TA__IsFinite(target))
         {
            out_res = TA__Fail("TP level target invalid", TA_ERR_INVALID_PARAM);
            return false;
         }

         double tp = 0.0;

         if(ttype==TA_TARGET_R)
           {
            if(sl_price<=0.0 || !TA__IsFinite(sl_price))
            {
               out_res = TA__Fail("SL required for RR-based TP levels", TA_ERR_SL_REQUIRED);
               return false;
            }

            TA_Result r2;
            if(!CalcTPFromRR(br, is_buy, entry_price, sl_price, target, tp, r2))
              {
               out_res = r2;
               return false;
              }
           }
         else if(ttype==TA_TARGET_POINTS)
           {
            TA_Result r2;
            if(!CalcTPFromPoints(br, is_buy, entry_price, target, tp, r2))
              {
               out_res = r2;
               return false;
              }
           }
         else // TA_TARGET_PRICE
           {
            tp = TA_NormalizePrice(br, target);

            // Sanity: must be on profit side.
            if(is_buy && tp<=entry_price)
            {
               out_res = TA__Fail("TP level price must be above entry", TA_ERR_TP_INVALID);
               return false;
            }
            if(!is_buy && tp>=entry_price)
            {
               out_res = TA__Fail("TP level price must be below entry", TA_ERR_TP_INVALID);
               return false;
            }

            // Stops level check.
            if(!EnforceStopsLevelTP(br, is_buy, entry_price, tp, out_res))
               return false;
           }

         out_prices[out_count++] = tp;
         if(out_count>=TA_MAX_TP_LEVELS) break;
        }

      return true;
     }

   // Utility: given SL distance in points and RR, derive TP distance in points.
   double CalcTPPointsFromRR(const double sl_points, const double rr_target) const
     {
      if(sl_points<=0.0 || rr_target<=0.0) return 0.0;
      const double v = sl_points * rr_target;
      return (TA__IsFinite(v) ? v : 0.0);
     }

private:

   // Enforce broker stops level for a TP relative to entry.
   // NOTE: In live trading, the platform applies stops level against current bid/ask.
   // Here we enforce a conservative rule relative to entry price to avoid obvious rejects.
   bool EnforceStopsLevelTP(const TA_BrokerRules &br,
                            const bool is_buy,
                            const double entry_price,
                            double &io_tp,
                            TA_Result &out_res) const
     {
      out_res = TA__Ok();
      const double min_pts = br.stops_level_points;
      if(min_pts<=0.0) return true;

      double dist = TA_PointsBetweenPrices(br, entry_price, io_tp);
      if(dist >= min_pts) return true;

      // Push TP further away to satisfy min distance.
      io_tp = TA_PriceFromPoints(br, entry_price, min_pts, is_buy);
      io_tp = TA_NormalizePrice(br, io_tp);

      // Re-check direction.
      if(is_buy && io_tp<=entry_price)
      {
         out_res = TA__Fail("TP cannot satisfy stops level", TA_ERR_TP_INVALID);
         return false;
      }
      if(!is_buy && io_tp>=entry_price)
      {
         out_res = TA__Fail("TP cannot satisfy stops level", TA_ERR_TP_INVALID);
         return false;
      }

      return true;
     }
  };

#endif // __TA_RR_MQH__

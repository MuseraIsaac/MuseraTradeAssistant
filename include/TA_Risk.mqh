//+------------------------------------------------------------------+
//|                                                    TA_Risk.mqh    |
//|                                  (c) 2026, Musera Isaac          |
//|  Project: MuseraTradeAssistant (MT5 Utility)                      |
//|                                                                  |
//|  Risk sizing + money/margin preview utilities.                    |
//|                                                                  |
//|  Location (relative to terminal data folder):                     |
//|  MQL5\Experts\MuseraTradeAssistant\include\TA_Risk.mqh            |
//+------------------------------------------------------------------+
#ifndef __TA_RISK_MQH__
#define __TA_RISK_MQH__

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"
#include "TA_BrokerRules.mqh"
#include "TA_State.mqh"

// ------------------------------ Preview struct ------------------------------
struct TA_RiskPreview
{
   bool   ok;
   string message;

   double volume_raw;          // calculated volume before broker normalization
   double volume;              // normalized volume (min/max/step)
   bool   clamped_min;
   bool   clamped_max;

   double sl_points;           // stop distance (points)
   double tp_points;           // tp distance (points)

   double value_per_point_1lot; // deposit currency per point per 1.0 lot

   double risk_money_target;   // target risk (from state)
   double risk_money_actual;   // actual risk (after normalization/clamp)

   double reward_money;        // expected reward (tp_points) for the chosen volume
   double rr;                  // reward/risk

   double margin_required;     // estimated margin for the volume (may be -1 if unknown)
   double free_margin;         // current free margin snapshot
};

// ------------------------------ Helpers ------------------------------
inline bool TA__RiskFail(TA_Result &res, const int code, const string msg)
{
   res.ok      = false;
   res.code    = code;
   res.message = msg;
   return false;
}

inline bool TA__RiskOk(TA_Result &res)
{
   res.ok      = true;
   res.code    = 0;
   res.message = "";
   return true;
}

inline string TA__Fmt2(const double x)
{
   return DoubleToString(x, 2);
}

// ------------------------------ TA_Risk ------------------------------
// NOTE:
// - This module is intentionally self-contained and "pure" (no UI dependencies).
// - It is called by OrderBuilder to compute volumes from SL distance and by UI to show previews.

class TA_Risk
{
private:
   string m_symbol;

public:
   TA_Risk() { m_symbol = _Symbol; }

   void Init(const TA_Context &ctx)
   {
      m_symbol = (ctx.symbol == "" ? _Symbol : ctx.symbol);
   }

   // Compute risk money according to TA_State (percent/money) and selected base (balance/equity/free margin).
   bool RiskMoneyFromState(const TA_State &st, double &out_money, TA_Result &res) const
   {
      out_money = 0.0;

      if(st.risk_mode == TA_RISK_FIXED_LOT)
      {
         // In fixed lot mode, "risk money" is not the primary input (volume is),
         // but UI can still display a derived risk money later. Return ok with 0.
         return TA__RiskOk(res);
      }

      if(st.risk_mode == TA_RISK_MONEY)
      {
         if(st.risk_money <= 0.0)
            return TA__RiskFail(res, 610, "Risk money must be > 0.");
         out_money = st.risk_money;
         return TA__RiskOk(res);
      }

      if(st.risk_mode == TA_RISK_BALANCE_PCT || st.risk_mode == TA_RISK_EQUITY_PCT)
      {
         if(st.risk_percent <= 0.0)
            return TA__RiskFail(res, 611, "Risk percent must be > 0.");

         const double base = TA_AccountBaseMoney(st.risk_base);
         if(base <= 0.0)
            return TA__RiskFail(res, 612, "Risk base money is invalid/zero.");

         out_money = TA_MoneyRiskFromPercent(st.risk_base, st.risk_percent);
         return TA__RiskOk(res);
      }

      return TA__RiskFail(res, 613, "Unknown risk mode.");
   }

   // Estimate margin requirement for a hypothetical market position.
   // If margin cannot be calculated, out_margin is set to -1 but function still returns true.
   bool EstimateMargin(const bool is_buy, const double volume, double &out_margin) const
   {
      out_margin = -1.0;

      if(volume <= 0.0) return true;

      const ENUM_ORDER_TYPE type = (is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      const double price = (is_buy ? TA_Ask(m_symbol) : TA_Bid(m_symbol));

      double margin = 0.0;
      if(!OrderCalcMargin(type, m_symbol, volume, price, margin))
      {
         out_margin = -1.0;
         return true;
      }

      out_margin = margin;
      return true;
   }

   // Compute volume from SL distance (points) using broker rules and state.
   // sl_points must be > 0 for percent/money modes.
   bool ComputeVolume(const TA_State &st,
                      const TA_BrokerRules &br,
                      const double sl_points,
                      double &out_volume,
                      double &out_raw,
                      double &out_target_risk_money,
                      double &out_actual_risk_money,
                      bool &out_clamped_min,
                      bool &out_clamped_max,
                      TA_Result &res) const
   {
      out_volume           = 0.0;
      out_raw              = 0.0;
      out_target_risk_money= 0.0;
      out_actual_risk_money= 0.0;
      out_clamped_min      = false;
      out_clamped_max      = false;

      const string sym = (br.Symbol() != "" ? br.Symbol() : m_symbol);
      const double vpp = TA_ValuePerPoint(sym);

      if(st.risk_mode == TA_RISK_FIXED_LOT)
      {
         if(st.fixed_lot <= 0.0)
            return TA__RiskFail(res, 620, "Fixed lot must be > 0.");

         out_raw    = st.fixed_lot;
         out_volume = br.NormalizeLots(out_raw);

         // Clamp flags
         if(out_volume < br.LotMin() - 1e-12) { out_volume = br.LotMin(); out_clamped_min=true; }
         if(out_volume > br.LotMax() + 1e-12) { out_volume = br.LotMax(); out_clamped_max=true; }

         // Derived actual risk money (if SL is known and vpp is valid)
         if(sl_points > 0.0 && vpp > 0.0)
            out_actual_risk_money = sl_points * vpp * out_volume;

         return TA__RiskOk(res);
      }

      // Money / Percent modes require SL distance
      if(sl_points <= 0.0)
         return TA__RiskFail(res, 621, "SL distance must be > 0 to compute risk-based lot size.");

      if(vpp <= 0.0)
         return TA__RiskFail(res, 622, "Cannot compute value per point for symbol.");

      double target_money = 0.0;
      if(!RiskMoneyFromState(st, target_money, res))
         return false;

      out_target_risk_money = target_money;

      // Risk money for 1 lot with this stop distance:
      const double money_per_1lot = sl_points * vpp;
      if(money_per_1lot <= 0.0)
         return TA__RiskFail(res, 623, "Invalid money per 1 lot for the chosen SL distance.");

      const double raw = target_money / money_per_1lot;
      out_raw = raw;

      double vol = br.NormalizeLots(raw);

      // Clamp to broker limits (normalization may already clamp by step rounding, not by min/max)
      if(vol < br.LotMin() - 1e-12) { vol = br.LotMin(); out_clamped_min = true; }
      if(vol > br.LotMax() + 1e-12) { vol = br.LotMax(); out_clamped_max = true; }

      // Validity check
      const double min_vol = br.LotMin();
      const double max_vol = br.LotMax();
      const double step    = br.LotStep();
      double snapped = vol;
      if(step > 0.0)
         snapped = min_vol + TA_RoundToStep(vol - min_vol, step);

      if(vol < min_vol - 1e-12 || vol > max_vol + 1e-12 || (step > 0.0 && MathAbs(vol - snapped) > 1e-8))
      {
         string msg = StringFormat("Computed volume invalid. min=%.2f max=%.2f step=%.2f got=%.2f",
                                   min_vol, max_vol, step, vol);
         return TA__RiskFail(res, 624, msg);
      }

      out_volume = vol;

      // Actual risk money after normalization/clamp:
      out_actual_risk_money = sl_points * vpp * out_volume;

      return TA__RiskOk(res);
   }

   // Compute a full preview (volume + money + RR + margin).
   // tp_points can be 0 if unknown; reward_money/rr will be 0.
   bool Preview(const TA_Context &ctx,
                const TA_State &st,
                const TA_BrokerRules &br,
                const bool is_buy,
                const double sl_points,
                const double tp_points,
                TA_RiskPreview &out,
                TA_Result &res)
   {
      Init(ctx);

      out.ok = false;
      out.message = "";

      out.sl_points = sl_points;
      out.tp_points = tp_points;
      out.value_per_point_1lot = TA_ValuePerPoint((br.Symbol() != "" ? br.Symbol() : m_symbol));
      out.clamped_min = false;
      out.clamped_max = false;

      double vol=0, raw=0, target_money=0, actual_money=0;
      bool clamp_min=false, clamp_max=false;

      if(!ComputeVolume(st, br, sl_points, vol, raw, target_money, actual_money, clamp_min, clamp_max, res))
      {
         out.ok = false;
         out.message = res.message;
         return false;
      }

      out.volume_raw        = raw;
      out.volume            = vol;
      out.risk_money_target = target_money;
      out.risk_money_actual = actual_money;
      out.clamped_min       = clamp_min;
      out.clamped_max       = clamp_max;

      // Reward estimate
      if(tp_points > 0.0 && out.value_per_point_1lot > 0.0 && vol > 0.0)
         out.reward_money = tp_points * out.value_per_point_1lot * vol;
      else
         out.reward_money = 0.0;

      // RR
      if(out.risk_money_actual > 0.0)
         out.rr = out.reward_money / out.risk_money_actual;
      else
         out.rr = 0.0;

      // Margin estimate
      out.free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double m=0.0;
      EstimateMargin(is_buy, vol, m);
      out.margin_required = m;

      out.ok = true;

      // Message hint if clamped
      if(out.clamped_min || out.clamped_max)
      {
         string why = (out.clamped_min ? "min" : "max");
         out.message = "Volume clamped to broker " + why + " limit.";
      }
      else
      {
         out.message = "";
      }

      return true;
   }

   // Convenience: compute volume only.
   bool ComputeVolumeSimple(const TA_Context &ctx,
                            const TA_State &st,
                            const TA_BrokerRules &br,
                            const double sl_points,
                            double &out_volume,
                            TA_Result &res)
   {
      Init(ctx);

      double raw=0, target_money=0, actual_money=0;
      bool clamp_min=false, clamp_max=false;

      return ComputeVolume(st, br, sl_points,
                           out_volume, raw, target_money, actual_money,
                           clamp_min, clamp_max, res);
   }

   // Convenience: compute risk/reward money for an already-known volume.
   // Useful when SL/TP are adjusted interactively by user dragging lines.
   bool MoneyForMove(const double volume,
                     const double sl_points,
                     const double tp_points,
                     double &out_risk_money,
                     double &out_reward_money,
                     double &out_rr) const
   {
      out_risk_money   = 0.0;
      out_reward_money = 0.0;
      out_rr           = 0.0;

      const double vpp = TA_ValuePerPoint(m_symbol);
      if(vpp <= 0.0 || volume <= 0.0) return false;

      if(sl_points > 0.0) out_risk_money   = sl_points * vpp * volume;
      if(tp_points > 0.0) out_reward_money = tp_points * vpp * volume;

      if(out_risk_money > 0.0) out_rr = out_reward_money / out_risk_money;
      return true;
   }
};

#endif // __TA_RISK_MQH__
//+------------------------------------------------------------------+

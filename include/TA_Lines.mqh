//+------------------------------------------------------------------+
//|                                                      TA_Lines.mqh |
//|                        MuseraTradeAssistant (c) 2026, Musera Isaac |
//|  Chart line helpers: Entry / SL / TP / TP1-TP3 / BE preview lines  |
//|                                                                   |
//|  Purpose                                                         |
//|  - Draw draggable SL/TP preview lines for fast manual adjustment. |
//|  - Keep calculations tickless (call UpdatePreview() from OnTimer).|
//|  - When user drags SL/TP, update TA_State (sl_points/tp_points).  |
//|                                                                   |
//|  Dependencies                                                    |
//|  - TA_Context (TA_Types.mqh)                                      |
//|  - TA_State   (TA_State.mqh)                                      |
//|  - TA_BrokerRules (min stops/freeze, normalization)               |
//+------------------------------------------------------------------+
#ifndef __TA_LINES_MQH__
#define __TA_LINES_MQH__

#include "TA_Constants.mqh"
#include "TA_Types.mqh"
#include "TA_State.mqh"
#include "TA_Utils.mqh"
#include "TA_BrokerRules.mqh"

// ------------------------------ Naming ------------------------------
#ifndef TA_OBJ_PREFIX
   #define TA_OBJ_PREFIX "MTA_"
#endif

// Suffixes (prefixed per instance by magic)
#define TA_LINE_ENTRY   "ENTRY"
#define TA_LINE_SL      "SL"
#define TA_LINE_TP      "TP"
#define TA_LINE_TP1     "TP1"
#define TA_LINE_TP2     "TP2"
#define TA_LINE_TP3     "TP3"
#define TA_LINE_BE      "BE"

// ------------------------------ Small helpers ------------------------------
string TA__LinesPrefix(const TA_Context &ctx)
{
   // Prefix per EA instance (magic) to avoid object collisions
   return (string)TA_OBJ_PREFIX + (string)ctx.magic + "_";
}

string TA__LineName(const TA_Context &ctx, const string suffix)
{
   return TA__LinesPrefix(ctx) + suffix;
}

bool TA__ObjExists(const long chart_id, const string name)
{
   return (ObjectFind(chart_id, name) >= 0);
}

void TA__ObjDeleteSafe(const long chart_id, const string name)
{
   if(ObjectFind(chart_id, name) >= 0)
      ObjectDelete(chart_id, name);
}

// Create/update a horizontal line with consistent properties.
bool TA__EnsureHLine(const long chart_id,
                           const string name,
                           const double price,
                           const color clr,
                           const ENUM_LINE_STYLE style,
                           const int width,
                           const bool selectable,
                           const bool hidden,
                           const string text)
{
   if(ObjectFind(chart_id, name) < 0)
   {
      if(!ObjectCreate(chart_id, name, OBJ_HLINE, 0, 0, price))
         return false;
   }

   ObjectSetDouble(chart_id, name, OBJPROP_PRICE, price);
   ObjectSetInteger(chart_id, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_id, name, OBJPROP_STYLE, style);
   ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(chart_id, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN, hidden);
   ObjectSetInteger(chart_id, name, OBJPROP_BACK, false);

   // Description shown on chart for some object styles / terminal settings.
   ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
   ObjectSetString(chart_id, name, OBJPROP_TOOLTIP, text);

   return true;
}

bool TA__GetHLinePrice(const long chart_id, const string name, double &price_out)
{
   if(ObjectFind(chart_id, name) < 0) return false;
   price_out = ObjectGetDouble(chart_id, name, OBJPROP_PRICE);
   return (price_out > 0.0);
}

void TA__SetHLinePriceSafe(const long chart_id, const string name, const double price)
{
   if(ObjectFind(chart_id, name) >= 0)
      ObjectSetDouble(chart_id, name, OBJPROP_PRICE, price);
}

// ------------------------------ TA_Lines ------------------------------
// Recommended usage:
// - Create one instance in your EA globals (e.g., TA_Lines g_lines;)
// - g_lines.Init(ctx, state, broker);
// - Call g_lines.SetSide(is_buy_preview) from UI selection.
// - In OnTimer: g_lines.UpdatePreview(ctx, state, broker);
// - In OnChartEvent: g_lines.OnChartEvent(ctx, state, broker, id, lparam, dparam, sparam);
class TA_Lines
{
private:
   bool   m_inited;
   bool   m_is_buy;      // preview direction
   long   m_chart;
   string m_symbol;
   int    m_digits;
   double m_point;

   // Visual style defaults (can be overridden via SyncConfig if you add them to TA_State/UI theme)
   color           m_entry_clr;
   color           m_sl_clr;
   color           m_tp_clr;
   color           m_tp1_clr;
   color           m_tp2_clr;
   color           m_tp3_clr;
   color           m_be_clr;

   ENUM_LINE_STYLE m_entry_style;
   ENUM_LINE_STYLE m_sl_style;
   ENUM_LINE_STYLE m_tp_style;
   ENUM_LINE_STYLE m_partial_style;
   ENUM_LINE_STYLE m_be_style;

   int             m_entry_w;
   int             m_sl_w;
   int             m_tp_w;
   int             m_partial_w;
   int             m_be_w;

private:
   double EntryPrice(const TA_Context &ctx) const
   {
      double ask = 0.0, bid = 0.0;
      SymbolInfoDouble(ctx.symbol, SYMBOL_ASK, ask);
      SymbolInfoDouble(ctx.symbol, SYMBOL_BID, bid);
      if(m_is_buy) return (ask > 0.0 ? ask : bid);
      return (bid > 0.0 ? bid : ask);
   }

   double PriceFromPoints(const double entry, const int points, const bool for_tp) const
   {
      if(points <= 0) return 0.0;
      // For BUY: TP above entry, SL below entry
      // For SELL: TP below entry, SL above entry
      const int dir = (m_is_buy ? +1 : -1);
      const int sgn = (for_tp ? dir : -dir);
      return entry + (double)sgn * (double)points * m_point;
   }

   int PointsFromPrice(const double entry, const double price, const bool from_tp) const
   {
      if(entry <= 0.0 || price <= 0.0) return 0;

      const double delta = (from_tp
                           ? (m_is_buy ? (price - entry) : (entry - price))
                           : (m_is_buy ? (entry - price) : (price - entry)));

      if(delta <= 0.0) return 0;
      return (int)MathRound(delta / m_point);
   }

   void DeleteAll(const TA_Context &ctx)
   {
      TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_ENTRY));
      TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_SL));
      TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP));
      TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP1));
      TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP2));
      TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP3));
      TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_BE));
   }

public:
   TA_Lines()
   {
      m_inited = false;
      m_is_buy = true;
      m_chart  = 0;
      m_symbol = "";
      m_digits = 0;
      m_point  = 0.0;

      // Default colors (simple + readable)
      m_entry_clr = clrDodgerBlue;
      m_sl_clr    = clrCrimson;
      m_tp_clr    = clrLimeGreen;
      m_tp1_clr   = clrSeaGreen;
      m_tp2_clr   = clrGreen;
      m_tp3_clr   = clrDarkGreen;
      m_be_clr    = clrOrange;

      m_entry_style   = STYLE_DOT;
      m_sl_style      = STYLE_SOLID;
      m_tp_style      = STYLE_SOLID;
      m_partial_style = STYLE_DASH;
      m_be_style      = STYLE_DOT;

      m_entry_w   = 1;
      m_sl_w      = 2;
      m_tp_w      = 2;
      m_partial_w = 1;
      m_be_w      = 1;
   }

   bool Init(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &broker)
   {
      m_chart  = ctx.chart_id;
      m_symbol = ctx.symbol;
      m_digits = (int)SymbolInfoInteger(ctx.symbol, SYMBOL_DIGITS);
      m_point  = SymbolInfoDouble(ctx.symbol, SYMBOL_POINT);
      if(m_point <= 0.0) m_point = TA_Point(ctx.symbol);

      // You can later map styles/colors to st.ui_theme if you add them there.
      m_inited = true;
      return true;
   }

   void Destroy(const TA_Context &ctx)
   {
      if(!m_inited) return;
      DeleteAll(ctx);
      m_inited = false;
   }

   void SetSide(const bool is_buy_preview)
   {
      m_is_buy = is_buy_preview;
   }

   bool IsBuy() const { return m_is_buy; }

   // Optional: if you add style/theme options to TA_State you can apply them here.
   void SyncConfig(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &broker)
   {
      // placeholder (theme mapping)
   }

   // Draw/update preview lines from current state:
   // - ENTRY always (non-draggable)
   // - SL/TP if enabled in state
   // - TP1/2/3 if partials enabled AND SL enabled (RR requires risk points)
   // - BE if enabled (shows projected BE stop after trigger)
   void UpdatePreview(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &broker)
   {
      if(!m_inited) return;

      const double entry = TA_NormalizePrice(ctx.symbol, EntryPrice(ctx));
      if(entry <= 0.0) return;

      // ENTRY line (always)
      TA__EnsureHLine(ctx.chart_id,
                      TA__LineName(ctx, TA_LINE_ENTRY),
                      entry,
                      m_entry_clr,
                      m_entry_style,
                      m_entry_w,
                      false,  // selectable
                      true,   // hidden
                      "ENTRY");

      double sl = 0.0;
      double tp = 0.0;
      bool sl_active = false;
      bool tp_active = false;

      if(st.sl_mode == TA_SL_POINTS && st.sl_points > 0)
      {
         sl = TA_NormalizePrice(ctx.symbol, PriceFromPoints(entry, st.sl_points, false));
         sl_active = (sl > 0.0);
      }
      else if(st.sl_mode == TA_SL_PRICE && st.sl_price > 0.0)
      {
         sl = TA_NormalizePrice(ctx.symbol, st.sl_price);
         sl_active = (sl > 0.0);
      }

      if(st.tp_mode == TA_TP_POINTS && st.tp_points > 0)
      {
         tp = TA_NormalizePrice(ctx.symbol, PriceFromPoints(entry, st.tp_points, true));
         tp_active = (tp > 0.0);
      }
      else if(st.tp_mode == TA_TP_PRICE && st.tp_price > 0.0)
      {
         tp = TA_NormalizePrice(ctx.symbol, st.tp_price);
         tp_active = (tp > 0.0);
      }
      else if(st.tp_mode == TA_TP_RR && sl_active && st.rr_target > 0.0)
      {
         const int risk_pts = (st.sl_mode == TA_SL_POINTS ? st.sl_points : PointsFromPrice(entry, sl, false));
         if(risk_pts > 0)
         {
            double p = entry + (m_is_buy ? +1.0 : -1.0) * (double)risk_pts * st.rr_target * m_point;
            tp = TA_NormalizePrice(ctx.symbol, p);
            tp_active = (tp > 0.0);
         }
      }

      if(sl_active)
      {
         broker.EnsureStopsDistance(sl, tp,
                                   (m_is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL),
                                   entry);

         TA__EnsureHLine(ctx.chart_id,
                         TA__LineName(ctx, TA_LINE_SL),
                         sl,
                         m_sl_clr,
                         m_sl_style,
                         m_sl_w,
                         true,   // draggable
                         true,   // hidden
                         "SL");

         if(tp_active)
         {
            broker.EnsureStopsDistance(sl, tp,
                                       (m_is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL),
                                       entry);

            TA__EnsureHLine(ctx.chart_id,
                            TA__LineName(ctx, TA_LINE_TP),
                            tp,
                            m_tp_clr,
                            m_tp_style,
                            m_tp_w,
                            true,  // draggable
                            true,
                            "TP");
         }
         else
         {
            TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP));
         }

         const bool can_partials = (st.tp_partials_enabled && sl_active);
         if(can_partials)
         {
            const int risk_pts = (st.sl_mode == TA_SL_POINTS ? st.sl_points : PointsFromPrice(entry, sl, false));
            const double dir = (m_is_buy ? +1.0 : -1.0);

            for(int i=0;i<TA_MAX_TP_LEVELS;i++)
            {
               const string name = (i==0 ? TA_LINE_TP1 : (i==1 ? TA_LINE_TP2 : TA_LINE_TP3));
               const color clr = (i==0 ? m_tp1_clr : (i==1 ? m_tp2_clr : m_tp3_clr));

               if(!st.tp_levels[i].enabled)
               {
                  TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, name));
                  continue;
               }

               double lvl_price = 0.0;
               if(st.tp_levels[i].type == TA_TARGET_R && risk_pts > 0)
               {
                  lvl_price = entry + dir * (double)risk_pts * st.tp_levels[i].target * m_point;
               }
               else if(st.tp_levels[i].type == TA_TARGET_POINTS)
               {
                  lvl_price = entry + dir * st.tp_levels[i].target * m_point;
               }
               else if(st.tp_levels[i].type == TA_TARGET_PRICE)
               {
                  lvl_price = st.tp_levels[i].target;
               }

               if(lvl_price > 0.0)
               {
                  lvl_price = TA_NormalizePrice(ctx.symbol, lvl_price);
                  TA__EnsureHLine(ctx.chart_id,
                                  TA__LineName(ctx, name),
                                  lvl_price,
                                  clr,
                                  m_partial_style,
                                  m_partial_w,
                                  false,
                                  true,
                                  name);
               }
               else
               {
                  TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, name));
               }
            }
         }
         else
         {
            TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP1));
            TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP2));
            TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP3));
         }

         if(st.be_enabled)
         {
            const double be_stop = entry + (m_is_buy ? +1.0 : -1.0) * (double)st.be_offset_points * m_point;
            TA__EnsureHLine(ctx.chart_id,
                            TA__LineName(ctx, TA_LINE_BE),
                            TA_NormalizePrice(ctx.symbol, be_stop),
                            m_be_clr,
                            m_be_style,
                            m_be_w,
                            false,
                            true,
                            "BE");
         }
         else
         {
            TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_BE));
         }
      }
      else
      {
         TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_SL));
         TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP));
         TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP1));
         TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP2));
         TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_TP3));
         TA__ObjDeleteSafe(ctx.chart_id, TA__LineName(ctx, TA_LINE_BE));
      }
   }

   // Handle SL/TP drag to update TA_State (points).
   // Call from EA's OnChartEvent.
   void OnChartEvent(const TA_Context &ctx,
                     TA_State &st,
                     const TA_BrokerRules &broker,
                     const int id,
                     const long &lparam,
                     const double &dparam,
                     const string &sparam)
   {
      if(!m_inited) return;

      // React to object drag/change
      if(id != CHARTEVENT_OBJECT_DRAG &&
         id != CHARTEVENT_OBJECT_CHANGE)
         return;

      // Only our objects (prefix includes magic)
      const string pref = TA__LinesPrefix(ctx);
      if(StringLen(sparam) < StringLen(pref)) return;
      if(StringSubstr(sparam, 0, StringLen(pref)) != pref) return;

      const string name_sl = TA__LineName(ctx, TA_LINE_SL);
      const string name_tp = TA__LineName(ctx, TA_LINE_TP);

      const double entry = TA_NormalizePrice(ctx.symbol, EntryPrice(ctx));
      if(entry <= 0.0) return;

      // Current prices from objects (if present), else from state
      double sl = 0.0, tp = 0.0;
      if(st.sl_mode == TA_SL_POINTS && st.sl_points > 0)
         sl = TA_NormalizePrice(ctx.symbol, PriceFromPoints(entry, st.sl_points, false));
      else if(st.sl_mode == TA_SL_PRICE && st.sl_price > 0.0)
         sl = TA_NormalizePrice(ctx.symbol, st.sl_price);

      if(st.tp_mode == TA_TP_POINTS && st.tp_points > 0)
         tp = TA_NormalizePrice(ctx.symbol, PriceFromPoints(entry, st.tp_points, true));
      else if(st.tp_mode == TA_TP_PRICE && st.tp_price > 0.0)
         tp = TA_NormalizePrice(ctx.symbol, st.tp_price);

      // Read moved line
      if(sparam == name_sl)
      {
         double new_sl = 0.0;
         if(!TA__GetHLinePrice(ctx.chart_id, name_sl, new_sl) || new_sl <= 0.0)
            return;

         sl = TA_NormalizePrice(ctx.symbol, new_sl);

         // Validate/repair with broker rules (also keeps TP consistent)
         if(!broker.EnsureStopsDistance(sl, tp,
                                       (m_is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL),
                                       entry))
         {
            // Revert visual to last known good
            double fallback_sl = (st.sl_mode == TA_SL_PRICE && st.sl_price > 0.0)
                                 ? st.sl_price
                                 : PriceFromPoints(entry, st.sl_points, false);
            TA__SetHLinePriceSafe(ctx.chart_id, name_sl, fallback_sl);
            if(st.tp_mode == TA_TP_POINTS && st.tp_points > 0)
               TA__SetHLinePriceSafe(ctx.chart_id, name_tp, PriceFromPoints(entry, st.tp_points, true));
            else if(st.tp_mode == TA_TP_PRICE && st.tp_price > 0.0)
               TA__SetHLinePriceSafe(ctx.chart_id, name_tp, st.tp_price);
            return;
         }

         // Update state from (possibly adjusted) sl/tp
         st.sl_points = PointsFromPrice(entry, sl, false);
         if(st.sl_points > 0)
         {
            st.sl_enabled = true;
            st.sl_mode = TA_SL_POINTS;
            st.sl_price = 0.0;
         }

         if(tp > 0.0 && st.tp_mode == TA_TP_POINTS)
            st.tp_points = PointsFromPrice(entry, tp, true);

         // Update objects to adjusted prices
         TA__SetHLinePriceSafe(ctx.chart_id, name_sl, sl);
         if(TA__ObjExists(ctx.chart_id, name_tp)) TA__SetHLinePriceSafe(ctx.chart_id, name_tp, tp);
      }
      else if(sparam == name_tp)
      {
         double new_tp = 0.0;
         if(!TA__GetHLinePrice(ctx.chart_id, name_tp, new_tp) || new_tp <= 0.0)
            return;

         tp = TA_NormalizePrice(ctx.symbol, new_tp);

         if(!broker.EnsureStopsDistance(sl, tp,
                                       (m_is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL),
                                       entry))
         {
            // Revert visual
            double fallback_tp = (st.tp_mode == TA_TP_PRICE && st.tp_price > 0.0)
                                 ? st.tp_price
                                 : PriceFromPoints(entry, st.tp_points, true);
            TA__SetHLinePriceSafe(ctx.chart_id, name_tp, fallback_tp);
            if(st.sl_mode == TA_SL_POINTS && st.sl_points > 0)
               TA__SetHLinePriceSafe(ctx.chart_id, name_sl, PriceFromPoints(entry, st.sl_points, false));
            else if(st.sl_mode == TA_SL_PRICE && st.sl_price > 0.0)
               TA__SetHLinePriceSafe(ctx.chart_id, name_sl, st.sl_price);
            return;
         }

         st.tp_points = PointsFromPrice(entry, tp, true);
         if(st.tp_points > 0)
         {
            st.tp_enabled = true;
            st.tp_mode = TA_TP_POINTS;
            st.tp_price = 0.0;
         }

         if(st.sl_mode == TA_SL_POINTS && sl > 0.0)
            st.sl_points = PointsFromPrice(entry, sl, false);

         TA__SetHLinePriceSafe(ctx.chart_id, name_tp, tp);
         if(TA__ObjExists(ctx.chart_id, name_sl)) TA__SetHLinePriceSafe(ctx.chart_id, name_sl, sl);
      }
   }
};

#endif // __TA_LINES_MQH__

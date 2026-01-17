//+------------------------------------------------------------------+
//|                                                    UI_InfoTab.mqh |
//|                        MuseraTradeAssistant (UI module)           |
//|                                  (c) 2026, Musera Isaac           |
//|                                                                  |
//|  Info/Status tab: shows account/symbol status + current config    |
//|  summary. Lightweight and updated on OnTimer (tickless UI).       |
//|                                                                  |
//|  Location:                                                        |
//|   MQL5\Experts\MuseraTradeAssistant\include\UI\UI_InfoTab.mqh      |
//+------------------------------------------------------------------+
#ifndef __UI_INFO_TAB_MQH__
#define __UI_INFO_TAB_MQH__

#include "UI_Theme.mqh"

#include "../TA_Types.mqh"
#include "../TA_State.mqh"
#include "../TA_Enums.mqh"

// ------------------------ helpers local to this tab ------------------------
string UI_Info_TFName(const ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return EnumToString(tf);
   }
}

string UI_Info_Bool(const bool v) { return v ? "ON" : "OFF"; }

string UI_Info_Money(const double v, const int digits=2)
{
   return DoubleToString(v, digits);
}

string UI_Info_Int(const long v) { return (string)v; }

//+------------------------------------------------------------------+
//| UI_InfoTab                                                       |
//+------------------------------------------------------------------+
class UI_InfoTab
{
private:
   string   m_prefix;
   int      m_left, m_top, m_w, m_h;
   UI_Theme m_theme;
   bool     m_visible;

   // background + title
   string id_bg;
   string id_title;
   string id_sub;

   // account section
   string id_acct_hdr;
   string id_balance;
   string id_equity;
   string id_free;
   string id_ml;
   string id_leverage;

   // symbol section
   string id_sym_hdr;
   string id_symbol;
   string id_tf;
   string id_bidask;
   string id_spread;
   string id_tick;
   string id_server_time;

   // config summary section
   string id_cfg_hdr;
   string id_preset;
   string id_risk;
   string id_sl_tp;
   string id_partials;
   string id_be;
   string id_trail;

   // utility buttons
   string id_btn_ui_front;
   string id_btn_candles_front;

   // cached last display strings (avoid excessive ObjectSetString calls)
   string m_last_balance, m_last_equity, m_last_free, m_last_ml, m_last_lev;
   string m_last_symbol, m_last_tf, m_last_bidask, m_last_spread, m_last_tick, m_last_srv;
   string m_last_preset, m_last_risk, m_last_sltp, m_last_partials, m_last_be, m_last_trail;

private:
   void BuildIds(const string &prefix)
   {
      id_bg            = MakeId(prefix, "info.bg");
      id_title         = MakeId(prefix, "info.title");
      id_sub           = MakeId(prefix, "info.sub");

      id_acct_hdr      = MakeId(prefix, "info.acct.hdr");
      id_balance       = MakeId(prefix, "info.acct.balance");
      id_equity        = MakeId(prefix, "info.acct.equity");
      id_free          = MakeId(prefix, "info.acct.free");
      id_ml            = MakeId(prefix, "info.acct.ml");
      id_leverage      = MakeId(prefix, "info.acct.lev");

      id_sym_hdr       = MakeId(prefix, "info.sym.hdr");
      id_symbol        = MakeId(prefix, "info.sym.symbol");
      id_tf            = MakeId(prefix, "info.sym.tf");
      id_bidask        = MakeId(prefix, "info.sym.bidask");
      id_spread        = MakeId(prefix, "info.sym.spread");
      id_tick          = MakeId(prefix, "info.sym.tick");
      id_server_time   = MakeId(prefix, "info.sym.time");

      id_cfg_hdr       = MakeId(prefix, "info.cfg.hdr");
      id_preset        = MakeId(prefix, "info.cfg.preset");
      id_risk          = MakeId(prefix, "info.cfg.risk");
      id_sl_tp         = MakeId(prefix, "info.cfg.sltp");
      id_partials      = MakeId(prefix, "info.cfg.partials");
      id_be            = MakeId(prefix, "info.cfg.be");
      id_trail         = MakeId(prefix, "info.cfg.trail");

      id_btn_ui_front      = MakeId(prefix, "info.btn.ui_front");
      id_btn_candles_front = MakeId(prefix, "info.btn.candles_front");
   }

   void CreateStaticLayout()
   {
      // background (tab area)
      CreateRect(id_bg, Rect(m_left, m_top, m_left + m_w, m_top + m_h), m_theme);
      SetBg(id_bg, m_theme);

      int x = m_left + 10;
      int y = m_top  + 8;

      CreateLabel(id_title, Rect(x, y, x + m_w - 20, y + 18), "Info / Status", m_theme);
      SetLabel(id_title, m_theme, true);
      y += 18;

      CreateLabel(id_sub, Rect(x, y, x + m_w - 20, y + 16),
                  "Account, Symbol and current settings summary.", m_theme);
      SetLabel(id_sub, m_theme, false);
      y += 20;

      // --- Account section ---
      CreateLabel(id_acct_hdr, Rect(x, y, x + m_w - 20, y + 16), "ACCOUNT", m_theme);
      SetLabel(id_acct_hdr, m_theme, true);
      y += 18;

      CreateLabel(id_balance, Rect(x, y, x + m_w - 20, y + 16), "Balance: --", m_theme);
      SetLabel(id_balance, m_theme, false);
      y += 16;

      CreateLabel(id_equity, Rect(x, y, x + m_w - 20, y + 16), "Equity: --", m_theme);
      SetLabel(id_equity, m_theme, false);
      y += 16;

      CreateLabel(id_free, Rect(x, y, x + m_w - 20, y + 16), "Free Margin: --", m_theme);
      SetLabel(id_free, m_theme, false);
      y += 16;

      CreateLabel(id_ml, Rect(x, y, x + m_w - 20, y + 16), "Margin Level: --", m_theme);
      SetLabel(id_ml, m_theme, false);
      y += 16;

      CreateLabel(id_leverage, Rect(x, y, x + m_w - 20, y + 16), "Leverage: --", m_theme);
      SetLabel(id_leverage, m_theme, false);
      y += 22;

      // --- Symbol section ---
      CreateLabel(id_sym_hdr, Rect(x, y, x + m_w - 20, y + 16), "SYMBOL", m_theme);
      SetLabel(id_sym_hdr, m_theme, true);
      y += 18;

      CreateLabel(id_symbol, Rect(x, y, x + m_w - 20, y + 16), "Symbol: --", m_theme);
      SetLabel(id_symbol, m_theme, false);
      y += 16;

      CreateLabel(id_tf, Rect(x, y, x + m_w - 20, y + 16), "Timeframe: --", m_theme);
      SetLabel(id_tf, m_theme, false);
      y += 16;

      CreateLabel(id_bidask, Rect(x, y, x + m_w - 20, y + 16), "Bid/Ask: --", m_theme);
      SetLabel(id_bidask, m_theme, false);
      y += 16;

      CreateLabel(id_spread, Rect(x, y, x + m_w - 20, y + 16), "Spread: --", m_theme);
      SetLabel(id_spread, m_theme, false);
      y += 16;

      CreateLabel(id_tick, Rect(x, y, x + m_w - 20, y + 16), "Tick: --", m_theme);
      SetLabel(id_tick, m_theme, false);
      y += 16;

      CreateLabel(id_server_time, Rect(x, y, x + m_w - 20, y + 16), "Server Time: --", m_theme);
      SetLabel(id_server_time, m_theme, false);
      y += 22;

      // --- Config summary ---
      CreateLabel(id_cfg_hdr, Rect(x, y, x + m_w - 20, y + 16), "CURRENT SETTINGS", m_theme);
      SetLabel(id_cfg_hdr, m_theme, true);
      y += 18;

      CreateLabel(id_preset, Rect(x, y, x + m_w - 20, y + 16), "Preset: --", m_theme);
      SetLabel(id_preset, m_theme, false);
      y += 16;

      CreateLabel(id_risk, Rect(x, y, x + m_w - 20, y + 16), "Risk: --", m_theme);
      SetLabel(id_risk, m_theme, false);
      y += 16;

      CreateLabel(id_sl_tp, Rect(x, y, x + m_w - 20, y + 16), "SL/TP: --", m_theme);
      SetLabel(id_sl_tp, m_theme, false);
      y += 16;

      CreateLabel(id_partials, Rect(x, y, x + m_w - 20, y + 16), "TP Partials: --", m_theme);
      SetLabel(id_partials, m_theme, false);
      y += 16;

      CreateLabel(id_be, Rect(x, y, x + m_w - 20, y + 16), "Break-even: --", m_theme);
      SetLabel(id_be, m_theme, false);
      y += 16;

      CreateLabel(id_trail, Rect(x, y, x + m_w - 20, y + 16), "Trailing: --", m_theme);
      SetLabel(id_trail, m_theme, false);
      y += 20;

      // small utilities
      int bw = (m_w - 30) / 2;
      CreateButton(id_btn_ui_front, Rect(x, y, x + bw, y + 22), "UI Front", m_theme);
      SetBtn(id_btn_ui_front, m_theme);

      CreateButton(id_btn_candles_front, Rect(x + bw + 10, y, x + 2*bw + 10, y + 22), "Candles Front", m_theme);
      SetBtn(id_btn_candles_front, m_theme);
   }

   void UpdateAccount()
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
      double fm  = AccountInfoDouble(ACCOUNT_FREEMARGIN);
      double ml  = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      long lev   = AccountInfoInteger(ACCOUNT_LEVERAGE);

      string s_bal = "Balance: " + UI_Info_Money(bal, 2);
      string s_eq  = "Equity: " + UI_Info_Money(eq, 2);
      string s_fm  = "Free Margin: " + UI_Info_Money(fm, 2);
      string s_ml  = "Margin Level: " + (ml <= 0 ? "--" : (DoubleToString(ml, 1) + "%"));
      string s_lev = "Leverage: 1:" + UI_Info_Int(lev);

      if(s_bal != m_last_balance) { ObjectSetString(0, id_balance, OBJPROP_TEXT, s_bal); m_last_balance = s_bal; }
      if(s_eq  != m_last_equity ) { ObjectSetString(0, id_equity,  OBJPROP_TEXT, s_eq ); m_last_equity  = s_eq;  }
      if(s_fm  != m_last_free   ) { ObjectSetString(0, id_free,    OBJPROP_TEXT, s_fm ); m_last_free    = s_fm;  }
      if(s_ml  != m_last_ml     ) { ObjectSetString(0, id_ml,      OBJPROP_TEXT, s_ml ); m_last_ml      = s_ml;  }
      if(s_lev != m_last_lev    ) { ObjectSetString(0, id_leverage,OBJPROP_TEXT, s_lev); m_last_lev     = s_lev; }
   }

   void UpdateSymbol(const TA_Context &ctx)
   {
      MqlTick t;
      bool ok = SymbolInfoTick(ctx.symbol, t);

      string s_symbol = "Symbol: " + ctx.symbol;
      string s_tf     = "Timeframe: " + UI_Info_TFName((ENUM_TIMEFRAMES)Period());
      string s_bidask = ok ? ("Bid/Ask: " + DoubleToString(t.bid, (int)SymbolInfoInteger(ctx.symbol, SYMBOL_DIGITS))
                                 + " / " + DoubleToString(t.ask, (int)SymbolInfoInteger(ctx.symbol, SYMBOL_DIGITS)))
                           : "Bid/Ask: --";

      double spread_pts = (ok && _Point > 0.0) ? (t.ask - t.bid) / _Point : 0.0;
      string s_spread = ok ? ("Spread: " + DoubleToString(spread_pts, 1) + " pts") : "Spread: --";

      double tv = SymbolInfoDouble(ctx.symbol, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(ctx.symbol, SYMBOL_TRADE_TICK_SIZE);
      string s_tick = "Tick: val " + DoubleToString(tv, 2) + " size " + DoubleToString(ts, 6);

      string s_srv = "Server Time: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);

      if(s_symbol != m_last_symbol) { ObjectSetString(0, id_symbol, OBJPROP_TEXT, s_symbol); m_last_symbol = s_symbol; }
      if(s_tf     != m_last_tf    ) { ObjectSetString(0, id_tf,     OBJPROP_TEXT, s_tf    ); m_last_tf     = s_tf;     }
      if(s_bidask != m_last_bidask) { ObjectSetString(0, id_bidask, OBJPROP_TEXT, s_bidask); m_last_bidask = s_bidask; }
      if(s_spread != m_last_spread) { ObjectSetString(0, id_spread, OBJPROP_TEXT, s_spread); m_last_spread = s_spread; }
      if(s_tick   != m_last_tick  ) { ObjectSetString(0, id_tick,   OBJPROP_TEXT, s_tick  ); m_last_tick   = s_tick;   }
      if(s_srv    != m_last_srv   ) { ObjectSetString(0, id_server_time, OBJPROP_TEXT, s_srv); m_last_srv = s_srv; }
   }

   void UpdateConfigSummary(const TA_Context &ctx, const TA_State &st)
   {
      // Preset
      string preset = st.current_preset_name;
      if(preset == "") preset = "(none)";
      string s_preset = "Preset: " + preset;

      // Risk
      string s_risk = "Risk: " + RiskModeName(st.risk_mode) + " | " +
                      (st.risk_mode == TA_RISK_FIXED_LOTS
                        ? ("Lots " + DoubleToString(st.fixed_lots, 2))
                        : (DoubleToString(st.risk_value, 2) + "%"));

      // SL/TP
      string sls = (st.sl_mode == TA_SL_NONE) ? "SL none" :
                   (st.sl_mode == TA_SL_POINTS ? ("SL " + IntegerToString(st.sl_points) + " pts") :
                    (st.sl_mode == TA_SL_PRICE ? ("SL @" + DoubleToString(st.sl_price, (int)SymbolInfoInteger(ctx.symbol, SYMBOL_DIGITS))) :
                     ("SL RR")));
      string tps = (st.tp_mode == TA_TP_NONE) ? "TP none" :
                   (st.tp_mode == TA_TP_POINTS ? ("TP " + IntegerToString(st.tp_points) + " pts") :
                    (st.tp_mode == TA_TP_PRICE ? ("TP @" + DoubleToString(st.tp_price, (int)SymbolInfoInteger(ctx.symbol, SYMBOL_DIGITS))) :
                     ("TP RR")));
      string s_sltp = "SL/TP: " + sls + " | " + tps;

      // Partials
      string s_partials = "TP Partials: " + UI_Info_Bool(st.tp_partials_enabled);
      if(st.tp_partials_enabled)
      {
         // describe by R if using RR mode, else by points if points mode
         if(st.tp_partials_mode == TA_PARTIALS_BY_R)
         {
            s_partials += " (R: " +
               DoubleToString(st.tp1_at_r,2) + "/" + DoubleToString(st.tp2_at_r,2) + "/" + DoubleToString(st.tp3_at_r,2) +
               " | %: " +
               DoubleToString(st.tp1_close_pct,0) + "/" + DoubleToString(st.tp2_close_pct,0) + "/" + DoubleToString(st.tp3_close_pct,0) + ")";
         }
         else
         {
            s_partials += " (pts: " +
               IntegerToString(st.tp1_at_points) + "/" + IntegerToString(st.tp2_at_points) + "/" + IntegerToString(st.tp3_at_points) +
               " | %: " +
               DoubleToString(st.tp1_close_pct,0) + "/" + DoubleToString(st.tp2_close_pct,0) + "/" + DoubleToString(st.tp3_close_pct,0) + ")";
         }
      }

      // Break-even
      string s_be = "Break-even: " + UI_Info_Bool(st.be_enabled);
      if(st.be_enabled)
      {
         if(st.be_mode == TA_BE_BY_R)
            s_be += " (at R " + DoubleToString(st.be_at_r,2) + ", lock " + IntegerToString(st.be_lock_points) + " pts)";
         else
            s_be += " (at " + IntegerToString(st.be_at_points) + " pts, lock " + IntegerToString(st.be_lock_points) + " pts)";
      }

      // Trailing
      string s_tr = "Trailing: " + UI_Info_Bool(st.trailing_enabled);
      if(st.trailing_enabled)
         s_tr += " (" + TrailModeName(st.trailing_mode) + ")";

      if(s_preset   != m_last_preset ) { ObjectSetString(0, id_preset,   OBJPROP_TEXT, s_preset  ); m_last_preset  = s_preset;  }
      if(s_risk     != m_last_risk   ) { ObjectSetString(0, id_risk,     OBJPROP_TEXT, s_risk    ); m_last_risk    = s_risk;    }
      if(s_sltp     != m_last_sltp   ) { ObjectSetString(0, id_sl_tp,    OBJPROP_TEXT, s_sltp    ); m_last_sltp    = s_sltp;    }
      if(s_partials != m_last_partials){ ObjectSetString(0, id_partials, OBJPROP_TEXT, s_partials); m_last_partials= s_partials; }
      if(s_be       != m_last_be     ) { ObjectSetString(0, id_be,       OBJPROP_TEXT, s_be      ); m_last_be      = s_be;      }
      if(s_tr       != m_last_trail  ) { ObjectSetString(0, id_trail,    OBJPROP_TEXT, s_tr      ); m_last_trail   = s_tr;      }
   }

public:
   UI_InfoTab() : m_left(0), m_top(0), m_w(0), m_h(0), m_visible(false) {}

   bool Create(const string prefix, int x, int y, int w, int h, const UI_Theme &theme)
   {
      m_prefix = prefix;
      m_left   = x;
      m_top    = y;
      m_w      = w;
      m_h      = h;
      m_theme  = theme;
      m_visible = false;

      BuildIds(prefix);
      CreateStaticLayout();
      SetVisible(false);
      return true;
   }

   void Destroy()
   {
      DeleteObjectsByPrefix(m_prefix + "info.");
      m_visible = false;
   }

   void SetVisible(const bool v)
   {
      m_visible = v;
      ShowObjectsByPrefix(m_prefix + "info.", v);
   }

   bool Visible() const { return m_visible; }

   void SyncFromState(const TA_Context &ctx, const TA_State &st)
   {
      // Config summary depends on state; apply now so tab is correct when opened.
      UpdateConfigSummary(ctx, st);
   }

   void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      if(!m_visible) return;

      UpdateAccount();
      UpdateSymbol(ctx);
      UpdateConfigSummary(ctx, st);
   }

   void OnChartEvent(const TA_Context &ctx, const TA_State &st,
                     const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(!m_visible) return;

      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         if(sparam == id_btn_ui_front)
         {
            // Candles behind objects (UI on top)
            ChartSetInteger(0, CHART_FOREGROUND, false);
            ChartRedraw();
         }
         else if(sparam == id_btn_candles_front)
         {
            // Candles in foreground (objects behind)
            ChartSetInteger(0, CHART_FOREGROUND, true);
            ChartRedraw();
         }
      }
   }
};

#endif // __UI_INFO_TAB_MQH__
//+------------------------------------------------------------------+

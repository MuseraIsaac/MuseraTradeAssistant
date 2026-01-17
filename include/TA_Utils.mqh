//+------------------------------------------------------------------+
//|                                                    TA_Utils.mqh  |
//|                       MuseraTradeAssistant (include)             |
//|                                  (c) 2026, Musera Isaac          |
//+------------------------------------------------------------------+
#property strict

#ifndef __TA_UTILS_MQH__
#define __TA_UTILS_MQH__

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"

#include <Trade/SymbolInfo.mqh>

// -----------------------------
// Result helpers
// -----------------------------
#ifndef __TA_RESULT_HELPERS_MQH__
#define __TA_RESULT_HELPERS_MQH__
inline TA_Result TA__Ok(const string msg="")
{
   TA_Result r; r.ok=true; r.code=0; r.message=msg; return r;
}

inline TA_Result TA__Fail(const string msg, const int code)
{
   TA_Result r; r.ok=false; r.code=code; r.message=msg; return r;
}

inline void TA__Ok(TA_Result &r, const string msg="")
{
   r.ok=true; r.code=0; r.message=msg;
}

inline void TA__Fail(TA_Result &r, const int code, const string msg)
{
   r.ok=false; r.code=code; r.message=msg;
}
#endif

// -----------------------------
// String helpers
// -----------------------------
inline string TA_Trim(const string s)
{
   string t=s; StringTrimLeft(t); StringTrimRight(t); return t;
}

inline string TA_ToUpper(const string s)
{
   string t=s; StringToUpper(t); return t;
}

inline string TA_ToLower(const string s)
{
   string t=s; StringToLower(t); return t;
}

// -----------------------------
// Numeric helpers
// -----------------------------
inline bool TA__IsFinite(const double x)
{
   // NaN check: NaN != NaN
   if(x!=x) return false;
   // INF check (use a very wide bound)
   if(MathAbs(x) > 1e308) return false;
   return true;
}

// Backward-compatible alias used by some modules
inline bool TA_IsFinite(const double x) { return TA__IsFinite(x); }

inline double TA_Clamp(const double v, const double lo, const double hi)
{
   if(v<lo) return lo;
   if(v>hi) return hi;
   return v;
}

inline double TA_RoundToStep(const double value, const double step)
{
   if(step<=0.0) return value;
   return MathRound(value/step)*step;
}

// -----------------------------
// Symbol helpers
// -----------------------------
inline int TA_SymbolDigits(const string sym)
{
   return (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
}

inline double TA_Point(const string sym)
{
   return SymbolInfoDouble(sym, SYMBOL_POINT);
}

inline double TA_SymbolTickSize(const string sym)
{
   double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(ts<=0.0) ts = TA_Point(sym);
   return ts;
}

inline bool TA_SymbolTradingAllowed(const string sym)
{
   long mode = SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED) return false;

   // Also require symbol to be selected so that Bid/Ask can be refreshed.
   // (If not selected, selecting is safe.)
   if(!SymbolSelect(sym, true))
      return false;
   return true;
}

inline double TA_NormalizePrice(const string sym, const double price)
{
   return NormalizeDouble(price, TA_SymbolDigits(sym));
}

inline double TA_NormalizePriceToTick(const double price, const double tick_size)
{
   if(tick_size<=0.0) return price;
   return MathRound(price/tick_size)*tick_size;
}

inline double TA_PipsToPrice(const string sym, const double pips)
{
   const double pt = TA_Point(sym);
   const int digits = TA_SymbolDigits(sym);
   const double pip = ((digits==3 || digits==5) ? (pt * 10.0) : pt);
   return pips * pip;
}

inline double TA_PriceToPoints(const string sym, const double price_diff)
{
   const double pt = TA_Point(sym);
   if(pt <= 0.0) return 0.0;
   return price_diff / pt;
}

inline double TA_Bid(const string sym)
{
   double v=0.0; SymbolInfoDouble(sym, SYMBOL_BID, v); return v;
}

inline double TA_Ask(const string sym)
{
   double v=0.0; SymbolInfoDouble(sym, SYMBOL_ASK, v); return v;
}

// -----------------------------
// Volume helpers
// -----------------------------
inline double TA_VolumeMin(const string sym)  { return SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);  }
inline double TA_VolumeMax(const string sym)  { return SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);  }
inline double TA_VolumeStep(const string sym) { return SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP); }

inline double TA_NormalizeVolume(const string sym, double lots)
{
   double vmin  = TA_VolumeMin(sym)
   double vmax  = TA_VolumeMax(sym);
   double vstep = TA_VolumeStep(sym);

   if(!TA__IsFinite(lots)) lots = vmin;
   lots = TA_Clamp(lots, vmin, vmax);

   if(vstep>0.0)
      lots = TA_RoundToStep(lots, vstep);

   lots = TA_Clamp(lots, vmin, vmax);
   return NormalizeDouble(lots, 8);
}

inline double TA_ValuePerPoint(const string sym)
{
   const double tick_value = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   const double pt = TA_Point(sym);
   if(tick_value<=0.0 || tick_size<=0.0 || pt<=0.0) return 0.0;
   return tick_value * (pt / tick_size);
}

// -----------------------------
// Account helpers
// -----------------------------
inline double TA_AccountBaseMoney(const ENUM_TA_RISK_BASIS basis)
{
   switch(basis)
     {
      case TA_BASIS_BALANCE: return AccountInfoDouble(ACCOUNT_BALANCE);
      case TA_BASIS_EQUITY:  return AccountInfoDouble(ACCOUNT_EQUITY);
      case TA_BASIS_FREE_MG: return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
     }
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

inline double TA_MoneyRiskFromPercent(const ENUM_TA_RISK_BASIS basis, const double percent)
{
   if(!TA__IsFinite(percent) || percent<=0.0) return 0.0;
   return TA_AccountBaseMoney(basis) * (percent/100.0);
}

// -----------------------------
// File helpers (Terminal data folder by default)
// -----------------------------
inline bool TA__ReadAllText(const string path, string &out_text, const bool common=false)
{
   out_text = "";
   int flags = FILE_READ | FILE_TXT | FILE_ANSI;
   if(common) flags |= FILE_COMMON;

   int h = FileOpen(path, flags);
   if(h == INVALID_HANDLE)
      return false;

   string acc="";
   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      if(acc != "") acc += "\n";
      acc += line;
     }
   FileClose(h);
   out_text = acc;
   return true;
}

inline bool TA__WriteAllText(const string path, const string text, const bool common=false)
{
   int flags = FILE_WRITE | FILE_TXT | FILE_ANSI;
   if(common) flags |= FILE_COMMON;

   int h = FileOpen(path, flags);
   if(h == INVALID_HANDLE)
      return false;

   FileWriteString(h, text);
   FileClose(h);
   return true;
}

// -----------------------------
// Broker-rules macros
//
// TA_RR and some modules operate on TA_BrokerRules but include TA_Utils
// before TA_BrokerRules. Using macros avoids cyclic type-dependency.
// These macros compile where they are USED (after TA_BrokerRules is visible).
// -----------------------------

#define TA_NormalizePrice(br, price) NormalizeDouble((price), (br).Digits())
#define TA_PointsBetweenPrices(br, a, b) ( ( (br).Point()<=0.0 ) ? 0.0 : (MathAbs((a)-(b)) / (br).Point()) )
#define TA_PriceFromPoints(br, base_price, points, is_buy) ( (is_buy) ? ((base_price) + ((points) * (br).Point())) : ((base_price) - ((points) * (br).Point())) )

#endif // __TA_UTILS_MQH__

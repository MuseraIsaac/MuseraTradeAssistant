//+------------------------------------------------------------------+
//|                                                     TA_Enums.mqh |
//|                        (c) 2026, Musera Isaac                     |
//|  Enums used across MuseraTradeAssistant project.                   |
//|                                                                    |
//|  Path (expected):                                                  |
//|  MQL5\Experts\MuseraTradeAssistant\include\TA_Enums.mqh             |
//+------------------------------------------------------------------+
#property strict

#ifndef __MUSERA_TA_ENUMS_MQH__
#define __MUSERA_TA_ENUMS_MQH__

// ------------------------------
// Core app / UI state
// ------------------------------
enum ENUM_TA_APP_TAB
  {
   TA_TAB_TRADE    = 0,
   TA_TAB_CLOSE    = 1,
   TA_TAB_TRAILING = 2,
   TA_TAB_BE       = 3,
   TA_TAB_SETTINGS = 4,
   TA_TAB_INFO     = 5
  };

// ------------------------------
// Order types / direction
// ------------------------------
enum ENUM_TA_SIDE
  {
   TA_SIDE_NONE = -1,
   TA_SIDE_BUY  = 0,
   TA_SIDE_SELL = 1
  };

enum ENUM_TA_ORDER_KIND
  {
   TA_ORDER_MARKET = 0,
   TA_ORDER_LIMIT  = 1,
   TA_ORDER_STOP   = 2
  };

// Order builder intent (market vs pending)
enum ENUM_TA_ORDER_ACTION
  {
   TA_ACTION_MARKET  = 0,
   TA_ACTION_PENDING = 1
  };

// For virtual orders module
enum ENUM_TA_VORDER_KIND
  {
   TA_VORDER_NONE  = 0,
   TA_VORDER_LIMIT = 1,
   TA_VORDER_STOP  = 2
  };

// ------------------------------
// Risk / volume calculation
// ------------------------------
enum ENUM_TA_RISK_MODE
  {
   TA_RISK_FIXED_LOT     = 0,  // user sets lots explicitly
   TA_RISK_BALANCE_PCT   = 1,  // percent of balance
   TA_RISK_EQUITY_PCT    = 2,  // percent of equity
   TA_RISK_MONEY         = 3   // fixed money risk (account currency)
  };

// Legacy alias for UI wording
#define TA_RISK_FIXED_LOTS TA_RISK_FIXED_LOT

// Risk inputs reference point
enum ENUM_TA_RISK_BASIS
  {
   TA_BASIS_BALANCE = 0,
   TA_BASIS_EQUITY  = 1,
   TA_BASIS_FREE_MG = 2
  };

// R:R input style
enum ENUM_TA_RR_MODE
  {
   TA_RR_MANUAL_PRICES = 0, // user drags lines; TP/SL as prices
   TA_RR_PIPS          = 1, // SL/TP distances in points/pips
   TA_RR_R_MULTIPLE    = 2  // TP expressed as R multiple of SL distance
  };

// ------------------------------
// SL/TP modes (compatibility with older UI)
// ------------------------------
enum ENUM_TA_SL_MODE
  {
   TA_SL_NONE   = 0,
   TA_SL_POINTS = 1,
   TA_SL_PRICE  = 2,
   TA_SL_RR     = 3
  };

enum ENUM_TA_TP_MODE
  {
   TA_TP_NONE   = 0,
   TA_TP_POINTS = 1,
   TA_TP_PRICE  = 2,
   TA_TP_RR     = 3
  };

// Legacy aliases for points/pips naming.
#define TA_SL_PIPS TA_SL_POINTS
#define TA_TP_PIPS TA_TP_POINTS

// ------------------------------
// Partial TP / scaling out
// ------------------------------
enum ENUM_TA_PARTIAL_SCHEMA
  {
   TA_PARTIAL_OFF      = 0,
   TA_PARTIAL_TP1_TP2_TP3 = 1
  };

enum ENUM_TA_PARTIAL_TRIGGER
  {
   TA_PARTIAL_TRIGGER_BY_PRICE = 0, // trigger by TP line prices
   TA_PARTIAL_TRIGGER_BY_R     = 1  // trigger by R multiple (e.g., 1R/2R/3R)
  };

// Legacy partials mode (UI uses by-R vs by-points)
enum ENUM_TA_PARTIALS_MODE
  {
   TA_PARTIALS_BY_R      = 0,
   TA_PARTIALS_BY_POINTS = 1
  };

// ------------------------------
// Break-even logic
// ------------------------------
enum ENUM_TA_BE_MODE
  {
   TA_BE_OFF          = 0,
   TA_BE_AT_R         = 1,  // move SL to entry when profit reaches X*R
   TA_BE_AT_PIPS      = 2,  // move SL to entry when profit reaches X points
   TA_BE_AFTER_TP1    = 3   // move to BE after TP1 partial is executed
  };

// Legacy aliases used by UI text
#define TA_BE_BY_R    TA_BE_AT_R
#define TA_BE_BY_PIPS TA_BE_AT_PIPS

// ------------------------------
// Trailing logic
// ------------------------------
enum ENUM_TA_TRAIL_MODE
  {
   TA_TRAIL_NONE          = 0,
   TA_TRAIL_PIPS          = 1,   // classic fixed distance
   TA_TRAIL_FRACTALS      = 2,   // fractal-based
   TA_TRAIL_MA            = 3,   // moving average
   TA_TRAIL_SAR           = 4,   // parabolic SAR
   TA_TRAIL_ATR           = 5,   // ATR multiple
   TA_TRAIL_PARTIAL_CLOSE = 6,   // trailing + partial close blend
   TA_TRAIL_HIGHLOW_BAR   = 7    // previous bar high/low
  };

// Trailing application scope
enum ENUM_TA_TRAIL_SCOPE
  {
   TA_TRAIL_SCOPE_CURRENT_SYMBOL = 0,
   TA_TRAIL_SCOPE_ALL_SYMBOLS    = 1
  };

// ------------------------------
// Close tab commands
// ------------------------------
enum ENUM_TA_CLOSE_CMD
  {
   TA_CLOSE_NONE = 0,

   // Close positions
   TA_CLOSE_BUY       = 10,
   TA_CLOSE_SELL      = 11,
   TA_CLOSE_ALL       = 12,
   TA_CLOSE_PROFIT    = 13,
   TA_CLOSE_LOSS      = 14,

   // Partial close (by %)
   TA_CLOSE_PARTIAL_25 = 30,
   TA_CLOSE_PARTIAL_50 = 31,
   TA_CLOSE_PARTIAL_75 = 32,

   // Delete pendings
   TA_DELETE_BUY_LIMIT  = 50,
   TA_DELETE_SELL_LIMIT = 51,
   TA_DELETE_BUY_STOP   = 52,
   TA_DELETE_SELL_STOP  = 53,
   TA_DELETE_ALL_PEND   = 54
  };

// ------------------------------
// OCO (One Cancels Other)
// ------------------------------
enum ENUM_TA_OCO_MODE
  {
   TA_OCO_OFF          = 0,
   TA_OCO_PENDING_PAIR = 1,  // one pending cancels the other
   TA_OCO_VIRTUAL_PAIR = 2   // virtual pending cancels the other
  };

// ------------------------------
// Price line identifiers
// ------------------------------
enum ENUM_TA_LINE_ID
  {
   TA_LINE_ENTRY = 0,
   TA_LINE_SL    = 1,
   TA_LINE_TP    = 2,
   TA_LINE_TP1   = 3,
   TA_LINE_TP2   = 4,
   TA_LINE_TP3   = 5,
   TA_LINE_BE    = 6
  };

// ------------------------------
// Notifications
// ------------------------------
enum ENUM_TA_NOTIFY_CHANNEL
  {
   TA_NOTIFY_NONE   = 0,
   TA_NOTIFY_ALERT  = 1,
   TA_NOTIFY_PRINT  = 2,
   TA_NOTIFY_PUSH   = 3,
   TA_NOTIFY_SOUND  = 4
  };

// ------------------------------
// Time manager (trade schedule)
// ------------------------------
enum ENUM_TA_TIME_RULE
  {
   TA_TIME_ALWAYS = 0,
   TA_TIME_SESSION = 1,   // allow between start/end
   TA_TIME_DAYS = 2       // allow on selected days
  };

#endif // __MUSERA_TA_ENUMS_MQH__

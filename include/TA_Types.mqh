//+------------------------------------------------------------------+
//|                                                      TA_Types.mqh |
//|                        (c) 2026, Musera Isaac                     |
//|  Core types / DTOs used across MuseraTradeAssistant project.       |
//|                                                                    |
//|  Path (expected):                                                  |
//|  MQL5\Experts\MuseraTradeAssistant\include\TA_Types.mqh             |
//+------------------------------------------------------------------+
#property strict

#ifndef __MUSERA_TA_TYPES_MQH__
#define __MUSERA_TA_TYPES_MQH__

#include "TA_Enums.mqh"

// ------------------------------
// Core runtime context
// ------------------------------
struct TA_Result
{
   bool   ok;
   int    code;
   string message;

   void Reset(){ ok=true; code=0; message=""; }
};

struct TA_Context
{
   long     chart_id;     // ChartID()
   string   symbol;       // _Symbol
   ulong    magic;        // EA magic number
   int      digits;       // Symbol digits
   double   point;        // Symbol point
   double   tick_size;    // SYMBOL_TRADE_TICK_SIZE
   double   tick_value;   // SYMBOL_TRADE_TICK_VALUE
   double   lot_min;      // SYMBOL_VOLUME_MIN
   double   lot_max;      // SYMBOL_VOLUME_MAX
   double   lot_step;     // SYMBOL_VOLUME_STEP
   int      stops_level;  // SYMBOL_TRADE_STOPS_LEVEL (points)
   int      freeze_level; // SYMBOL_TRADE_FREEZE_LEVEL (points)
   int      spread_points;// current spread in points (optional cache)

   ENUM_TIMEFRAMES tf;    // chart timeframe (optional cache)
};

// ------------------------------
// Risk / RR / price-line configs
// ------------------------------
struct TA_RiskSettings
{
   ENUM_TA_RISK_MODE  mode;           // fixed lot / % / money
   ENUM_TA_RISK_BASIS basis;          // balance/equity/free margin
   double             fixed_lot;      // lots when mode=fixed
   double             risk_percent;   // % when mode=% based
   double             risk_money;     // money when mode=fixed money
   bool               cap_by_margin;  // optional safety
};

struct TA_RRSettings
{
   ENUM_TA_RR_MODE mode;

   // If mode = TA_RR_PIPS
   int    sl_points;
   int    tp_points;

   // If mode = TA_RR_R_MULTIPLE
   double tp_r_multiple;

   // If mode = TA_RR_MANUAL_PRICES, values come from draggable lines
};

struct TA_LinePrices
{
   bool   has_entry;
   bool   has_sl;
   bool   has_tp;
   bool   has_tp1;
   bool   has_tp2;
   bool   has_tp3;

   double entry;
   double sl;
   double tp;
   double tp1;
   double tp2;
   double tp3;
};

// ------------------------------
// Partial TP (TP1/TP2/TP3)
// ------------------------------
struct TA_PartialLevel
{
   bool   enabled;
   double close_percent;  // 0..100 (portion of initial volume to close)
   // Trigger can be in price (line) or in R-multiple, depending on schema.
   double trigger_price;  // absolute price (optional)
   double trigger_r;      // R multiple (optional)
};

struct TA_PartialSettings
{
   bool                   enabled;
   ENUM_TA_PARTIAL_SCHEMA  schema;     // off / tp1-3
   ENUM_TA_PARTIAL_TRIGGER trigger;    // by price or by R

   TA_PartialLevel         tp1;
   TA_PartialLevel         tp2;
   TA_PartialLevel         tp3;

   bool   move_sl_to_be_after_tp1; // common convenience option
};

// ------------------------------
// Break-even
// ------------------------------
struct TA_BESettings
{
   bool           enabled;
   ENUM_TA_BE_MODE mode;

   // When mode = TA_BE_AT_R
   double be_at_r;          // e.g., 1.0R

   // When mode = TA_BE_AT_PIPS
   int    be_at_points;     // points in profit before moving SL to BE

   // Extra offsets
   int    lock_points;      // move SL to entry +/- lock points
   bool   include_commission;// if you want BE to account for costs (optional)
};

// ------------------------------
// Trailing
// ------------------------------
struct TA_TrailPips
{
   int start_points;   // start trailing after profit >= this
   int step_points;    // how often to move
   int distance_points;// trailing distance
};

struct TA_TrailATR
{
   int    atr_period;
   double atr_mult;
};

struct TA_TrailMA
{
   int            ma_period;
   ENUM_MA_METHOD ma_method;
   ENUM_APPLIED_PRICE ma_price;
   int            shift;
};

struct TA_TrailSAR
{
   double step;
   double maximum;
};

struct TA_TrailFractals
{
   int left;   // fractal left bars (optional)
   int right;  // fractal right bars (optional)
};

struct TA_TrailHighLowBar
{
   int bars_back; // e.g., 1 = previous bar
};

struct TA_TrailSettings
{
   bool               enabled;
   ENUM_TA_TRAIL_MODE mode;
   ENUM_TA_TRAIL_SCOPE scope;

   // Common safety rules
   bool only_in_profit;
   int  min_move_points;   // ignore tiny moves
   int  cooldown_seconds;  // reduce modify spam

   // Mode-specific parameters (used by trailing/* modules)
   TA_TrailPips       pips;
   TA_TrailATR        atr;
   TA_TrailMA         ma;
   TA_TrailSAR        sar;
   TA_TrailFractals   fractals;
   TA_TrailHighLowBar hlbar;

   // Optional hybrid
   bool partial_close_on_trail; // used by Trail_PartialClose
   double partial_close_percent;
};

// ------------------------------
// Virtual orders / OCO / schedule / notifications
// ------------------------------
struct TA_VirtualOrderSettings
{
   bool enabled;              // if true, manage virtual pending orders and/or SL/TP
   bool virtual_sl_tp;        // keep SL/TP virtual (not sent to broker)
   bool virtual_pendings;     // keep pending orders virtual

   int  max_slippage_points;  // execution slippage cap for market conversions
};

struct TA_OCOSettings
{
   ENUM_TA_OCO_MODE mode;
   bool             enabled;

   // How far apart to place paired orders (optional)
   int              gap_points;
};

struct TA_TimeSettings
{
   ENUM_TA_TIME_RULE rule;

   // Session window (broker/server time)
   int session_start_hour;
   int session_start_min;
   int session_end_hour;
   int session_end_min;

   // Days mask (bitset: Mon..Sun)
   int days_mask; // 1=Mon ... 64=Sun (your TA_TimeManager defines mapping)
};

struct TA_NotifySettings
{
   ENUM_TA_NOTIFY_CHANNEL channel;
   bool                  enable_sounds;
   bool                  enable_push;
   bool                  enable_alerts;
   string                sound_ok;
   string                sound_error;
};

// ------------------------------
// Order planning & execution DTOs
// ------------------------------
struct TA_OrderPlan
{
   // Intent
   string         symbol;
   ENUM_TA_SIDE   side;
   ENUM_TA_ORDER_KIND kind;

   // Volumes / pricing
   double         volume;    // lots (already validated/normalized by broker rules)
   double         price;     // 0 for market (executor decides)
   double         sl;        // absolute price, 0 if none
   double         tp;        // absolute price, 0 if none

   // Optional partial levels
   double         tp1;
   double         tp2;
   double         tp3;

   // Metadata
   ulong          magic;
   string         comment;

   // Broker-related (optional)
   int            deviation_points;
   ENUM_ORDER_TYPE_FILLING filling;
   ENUM_ORDER_TYPE_TIME    time_type;
   datetime       expiration;

   // Snapshot of configs used for this plan (useful for managers)
   TA_PartialSettings partials;
   TA_BESettings      be;
   TA_TrailSettings   trail;
};

struct TA_ExecResult
{
   bool     success;
   uint     retcode;
   string   message;

   ulong    order_ticket;
   ulong    deal_ticket;
   ulong    position_ticket;

   double   filled_volume;
   double   filled_price;
};

// ------------------------------
// Position snapshots (for close tab / info tab)
// ------------------------------
struct TA_PositionSnapshot
{
   ulong  ticket;
   string symbol;
   ENUM_POSITION_TYPE type;

   double volume;
   double price_open;
   double sl;
   double tp;

   double profit;
   double swap;
   double commission;

   datetime time_open;
};

// ------------------------------
// Preset DTO (persistence)
// ------------------------------
struct TA_Preset
{
   string   name;
   datetime saved_at;
   // The concrete state object lives in TA_State.mqh.
};

#endif // __MUSERA_TA_TYPES_MQH__

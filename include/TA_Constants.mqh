//+------------------------------------------------------------------+
//|                                                     TA_Constants.mqh |
//|                        (c) 2026, Musera Isaac                         |
//|  Project-wide constants for MuseraTradeAssistant (MT5 Utility).        |
//|                                                                        |
//|  This header contains ONLY constants/macros (no project dependencies). |
//|  Keep it safe to include anywhere without pulling other headers.       |
//+------------------------------------------------------------------+
#ifndef __TA_CONSTANTS_MQH__
#define __TA_CONSTANTS_MQH__

// ----------------------------- Identity -----------------------------
#define TA_VERSION               "0.200"
#define TA_PRESET_MAGIC          0x4D544130

#define TA_PROJECT_NAME          "MuseraTradeAssistant"
#define TA_PROJECT_SHORT         "MTA"
#define TA_PROJECT_VENDOR        "Musera Isaac"
#define TA_LOG_PREFIX            "[MTA] "

// ----------------------------- Directories --------------------------
// NOTE: These are informational / convenience strings (not used by MetaTrader internally).
// All paths are relative to the Terminal Data Folder (File -> Open Data Folder).
#define TA_DIR_ROOT              "MQL5\\Experts\\MuseraTradeAssistant\\"
#define TA_DIR_INCLUDE           "MQL5\\Experts\\MuseraTradeAssistant\\include\\"
#define TA_DIR_UI                "MQL5\\Experts\\MuseraTradeAssistant\\include\\UI\\"
#define TA_DIR_TRAIL             "MQL5\\Experts\\MuseraTradeAssistant\\include\\trailing\\"
#define TA_DIR_RES               "MQL5\\Experts\\MuseraTradeAssistant\\resources\\"
#define TA_DIR_RES_IMAGES        "MQL5\\Experts\\MuseraTradeAssistant\\resources\\images\\"
#define TA_DIR_RES_SOUNDS        "MQL5\\Experts\\MuseraTradeAssistant\\resources\\sounds\\"

// Resource file names (your UI layer can load these as files OR embed via #resource)
#define TA_ICON_BUY_FILE         "resources\\images\\icon_buy.png"
#define TA_ICON_SELL_FILE        "resources\\images\\icon_sell.png"
#define TA_ICON_CLOSE_FILE       "resources\\images\\icon_close.png"
#define TA_ICON_SETTINGS_FILE    "resources\\images\\icon_settings.png"

#define TA_SOUND_NOTIFY_FILE     "resources\\sounds\\notify.wav"
#define TA_SOUND_ERROR_FILE      "resources\\sounds\\error.wav"

// If you choose to embed images as resources, define and use resource aliases like:
//   #resource "\\" + TA_DIR_ROOT + TA_ICON_BUY_FILE  as  "::MTA_ICON_BUY"
// Then UI can reference resource name string ("::MTA_ICON_BUY").

// ----------------------------- UI Layout ----------------------------
// General UI sizing (defaults; actual values can be overridden by EA inputs)
#define TA_UI_DEFAULT_X          10
#define TA_UI_DEFAULT_Y          20
#define TA_UI_DEFAULT_W          330
#define TA_UI_DEFAULT_H          360

// Panel layout
#define TA_UI_PAD                10
#define TA_UI_TITLE_H            26
#define TA_UI_TABBAR_H           26
#define TA_UI_STATUSBAR_H        18
#define TA_UI_ROW_H              18
#define TA_UI_BTN_H              20
#define TA_UI_EDIT_H             18
#define TA_UI_DROPDOWN_H         18

// Basic typography (themes may override)
#define TA_UI_FONT_MAIN          "Arial"
#define TA_UI_FONT_MONO          "Consolas"
#define TA_UI_FONT_BOLD          "Arial Bold"
#define TA_UI_FONT_SIZE          9
#define TA_UI_FONT_SIZE_TITLE    11

// Object naming
#define TA_UI_PREFIX             "MTA_"

// IMPORTANT: Chart layering
// - EA will set CHART_FOREGROUND=false to draw candles behind objects.
// - All UI objects should set OBJPROP_BACK=false (on top).
#define TA_UI_CHART_FOREGROUND   (false)

// ----------------------------- Limits -------------------------------
// Hard limits to keep UI/logic safe
#define TA_MAX_TP_LEVELS         3
#define TA_MAX_PRESETS           50
#define TA_MAX_OPEN_POS_TRACK    200
#define TA_MAX_PENDING_TRACK     200

// -------------------------- Risk / RR Defaults ----------------------
// NOTE: Risk modes / enums live in TA_Enums.mqh. Keep these numeric.
#define TA_DFLT_RISK_PERCENT     1.0      // % of balance (or equity) per trade
#define TA_DFLT_RISK_MONEY       10.0     // fixed currency risk
#define TA_DFLT_RR               2.0      // risk:reward target preview
#define TA_DFLT_SL_PIPS          20.0
#define TA_DFLT_TP_PIPS          40.0

// -------------------------- Partials Defaults -----------------------
// Distances can be expressed in R-multiples or pips, depending on TA_State settings.
// The engine (TA_PartialClose) decides interpretation based on TA_State.
#define TA_DFLT_TP1_R            1.0
#define TA_DFLT_TP2_R            2.0
#define TA_DFLT_TP3_R            3.0

// Volume distribution for TP1/TP2/TP3 (percent of initial position volume).
// Must sum to 100 in your validation layer.
#define TA_DFLT_TP1_CLOSE_PCT    50
#define TA_DFLT_TP2_CLOSE_PCT    30
#define TA_DFLT_TP3_CLOSE_PCT    20

// ------------------------ Break-even Defaults -----------------------
#define TA_DFLT_BE_TRIGGER_R     1.0      // move SL to BE after >= 1R
#define TA_DFLT_BE_OFFSET_PIPS   0.0      // add offset (e.g., spread+commission) if desired

// ------------------------ Trailing Defaults -------------------------
// Mode selection is in TA_Enums.mqh. These are generic params used by multiple strategies.
#define TA_DFLT_TRAIL_START_R    1.5
#define TA_DFLT_TRAIL_STEP_PIPS  5.0
#define TA_DFLT_TRAIL_DIST_PIPS  20.0

// ATR trailing defaults
#define TA_DFLT_ATR_PERIOD       14
#define TA_DFLT_ATR_MULT         2.0

// MA trailing defaults
#define TA_DFLT_MA_PERIOD        50
#define TA_DFLT_MA_METHOD        1        // 0=SMA,1=EMA,2=SMMA,3=LWMA (keep numeric here)

// ------------------------ Execution Defaults ------------------------
// Slippage/deviation (points)
#define TA_DFLT_DEVIATION_POINTS 20

// Max retries for trade actions that can be requoted/rejected
#define TA_DFLT_TRADE_RETRIES    2

// ------------------------ Misc -------------------------------------
// Serialization / persistence
#define TA_PRESET_FILE_EXT       ".json"
#define TA_PRESET_FOLDER         "MuseraTradeAssistant\\"

// Misc timers
#define TA_UI_TIMER_MIN_SECONDS  1
#define TA_UI_TIMER_MAX_SECONDS  10

#endif // __TA_CONSTANTS_MQH__
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                              MuseraTradeAssistant.mq5 |
//|                                  (c) 2026, Musera Isaac               |
//|  Trade Assistant / Trade Manager style utility (project shell).        |
//|                                                                       |
//|  NOTE: This file intentionally depends on external project includes    |
//|  under: MQL5\Experts\MuseraTradeAssistant\include\...                  |
//|  It is expected NOT to compile until those includes are created.       |
//+------------------------------------------------------------------+
#property strict
#property version   "1.000"
#property description "Trade Assistant shell: TP partials (TP1/TP2/TP3), trailing modes dropdown, break-even, presets save/load. Requires project includes."

// ------------------------- REQUIRED PROJECT FILES -------------------------
// Relative to MQL5\Data Folder:
//
// MQL5\Experts\MuseraTradeAssistant\MuseraTradeAssistant.mq5
// MQL5\Experts\MuseraTradeAssistant\include\TA_Constants.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Enums.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Types.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Utils.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Validation.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_BrokerRules.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_State.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Persistence.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Risk.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_RR.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Lines.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_OrderBuilder.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_OrderExecutor.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_PositionManager.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_PartialClose.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Breakeven.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_LimitTrail.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_OCO.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_VirtualOrders.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_TimeManager.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Notifications.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Hotkeys.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_Screenshot.mqh
// MQL5\Experts\MuseraTradeAssistant\include\TA_SRBreakAlert.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_App.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_Theme.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_Tabs.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_TradeTab.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_CloseTab.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_TrailingTab.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_BE_Tab.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_SettingsTab.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_InfoTab.mqh
// MQL5\Experts\MuseraTradeAssistant\include\UI\UI_Bindings.mqh
// MQL5\Experts\MuseraTradeAssistant\include\trailing\Trail_Base.mqh
// MQL5\Experts\MuseraTradeAssistant\include\trailing\Trail_Pips.mqh
// MQL5\Experts\MuseraTradeAssistant\include\trailing\Trail_Fractals.mqh
// MQL5\Experts\MuseraTradeAssistant\include\trailing\Trail_MA.mqh
// MQL5\Experts\MuseraTradeAssistant\include\trailing\Trail_SAR.mqh
// MQL5\Experts\MuseraTradeAssistant\include\trailing\Trail_ATR.mqh
// MQL5\Experts\MuseraTradeAssistant\include\trailing\Trail_PartialClose.mqh
// MQL5\Experts\MuseraTradeAssistant\include\trailing\Trail_HighLowBar.mqh
//
// Optional resources (if you reference them in UI):
// MQL5\Experts\MuseraTradeAssistant\resources\images\icon_buy.png
// MQL5\Experts\MuseraTradeAssistant\resources\images\icon_sell.png
// MQL5\Experts\MuseraTradeAssistant\resources\images\icon_close.png
// MQL5\Experts\MuseraTradeAssistant\resources\images\icon_settings.png
// MQL5\Experts\MuseraTradeAssistant\resources\sounds\notify.wav
// MQL5\Experts\MuseraTradeAssistant\resources\sounds\error.wav
// -------------------------------------------------------------------------

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/AccountInfo.mqh>

// ---- Project core ----
#include "include/TA_Constants.mqh"
#include "include/TA_Enums.mqh"
#include "include/TA_Types.mqh"
#include "include/TA_Utils.mqh"
#include "include/TA_Validation.mqh"
#include "include/TA_BrokerRules.mqh"
#include "include/TA_State.mqh"
#include "include/TA_Persistence.mqh"
#include "include/TA_Risk.mqh"
#include "include/TA_RR.mqh"
#include "include/TA_Lines.mqh"
#include "include/TA_OrderBuilder.mqh"
#include "include/TA_OrderExecutor.mqh"
#include "include/TA_PositionManager.mqh"
#include "include/TA_PartialClose.mqh"
#include "include/TA_Breakeven.mqh"
#include "include/TA_LimitTrail.mqh"
#include "include/TA_OCO.mqh"
#include "include/TA_VirtualOrders.mqh"
#include "include/TA_TimeManager.mqh"
#include "include/TA_Notifications.mqh"
#include "include/TA_Hotkeys.mqh"
#include "include/TA_Screenshot.mqh"
#include "include/TA_SRBreakAlert.mqh"

// ---- UI ----
#include "include/UI/UI_App.mqh"
#include "include/UI/UI_Theme.mqh"
#include "include/UI/UI_Tabs.mqh"
#include "include/UI/UI_TradeTab.mqh"
#include "include/UI/UI_CloseTab.mqh"
#include "include/UI/UI_TrailingTab.mqh"
#include "include/UI/UI_BE_Tab.mqh"
#include "include/UI/UI_SettingsTab.mqh"
#include "include/UI/UI_InfoTab.mqh"
#include "include/UI/UI_Bindings.mqh"

// ---- Trailing modes ----
#include "include/trailing/Trail_Base.mqh"
#include "include/trailing/Trail_Pips.mqh"
#include "include/trailing/Trail_Fractals.mqh"
#include "include/trailing/Trail_MA.mqh"
#include "include/trailing/Trail_SAR.mqh"
#include "include/trailing/Trail_ATR.mqh"
#include "include/trailing/Trail_PartialClose.mqh"
#include "include/trailing/Trail_HighLowBar.mqh"

// ------------------------------ Inputs ------------------------------
input ulong   InpMagic              = 260114;   // Magic number for orders
input int     InpTimerSeconds       = 1;        // Timer tick (UI + managers)
input bool    InpForceObjectsOnTop  = true;     // Ensure UI objects are in front of candles
input string  InpPresetsFile        = "MuseraTradeAssistant_presets.json"; // persistence backend decides location
input string  InpAutoLoadPreset     = "";       // preset name to auto-load at start (empty=none)
input bool    InpAutoSaveLastPreset = true;     // persistence backend may store last used preset name

input int     InpUI_X               = 10;
input int     InpUI_Y               = 20;
input int     InpUI_W               = 330;
input int     InpUI_H               = 360;

// ------------------------------ Globals ------------------------------
CTrade        g_trade;
CSymbolInfo   g_sym;
CPositionInfo g_pos;
CAccountInfo  g_acc;

// Core context/state (expected in includes)
TA_Context           g_ctx;        // chart/symbol/magic/etc
TA_State             g_state;      // all user-configurable settings + runtime flags
TA_BrokerRules       g_broker;     // broker constraints/steps (min lot, stops level, freeze level...)
TA_Persistence       g_persist;    // presets + last preset
TA_OrderBuilder      g_builder;    // builds requests (risk, SL/TP, comment, etc)
TA_OrderExecutor     g_exec;       // sends/modifies requests
TA_PositionManager   g_pm;         // manages open positions + close tab ops
TA_PartialClose      g_partial;    // TP partials engine (TP1/TP2/TP3)
TA_Breakeven         g_be;         // break-even engine
TA_LimitTrail        g_trail;      // trailing wrapper (dropdown chooses strategy)
TA_OCO               g_oco;        // OCO logic (pending/virtual)
TA_VirtualOrders     g_vorders;    // virtual pending & virtual SL/TP if enabled
TA_TimeManager       g_time;       // trade time scheduler
TA_Notifications     g_notify;     // push/sounds/alerts/logs
TA_Hotkeys           g_hotkeys;    // keyboard shortcuts
TA_Screenshot        g_shot;       // screenshot helper
TA_SRBreakAlert      g_sr;         // S/R break alerts

UI_App               g_ui;         // main UI app
UI_Bindings          g_bind;       // UI <-> core bindings

bool g_ready = false;

// ------------------------------ Internal helpers ------------------------------
void ApplyChartForeground()
{
   if(!InpForceObjectsOnTop) return;

   // When CHART_FOREGROUND=false, the chart (candles) is drawn behind graphical objects.
   // This helps UI panels stay visible above candles.
   ChartSetInteger(0, CHART_FOREGROUND, false);
   ChartRedraw();
}

// ------------------------------ UI -> Core callbacks ------------------------------
// UI_Bindings is expected to call these functions (or equivalent) when user interacts with controls.
// Define a clear contract early; implementation details live in includes.

void TA_OnUI_PlaceMarket(const bool is_buy)
{
   // Build an order plan from current state (risk, SL/TP, partials, etc),
   // then execute and register managers (partials, BE, trailing...).
   TA_OrderPlan plan;
   if(!g_builder.BuildMarketPlan(g_ctx, g_state, is_buy, plan))
   {
      g_notify.Error("Cannot build order plan (validation failed).");
      return;
   }

   TA_ExecResult er;
   if(!g_exec.SendMarket(plan, er))
   {
      g_notify.Error("OrderSend failed: " + er.message);
      return;
   }

   // Register post-entry managers.
   // 1) Partial TP (TP1/TP2/TP3) - if enabled in state
   if(g_state.tp_partials_enabled)
      g_partial.RegisterPosition(er.position_ticket, g_ctx, g_state);

   // 2) Break-even - if enabled in state
   if(g_state.be_enabled)
      g_be.RegisterPosition(er.position_ticket, g_ctx, g_state);

   // 3) Trailing - if enabled and mode != NONE
   if(g_state.trailing_enabled)
      g_trail.RegisterPosition(er.position_ticket, g_ctx, g_state);

   g_notify.Info("Order placed. Ticket=" + IntegerToString((int)er.order_ticket));
}

void TA_OnUI_SetTrailingMode(const ENUM_TA_TRAIL_MODE mode)
{
   g_state.trailing_mode = mode;
   g_trail.SetMode(mode, g_ctx, g_state);
   g_notify.Info("Trailing mode set.");
}

void TA_OnUI_ToggleBreakEven(const bool enabled)
{
   g_state.be_enabled = enabled;
   g_be.SyncConfig(g_ctx, g_state);
}

void TA_OnUI_TogglePartials(const bool enabled)
{
   g_state.tp_partials_enabled = enabled;
   g_partial.SyncConfig(g_ctx, g_state);
}

void TA_OnUI_SavePreset(const string preset_name)
{
   string name = preset_name;
   StringTrimLeft(name);
   StringTrimRight(name);
   if(name=="")
   {
      g_notify.Error("Preset name is empty.");
      return;
   }

   if(!g_persist.SavePreset(name, g_state))
   {
      g_notify.Error("Failed to save preset.");
      return;
   }

   if(InpAutoSaveLastPreset)
      g_persist.SetLastPreset(name);

   g_notify.Info("Preset saved: " + name);
}

void TA_OnUI_LoadPreset(const string preset_name)
{
   string name = preset_name;
   StringTrimLeft(name);
   StringTrimRight(name);
   if(name=="")
   {
      g_notify.Error("Preset name is empty.");
      return;
   }

   TA_State loaded;
   if(!g_persist.LoadPreset(name, loaded))
   {
      g_notify.Error("Preset not found: " + name);
      return;
   }

   g_state = loaded; // assumes TA_State supports assignment
   g_be.SyncConfig(g_ctx, g_state);
   g_partial.SyncConfig(g_ctx, g_state);
   g_trail.SyncConfig(g_ctx, g_state);
   g_vorders.SyncConfig(g_ctx, g_state);
   g_oco.SyncConfig(g_ctx, g_state);
   g_pm.SyncConfig(g_ctx, g_state);

   if(InpAutoSaveLastPreset)
      g_persist.SetLastPreset(name);

   g_ui.SyncFromState(g_ctx, g_state);
   g_notify.Info("Preset loaded: " + name);
}

void TA_OnUI_CloseCommand(const ENUM_TA_CLOSE_CMD cmd)
{
   // Close tab actions (close buy/sell, close all, delete pendings, etc).
   g_pm.ExecuteCloseCommand(g_ctx, g_state, cmd);
}

// ------------------------------ MT5 event handlers ------------------------------
int OnInit()
{
   g_ready = false;

   g_sym.Name(_Symbol);

   // Context: filled by TA_Utils in your includes (recommended).
   g_ctx.chart_id = ChartID();
   g_ctx.symbol   = _Symbol;
   g_ctx.magic    = InpMagic;

   ApplyChartForeground();

   // Enable richer UI events (mouse move, object drag, etc) if your UI uses them.
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);

   // Init broker rules + state + persistence.
   if(!g_broker.Init(g_ctx))
   {
      Print("Broker rules init failed");
      return INIT_FAILED;
   }

   g_persist.Init(g_ctx, InpPresetsFile);

   g_state.InitDefaults(g_ctx);

   // Auto-load preset (explicit) or last preset (optional) via persistence backend.
   if(InpAutoLoadPreset != "")
   {
      TA_OnUI_LoadPreset(InpAutoLoadPreset);
   }
   else if(InpAutoSaveLastPreset)
   {
      string last = g_persist.GetLastPreset();
      if(last != "")
         TA_OnUI_LoadPreset(last);
   }

   // Init managers (they should read current g_state).
   g_pm.Init(g_ctx, g_state, g_broker);
   g_partial.Init(g_ctx, g_state, g_broker);
   g_be.Init(g_ctx, g_state, g_broker);
   g_trail.Init(g_ctx, g_state, g_broker);
   g_vorders.Init(g_ctx, g_state, g_broker);
   g_oco.Init(g_ctx, g_state, g_broker);
   g_time.Init(g_ctx, g_state);
   g_hotkeys.Init(g_ctx, g_state);
   g_notify.Init(g_ctx, g_state);
   g_shot.Init(g_ctx, g_state);
   g_sr.Init(g_ctx, g_state);

   // UI + bindings
   if(!g_ui.Create(g_ctx, InpUI_X, InpUI_Y, InpUI_W, InpUI_H))
   {
      Print("UI create failed");
      return INIT_FAILED;
   }

   // Bind UI to core callbacks (your UI_Bindings implementation decides how).
   g_bind.Attach(g_ctx, g_ui, g_state);
   g_bind.BindCallbacks(
      TA_OnUI_PlaceMarket,
      TA_OnUI_SetTrailingMode,
      TA_OnUI_ToggleBreakEven,
      TA_OnUI_TogglePartials,
      TA_OnUI_SavePreset,
      TA_OnUI_LoadPreset,
      TA_OnUI_CloseCommand
   );

   EventSetTimer(MathMax(1, InpTimerSeconds));
   g_ready = true;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   if(!g_ready)
      return;

   // Save last preset or current state snapshot if your persistence supports it.
   if(InpAutoSaveLastPreset)
      g_persist.Flush();

   g_ui.Destroy();
   g_ready = false;
}

void OnTimer()
{
   if(!g_ready) return;

   // Time-based processing (tickless UI responsiveness).
   g_time.OnTimer(g_ctx, g_state);

   // Managers run in deterministic order:
   // - virtual orders and OCO can create/modify/close positions
   // - partials & BE & trailing adjust SL/TP/partial closes
   // - position manager updates aggregates used by Close tab
   g_vorders.OnTimer(g_ctx, g_state);
   g_oco.OnTimer(g_ctx, g_state);

   g_partial.OnTimer(g_ctx, g_state);  // TP1/TP2/TP3
   g_be.OnTimer(g_ctx, g_state);       // break-even logic
   g_trail.OnTimer(g_ctx, g_state);    // selected trailing mode from dropdown
   g_pm.OnTimer(g_ctx, g_state);

   g_sr.OnTimer(g_ctx, g_state);
   g_hotkeys.OnTimer(g_ctx, g_state);

   // Keep UI synced with latest metrics (spread, risk calc preview, open P/L, etc).
   g_ui.OnTimer(g_ctx, g_state);
   ChartRedraw();
}

void OnTick()
{
   // Keep very light (no UI/ticks coupling). Heavy work stays in OnTimer.
   // You may still use tick as a hint for faster trailing/BE reaction if desired:
   // g_trail.OnTick(g_ctx, g_state);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(!g_ready) return;

   g_pm.OnTradeTransaction(g_ctx, g_state, trans, request, result);
   g_partial.OnTradeTransaction(g_ctx, g_state, trans, request, result);
   g_be.OnTradeTransaction(g_ctx, g_state, trans, request, result);
   g_trail.OnTradeTransaction(g_ctx, g_state, trans, request, result);
   g_vorders.OnTradeTransaction(g_ctx, g_state, trans, request, result);
   g_oco.OnTradeTransaction(g_ctx, g_state, trans, request, result);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(!g_ready) return;

   // UI first (buttons, dropdowns, edit boxes).
   g_ui.OnChartEvent(g_ctx, g_state, id, lparam, dparam, sparam);

   // Then lines (SL/TP drag), hotkeys, etc.
   g_hotkeys.OnChartEvent(g_ctx, g_state, id, lparam, dparam, sparam);
   g_trail.OnChartEvent(g_ctx, g_state, id, lparam, dparam, sparam);
   g_be.OnChartEvent(g_ctx, g_state, id, lparam, dparam, sparam);
   g_partial.OnChartEvent(g_ctx, g_state, id, lparam, dparam, sparam);

   // If UI altered state (e.g., user changed trailing mode), bindings should sync here:
   g_bind.SyncCoreToUI(g_ctx, g_ui, g_state);
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                   UI_Bindings.mqh |
//|                        MuseraTradeAssistant (UI module)           |
//|                                  (c) 2026, Musera Isaac           |
//|                                                                  |
//|  Purpose:                                                         |
//|   Bridges UI controls/events to the core trade assistant logic.    |
//|   This module stores callback references (EA-level functions)      |
//|   and exposes small wrapper methods that UI tabs can call.         |
//|                                                                  |
//|  NOTE: In this project shell, most tabs directly mutate TA_State   |
//|  (passed by reference) and may call EA callbacks directly.         |
//|  UI_Bindings still provides a clean contract so you can refactor   |
//|  tabs later to only depend on this bridge.                         |
//|                                                                  |
//|  Location:                                                        |
//|   MQL5\Experts\MuseraTradeAssistant\include\UI\UI_Bindings.mqh      |
//+------------------------------------------------------------------+
#ifndef __UI_BINDINGS_MQH__
#define __UI_BINDINGS_MQH__

// Core types
#include "../TA_Types.mqh"
#include "../TA_State.mqh"
#include "../TA_Enums.mqh"

// UI root
#include "UI_App.mqh"

//+------------------------------------------------------------------+
//| Callback types                                                    |
//+------------------------------------------------------------------+
// MQL5 supports function pointers; these allow the EA (main .mq5) to
// register its handlers without the UI needing to include the EA file.
typedef void (*TA_CB_PlaceMarket)(const bool is_buy);
typedef void (*TA_CB_SetTrailingMode)(const ENUM_TA_TRAIL_MODE mode);
typedef void (*TA_CB_Toggle)(const bool enabled);
typedef void (*TA_CB_Preset)(const string preset_name);
typedef void (*TA_CB_CloseCmd)(const ENUM_TA_CLOSE_CMD cmd);

//+------------------------------------------------------------------+
//| UI_Bindings                                                       |
//+------------------------------------------------------------------+
class UI_Bindings
{
private:
   // Pointers to the "current" instances (optional – useful for future refactors)
   UI_App   *m_ui;

   // Registered callbacks (EA-level)
   TA_CB_PlaceMarket      m_cb_place_market;
   TA_CB_SetTrailingMode  m_cb_set_trailing_mode;
   TA_CB_Toggle           m_cb_toggle_be;
   TA_CB_Toggle           m_cb_toggle_partials;
   TA_CB_Preset           m_cb_save_preset;
   TA_CB_Preset           m_cb_load_preset;
   TA_CB_CloseCmd         m_cb_close_cmd;

   bool m_attached;

public:
   UI_Bindings()
   {
      m_ui = NULL;

      m_cb_place_market     = NULL;
      m_cb_set_trailing_mode= NULL;
      m_cb_toggle_be        = NULL;
      m_cb_toggle_partials  = NULL;
      m_cb_save_preset      = NULL;
      m_cb_load_preset      = NULL;
      m_cb_close_cmd        = NULL;

      m_attached = false;
   }

   // Attach is optional; it simply keeps pointers for convenience.
   void Attach(const TA_Context &ctx, UI_App &ui, TA_State &state)
   {
      m_ui = &ui;
      m_attached = true;
   }

   bool IsAttached() const { return m_attached; }

   // Register EA callbacks
   void BindCallbacks(TA_CB_PlaceMarket cb_place_market,
                      TA_CB_SetTrailingMode cb_set_trailing_mode,
                      TA_CB_Toggle cb_toggle_be,
                      TA_CB_Toggle cb_toggle_partials,
                      TA_CB_Preset cb_save_preset,
                      TA_CB_Preset cb_load_preset,
                      TA_CB_CloseCmd cb_close_cmd)
   {
      m_cb_place_market      = cb_place_market;
      m_cb_set_trailing_mode = cb_set_trailing_mode;
      m_cb_toggle_be         = cb_toggle_be;
      m_cb_toggle_partials   = cb_toggle_partials;
      m_cb_save_preset       = cb_save_preset;
      m_cb_load_preset       = cb_load_preset;
      m_cb_close_cmd         = cb_close_cmd;
   }

   // ------------------ Wrapper calls (UI -> EA) ------------------
   void PlaceMarket(const bool is_buy)
   {
      if(m_cb_place_market != NULL)
         m_cb_place_market(is_buy);
   }

   void SetTrailingMode(const ENUM_TA_TRAIL_MODE mode)
   {
      if(m_cb_set_trailing_mode != NULL)
         m_cb_set_trailing_mode(mode);
   }

   void ToggleBreakEven(const bool enabled)
   {
      if(m_cb_toggle_be != NULL)
         m_cb_toggle_be(enabled);
   }

   void TogglePartials(const bool enabled)
   {
      if(m_cb_toggle_partials != NULL)
         m_cb_toggle_partials(enabled);
   }

   void SavePreset(const string preset_name)
   {
      if(m_cb_save_preset != NULL)
         m_cb_save_preset(preset_name);
   }

   void LoadPreset(const string preset_name)
   {
      if(m_cb_load_preset != NULL)
         m_cb_load_preset(preset_name);
   }

   void CloseCommand(const ENUM_TA_CLOSE_CMD cmd)
   {
      if(m_cb_close_cmd != NULL)
         m_cb_close_cmd(cmd);
   }

   // ------------------ Sync helpers ------------------
   // Called after UI processing to allow the bridge to reconcile any
   // "deferred" actions (if you adopt that pattern later).
   //
   // In this shell implementation, tabs mutate TA_State directly, so
   // this method is intentionally conservative (no-op).
   void SyncCoreToUI(const TA_Context &ctx, UI_App &ui, TA_State &state)
   {

      // No-op by default.
      // If you later change tabs to store UI control values internally
      // (instead of writing directly to TA_State), this is the place to:
      //  - pull values from UI controls into TA_State
      //  - clamp/validate (using TA_Validation)
      //  - push computed/normalized values back into UI via ui.SyncFromState()
   }

   // Convenience: safe UI refresh from core state (used by EA after preset load).
   void RefreshUIFromState(const TA_Context &ctx)
   {
      // Deprecated overload retained for compatibility; use RefreshUIFromState(ctx, state).
   }

   void RefreshUIFromState(const TA_Context &ctx, TA_State &state)
   {
      if(m_ui == NULL) return;
      m_ui.SyncFromState(ctx, state);
   }
};

#endif // __UI_BINDINGS_MQH__
//+------------------------------------------------------------------+

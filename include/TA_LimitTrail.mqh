//+------------------------------------------------------------------+
//|                                              TA_LimitTrail.mqh    |
//|                                  (c) 2026, Musera Isaac           |
//|  Trailing controller: selects an active trailing strategy (Pips,   |
//|  Fractals, MA, SAR, ATR, PartialClose, HighLowBar) and delegates. |
//+------------------------------------------------------------------+
#property strict

// NOTE:
// This module is designed to be included AFTER TA_State.mqh / TA_Types.mqh,
// because the trailing strategy headers read TA_State fields.
// Typical include order in the EA:
//   TA_Types.mqh -> TA_State.mqh -> TA_LimitTrail.mqh -> trailing/*

// Core types (expected to be present in project include order)
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_State.mqh"
#include "TA_BrokerRules.mqh"

// Trailing strategies
#include "trailing/Trail_Base.mqh"
#include "trailing/Trail_Pips.mqh"
#include "trailing/Trail_Fractals.mqh"
#include "trailing/Trail_MA.mqh"
#include "trailing/Trail_SAR.mqh"
#include "trailing/Trail_ATR.mqh"
#include "trailing/Trail_PartialClose.mqh"
#include "trailing/Trail_HighLowBar.mqh"

//+------------------------------------------------------------------+
//| TA_LimitTrail                                                     |
//| - Keeps a pointer to the active strategy based on ENUM_TA_TRAIL_MODE |
//| - Lazily initializes each strategy when first used                 |
//| - Re-registers existing positions when switching modes (best-effort) |
//+------------------------------------------------------------------+
class TA_LimitTrail
{
private:
   ENUM_TA_TRAIL_MODE m_mode;
   uint               m_last_run_ms;

   // Concrete strategies (owned)
   Trail_Pips         m_pips;
   Trail_Fractals     m_fractals;
   Trail_MA           m_ma;
   Trail_SAR          m_sar;
   Trail_ATR          m_atr;
   Trail_PartialClose m_partial;
   Trail_HighLowBar   m_hlbar;

   // Active (non-owning)
   Trail_Base        *m_active;

   // Lazy init flags
   bool m_inited_pips;
   bool m_inited_fractals;
   bool m_inited_ma;
   bool m_inited_sar;
   bool m_inited_atr;
   bool m_inited_partial;
   bool m_inited_hlbar;

private:
   // Return the strategy instance pointer for the requested mode
   Trail_Base* StrategyForMode(const ENUM_TA_TRAIL_MODE mode)
   {
      switch(mode)
      {
         case TA_TRAIL_PIPS:          return &m_pips;
         case TA_TRAIL_FRACTALS:      return &m_fractals;
         case TA_TRAIL_MA:            return &m_ma;
         case TA_TRAIL_SAR:           return &m_sar;
         case TA_TRAIL_ATR:           return &m_atr;
         case TA_TRAIL_PARTIAL_CLOSE: return &m_partial;
         case TA_TRAIL_HIGHLOW_BAR:   return &m_hlbar;
         default:                     return NULL;
      }
   }

   bool IsInited(const ENUM_TA_TRAIL_MODE mode) const
   {
      switch(mode)
      {
         case TA_TRAIL_PIPS:          return m_inited_pips;
         case TA_TRAIL_FRACTALS:      return m_inited_fractals;
         case TA_TRAIL_MA:            return m_inited_ma;
         case TA_TRAIL_SAR:           return m_inited_sar;
         case TA_TRAIL_ATR:           return m_inited_atr;
         case TA_TRAIL_PARTIAL_CLOSE: return m_inited_partial;
         case TA_TRAIL_HIGHLOW_BAR:   return m_inited_hlbar;
         default:                     return true;
      }
   }

   void MarkInited(const ENUM_TA_TRAIL_MODE mode, const bool v)
   {
      switch(mode)
      {
         case TA_TRAIL_PIPS:          m_inited_pips     = v; break;
         case TA_TRAIL_FRACTALS:      m_inited_fractals = v; break;
         case TA_TRAIL_MA:            m_inited_ma       = v; break;
         case TA_TRAIL_SAR:           m_inited_sar      = v; break;
         case TA_TRAIL_ATR:           m_inited_atr      = v; break;
         case TA_TRAIL_PARTIAL_CLOSE: m_inited_partial  = v; break;
         case TA_TRAIL_HIGHLOW_BAR:   m_inited_hlbar    = v; break;
         default: break;
      }
   }

   // Best-effort: register all currently open positions matching the trailing scope
   void RegisterExistingPositions(const TA_Context &ctx, const TA_State &st)
   {
      if(m_active == NULL) return;

      // Current design uses only one scope constant in TA_State (THIS_SYMBOL_MAGIC).
      // If you extend scopes later, adjust this filter accordingly.
      const string want_symbol = ctx.symbol;
      const long   want_magic  = (long)ctx.magic;

      const int total = PositionsTotal();
      for(int i=total-1; i>=0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;

         string sym = (string)PositionGetString(POSITION_SYMBOL);
         long   mg  = (long)PositionGetInteger(POSITION_MAGIC);

         if(st.trailing_scope == TA_TRAIL_SCOPE_THIS_SYMBOL_MAGIC)
         {
            if(sym != want_symbol) continue;
            if(mg  != want_magic)  continue;
         }

         m_active->RegisterPosition(ticket, ctx, st);
      }
   }

   // Lazy init (only when switching/using a strategy)
   bool EnsureInit(const ENUM_TA_TRAIL_MODE mode,
                   const TA_Context &ctx,
                   const TA_State &st,
                   const TA_BrokerRules &br)
   {
      if(mode == TA_TRAIL_NONE) return true;
      if(IsInited(mode)) return true;

      Trail_Base *s = StrategyForMode(mode);
      if(s == NULL) return false;

      // Some strategies allocate indicator handles; Init should do that.
      bool ok = s.Init(ctx, st, br);
      MarkInited(mode, ok);
      return ok;
   }

   bool ShouldRun(const TA_State &st)
   {
      const int min_ms = (int)st.trailing_min_interval_ms;
      if(min_ms <= 0) return true;

      uint now = (uint)GetTickCount();
      if(m_last_run_ms == 0) { m_last_run_ms = now; return true; }

      // Wrap-safe difference (unsigned)
      uint diff = (uint)(now - m_last_run_ms);
      if((int)diff < min_ms) return false;

      m_last_run_ms = now;
      return true;
   }

public:
   TA_LimitTrail()
   {
      m_mode = TA_TRAIL_NONE;
      m_last_run_ms = 0;
      m_active = NULL;

      m_inited_pips = false;
      m_inited_fractals = false;
      m_inited_ma = false;
      m_inited_sar = false;
      m_inited_atr = false;
      m_inited_partial = false;
      m_inited_hlbar = false;
   }

   // Init called once from EA
   bool Init(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &br)
   {
      m_last_run_ms = 0;

      // Select initial mode from state (or NONE if disabled)
      ENUM_TA_TRAIL_MODE m = st.trailing_enabled ? st.trailing_mode : TA_TRAIL_NONE;
      return SetMode(m, ctx, st, br);
   }

   // SyncConfig called when state changes (sliders, inputs, presets, etc)
   void SyncConfig(const TA_Context &ctx, const TA_State &st)
   {
      // If user disabled trailing, keep active pointer but do nothing on timer.
      // If user changed mode in state, adopt it.
      if(st.trailing_enabled)
      {
         if(st.trailing_mode != m_mode)
         {
            // In this context we don't have broker rules; caller should call SetMode(...)
            // when changing modes. We still update m_mode and m_active best-effort.
            m_mode = st.trailing_mode;
            m_active = StrategyForMode(m_mode);
         }
      }
      else
      {
         m_mode = TA_TRAIL_NONE;
         m_active = NULL;
      }

      // Propagate config to inited strategies only (avoid touching unused ones)
      if(m_inited_pips)     m_pips.SyncConfig(ctx, st);
      if(m_inited_fractals) m_fractals.SyncConfig(ctx, st);
      if(m_inited_ma)       m_ma.SyncConfig(ctx, st);
      if(m_inited_sar)      m_sar.SyncConfig(ctx, st);
      if(m_inited_atr)      m_atr.SyncConfig(ctx, st);
      if(m_inited_partial)  m_partial.SyncConfig(ctx, st);
      if(m_inited_hlbar)    m_hlbar.SyncConfig(ctx, st);
   }

   // Mode setter used by UI dropdown
   bool SetMode(const ENUM_TA_TRAIL_MODE mode,
                const TA_Context &ctx,
                const TA_State &st,
                const TA_BrokerRules &br)
   {
      // Reset previous strategy (optional, keeps its internal map clean)
      if(m_active != NULL)
         m_active->Reset();

      m_mode = mode;

      if(!st.trailing_enabled || mode == TA_TRAIL_NONE)
      {
         m_active = NULL;
         return true;
      }

      m_active = StrategyForMode(mode);
      if(m_active == NULL)
      {
         m_mode = TA_TRAIL_NONE;
         return false;
      }

      if(!EnsureInit(mode, ctx, st, br))
      {
         m_active = NULL;
         m_mode = TA_TRAIL_NONE;
         return false;
      }

      // Apply latest parameters
      m_active->SyncConfig(ctx, st);

      // Best-effort: allow strategy to handle already-open positions after mode switch
      RegisterExistingPositions(ctx, st);

      return true;
   }

   // Called on new entry
   void RegisterPosition(const ulong position_ticket, const TA_Context &ctx, const TA_State &st)
   {
      if(!st.trailing_enabled) return;
      if(m_active == NULL) return;
      m_active->RegisterPosition(position_ticket, ctx, st);
   }

   void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      if(!st.trailing_enabled) return;
      if(m_active == NULL) return;
      if(!ShouldRun(st)) return;

      m_active->OnTimer(ctx, st);
   }

   void OnChartEvent(const TA_Context &ctx, const TA_State &st,
                     const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(m_active == NULL) return;
      m_active->OnChartEvent(ctx, st, id, lparam, dparam, sparam);
   }

   void OnTradeTransaction(const TA_Context &ctx, const TA_State &st,
                           const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {
      if(m_active == NULL) return;
      m_active->OnTradeTransaction(ctx, st, trans, request, result);
   }

   ENUM_TA_TRAIL_MODE Mode() const { return m_mode; }
};
//+------------------------------------------------------------------+

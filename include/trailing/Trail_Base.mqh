//+------------------------------------------------------------------+
//|                                         trailing/Trail_Base.mqh   |
//|                                  (c) 2026, Musera Isaac           |
//|  Base interface + helpers for trailing strategies used by          |
//|  MuseraTradeAssistant.                                             |
//|                                                                    |
//|  This file is designed to be lightweight and only defines a base   |
//|  contract. Concrete trailing modes implement their own logic in:   |
//|    Trail_Pips.mqh, Trail_ATR.mqh, Trail_MA.mqh, etc.               |
//|                                                                    |
//|  Expected usage (from TA_LimitTrail wrapper):                       |
//|    - Create one instance per strategy                              |
//|    - Call Init() once (or when symbol changes)                     |
//|    - Call SyncConfig() when presets/settings change                |
//|    - Call RegisterPosition() after a new entry                     |
//|    - Call OnTimer()/OnTick() to manage trailing                    |
//+------------------------------------------------------------------+
#property strict

#ifndef __MUSERA_TA_TRAIL_BASE_MQH__
#define __MUSERA_TA_TRAIL_BASE_MQH__

// Forward declarations (defined in other project includes)
struct TA_Context;
struct TA_State;
class TA_BrokerRules;

//+------------------------------------------------------------------+
//| Trail_Base: abstract trailing strategy                             |
//+------------------------------------------------------------------+
class Trail_Base
{
protected:
   string m_name;

public:
   Trail_Base(const string name="Base") : m_name(name) {}
   virtual ~Trail_Base() {}

   // Human-readable mode name (for UI dropdown, logs, etc.)
   virtual string Name() const { return m_name; }

   // Called once after EA init, or when strategy is constructed/selected.
   // Return false to indicate the strategy cannot run (missing indicator handles, etc.).
   virtual bool Init(const TA_Context &ctx, const TA_State &st, const TA_BrokerRules &br) { return true; }
   // Optional cleanup (release indicator handles, etc.)
   virtual void Deinit() {}

   // Optional: clear internal tracked positions (if strategy maintains a list).
   virtual void ClearAll() {}


   // Called when the strategy becomes the active mode (or when switching symbols/timeframes).
   virtual void Reset() {}

   // Called when user changes settings/preset affecting trailing.
   virtual void SyncConfig(const TA_Context &ctx, const TA_State &st) {}

   // Register a position for trailing management.
   virtual void RegisterPosition(const ulong position_ticket, const TA_Context &ctx, const TA_State &st) {}

   // Unregister a position (closed, manual takeover, etc.).
   virtual void UnregisterPosition(const ulong position_ticket) {}

   // Tickless periodic work (recommended for UI-like tools).
   virtual void OnTimer(const TA_Context &ctx, const TA_State &st) {}

   // Optional fast-path updates (use sparingly).
   virtual void OnTick(const TA_Context &ctx, const TA_State &st) {}

   // Optional event handlers.
   virtual void OnChartEvent(const TA_Context &ctx, const TA_State &st,
                             const int id, const long &lparam, const double &dparam, const string &sparam) {}

   virtual void OnTradeTransaction(const TA_Context &ctx, const TA_State &st,
                                   const MqlTradeTransaction &trans,
                                   const MqlTradeRequest &request,
                                   const MqlTradeResult &result) {}

protected:
   // --------------------------- Small helpers ---------------------------

   // Select a position by ticket and return success.
   bool PosSelect(const ulong ticket) const
   {
      return PositionSelectByTicket(ticket);
   }

   // Helpers on the currently selected position (call after PosSelect()).
   string PosSymbol() const { return (string)PositionGetString(POSITION_SYMBOL); }
   long   PosType()   const { return (long)PositionGetInteger(POSITION_TYPE); } // POSITION_TYPE_BUY/SELL
   double PosOpen()   const { return (double)PositionGetDouble(POSITION_PRICE_OPEN); }
   double PosSL()     const { return (double)PositionGetDouble(POSITION_SL); }
   double PosTP()     const { return (double)PositionGetDouble(POSITION_TP); }
   double PosVol()    const { return (double)PositionGetDouble(POSITION_VOLUME); }

   // Normalize a price to the symbol's digits.
   double NormPrice(const string sym, const double price) const
   {
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      return NormalizeDouble(price, digits);
   }

   // Symbol point size.
   double Point(const string sym) const
   {
      return SymbolInfoDouble(sym, SYMBOL_POINT);
   }

   // Minimum distance checks are broker-dependent; wrapper may provide TA_BrokerRules.
   // This helper only performs minimal normalization & send.

   // Modify position SL/TP (keep the value not being modified).
   // - ticket must be a POSITION ticket (not order ticket).
   // - new_sl/new_tp can be 0.0 to remove SL/TP.
   // Returns true if request succeeded.
   bool ModifySLTP(const ulong ticket, const ulong magic, const double new_sl, const double new_tp, string &err) const
   {
      err = "";
      if(!PosSelect(ticket))
      {
         err = "Position not found";
         return false;
      }

      const string sym = PosSymbol();
      const double sl  = (new_sl <= 0.0 ? 0.0 : NormPrice(sym, new_sl));
      const double tp  = (new_tp <= 0.0 ? 0.0 : NormPrice(sym, new_tp));

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      req.action   = TRADE_ACTION_SLTP;
      req.symbol   = sym;
      req.position = ticket;
      req.sl       = sl;
      req.tp       = tp;
      req.magic    = magic;

      if(!OrderSend(req, res))
      {
         err = "OrderSend failed (TRADE_ACTION_SLTP)";
         return false;
      }

      // Accept DONE and DONE_PARTIAL as success; other retcodes are treated as error.
      if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL)
      {
         err = StringFormat("ModifySLTP failed retcode=%u (%s)",
                            (uint)res.retcode, res.comment);
         return false;
      }

      return true;
   }

   // Convenience: modify only SL, keep current TP.
   bool ModifySL(const ulong ticket, const ulong magic, const double new_sl, string &err) const
   {
      err="";
      if(!PosSelect(ticket))
      {
         err="Position not found";
         return false;
      }
      const double cur_tp = PosTP();
      return ModifySLTP(ticket, magic, new_sl, cur_tp, err);
   }

   // Convenience: modify only TP, keep current SL.
   bool ModifyTP(const ulong ticket, const ulong magic, const double new_tp, string &err) const
   {
      err="";
      if(!PosSelect(ticket))
      {
         err="Position not found";
         return false;
      }
      const double cur_sl = PosSL();
      return ModifySLTP(ticket, magic, cur_sl, new_tp, err);
   }

   // Small epsilon comparison in points.
   bool NearlyEqualPrice(const string sym, const double a, const double b, const double eps_points=0.2) const
   {
      const double eps = Point(sym) * eps_points;
      return (MathAbs(a - b) <= eps);
   }
};

#endif // __MUSERA_TA_TRAIL_BASE_MQH__
//+------------------------------------------------------------------+
//|                                             TA_PositionManager.mqh |
//|                        (c) 2026, Musera Isaac                      |
//|  Position & Close-Tab manager for MuseraTradeAssistant (MT5 EA).     |
//|                                                                     |
//|  Responsibilities:                                                   |
//|   - Track/open position aggregates (count, P/L, volume)              |
//|   - Execute "Close" tab commands (close buys/sells/all, delete       |
//|     pendings, close profit/loss groups, etc)                         |
//|   - Provide light OnTradeTransaction hooks to keep stats fresh       |
//|                                                                     |
//|  Notes:                                                             |
//|   - Filters positions/orders by ctx.symbol + ctx.magic               |
//|   - Works on both Netting and Hedging accounts (closes by ticket).   |
//+------------------------------------------------------------------+
#ifndef __TA_POSITIONMANAGER_MQH__
#define __TA_POSITIONMANAGER_MQH__

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"

// ------------------------------ Stats --------------------------------
struct TA_PMStats
{
   int    positions_total;
   int    positions_buy;
   int    positions_sell;

   int    orders_pending;
   double volume_total;

   double profit;
   double swap;
   double commission;

   void Reset()
   {
      positions_total = 0;
      positions_buy   = 0;
      positions_sell  = 0;
      orders_pending  = 0;
      volume_total    = 0.0;
      profit          = 0.0;
      swap            = 0.0;
      commission      = 0.0;
   }

   double NetProfit() const { return profit + swap + commission; }
};

// --------------------------- Position Manager ------------------------
class TA_PositionManager
{
private:
   CTrade        m_trade;
   CPositionInfo m_pos;
   COrderInfo    m_ord;

   bool          m_inited;
   TA_PMStats    m_stats;

   // Basic filters (cached for convenience)
   ulong         m_magic;
   string        m_symbol;

private:
   bool IsMySymbol(const TA_Context &ctx, const string sym) const
   {
      // Safety: allow future "all-symbol" mode if ctx.symbol is empty or "*"
      if(ctx.symbol == "" || ctx.symbol == "*")
         return true;
      return (sym == ctx.symbol);
   }

   bool IsMyPositionSelected(const TA_Context &ctx) const
   {
      const string sym = PositionGetString(POSITION_SYMBOL);
      const long   mag = (long)PositionGetInteger(POSITION_MAGIC);
      if(!IsMySymbol(ctx, sym))
         return false;
      if((ulong)mag != ctx.magic)
         return false;
      return true;
   }

   bool IsMyOrderSelected(const TA_Context &ctx) const
   {
      const string sym = OrderGetString(ORDER_SYMBOL);
      const long   mag = (long)OrderGetInteger(ORDER_MAGIC);
      if(!IsMySymbol(ctx, sym))
         return false;
      if((ulong)mag != ctx.magic)
         return false;
      return true;
   }

   static bool IsPendingType(const ENUM_ORDER_TYPE t)
   {
      return (t == ORDER_TYPE_BUY_LIMIT  ||
              t == ORDER_TYPE_SELL_LIMIT ||
              t == ORDER_TYPE_BUY_STOP   ||
              t == ORDER_TYPE_SELL_STOP  ||
              t == ORDER_TYPE_BUY_STOP_LIMIT ||
              t == ORDER_TYPE_SELL_STOP_LIMIT);
   }

   void UpdateStats(const TA_Context &ctx)
   {
      m_stats.Reset();

      // -------- Positions --------
      const int ptotal = PositionsTotal();
      for(int i=ptotal-1; i>=0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         if(!IsMyPositionSelected(ctx))
            continue;

         const long type = (long)PositionGetInteger(POSITION_TYPE);
         const double vol = PositionGetDouble(POSITION_VOLUME);

         m_stats.positions_total++;
         if(type == POSITION_TYPE_BUY)  m_stats.positions_buy++;
         if(type == POSITION_TYPE_SELL) m_stats.positions_sell++;

         m_stats.volume_total += vol;

         m_stats.profit      += PositionGetDouble(POSITION_PROFIT);
         m_stats.swap        += PositionGetDouble(POSITION_SWAP);
         m_stats.commission  += PositionGetDouble(POSITION_COMMISSION);
      }

      // -------- Pending Orders --------
      const int ototal = OrdersTotal();
      for(int i=ototal-1; i>=0; --i)
      {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if(!OrderSelect(ticket))
            continue;

         if(!IsMyOrderSelected(ctx))
            continue;

         const ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(!IsPendingType(t))
            continue;

         m_stats.orders_pending++;
      }
   }

   int ClosePositionsFiltered(const TA_Context &ctx,
                             const int only_side,        // -1=any, 0=buy, 1=sell
                             const int pnl_filter)       //  0=any, 1=profit only, -1=loss only
   {
      int closed = 0;

      // Iterate backwards - some brokers reorder pool after close
      for(int i=PositionsTotal()-1; i>=0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         if(!IsMyPositionSelected(ctx))
            continue;

         const long type = (long)PositionGetInteger(POSITION_TYPE);
         if(only_side == 0 && type != POSITION_TYPE_BUY)
            continue;
         if(only_side == 1 && type != POSITION_TYPE_SELL)
            continue;

         const double pnl = PositionGetDouble(POSITION_PROFIT)
                          + PositionGetDouble(POSITION_SWAP)
                          + PositionGetDouble(POSITION_COMMISSION);

         if(pnl_filter == 1 && pnl <= 0.0)
            continue;
         if(pnl_filter == -1 && pnl >= 0.0)
            continue;

         ResetLastError();
         if(m_trade.PositionClose(ticket))
            closed++;
      }

      return closed;
   }

   int DeletePendingsFiltered(const TA_Context &ctx)
   {
      int deleted = 0;

      for(int i=OrdersTotal()-1; i>=0; --i)
      {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if(!OrderSelect(ticket))
            continue;

         if(!IsMyOrderSelected(ctx))
            continue;

         const ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(!IsPendingType(t))
            continue;

         ResetLastError();
         if(m_trade.OrderDelete(ticket))
            deleted++;
      }

      return deleted;
   }

public:
   TA_PositionManager()
   {
      m_inited = false;
      m_magic  = 0;
      m_symbol = "";
      m_stats.Reset();
   }

   bool Init(const TA_Context &ctx, const TA_State &state, const TA_BrokerRules &broker)
   {

      m_magic  = ctx.magic;
      m_symbol = ctx.symbol;

      m_trade.SetExpertMagicNumber((uint)ctx.magic);
      m_trade.SetAsyncMode(false);

      m_inited = true;

      UpdateStats(ctx);
      return true;
   }

   void SyncConfig(const TA_Context &ctx, const TA_State &state)
   {

      // Ensure trade object uses correct magic if user changes it via preset.
      m_trade.SetExpertMagicNumber((uint)ctx.magic);

      // Optional: if you add slippage/deviation settings in TA_State, set here.
      // Example:
      // if(state.deviation_points > 0) m_trade.SetDeviationInPoints((uint)state.deviation_points);
   }

   void OnTimer(const TA_Context &ctx, TA_State &state)
   {
      if(!m_inited)
         return;

      UpdateStats(ctx);
   }

   void OnTradeTransaction(const TA_Context &ctx,
                           TA_State &state,
                           const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {

      if(!m_inited)
         return;

      // Keep this lightweight: just refresh aggregates.
      UpdateStats(ctx);
   }

   TA_PMStats Stats() const { return m_stats; }

   // Execute a command from the Close tab.
   //
   // IMPORTANT: We intentionally map by integer values to keep this module robust
   // even if you rename enum items. Keep ENUM_TA_CLOSE_CMD order consistent with UI:
   //
   //  0 = None / No-op
   //  1 = Close All (this symbol + magic)
   //  2 = Close Buys
   //  3 = Close Sells
   //  4 = Close Profitable
   //  5 = Close Losing
   //  6 = Delete Pendings
   //  7 = Close All + Delete Pendings
   //
   bool ExecuteCloseCommand(const TA_Context &ctx, TA_State &state, const ENUM_TA_CLOSE_CMD cmd)
   {
      if(!m_inited)
         return false;

      const int c = (int)cmd;

      int closed  = 0;
      int deleted = 0;

      switch(c)
      {
         case 0: // none
            return true;

         case 1: // close all
            closed = ClosePositionsFiltered(ctx, -1, 0);
            break;

         case 2: // close buys
            closed = ClosePositionsFiltered(ctx, 0, 0);
            break;

         case 3: // close sells
            closed = ClosePositionsFiltered(ctx, 1, 0);
            break;

         case 4: // close profitable
            closed = ClosePositionsFiltered(ctx, -1, 1);
            break;

         case 5: // close losing
            closed = ClosePositionsFiltered(ctx, -1, -1);
            break;

         case 6: // delete pendings
            deleted = DeletePendingsFiltered(ctx);
            break;

         case 7: // close all + delete pendings
            closed  = ClosePositionsFiltered(ctx, -1, 0);
            deleted = DeletePendingsFiltered(ctx);
            break;

         default:
            return false;
      }

      // Refresh stats (and let UI show results if it reads Stats()).
      UpdateStats(ctx);

      // If you have a notifications module, you can emit messages at caller level.
      // Here we only return success.
      return true;
   }
};

#endif // __TA_POSITIONMANAGER_MQH__

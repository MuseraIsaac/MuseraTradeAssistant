//+------------------------------------------------------------------+
//|                                           TA_TimeManager.mqh      |
//|                                  (c) 2026, Musera Isaac           |
//|  Time/session gatekeeper for MuseraTradeAssistant.                 |
//|                                                                    |
//|  Purpose                                                           |
//|   - Provide a single place to evaluate "can we open new trades now"|
//|     based on a simple weekly schedule + intraday session window.   |
//|   - Cache status for UI (OPEN/CLOSED + next change time).          |
//|                                                                    |
//|  Expected TA_State fields (define in TA_State.mqh):                |
//|    ENUM_TA_TIME_RULE time_rule;                                    |
//|       - When time_rule == TA_TIME_ANY : always allowed.            |
//|       - Otherwise: enforce schedule below.                         |
//|    bool allow_mon, allow_tue, allow_wed, allow_thu, allow_fri;      |
//|    bool allow_sat, allow_sun;                                      |
//|    int  session_start_hour, session_start_min;                     |
//|    int  session_end_hour,   session_end_min;                       |
//|    int  utc_offset_seconds;   // rule-time = UTC + offset           |
//|                                                                    |
//|  Notes                                                             |
//|   - This module does NOT place/close trades. It only computes       |
//|     "allowed now" and timings that other modules/UI can use.       |
//|   - Overnight sessions are supported (e.g., 22:00 -> 06:00).        |
//|   - If start==end, that is treated as a 24h session for allowed     |
//|     days.                                                          |
//+------------------------------------------------------------------+
#ifndef __TA_TIMEMANAGER_MQH__
#define __TA_TIMEMANAGER_MQH__

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"

//------------------------------ Helpers ------------------------------

bool TA__DayAllowed(const int dow, const TA_State &st)
{
   // MQL: 0=Sunday, 1=Monday, ... 6=Saturday
   switch(dow)
   {
      case 0: return st.allow_sun;
      case 1: return st.allow_mon;
      case 2: return st.allow_tue;
      case 3: return st.allow_wed;
      case 4: return st.allow_thu;
      case 5: return st.allow_fri;
      case 6: return st.allow_sat;
   }
   return false;
}

datetime TA__Midnight(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

datetime TA__AtHM(const datetime day_midnight, const int hour, const int minute)
{
   MqlDateTime dt;
   TimeToStruct(day_midnight, dt);
   dt.hour = MathMax(0, MathMin(23, hour));
   dt.min  = MathMax(0, MathMin(59, minute));
   dt.sec  = 0;
   return StructToTime(dt);
}

// Interval in "rule time zone" (UTC + st.utc_offset_seconds)
struct TA_TimeInterval
{
   datetime start_rule;
   datetime end_rule;   // strictly > start_rule
   int      start_dow;  // day-of-week of start (rule zone)
};

//------------------------------ Class ------------------------------

class TA_TimeManager
{
private:
   bool     m_inited;

   // Cached timestamps
   datetime m_now_utc;
   datetime m_now_rule;

   // Cached evaluation
   bool     m_allowed_now;
   string   m_status;

   bool     m_has_active;
   datetime m_active_start_rule;
   datetime m_active_end_rule;

   bool     m_has_next;
   datetime m_next_start_rule;
   datetime m_next_end_rule;

private:
   void BuildIntervals(const TA_State &st, const datetime now_rule, TA_TimeInterval &out[])
   {
      ArrayResize(out, 0);

      // If user blocked all days, keep empty.
      bool any_day = (st.allow_mon || st.allow_tue || st.allow_wed || st.allow_thu ||
                      st.allow_fri || st.allow_sat || st.allow_sun);
      if(!any_day)
         return;

      const datetime base_mid = TA__Midnight(now_rule);

      // Window times (in minutes)
      const int sh = st.session_start_hour;
      const int sm = st.session_start_min;
      const int eh = st.session_end_hour;
      const int em = st.session_end_min;

      // Build intervals for yesterday .. next 7 days to properly cover overnight windows.
      for(int i=-1; i<=7; i++)
      {
         datetime day_mid = base_mid + (datetime)(i * 86400);
         int dow = TimeDayOfWeek(day_mid);

         if(!TA__DayAllowed(dow, st))
            continue;

         datetime start = TA__AtHM(day_mid, sh, sm);
         datetime end   = TA__AtHM(day_mid, eh, em);

         // Interpret:
         //  - start==end => 24h session on allowed day
         //  - start < end => same-day session
         //  - start > end => overnight session ending next day
         if(start == end)
         {
            end = start + 86400;
         }
         else if(start > end)
         {
            end += 86400;
         }

         int n = ArraySize(out);
         ArrayResize(out, n+1);
         out[n].start_rule = start;
         out[n].end_rule   = end;
         out[n].start_dow  = dow;
      }

      // Ensure sorted by start time (i is increasing, but keep safe).
      int n = ArraySize(out);
      for(int a=0; a<n-1; a++)
      {
         for(int b=a+1; b<n; b++)
         {
            if(out[b].start_rule < out[a].start_rule)
            {
               TA_TimeInterval tmp = out[a];
               out[a] = out[b];
               out[b] = tmp;
            }
         }
      }
   }

   void Evaluate(const TA_Context &ctx, const TA_State &st)
   {
      (void)ctx; // currently unused, but kept for future (per-symbol schedules, etc.)

      m_now_utc  = TA_NowUTC();
      m_now_rule = TA_UTCToOffset(m_now_utc, st.utc_offset_seconds);

      m_allowed_now = true;
      m_status      = "Time: ANY";

      m_has_active = false;
      m_active_start_rule = 0;
      m_active_end_rule   = 0;

      m_has_next = false;
      m_next_start_rule = 0;
      m_next_end_rule   = 0;

      // Unrestricted
      if(st.time_rule == TA_TIME_ANY)
         return;

      // Build allowed intervals (rule zone)
      TA_TimeInterval intervals[];
      BuildIntervals(st, m_now_rule, intervals);

      // Find active interval (if any)
      int active_idx = -1;
      for(int i=0; i<ArraySize(intervals); i++)
      {
         if(m_now_rule >= intervals[i].start_rule && m_now_rule < intervals[i].end_rule)
         {
            active_idx = i;
            break;
         }
      }

      if(active_idx >= 0)
      {
         m_allowed_now = true;
         m_status      = "Time: OPEN";
         m_has_active  = true;
         m_active_start_rule = intervals[active_idx].start_rule;
         m_active_end_rule   = intervals[active_idx].end_rule;
         return;
      }

      // Not allowed now: find next interval start
      m_allowed_now = false;
      m_status      = "Time: CLOSED";

      datetime best_start = 0;
      datetime best_end   = 0;

      for(int i=0; i<ArraySize(intervals); i++)
      {
         if(intervals[i].start_rule > m_now_rule)
         {
            best_start = intervals[i].start_rule;
            best_end   = intervals[i].end_rule;
            break;
         }
      }

      if(best_start > 0 && best_end > best_start)
      {
         m_has_next = true;
         m_next_start_rule = best_start;
         m_next_end_rule   = best_end;
      }
   }

public:
   TA_TimeManager(void)
   {
      m_inited = false;
      m_now_utc = 0;
      m_now_rule = 0;
      m_allowed_now = true;
      m_status = "Time: ANY";
      m_has_active = false;
      m_active_start_rule = 0;
      m_active_end_rule = 0;
      m_has_next = false;
      m_next_start_rule = 0;
      m_next_end_rule = 0;
   }

   void Init(const TA_Context &ctx, const TA_State &st)
   {
      m_inited = true;
      Evaluate(ctx, st);
   }

   void SyncConfig(const TA_Context &ctx, const TA_State &st)
   {
      if(!m_inited) Init(ctx, st);
      else Evaluate(ctx, st);
   }

   void OnTimer(const TA_Context &ctx, const TA_State &st)
   {
      if(!m_inited) return;
      Evaluate(ctx, st);
   }

   // ---- Public status ----
   bool AllowedNow(void) const { return m_allowed_now; }
   string StatusText(void) const { return m_status; }

   datetime NowUTC(void) const { return m_now_utc; }
   datetime NowRule(void) const { return m_now_rule; }

   // ---- Active window (only valid if HasActiveWindow()==true) ----
   bool HasActiveWindow(void) const { return m_has_active; }
   datetime ActiveStartRule(void) const { return m_active_start_rule; }
   datetime ActiveEndRule(void) const { return m_active_end_rule; }

   datetime ActiveStartUTC(const TA_State &st) const
   {
      if(!m_has_active) return 0;
      return TA_OffsetToUTC(m_active_start_rule, st.utc_offset_seconds);
   }

   datetime ActiveEndUTC(const TA_State &st) const
   {
      if(!m_has_active) return 0;
      return TA_OffsetToUTC(m_active_end_rule, st.utc_offset_seconds);
   }

   // ---- Next window (only valid if HasNextWindow()==true) ----
   bool HasNextWindow(void) const { return m_has_next; }
   datetime NextStartRule(void) const { return m_next_start_rule; }
   datetime NextEndRule(void) const { return m_next_end_rule; }

   datetime NextStartUTC(const TA_State &st) const
   {
      if(!m_has_next) return 0;
      return TA_OffsetToUTC(m_next_start_rule, st.utc_offset_seconds);
   }

   datetime NextEndUTC(const TA_State &st) const
   {
      if(!m_has_next) return 0;
      return TA_OffsetToUTC(m_next_end_rule, st.utc_offset_seconds);
   }

   // Convenience: seconds until next change:
   //  - If allowed now: seconds until window END
   //  - Else: seconds until next window START (if any), otherwise 0
   int SecondsToNextChange(const TA_State &st) const
   {
      datetime now_rule = m_now_rule;

      if(m_has_active)
      {
         datetime end = m_active_end_rule;
         long secs = (long)(end - now_rule);
         return (int)MathMax(0, secs);
      }
      if(m_has_next)
      {
         datetime start = m_next_start_rule;
         long secs = (long)(start - now_rule);
         return (int)MathMax(0, secs);
      }
      return 0;
   }
};

#endif // __TA_TIMEMANAGER_MQH__

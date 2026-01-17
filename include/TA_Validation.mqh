//+------------------------------------------------------------------+
//|                                                TA_Validation.mqh  |
//|                         MuseraTradeAssistant (c) 2026, Musera Isaac |
//+------------------------------------------------------------------+
#property strict

#ifndef __TA_VALIDATION_MQH__
#define __TA_VALIDATION_MQH__

#include "TA_Types.mqh"
#include "TA_Utils.mqh"

inline void TA_ResetResult(TA_Result &res){ res.ok=true; res.code=0; res.message=""; }
inline bool TA_Ok(TA_Result &res){ TA_ResetResult(res); return true; }
inline bool TA_Fail(TA_Result &res,int code,const string msg){ res.ok=false; res.code=code; res.message=msg; return false; }

// Current project shell does not rely on deep validation yet.
// Keep this header minimal and compilable; extend as the tool evolves.

#endif // __TA_VALIDATION_MQH__

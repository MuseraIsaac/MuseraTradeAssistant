//+------------------------------------------------------------------+
//|                                           TA_Notifications.mqh    |
//|                         MuseraTradeAssistant (project include)    |
//|                                  (c) 2026, Musera Isaac          |
//|                                                                  |
//|  Notification and logging helper (terminal / alert / push / sound)|
//+------------------------------------------------------------------+

#include "TA_Constants.mqh"
#include "TA_Enums.mqh"
#include "TA_Types.mqh"
#include "TA_State.mqh"
#include "TA_Utils.mqh"

// NOTE:
// - This module depends on TA_State fields:
//     notify_channel, notify_on_trade, notify_on_error,
//     notify_use_sound, notify_sound_ok, notify_sound_error, notify_prefix
// - ENUM_TA_NOTIFY_CHANNEL is defined in TA_Enums.mqh.

class TA_Notifications
{
private:
   bool        m_inited;          // initialized via Init()
   TA_Context  m_ctx;
   TA_State   *m_state;           // non-owning (state lives in main EA)

   datetime    m_last_info;
   datetime    m_last_warn;
   datetime    m_last_error;
   datetime    m_last_trade;

   // Simple throttling to avoid spamming (seconds)
   int         m_throttle_info;
   int         m_throttle_warn;
   int         m_throttle_error;  // errors: allow immediate when 0
   int         m_throttle_trade;

private:
   string Prefix() const
   {
      if(m_state==NULL) return "TA: ";
      string p=m_state.notify_prefix;
      if(p=="") p="TA: ";
      return p;
   }

   ENUM_TA_NOTIFY_CHANNEL Channel() const
   {
      if(m_state==NULL) return TA_NOTIFY_PRINT;
      return (ENUM_TA_NOTIFY_CHANNEL)m_state.notify_channel;
   }

   bool TerminalEnabled() const { return (Channel()==TA_NOTIFY_PRINT); }
   bool AlertEnabled()    const { return (Channel()==TA_NOTIFY_ALERT); }
   bool PushEnabled()     const { return (Channel()==TA_NOTIFY_PUSH); }
   bool SoundOnly()       const { return (Channel()==TA_NOTIFY_SOUND); }
   bool NoneEnabled()     const { return (Channel()==TA_NOTIFY_NONE); }

   bool SoundEnabled() const
   {
      if(m_state==NULL) return false;
      // If user selected SOUND channel, treat as sound even if notify_use_sound is false.
      if(SoundOnly()) return true;
      return (m_state.notify_use_sound);
   }

   bool ShouldThrottle(const datetime last_ts,const int throttle_sec) const
   {
      if(throttle_sec<=0) return false;
      if(last_ts==0)      return false;
      datetime now=TimeCurrent();
      return ((now-last_ts) < throttle_sec);
   }

   void Stamp(datetime &last_ts){ last_ts=TimeCurrent(); }

   void PlayOkSound()
   {
      if(!SoundEnabled()) return;
      string f=(m_state!=NULL ? m_state.notify_sound_ok : "");
      if(f=="") f=TA_SOUND_NOTIFY_FILE;
      PlaySound(f);
   }

   void PlayErrorSound()
   {
      if(!SoundEnabled()) return;
      string f=(m_state!=NULL ? m_state.notify_sound_error : "");
      if(f=="") f=TA_SOUND_ERROR_FILE;
      PlaySound(f);
   }

   void SendTerminal(const string &msg){ Print(Prefix()+msg); }
   void SendAlert(const string &msg){ Alert(Prefix()+msg); }
   void SendPush(const string &msg){ SendNotification(Prefix()+msg); }

   void Dispatch(const string &msg,const bool is_error,const bool is_trade,const bool force)
   {
      if(!m_inited) return;
      if(m_state==NULL) return;

      // Channel gating
      if(NoneEnabled()) return;

      // State flags gating
      if(is_trade && !m_state.notify_on_trade) return;
      if(is_error && !m_state.notify_on_error) return;

      // Throttling
      if(!force)
      {
         if(is_error)
         {
            if(ShouldThrottle(m_last_error,m_throttle_error)) return;
            Stamp(m_last_error);
         }
         else if(is_trade)
         {
            if(ShouldThrottle(m_last_trade,m_throttle_trade)) return;
            Stamp(m_last_trade);
         }
         else
         {
            if(ShouldThrottle(m_last_info,m_throttle_info)) return;
            Stamp(m_last_info);
         }
      }

      // Sound first (optional)
      if(is_error) PlayErrorSound(); else PlayOkSound();

      // If channel is SOUND-only, do not send text notifications.
      if(SoundOnly()) return;

      if(TerminalEnabled()) SendTerminal(msg);
      if(AlertEnabled())    SendAlert(msg);
      if(PushEnabled())     SendPush(msg);
   }

public:
   TA_Notifications()
   {
      m_inited=false;
      m_state=NULL;
      m_last_info=0;
      m_last_warn=0;
      m_last_error=0;
      m_last_trade=0;
      m_throttle_info=1;
      m_throttle_warn=1;
      m_throttle_error=0;
      m_throttle_trade=1;
   }

   bool Init(const TA_Context &ctx, TA_State &st)
   {
      m_ctx=ctx;
      m_state=&st;
      m_inited=true;
      return true;
   }

   void SyncConfig(const TA_Context &ctx, TA_State &st)
   {
      m_ctx=ctx;
      m_state=&st;
   }

   // Convenience APIs used by main EA and modules
   void Info(const string &msg,bool force=false)  { Dispatch(msg,false,false,force); }
   void Warn(const string &msg,bool force=false)  { Dispatch("WARN: "+msg,false,false,force); }
   void Error(const string &msg,bool force=true)  { Dispatch("ERROR: "+msg,true,false,force); }
   void Trade(const string &msg,bool force=false) { Dispatch("TRADE: "+msg,false,true,force); }

   // Lightweight debug hook (prints only)
   void Debug(const string &msg)
   {
      if(!m_inited || m_state==NULL) return;
      if(TerminalEnabled()) Print(Prefix()+"DBG: "+msg);
   }

   bool IsTerminalEnabled() const { return TerminalEnabled(); }
   bool IsAlertEnabled()    const { return AlertEnabled(); }
   bool IsPushEnabled()     const { return PushEnabled(); }
};
//+------------------------------------------------------------------+

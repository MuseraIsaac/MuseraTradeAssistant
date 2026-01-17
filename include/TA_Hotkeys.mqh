//+------------------------------------------------------------------+
//|                                                    TA_Hotkeys.mqh |
//|                        (c) 2026, Musera Isaac                     |
//|  Keyboard shortcuts (hotkeys) manager.                             |
//|                                                                    |
//|  Path (expected):                                                  |
//|  MQL5\Experts\MuseraTradeAssistant\include\TA_Hotkeys.mqh           |
//|                                                                    |
//|  Design:                                                          |
//|  - Listens for CHARTEVENT_KEYDOWN                                  |
//|  - Matches against configured key chords                           |
//|  - Emits EventChartCustom() for decoupled handling (UI/Core)        |
//|                                                                    |
//|  NOTE: This module doesn't execute trades directly. It emits        |
//|  custom chart events that your UI_Bindings / UI_App can react to.   |
//+------------------------------------------------------------------+
#property strict

#ifndef __MUSERA_TA_HOTKEYS_MQH__
#define __MUSERA_TA_HOTKEYS_MQH__

#include "TA_Constants.mqh"
#include "TA_Types.mqh"
#include "TA_State.mqh"

// --------------------------------- Custom events ---------------------------------
// Hotkeys emit EventChartCustom(chart_id, TA_CE_HOTKEY_BASE + cmd, vk, flags, label)
// Receiver sees:
//   id == CHARTEVENT_CUSTOM + (TA_CE_HOTKEY_BASE + cmd)
//
// You can handle it in UI_App.OnChartEvent() or UI_Bindings:
//   int custom_id = id - CHARTEVENT_CUSTOM;
//   if(custom_id >= TA_CE_HOTKEY_BASE && custom_id < TA_CE_HOTKEY_BASE + TA_HK__COUNT) { ... }
// ----------------------------------------------------------------------------------
#define TA_CE_HOTKEY_BASE  3100

// ------------------------------ Commands ------------------------------
enum ENUM_TA_HOTKEY_CMD
{
   TA_HK_NONE = 0,

   TA_HK_BUY_MARKET,        // place market buy using current panel settings
   TA_HK_SELL_MARKET,       // place market sell using current panel settings

   TA_HK_CLOSE_ALL,         // close all positions & delete pendings (as per your close tab)
   TA_HK_CLOSE_BUY,         // close buy positions only
   TA_HK_CLOSE_SELL,        // close sell positions only

   TA_HK_TOGGLE_BE,         // toggle break-even enable
   TA_HK_TOGGLE_TRAIL,      // toggle trailing enable

   TA_HK_TOGGLE_UI,         // show/hide the assistant panel
   TA_HK_SCREENSHOT,        // take screenshot (if implemented)

   TA_HK__COUNT
};

// ------------------------------ Binding DTO ------------------------------
struct TA_HotkeyBinding
{
   int               vk;       // virtual key code
   bool              ctrl;
   bool              shift;
   bool              alt;
   ENUM_TA_HOTKEY_CMD cmd;
   string            label;    // optional label for UI/help
};

// ------------------------------ Helpers ------------------------------
string TA__UpperTrim(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToUpper(s);
   return s;
}

int TA__VkFromToken(string token)
{
   token = TA__UpperTrim(token);

   // Single character (A-Z, 0-9, etc)
   if(StringLen(token) == 1)
   {
      ushort ch = (ushort)StringGetCharacter(token, 0);
      return (int)ch; // ASCII/Unicode basic plane for A-Z/0-9
   }

   // Function keys F1..F24
   if(StringLen(token) >= 2 && StringGetCharacter(token, 0) == 'F')
   {
      int n = (int)StringToInteger(StringSubstr(token, 1));
      if(n >= 1 && n <= 24)
         return 111 + n; // VK_F1=112
   }

   // Named keys (subset)
   if(token == "ESC" || token == "ESCAPE")   return 27;
   if(token == "SPACE")                      return 32;
   if(token == "ENTER" || token == "RETURN") return 13;
   if(token == "TAB")                        return 9;
   if(token == "BACKSPACE")                  return 8;
   if(token == "DEL" || token == "DELETE")   return 46;
   if(token == "INS" || token == "INSERT")   return 45;
   if(token == "HOME")                       return 36;
   if(token == "END")                        return 35;
   if(token == "PGUP" || token == "PAGEUP")  return 33;
   if(token == "PGDN" || token == "PAGEDOWN")return 34;
   if(token == "UP")                         return 38;
   if(token == "DOWN")                       return 40;
   if(token == "LEFT")                       return 37;
   if(token == "RIGHT")                      return 39;

   // Unknown token
   return -1;
}

// Parses chord like "CTRL+SHIFT+B" or "F9" into components
bool TA__ParseChord(const string chord, int &vk, bool &ctrl, bool &shift, bool &alt)
{
   vk = -1; ctrl = false; shift = false; alt = false;

   string s = chord;
   StringTrimLeft(s);
   StringTrimRight(s);
   if(s == "") return false;

   // Split by '+'
   string parts[];
   int n = StringSplit(s, '+', parts);
   if(n <= 0) return false;

   for(int i=0;i<n;i++)
   {
      string p = TA__UpperTrim(parts[i]);
      if(p == "") continue;

      if(p == "CTRL" || p == "CONTROL") { ctrl = true; continue; }
      if(p == "SHIFT")                  { shift = true; continue; }
      if(p == "ALT")                    { alt = true; continue; }

      // otherwise: key token
      int k = TA__VkFromToken(p);
      if(k < 0) return false;
      vk = k;
   }

   return (vk >= 0);
}

// Maps modifier flags from CHARTEVENT_KEYDOWN dparam (best-effort)
void TA__FlagsToMods(const long flags, bool &ctrl, bool &shift, bool &alt)
{
   // In MetaTrader, dparam for KEYDOWN commonly behaves like:
   // 1=SHIFT, 2=CTRL, 4=ALT (Windows-style bitmask). Treat as best-effort.
   shift = ((flags & 1) != 0);
   ctrl  = ((flags & 2) != 0);
   alt   = ((flags & 4) != 0);
}

// ------------------------------ Hotkeys manager ------------------------------
class TA_Hotkeys
{
private:
   TA_HotkeyBinding m_bindings[];
   bool             m_enabled;
   ulong            m_last_fire_ms;
   int              m_last_vk;

   void AddBinding(const int vk, const bool ctrl, const bool shift, const bool alt,
                   const ENUM_TA_HOTKEY_CMD cmd, const string label)
   {
      int sz = ArraySize(m_bindings);
      ArrayResize(m_bindings, sz+1);
      m_bindings[sz].vk    = vk;
      m_bindings[sz].ctrl  = ctrl;
      m_bindings[sz].shift = shift;
      m_bindings[sz].alt   = alt;
      m_bindings[sz].cmd   = cmd;
      m_bindings[sz].label = label;
   }

   void AddBindingChord(const string chord, const ENUM_TA_HOTKEY_CMD cmd, const string label)
   {
      int vk; bool ctrl, shift, alt;
      if(!TA__ParseChord(chord, vk, ctrl, shift, alt))
         return;
      AddBinding(vk, ctrl, shift, alt, cmd, label);
   }

   bool Match(const TA_HotkeyBinding &b, const int vk, const bool ctrl, const bool shift, const bool alt) const
   {
      if(b.vk != vk) return false;
      if(b.ctrl != ctrl) return false;
      if(b.shift != shift) return false;
      if(b.alt != alt) return false;
      return true;
   }

public:
   TA_Hotkeys(): m_enabled(true), m_last_fire_ms(0), m_last_vk(-1) {}

   // Enable/disable hotkeys at runtime
   void SetEnabled(const bool enabled) { m_enabled = enabled; }
   bool Enabled() const { return m_enabled; }

   // Default bindings (can be overridden later by Settings tab + persistence)
   void LoadDefaults()
   {
      ArrayResize(m_bindings, 0);

      // These are conservative defaults; you can change them freely:
      AddBindingChord("CTRL+B",        TA_HK_BUY_MARKET,   "Buy (market)");
      AddBindingChord("CTRL+S",        TA_HK_SELL_MARKET,  "Sell (market)");
      AddBindingChord("CTRL+SHIFT+C",  TA_HK_CLOSE_ALL,    "Close all");
      AddBindingChord("CTRL+SHIFT+1",  TA_HK_CLOSE_BUY,    "Close buys");
      AddBindingChord("CTRL+SHIFT+2",  TA_HK_CLOSE_SELL,   "Close sells");
      AddBindingChord("CTRL+SHIFT+B",  TA_HK_TOGGLE_BE,    "Toggle break-even");
      AddBindingChord("CTRL+SHIFT+T",  TA_HK_TOGGLE_TRAIL, "Toggle trailing");
      AddBindingChord("CTRL+H",        TA_HK_TOGGLE_UI,    "Toggle panel");
      AddBindingChord("CTRL+P",        TA_HK_SCREENSHOT,   "Screenshot");
   }

   void Init(const TA_Context &ctx, const TA_State &state)
   {
      // Receive keyboard events on this chart
      // (Safe to call repeatedly; returns false only if chart id invalid)
      ChartSetInteger((long)ctx.chart_id, CHART_EVENT_KEYBOARD, true);

      // Later: Load from state/persistence if you add fields.
      // For now, we install defaults.
      LoadDefaults();

      m_enabled = true;
      m_last_fire_ms = 0;
      m_last_vk = -1;

      (void)state; // unused for now
   }

   void OnTimer(const TA_Context &ctx, const TA_State &state)
   {
      // Reserved for future:
      // - long-press hotkeys
      // - displaying helper overlay
      (void)ctx; (void)state;
   }

   void OnChartEvent(const TA_Context &ctx, const TA_State &state,
                     const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      (void)state;
      (void)sparam;

      if(!m_enabled) return;
      if(id != CHARTEVENT_KEYDOWN) return;

      const int  vk = (int)lparam;
      const long flags = (long)dparam;

      bool ctrl=false, shift=false, alt=false;
      TA__FlagsToMods(flags, ctrl, shift, alt);

      // Debounce auto-repeat (especially when key held down)
      ulong now = (ulong)GetTickCount();
      if(vk == m_last_vk && (now - m_last_fire_ms) < 250)
         return;

      for(int i=0; i<ArraySize(m_bindings); i++)
      {
         if(Match(m_bindings[i], vk, ctrl, shift, alt))
         {
            m_last_vk = vk;
            m_last_fire_ms = now;

            // Emit custom event for UI/Core to handle.
            // custom_id = TA_CE_HOTKEY_BASE + cmd
            EventChartCustom((long)ctx.chart_id,
                             TA_CE_HOTKEY_BASE + (int)m_bindings[i].cmd,
                             (long)vk,
                             (double)flags,
                             m_bindings[i].label);
            return;
         }
      }
   }

   // Optional helper for Info tab: returns a multi-line list of bindings.
   string DescribeBindings() const
   {
      string s = "";
      for(int i=0; i<ArraySize(m_bindings); i++)
      {
         string line = "";
         if(m_bindings[i].ctrl)  line += "CTRL+";
         if(m_bindings[i].shift) line += "SHIFT+";
         if(m_bindings[i].alt)   line += "ALT+";
         line += IntegerToString(m_bindings[i].vk);
         if(m_bindings[i].label != "")
            line += "  -> " + m_bindings[i].label;
         s += line + "\n";
      }
      return s;
   }
};

#endif // __MUSERA_TA_HOTKEYS_MQH__
//+------------------------------------------------------------------+

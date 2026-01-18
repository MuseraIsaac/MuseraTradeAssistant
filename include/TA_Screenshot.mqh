//+------------------------------------------------------------------+
//|                                                     TA_Screenshot.mqh |
//|                             MuseraTradeAssistant (c) 2026, Musera Isaac|
//|
//|  Screenshot helper:
//|   - Creates a safe subfolder under MQL5\Files\
//|   - Generates readable filenames (symbol, timeframe, timestamp)
//|   - Provides a simple Capture() API you can call from UI/hotkeys
//|
//|  Notes:
//|   - ChartScreenShot() writes to the terminal "Files" sandbox when you
//|     pass a relative path. Example saved location:
//|       <terminal_data>\MQL5\Files\<subdir>\<file>.png
//|   - This module does NOT assume any specific TA_State fields; it can be
//|     wired to state later via SyncConfig() if you add settings.
//+------------------------------------------------------------------+
#ifndef TA_SCREENSHOT_MQH
#define TA_SCREENSHOT_MQH

#include "TA_Types.mqh"   // TA_Context

// Forward declaration (TA_State is defined in TA_State.mqh which the EA includes earlier)
struct TA_State;

// ------------------------------ TA_Screenshot ------------------------------
class TA_Screenshot
{
private:
   string   m_subdir;       // Relative to MQL5\Files
   string   m_prefix;       // Filename prefix
   int      m_width;        // 0 => use chart width
   int      m_height;       // 0 => use chart height
   string   m_last_file;    // Last relative filename
   string   m_last_error;   // Last error message

private:
   // Convert common invalid filename chars to underscores
   static string SanitizeFilePart(string s)
   {
      StringTrimLeft(s);
      StringTrimRight(s);

      // Replace path separators and illegal filename characters
      const string bad = "\\/:*?\"<>|";
      for(int i=0;i<(int)StringLen(bad);i++)
      {
         ushort ch = (ushort)StringGetCharacter(bad, i);
         StringReplace(s, (string)ShortToString((short)ch), "_"); // fallback, but keep below as well
      }

      // Above fallback can be quirky; ensure explicit replacements too:
      StringReplace(s, "\\", "_");
      StringReplace(s, "/",  "_");
      StringReplace(s, ":",  "_");
      StringReplace(s, "*",  "_");
      StringReplace(s, "?",  "_");
      StringReplace(s, "\"", "_");
      StringReplace(s, "<",  "_");
      StringReplace(s, ">",  "_");
      StringReplace(s, "|",  "_");

      // Collapse double underscores a bit (optional)
      while(StringFind(s, "__") >= 0)
         StringReplace(s, "__", "_");

      return s;
   }

   static string Two(int v)
   {
      if(v < 10) return "0" + IntegerToString(v);
      return IntegerToString(v);
   }

   static string TFShort(const ENUM_TIMEFRAMES tf)
   {
      switch(tf)
      {
         case PERIOD_M1:   return "M1";
         case PERIOD_M2:   return "M2";
         case PERIOD_M3:   return "M3";
         case PERIOD_M4:   return "M4";
         case PERIOD_M5:   return "M5";
         case PERIOD_M6:   return "M6";
         case PERIOD_M10:  return "M10";
         case PERIOD_M12:  return "M12";
         case PERIOD_M15:  return "M15";
         case PERIOD_M20:  return "M20";
         case PERIOD_M30:  return "M30";
         case PERIOD_H1:   return "H1";
         case PERIOD_H2:   return "H2";
         case PERIOD_H3:   return "H3";
         case PERIOD_H4:   return "H4";
         case PERIOD_H6:   return "H6";
         case PERIOD_H8:   return "H8";
         case PERIOD_H12:  return "H12";
         case PERIOD_D1:   return "D1";
         case PERIOD_W1:   return "W1";
         case PERIOD_MN1:  return "MN1";
         default:          return "TF";
      }
   }

   // Create nested folders relative to MQL5\Files
   bool EnsureSubdir(const string rel_path)
   {
      string p = rel_path;
      if(p == "") return true;

      // Normalize separators to backslash for FolderCreate()
      StringReplace(p, "/", "\\");

      // Strip leading slashes
      while(StringLen(p) > 0)
      {
         ushort c0 = (ushort)StringGetCharacter(p, 0);
         if(c0=='\\' || c0=='/')
            p = StringSubstr(p, 1);
         else
            break;
      }

      string parts[];
      int n = StringSplit(p, '\\', parts);
      if(n <= 0) return true;

      string cur = "";
      for(int i=0;i<n;i++)
      {
         if(parts[i] == "") continue;
         cur = (cur == "" ? parts[i] : (cur + "\\" + parts[i]));

         ResetLastError();
         if(FolderCreate(cur))
            continue;

         int err = GetLastError();
         // If it already exists, ignore
         if(err == 5004 /*ERR_FILE_ALREADY_EXISTS*/ || err == 5007 /*ERR_DIRECTORY_ALREADY_EXISTS*/ || err == 5010 /*ERR_FILE_EXISTS*/)
            continue;

         // Some terminals return 0 even when it exists; be tolerant
         // But if it's a real error, store it
         if(err != 0)
         {
            m_last_error = "FolderCreate failed: " + cur + " (err=" + IntegerToString(err) + ")";
            return false;
         }
      }
      return true;
   }

   string BuildFilename(const TA_Context &ctx, const string tag) const
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      string tstamp = IntegerToString(dt.year) + Two(dt.mon) + Two(dt.day) + "_" + Two(dt.hour) + Two(dt.min) + Two(dt.sec);

      const string sym = SanitizeFilePart(ctx.symbol);
      const string tf  = TFShort((ENUM_TIMEFRAMES)Period()); // chart period

      string clean_tag = SanitizeFilePart(tag);
      string file = m_prefix + "_" + sym + "_" + tf + "_" + tstamp;
      if(clean_tag != "")
         file += "_" + clean_tag;

      file += ".png";
      return file;
   }

public:
   TA_Screenshot()
   {
      m_subdir     = "MuseraTradeAssistant\\screenshots";
      m_prefix     = "MTA";
      m_width      = 0;
      m_height     = 0;
      m_last_file  = "";
      m_last_error = "";
   }

   // Called from EA OnInit()
   void Init(const TA_Context &ctx, const TA_State &st)
   {
      m_last_error = "";
      EnsureSubdir(m_subdir);
   }

   // Optional future: read config from state (folder/prefix/size)
   void SyncConfig(const TA_Context &ctx, const TA_State &st)
   {
      // Intentionally empty for now.
   }

   // Optional hooks (no-op)
   void OnTimer(const TA_Context &ctx, const TA_State &st) { }
   void OnTradeTransaction(const TA_Context &ctx, const TA_State &st,
                           const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {
   }

   void OnChartEvent(const TA_Context &ctx, const TA_State &st,
                     const int id, const long &lparam, const double &dparam, const string &sparam)
   {
   }

   // ------------------------------ Configuration ------------------------------
   void SetFolder(const string rel_subdir) { m_subdir = rel_subdir; EnsureSubdir(m_subdir); }
   void SetPrefix(const string prefix)     { m_prefix = SanitizeFilePart(prefix); }
   void SetSize(const int w, const int h)  { m_width = w; m_height = h; }

   string LastFile()  const { return m_last_file; }
   string LastError() const { return m_last_error; }

   // ------------------------------ Action ------------------------------
   // tag: optional descriptor (e.g., "TP1", "entry", "manual")
   // width/height: override capture size (0 => use stored or chart size)
   bool Capture(const TA_Context &ctx, const string tag = "", const int width = 0, const int height = 0)
   {
      m_last_error = "";
      if(!EnsureSubdir(m_subdir))
         return false;

      string file = BuildFilename(ctx, tag);
      string rel  = (m_subdir == "" ? file : (m_subdir + "\\" + file));

      int w = width;
      int h = height;

      if(w <= 0) w = m_width;
      if(h <= 0) h = m_height;

      if(w <= 0) w = (int)ChartGetInteger(ctx.chart_id, CHART_WIDTH_IN_PIXELS, 0);
      if(h <= 0) h = (int)ChartGetInteger(ctx.chart_id, CHART_HEIGHT_IN_PIXELS, 0);

      // Safe fallback
      if(w <= 0) w = 1280;
      if(h <= 0) h = 720;

      ResetLastError();
      bool ok = ChartScreenShot(ctx.chart_id, rel, w, h, ALIGN_RIGHT);

      if(!ok)
      {
         int err = GetLastError();
         m_last_error = "ChartScreenShot failed (err=" + IntegerToString(err) + "), file=" + rel;
         return false;
      }

      m_last_file = rel;
      return true;
   }
};

#endif // TA_SCREENSHOT_MQH

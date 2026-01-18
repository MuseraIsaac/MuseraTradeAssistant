//+------------------------------------------------------------------+
//|                                              TA_Persistence.mqh  |
//|                      MuseraTradeAssistant (project include)      |
//|                                  (c) 2026, Musera Isaac          |
//+------------------------------------------------------------------+
//  Presets persistence backend.
//
//  Design goals
//  - Simple and robust (line-based file format; no JSON dependency).
//  - Safe preset file names (sanitized).
//  - Stores "last used preset" in a small meta file.
//
//  File layout (relative to MQL5\Files):
//    <TA_PRESET_FOLDER>\_meta.ta
//    <TA_PRESET_FOLDER>\<preset_name><TA_PRESET_FILE_EXT>
//
//  REQUIRED TA_State contract (implemented in TA_State.mqh):
//    bool Serialize(string &out_text) const;
//    bool Deserialize(const string &in_text);
//
//  Notes
//  - This is a project include (.mqh) and is intended to be included AFTER TA_State.mqh.
//  - If you change TA_PRESET_FOLDER / TA_PRESET_FILE_EXT, old presets may not be found.
//+------------------------------------------------------------------+
#property strict

#ifndef __TA_PERSISTENCE_MQH__
#define __TA_PERSISTENCE_MQH__

#include "TA_Constants.mqh"
#include "TA_Types.mqh"
#include "TA_Utils.mqh"

// Forward declare to avoid tight include coupling.
// (TA_State should already be defined before including this file.)
class TA_State;

//--------------------------- internal helpers ---------------------------//
string TA__Trim(const string s)
{
   string t = s;
   StringTrimLeft(t);
   StringTrimRight(t);
   return t;
}

bool TA__StartsWith(const string s, const string prefix)
{
   if(StringLen(prefix) <= 0) return true;
   if(StringLen(s) < StringLen(prefix)) return false;
   return (StringSubstr(s, 0, (int)StringLen(prefix)) == prefix);
}

string TA__SanitizePresetName(const string raw)
{
   string n = TA__Trim(raw);
   if(n == "") n = "preset";

   // Replace disallowed chars with underscore.
   // Allowed: A-Z a-z 0-9 _ - space
   for(int i=0; i<(int)StringLen(n); i++)
   {
      ushort ch = StringGetCharacter(n, i);

      bool ok = ((ch>='0' && ch<='9') ||
                 (ch>='A' && ch<='Z') ||
                 (ch>='a' && ch<='z') ||
                 ch=='_' || ch=='-' || ch==' ');

      if(!ok)
         StringSetCharacter(n, i, '_');
   }

   // Collapse multiple spaces and trim again.
   n = TA__Trim(n);
   while(StringFind(n, "  ") >= 0) StringReplace(n, "  ", " ");

   // Avoid path traversal and separators.
   StringReplace(n, "..", "_");
   StringReplace(n, "/", "_");
   StringReplace(n, "\\", "_");
   StringReplace(n, ":", "_");

   // Limit length (avoid very long file names on Windows).
   if(StringLen(n) > 60)
      n = StringSubstr(n, 0, 60);

   return n;
}

string TA__PresetFolder()
{
   // Stored under: <TerminalData>\MQL5\Files\<TA_PRESET_FOLDER>\
   return TA_PRESET_FOLDER;
}

bool TA__EnsureFolder(const string folder)
{
   // FolderCreate returns true if created or already exists in many builds;
   // but some builds return false if it already exists, so we don't treat it as fatal.
   if(folder == "") return false;

   if(FolderCreate(folder))
      return true;

   // If creation returns false, the folder might still exist.
   return FileIsExist(folder);
}

string TA__MetaFilePath()
{
   return TA__PresetFolder() + "\\_meta.ta";
}

string TA__PresetFilePath(const string preset_name_sanitized)
{
   return TA__PresetFolder() + "\\" + preset_name_sanitized + TA_PRESET_FILE_EXT;
}

bool TA__WriteTextFile(const string path, const string text)
{
   int h = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE)
      return false;

   // Write exact content (FileWriteString does not append new line).
   FileWriteString(h, text);
   FileClose(h);
   return true;
}

/*bool TA__ReadAllText(const string path, string &out_text)
{
   out_text = "";
   int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE)
      return false;

   // Read line-by-line to avoid FileReadString tokenization issues.
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      out_text += line;

      // In FILE_TXT mode, FileReadString drops EOL - we re-add it
      if(!FileIsEnding(h))
         out_text += "\n";
   }

   FileClose(h);
   return true;
}*/

//--------------------------- TA_Persistence ---------------------------//
class TA_Persistence
{
private:
   TA_Context m_ctx;
   string     m_file_hint;
   string     m_last_preset;
   bool       m_ready;

   bool ReadMeta()
   {
      m_last_preset = "";

      string meta;
      if(!TA__ReadAllText(TA__MetaFilePath(), meta))
         return true; // meta missing is OK

      // Very small key=value format
      string lines[];
      int n = StringSplit(meta, '\n', lines);
      for(int i=0; i<n; i++)
      {
         string ln = TA__Trim(lines[i]);
         if(ln=="" || TA__StartsWith(ln, "#")) continue;

         int eq = StringFind(ln, "=");
         if(eq <= 0) continue;

         string k = TA__Trim(StringSubstr(ln, 0, eq));
         string v = TA__Trim(StringSubstr(ln, eq+1));

         if(k == "last_preset")
            m_last_preset = v;
      }
      return true;
   }

   bool WriteMeta()
   {
      string meta = "";
      meta += "# MuseraTradeAssistant meta\n";
      meta += "magic=" + IntegerToString((int)TA_PRESET_MAGIC) + "\n";
      meta += "version=" + TA_VERSION + "\n";
      meta += "last_preset=" + m_last_preset + "\n";
      return TA__WriteTextFile(TA__MetaFilePath(), meta);
   }

public:
   TA_Persistence(): m_file_hint(""), m_last_preset(""), m_ready(false) {}

   void Init(const TA_Context &ctx, const string file_hint)
   {
      m_ctx = ctx;
      m_file_hint = file_hint;
      m_ready = true;

      // Ensure preset folder exists.
      TA__EnsureFolder(TA__PresetFolder());

      // Load meta if present.
      ReadMeta();
   }

   // Save preset: writes a small header + serialized state.
   bool SavePreset(const string preset_name, const TA_State &state)
   {
      if(!m_ready) return false;

      string name = TA__SanitizePresetName(preset_name);
      if(!TA__EnsureFolder(TA__PresetFolder()))
         return false;

      string payload = "";
      // TA_State contract
      if(!state.Serialize(payload))
         return false;

      // Normalize line endings
      StringReplace(payload, "\r", "");

      string file_text = "";
      file_text += "# MuseraTradeAssistant preset\n";
      file_text += "magic=" + IntegerToString((int)TA_PRESET_MAGIC) + "\n";
      file_text += "version=" + TA_VERSION + "\n";
      file_text += "name=" + name + "\n";
      file_text += "saved_at=" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\n";
      file_text += "---BEGIN_STATE---\n";
      file_text += payload;
      if(StringLen(payload) > 0 && StringSubstr(payload, (int)StringLen(payload)-1, 1) != "\n")
         file_text += "\n";
      file_text += "---END_STATE---\n";

      string path = TA__PresetFilePath(name);
      if(!TA__WriteTextFile(path, file_text))
         return false;

      // Update last preset (in-memory); caller decides when to Flush() if desired.
      m_last_preset = name;
      return true;
   }

   bool LoadPreset(const string preset_name, TA_State &out_state)
   {
      if(!m_ready) return false;

      string name = TA__SanitizePresetName(preset_name);
      string path = TA__PresetFilePath(name);

      string txt;
      if(!TA__ReadAllText(path, txt))
         return false;

      // Basic parsing
      string lines[];
      int n = StringSplit(txt, '\n', lines);

      bool in_state = false;
      string payload = "";

      for(int i=0; i<n; i++)
      {
         string ln = lines[i];

         if(!in_state)
         {
            string t = TA__Trim(ln);
            if(t == "---BEGIN_STATE---")
            {
               in_state = true;
               continue;
            }
            // ignore header
            continue;
         }
         else
         {
            string t = TA__Trim(ln);
            if(t == "---END_STATE---")
               break;

            payload += ln;
            payload += "\n";
         }
      }

      StringReplace(payload, "\r", "");

      // TA_State contract
      if(!out_state.Deserialize(payload))
         return false;

      // Update last preset
      m_last_preset = name;
      return true;
   }

   bool DeletePreset(const string preset_name)
   {
      string name = TA__SanitizePresetName(preset_name);
      string path = TA__PresetFilePath(name);
      return FileDelete(path);
   }

   void SetLastPreset(const string preset_name)
   {
      m_last_preset = TA__SanitizePresetName(preset_name);
   }

   string GetLastPreset()
   {
      // If empty, attempt to read meta again (in case file changed).
      if(m_last_preset == "")
         ReadMeta();
      return m_last_preset;
   }

   void Flush()
   {
      if(!m_ready) return;
      TA__EnsureFolder(TA__PresetFolder());
      WriteMeta();
   }
};

#endif // __TA_PERSISTENCE_MQH__

#ifndef __MUSERA_TA_UI_SETTINGS_TAB_MQH__
#define __MUSERA_TA_UI_SETTINGS_TAB_MQH__

// Settings tab: presets + global toggles + misc options.
// This is a small, self-contained UI module. It depends on:
// - UI_Theme.mqh (colors/fonts)
// - TA_Enums.mqh / TA_Types.mqh / TA_State.mqh (state)
// - TA_Persistence.mqh (preset listing)

#include "../TA_Enums.mqh"
#include "../TA_Types.mqh"
#include "../TA_State.mqh"
#include "../TA_Persistence.mqh"
#include "UI_Theme.mqh"

class UI_SettingsTab
{
private:
   string   m_prefix;
   int      m_x, m_y, m_w, m_h;

   // Object names
   string   m_lbl_title;
   string   m_cb_autosave;
   string   m_edit_preset;
   string   m_btn_save;
   string   m_btn_load;
   string   m_combo_presets;

   // internal
   bool     m_visible;

   string Name(const string id) const { return m_prefix + id; }

   void EnsureRect(const string name, int x, int y, int w, int h, color fill, color border)
   {
      if(!ObjectFind(0,name))
      {
         ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(0,name,OBJPROP_BACK,false);
      }
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,name,OBJPROP_COLOR,border);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,fill);
   }

   void EnsureLabel(const string name, const string text, int x, int y, int fs, color c)
   {
      if(!ObjectFind(0,name))
      {
         ObjectCreate(0,name,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      }
      ObjectSetString(0,name,OBJPROP_FONT,UI_FONT);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fs);
      ObjectSetInteger(0,name,OBJPROP_COLOR,c);
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   }

   void EnsureButton(const string name, const string text, int x, int y, int w, int h)
   {
      if(!ObjectFind(0,name))
      {
         ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      }
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetString(0,name,OBJPROP_FONT,UI_FONT);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,UI_FONT_SMALL);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,name,OBJPROP_COLOR,UI_COLOR_BTN_BORDER);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,UI_COLOR_BTN_FACE);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }

   void EnsureEdit(const string name, const string text, int x, int y, int w, int h)
   {
      if(!ObjectFind(0,name))
      {
         ObjectCreate(0,name,OBJ_EDIT,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      }
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetString(0,name,OBJPROP_FONT,UI_FONT);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,UI_FONT_SMALL);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,UI_COLOR_PANEL);
      ObjectSetInteger(0,name,OBJPROP_COLOR,UI_COLOR_VALUE);
      ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,UI_COLOR_BORDER);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }

   void EnsureCombo(const string name, int x, int y, int w, int h)
   {
      if(!ObjectFind(0,name))
      {
         ObjectCreate(0,name,OBJ_COMBOBOX,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      }
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,UI_COLOR_PANEL);
      ObjectSetInteger(0,name,OBJPROP_COLOR,UI_COLOR_VALUE);
      ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,UI_COLOR_BORDER);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }

   void EnsureCheckbox(const string name, const string text, int x, int y)
   {
      if(!ObjectFind(0,name))
      {
         ObjectCreate(0,name,OBJ_CHECKBOX,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      }
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetString(0,name,OBJPROP_FONT,UI_FONT);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,UI_FONT_SMALL);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_COLOR,UI_COLOR_LABEL);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }

public:
   UI_SettingsTab(): m_prefix(""), m_x(0), m_y(0), m_w(0), m_h(0), m_visible(false) {}

   bool Create(const string prefix, int x, int y, int w, int h)
   {
      m_prefix = prefix + "SET_";
      m_x=x; m_y=y; m_w=w; m_h=h;

      // background panel for the tab
      EnsureRect(Name("BG"), m_x, m_y, m_w, m_h, UI_COLOR_PANEL, UI_COLOR_BORDER);

      m_lbl_title    = Name("LBL_TITLE");
      m_cb_autosave  = Name("CB_AUTOSAVE");
      m_edit_preset  = Name("ED_PRESET");
      m_btn_save     = Name("BTN_SAVE");
      m_btn_load     = Name("BTN_LOAD");
      m_combo_presets= Name("CB_PRESETS");

      EnsureLabel(m_lbl_title, "Settings / Presets", m_x+10, m_y+10, UI_FONT_MED, UI_COLOR_HEADER_TEXT);

      EnsureCheckbox(m_cb_autosave, "Auto-save last preset", m_x+10, m_y+40);
      EnsureLabel(Name("LBL_PRESET"), "Preset name:", m_x+10, m_y+70, UI_FONT_SMALL, UI_COLOR_LABEL);
      EnsureEdit(m_edit_preset, "", m_x+100, m_y+66, m_w-110, 20);

      EnsureButton(m_btn_save, "Save", m_x+10, m_y+96, 80, 22);
      EnsureButton(m_btn_load, "Load", m_x+100, m_y+96, 80, 22);

      EnsureLabel(Name("LBL_LIST"), "Saved presets:", m_x+10, m_y+130, UI_FONT_SMALL, UI_COLOR_LABEL);
      EnsureCombo(m_combo_presets, m_x+10, m_y+150, m_w-20, 22);

      Show(true);
      return true;
   }

   void Destroy()
   {
      const string ids[] = {"BG","LBL_TITLE","CB_AUTOSAVE","LBL_PRESET","ED_PRESET","BTN_SAVE","BTN_LOAD","LBL_LIST","CB_PRESETS"};
      for(int i=0;i<ArraySize(ids);i++)
         ObjectDelete(0, Name(ids[i]));
   }

   void Show(const bool visible)
   {
      m_visible = visible;
      // show/hide: set hidden flag
      string ids[] = {"BG","LBL_TITLE","CB_AUTOSAVE","LBL_PRESET","ED_PRESET","BTN_SAVE","BTN_LOAD","LBL_LIST","CB_PRESETS"};
      for(int i=0;i<ArraySize(ids);i++)
      {
         string n = Name(ids[i]);
         if(ObjectFind(0,n))
            ObjectSetInteger(0,n,OBJPROP_HIDDEN,!visible);
      }
   }

   bool IsVisible() const { return m_visible; }

   // Called when state changes externally
   void SyncFromState(const TA_Context &ctx, const TA_State &st)
   {
      // Autosave checkbox: reflect st flag if you store it there; otherwise leave unchecked
      if(ObjectFind(0,m_cb_autosave))
         ObjectSetInteger(0,m_cb_autosave,OBJPROP_STATE, st.ui_autosave_last_preset ? 1 : 0);
   }

   // Populate presets list from persistence backend
   void RefreshPresets(const TA_Context &ctx, TA_Persistence &persist)
   {
      if(!ObjectFind(0,m_combo_presets)) return;

      // clear items
      const int count = (int)ObjectGetInteger(0,m_combo_presets,OBJPROP_ITEMS);
      for(int i=count-1;i>=0;i--)
         ObjectSetString(0,m_combo_presets,OBJPROP_ITEM_TEXT,i,"");

      string names[];
      if(!persist.ListPresets(names))
         return;

      // Add items
      for(int i=0;i<ArraySize(names);i++)
      {
         ObjectSetString(0,m_combo_presets,OBJPROP_ITEM_TEXT,i,names[i]);
      }
   }

   // UI event: return selected preset name (if any)
   string SelectedPreset() const
   {
      if(!ObjectFind(0,m_combo_presets)) return "";
      int idx = (int)ObjectGetInteger(0,m_combo_presets,OBJPROP_SELECTED);
      string s = ObjectGetString(0,m_combo_presets,OBJPROP_ITEM_TEXT,idx);
      return s;
   }

   string EnteredPresetName() const
   {
      if(!ObjectFind(0,m_edit_preset)) return "";
      return ObjectGetString(0,m_edit_preset,OBJPROP_TEXT);
   }

   bool AutoSaveChecked() const
   {
      if(!ObjectFind(0,m_cb_autosave)) return false;
      return (ObjectGetInteger(0,m_cb_autosave,OBJPROP_STATE) == 1);
   }

   bool OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam,
                     bool &out_clicked_save, bool &out_clicked_load)
   {
      out_clicked_save = false;
      out_clicked_load = false;
      if(!m_visible) return false;

      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         if(sparam == m_btn_save)
         {
            out_clicked_save = true;
            return true;
         }
         if(sparam == m_btn_load)
         {
            out_clicked_load = true;
            return true;
         }
      }
      return false;
   }

};

#endif

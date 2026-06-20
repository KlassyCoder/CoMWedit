program CasterEditor;
{
  Caster of Magic — Savegame Editor (GUI).
  Tabbed window: Wizards / Cities / Map / Reroll. Edits the selected save's bytes via the
  verified Offsets table (SaveModel) and writes back into the .SAV zip. Runs from the game
  folder (so it can list the save slots).

  Build:  lazbuild CasterEditor.lpi
}
{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Controls, Graphics, StdCtrls, ComCtrls, ExtCtrls, Grids, Spin, Dialogs,
  Classes, SysUtils, StrUtils, Types, LCLType, LMessages, Registry, IniFiles, SaveModel, Offsets;

type
  // TStringGrid that scrolls live while the scrollbar thumb is dragged (not only on release).
  TLiveGrid = class(TStringGrid)
  protected
    procedure WMVScroll(var Msg: TLMVScroll); message LM_VSCROLL;
  end;

const
  DEFAULT_GAMEDIR = 'C:\Program Files (x86)\Steam\steamapps\common\Master of Magic\Master of Magic Caster Windows';
  GAME_REL = 'steamapps\common\Master of Magic\Master of Magic Caster Windows';
  APP_VERSION = '1.0';
  APP_TITLE = 'CoMWedit v' + APP_VERSION + ' — Caster of Magic for Windows Save Editor';
  REALM_NAMES: array[1..5] of string = ('Nature', 'Sorcery', 'Chaos', 'Life', 'Death');
  RETORT_NAMES: array[1..18] of string = (
    'Alchemy', 'Sage Master', 'Specialist', 'Warlord', 'Myrran', 'Tactician',
    'Channeler', 'Guardian', 'Omniscient', 'Archmage', 'Famous', 'Cult Leader',
    'Artificer', 'Runemaster', 'Astrologer', 'Conjurer', 'Charismatic', 'Spellweaver');
  ORE_NAMES: array[0..12] of string = (
    'None', 'Wild Game', 'Nightshade', 'Adamantium', 'Mithril', 'Orihalcon', 'Iron',
    'Coal', 'Silver', 'Gold', 'Gems', 'Crysx', 'Quork');
  NEUTRAL_ID = 15;
  RACE_NAMES: array[0..13] of string = (
    'Barbarian', 'Beastmen', 'Dark Elf', 'Draconian', 'Dwarf', 'Gnoll', 'Halfling',
    'High Elf', 'High Men', 'Klackon', 'Lizardmen', 'Nomad', 'Orc', 'Troll');
  TERRAIN_NAMES: array[0..16] of string = (
    'Ocean', 'Shore', 'Lake', 'River Mouth', 'Grassland', 'Hills', 'Mountain', 'Volcano',
    'Desert', 'Swamp', 'Tundra', 'River', 'Forest', 'Chaos Node', 'Nature Node', 'Sorcery Node',
    'River');
  SPELL_STATUS_NAMES: array[0..3] of string = ('Unknown', 'Researchable', 'Known', 'On Research List');
  MAX_SPELL_ID = 400;
  REALM7_NAMES: array[0..6] of string = ('All', 'Nature', 'Sorcery', 'Chaos', 'Life', 'Death', 'Arcane');
  RETORT_WARN = 'Warning: Selecting too many retorts can crash the in-game Mirror advisor (F9). '
    + 'The retorts still take full effect in the game - just don''t open the Mirror screen.';
  MAX_HERO_TYPES = 85;
  MAX_HERO_ABIL = 50;

type
  TMainForm = class(TForm)
  private
    FModel: TSaveModel;
    FSlot: string;          // current save file name
    FCurWiz: Integer;       // current wizard index
    FUpdating: Boolean;     // suppress OnChange while populating

    cbSave: TComboBox;
    btnLoad, btnSave, btnSaveAs: TButton;
    memStatus: TMemo;
    FSaveFiles: TStringList;            // filenames, parallel to cbSave items
    FSaveDesc: array[1..14] of string;  // in-game save names from COM.set (slot 1..14)
    pc: TPageControl;
    tsWiz, tsCity, tsMap, tsHero: TTabSheet;

    cbWiz: TComboBox;
    seGold, seMana, seSP, seFame, seRep: TSpinEdit;
    seBook: array[1..5] of TSpinEdit;
    chkRet: array[1..18] of TCheckBox;
    FRetortName: array[1..18] of string;   // mod-aware names (retorts.ini)
    FRetortExcl: array[1..18] of Integer;  // mutually-exclusive partner id, 0 = none
    FSpellName: array[0..MAX_SPELL_ID] of string;   // from Spells.dat (mod-aware)
    FSpellRealm: array[0..MAX_SPELL_ID] of Integer;  // 1=Nature..6=Arcane (Spells.dat offset 52)
    FSpellGrid: TStringGrid;                          // active spell-editor grid
    FStartupShown: Boolean;

    // Cities tab
    cbCity, cbCityOwner, cbCityRace: TComboBox;
    edCityName: TEdit;
    seCityPop: TSpinEdit;
    FCurCity: Integer;
    // Map tab
    cbPlane, cbOre: TComboBox;
    chkCorrupt: TCheckBox;
    scbMap: TScrollBox;
    pbMap: TPaintBox;
    lblActive: TLabel;
    FActiveX, FActiveY, FMapScale: Integer;
    FPanning: Boolean;
    FPanMouse, FPanScroll0: TPoint;
    FLandColor: array[0..16] of TColor;
    FOreColor: array[1..12] of TColor;
    FWizColor: array[0..15] of TColor;       // city owner colors (15 = neutral)
    FCityAt: array[1..200, 1..200] of Integer; // city id per tile on current plane, -1 = none

    // Heroes tab
    cbHWiz, cbHero: TComboBox;
    chkAbil, chkSuper: array[1..MAX_HERO_ABIL] of TCheckBox;
    FHeroTypeName: array[1..MAX_HERO_TYPES] of string;
    FHeroTypeCount: Integer;
    FAbilName: array[1..MAX_HERO_ABIL] of string;
    FAbilSuper: array[1..MAX_HERO_ABIL] of Boolean;
    FAbilCount: Integer;
    FHWiz, FHero: Integer;

    procedure BuildUI;
    procedure BuildCitiesTab;
    procedure BuildMapTab;
    procedure BuildHeroesTab;
    procedure LoadHeroData;
    procedure LoadRetortData;
    procedure HeroRefresh(Sender: TObject);
    procedure AbilChanged(Sender: TObject);
    procedure SuperChanged(Sender: TObject);
    procedure PopulateOwnerList;
    procedure CitySelected(Sender: TObject);
    procedure CityFieldChanged(Sender: TObject);
    procedure CityNameDone(Sender: TObject);
    procedure SetupColors;
    function TileColor(plane, x, y: Integer): TColor;
    function TileDesc(plane, x, y: Integer): string;
    function OwnerName(ownerId: Integer): string;
    procedure BuildCityMap(plane: Integer);
    procedure UpdateMapScale;
    procedure SetMapZoom(newScale: Integer);
    procedure MapZoomIn(Sender: TObject);
    procedure MapZoomOut(Sender: TObject);
    procedure PlaneChanged(Sender: TObject);
    procedure MapPaint(Sender: TObject);
    procedure MapMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure MapMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MapWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure OreChanged(Sender: TObject);
    procedure CorruptChanged(Sender: TObject);
    function NewSpin(aParent: TWinControl; x, y, aTag: Integer; const cap: string): TSpinEdit;
    procedure ListSaves;
    procedure DoLoad(Sender: TObject);
    procedure DoSave(Sender: TObject);
    procedure DoSaveAs(Sender: TObject);
    procedure WizSelected(Sender: TObject);
    procedure WizFieldChanged(Sender: TObject);
    procedure BookChanged(Sender: TObject);
    procedure RetortChanged(Sender: TObject);
    procedure LoadSpellNames;
    procedure LoadSaveDescriptions;
    procedure ShowSpellEditor(Sender: TObject);
    procedure SpellGridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure SpellBulk(Sender: TObject);
    procedure LoadWizardToUI;
    procedure SetStatus(const s: string);
    procedure FormShown(Sender: TObject);
    procedure ShowStartupMsg(Data: PtrInt);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;
  GameDir: string = '';
  StartupMessage: string = '';   // shown after the window appears, not before

function ValidGameDir(const p: string): Boolean;
begin
  Result := (p <> '') and FileExists(IncludeTrailingPathDelimiter(p) + 'Spells.dat');
end;

// For "N.sav" returns N (1..); -1 for AUTOSAVE/QUICKSAVE/TURN* and non-numeric names.
function SlotNumber(const fn: string): Integer;
begin
  if not SameText(ExtractFileExt(fn), '.sav') then Exit(-1);
  if not TryStrToInt(ChangeFileExt(fn, ''), Result) then Result := -1;
end;

function ConfigFilePath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'CoMWedit.ini';
end;

function SteamGameDirFromRegistry: string;
var reg: TRegistry; sp: string;
begin
  Result := '';
  reg := TRegistry.Create(KEY_READ);
  try
    reg.RootKey := HKEY_CURRENT_USER;
    if reg.OpenKeyReadOnly('Software\Valve\Steam') and reg.ValueExists('SteamPath') then
    begin
      sp := StringReplace(reg.ReadString('SteamPath'), '/', '\', [rfReplaceAll]);
      if sp <> '' then Result := IncludeTrailingPathDelimiter(sp) + GAME_REL;
    end;
  except
  end;
  reg.Free;
end;

function DetectGameDir: string;
var ini: TIniFile; p: string; bases: array[0..3] of string; i: Integer;
begin
  if FileExists(ConfigFilePath) then
  begin
    ini := TIniFile.Create(ConfigFilePath);
    try p := ini.ReadString('Game', 'Dir', ''); finally ini.Free; end;
    if ValidGameDir(p) then Exit(p);
  end;
  if ValidGameDir(DEFAULT_GAMEDIR) then Exit(DEFAULT_GAMEDIR);
  p := SteamGameDirFromRegistry;
  if ValidGameDir(p) then Exit(p);
  bases[0] := 'C:\Program Files (x86)\Steam\'; bases[1] := 'D:\Steam\';
  bases[2] := 'E:\Steam\'; bases[3] := 'D:\SteamLibrary\';
  for i := 0 to High(bases) do
  begin
    p := bases[i] + GAME_REL;
    if ValidGameDir(p) then Exit(p);
  end;
  Result := '';
end;

procedure SaveGameDirConfig(const p: string);
var ini: TIniFile;
begin
  try
    ini := TIniFile.Create(ConfigFilePath);
    try ini.WriteString('Game', 'Dir', p); finally ini.Free; end;
  except
  end;
end;

procedure EnsureGameDir;
var dlg: TSelectDirectoryDialog; firstTime: Boolean;
begin
  firstTime := not FileExists(ConfigFilePath);   // only confirm on the very first run
  GameDir := DetectGameDir;
  if not ValidGameDir(GameDir) then
  begin
    dlg := TSelectDirectoryDialog.Create(nil);
    try
      dlg.Title := 'Locate your Caster of Magic for Windows game folder (contains Spells.dat)';
      if dlg.Execute and ValidGameDir(dlg.FileName) then GameDir := dlg.FileName;
    finally
      dlg.Free;
    end;
  end;
  if ValidGameDir(GameDir) then
  begin
    SaveGameDirConfig(GameDir);
    if firstTime then
      StartupMessage := 'Found your Caster of Magic for Windows folder:' + LineEnding + LineEnding +
        GameDir + LineEnding + LineEnding +
        'Your saves will appear in the dropdown at the top. ' +
        'This is saved, so you won''t be asked again.';
  end
  else
    StartupMessage := 'Could not find your Caster of Magic for Windows game folder.' + LineEnding +
      'The save list will be empty. Restart CoMWedit to point it at the folder.';
end;

constructor TMainForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  Scaled := False;
  FModel := TSaveModel.Create;
  FSaveFiles := TStringList.Create;
  FCurWiz := -1;
  FCurCity := -1;
  FActiveX := -1; FActiveY := -1; FMapScale := 8;
  FHWiz := -1; FHero := -1;
  SetupColors;
  EnsureGameDir;
  LoadSpellNames;
  LoadHeroData;
  LoadRetortData;
  Caption := APP_TITLE;
  Width := 580;
  Height := 680;
  Position := poScreenCenter;
  BuildUI;
  OnShow := @FormShown;
  OnCloseQuery := @FormCloseQuery;
  ListSaves;
  if ValidGameDir(GameDir) then
    SetStatus(Format('Game folder found - %d saves available. Pick one and click Load.', [cbSave.Items.Count]))
  else
    SetStatus('Game folder not found - restart CoMWedit and browse to your game folder.');
end;

destructor TMainForm.Destroy;
begin
  FModel.Free;
  FSaveFiles.Free;
  inherited Destroy;
end;

function TMainForm.NewSpin(aParent: TWinControl; x, y, aTag: Integer; const cap: string): TSpinEdit;
var lbl: TLabel;
begin
  lbl := TLabel.Create(Self);
  lbl.Parent := aParent; lbl.Left := x; lbl.Top := y + 3; lbl.Caption := cap;
  Result := TSpinEdit.Create(Self);
  Result.Parent := aParent; Result.Left := x + 70; Result.Top := y; Result.Width := 90;
  Result.MinValue := 0; Result.MaxValue := 1000000; Result.Tag := aTag;
  Result.OnChange := @WizFieldChanged;
end;

procedure TMainForm.BuildUI;
var pnl: TPanel; lbl: TLabel; i: Integer; gbRes, gbBooks, gbRet: TGroupBox;
begin
  pnl := TPanel.Create(Self);
  pnl.Parent := Self; pnl.Align := alTop; pnl.Height := 40; pnl.BevelOuter := bvNone;

  lbl := TLabel.Create(Self); lbl.Parent := pnl; lbl.Left := 8; lbl.Top := 12; lbl.Caption := 'Save:';
  cbSave := TComboBox.Create(Self);
  cbSave.Parent := pnl; cbSave.Left := 44; cbSave.Top := 8; cbSave.Width := 240;
  cbSave.Style := csDropDownList;
  btnLoad := TButton.Create(Self);
  btnLoad.Parent := pnl; btnLoad.Left := 292; btnLoad.Top := 7; btnLoad.Width := 70;
  btnLoad.Caption := 'Load'; btnLoad.OnClick := @DoLoad;
  btnSave := TButton.Create(Self);
  btnSave.Parent := pnl; btnSave.Left := 368; btnSave.Top := 7; btnSave.Width := 70;
  btnSave.Caption := 'Save'; btnSave.OnClick := @DoSave; btnSave.Enabled := False;
  btnSaveAs := TButton.Create(Self);
  btnSaveAs.Parent := pnl; btnSaveAs.Left := 444; btnSaveAs.Top := 7; btnSaveAs.Width := 80;
  btnSaveAs.Caption := 'Save As...'; btnSaveAs.OnClick := @DoSaveAs; btnSaveAs.Enabled := False;

  memStatus := TMemo.Create(Self);
  memStatus.Parent := Self; memStatus.Align := alBottom; memStatus.Height := 66;
  memStatus.ReadOnly := True; memStatus.ScrollBars := ssVertical;
  memStatus.Color := clInfoBk;            // pale yellow so it stands out
  memStatus.Font.Size := 9;
  memStatus.Lines.Add('Ready.');

  pc := TPageControl.Create(Self);
  pc.Parent := Self; pc.Align := alClient;
  tsWiz := pc.AddTabSheet; tsWiz.Caption := 'Wizards';
  tsCity := pc.AddTabSheet; tsCity.Caption := 'Cities';
  tsMap := pc.AddTabSheet; tsMap.Caption := 'Map';
  tsHero := pc.AddTabSheet; tsHero.Caption := 'Heroes';

  // Wizards tab
  lbl := TLabel.Create(Self); lbl.Parent := tsWiz; lbl.Left := 16; lbl.Top := 18; lbl.Caption := 'Wizard:';
  cbWiz := TComboBox.Create(Self);
  cbWiz.Parent := tsWiz; cbWiz.Left := 72; cbWiz.Top := 14; cbWiz.Width := 200;
  cbWiz.Style := csDropDownList; cbWiz.OnChange := @WizSelected;

  // Resources
  gbRes := TGroupBox.Create(Self); gbRes.Parent := tsWiz;
  gbRes.Left := 12; gbRes.Top := 46; gbRes.Width := 384; gbRes.Height := 150;
  gbRes.Caption := 'Resources';
  seGold := NewSpin(gbRes, 14, 20, 1, 'Gold');
  seMana := NewSpin(gbRes, 200, 20, 2, 'Mana');
  seSP   := NewSpin(gbRes, 14, 52, 3, 'Cast Skill'); seSP.MaxValue := 2000;
  seFame := NewSpin(gbRes, 200, 52, 4, 'Fame');
  seRep  := NewSpin(gbRes, 14, 84, 6, 'Disposition'); seRep.MinValue := -100; seRep.MaxValue := 100;

  // Spellbooks
  gbBooks := TGroupBox.Create(Self); gbBooks.Parent := tsWiz;
  gbBooks.Left := 12; gbBooks.Top := 204; gbBooks.Width := 384; gbBooks.Height := 90;
  gbBooks.Caption := 'Spellbooks (0-13 per realm)';
  for i := 1 to 5 do
  begin
    lbl := TLabel.Create(Self); lbl.Parent := gbBooks;
    lbl.Left := 14 + (i-1)*74; lbl.Top := 16; lbl.Caption := REALM_NAMES[i];
    seBook[i] := TSpinEdit.Create(Self); seBook[i].Parent := gbBooks;
    seBook[i].Left := 14 + (i-1)*74; seBook[i].Top := 34; seBook[i].Width := 56;
    seBook[i].MinValue := 0; seBook[i].MaxValue := 13; seBook[i].Tag := i;
    seBook[i].OnChange := @BookChanged;
  end;

  // Retorts
  gbRet := TGroupBox.Create(Self); gbRet.Parent := tsWiz;
  gbRet.Left := 12; gbRet.Top := 302; gbRet.Width := 384; gbRet.Height := 196;
  gbRet.Caption := 'Retorts';
  for i := 1 to 18 do
  begin
    chkRet[i] := TCheckBox.Create(Self); chkRet[i].Parent := gbRet;
    chkRet[i].Left := 14 + ((i-1) div 6)*126; chkRet[i].Top := 18 + ((i-1) mod 6)*24;
    chkRet[i].Width := 124; chkRet[i].Caption := FRetortName[i]; chkRet[i].Tag := i;
    chkRet[i].OnChange := @RetortChanged;
  end;

  with TButton.Create(Self) do
  begin
    Parent := tsWiz; Left := 12; Top := 506; Width := 140; Height := 26;
    Caption := 'Edit Spells...'; OnClick := @ShowSpellEditor;
  end;

  BuildCitiesTab;
  BuildMapTab;
  BuildHeroesTab;
end;

procedure TMainForm.BuildCitiesTab;
var lbl: TLabel; gb: TGroupBox; i: Integer;
begin
  lbl := TLabel.Create(Self); lbl.Parent := tsCity; lbl.Left := 16; lbl.Top := 18; lbl.Caption := 'City:';
  cbCity := TComboBox.Create(Self);
  cbCity.Parent := tsCity; cbCity.Left := 60; cbCity.Top := 14; cbCity.Width := 220;
  cbCity.Style := csDropDownList; cbCity.Sorted := True; cbCity.OnChange := @CitySelected;

  gb := TGroupBox.Create(Self); gb.Parent := tsCity;
  gb.Left := 12; gb.Top := 50; gb.Width := 384; gb.Height := 212; gb.Caption := 'City';

  lbl := TLabel.Create(Self); lbl.Parent := gb; lbl.Left := 14; lbl.Top := 24; lbl.Caption := 'Name';
  edCityName := TEdit.Create(Self);
  edCityName.Parent := gb; edCityName.Left := 90; edCityName.Top := 20; edCityName.Width := 200;
  edCityName.MaxLength := 30; edCityName.OnEditingDone := @CityNameDone;

  lbl := TLabel.Create(Self); lbl.Parent := gb; lbl.Left := 14; lbl.Top := 56; lbl.Caption := 'Owner';
  cbCityOwner := TComboBox.Create(Self);
  cbCityOwner.Parent := gb; cbCityOwner.Left := 90; cbCityOwner.Top := 52; cbCityOwner.Width := 200;
  cbCityOwner.Style := csDropDownList; cbCityOwner.Tag := 1; cbCityOwner.OnChange := @CityFieldChanged;

  lbl := TLabel.Create(Self); lbl.Parent := gb; lbl.Left := 14; lbl.Top := 88; lbl.Caption := 'Race';
  cbCityRace := TComboBox.Create(Self);
  cbCityRace.Parent := gb; cbCityRace.Left := 90; cbCityRace.Top := 84; cbCityRace.Width := 200;
  cbCityRace.Style := csDropDownList; cbCityRace.Tag := 3; cbCityRace.OnChange := @CityFieldChanged;
  for i := 0 to High(RACE_NAMES) do cbCityRace.Items.Add(RACE_NAMES[i]);

  lbl := TLabel.Create(Self); lbl.Parent := gb; lbl.Left := 14; lbl.Top := 120; lbl.Caption := 'Population';
  seCityPop := TSpinEdit.Create(Self);
  seCityPop.Parent := gb; seCityPop.Left := 90; seCityPop.Top := 116; seCityPop.Width := 100;
  seCityPop.MinValue := 0; seCityPop.MaxValue := 60000; seCityPop.Tag := 2;
  seCityPop.OnChange := @CityFieldChanged;

  lbl := TLabel.Create(Self); lbl.Parent := gb; lbl.Left := 14; lbl.Top := 150;
  lbl.AutoSize := False; lbl.WordWrap := True; lbl.Width := 358; lbl.Height := 46;
  lbl.Caption := 'Note: changing a city''s race can leave it with buildings that race normally can''t '
    + 'build. This is usually harmless in-game.';
end;

procedure TMainForm.BuildMapTab;
var lbl: TLabel; i: Integer;
begin
  lbl := TLabel.Create(Self); lbl.Parent := tsMap; lbl.Left := 12; lbl.Top := 14; lbl.Caption := 'Plane';
  cbPlane := TComboBox.Create(Self);
  cbPlane.Parent := tsMap; cbPlane.Left := 56; cbPlane.Top := 10; cbPlane.Width := 110;
  cbPlane.Style := csDropDownList;
  cbPlane.Items.Add('Arcanus'); cbPlane.Items.Add('Myrror'); cbPlane.ItemIndex := 0;
  cbPlane.OnChange := @PlaneChanged;

  lbl := TLabel.Create(Self); lbl.Parent := tsMap; lbl.Left := 190; lbl.Top := 14; lbl.Caption := 'Resource';
  cbOre := TComboBox.Create(Self);
  cbOre.Parent := tsMap; cbOre.Left := 250; cbOre.Top := 10; cbOre.Width := 160;
  cbOre.Style := csDropDownList;
  for i := 0 to High(ORE_NAMES) do cbOre.Items.Add(ORE_NAMES[i]);
  cbOre.ItemIndex := 0; cbOre.OnChange := @OreChanged;

  chkCorrupt := TCheckBox.Create(Self);
  chkCorrupt.Parent := tsMap; chkCorrupt.Left := 430; chkCorrupt.Top := 12; chkCorrupt.Width := 110;
  chkCorrupt.Caption := 'Corrupted'; chkCorrupt.OnChange := @CorruptChanged;

  lblActive := TLabel.Create(Self); lblActive.Parent := tsMap; lblActive.Left := 12; lblActive.Top := 44;
  lblActive.Width := 380; lblActive.Caption := 'Load a save, then click a tile on the map to select it.';

  lbl := TLabel.Create(Self); lbl.Parent := tsMap; lbl.Left := 400; lbl.Top := 44; lbl.Caption := 'Zoom';
  with TButton.Create(Self) do
  begin Parent := tsMap; Left := 440; Top := 40; Width := 30; Height := 24; Caption := '-'; OnClick := @MapZoomOut; end;
  with TButton.Create(Self) do
  begin Parent := tsMap; Left := 474; Top := 40; Width := 30; Height := 24; Caption := '+'; OnClick := @MapZoomIn; end;

  scbMap := TScrollBox.Create(Self);
  scbMap.Parent := tsMap; scbMap.Left := 12; scbMap.Top := 68; scbMap.Width := 552; scbMap.Height := 466;
  scbMap.Anchors := [akLeft, akTop, akRight, akBottom];
  scbMap.HorzScrollBar.Tracking := True; scbMap.VertScrollBar.Tracking := True;

  pbMap := TPaintBox.Create(Self);
  pbMap.Parent := scbMap; pbMap.Left := 0; pbMap.Top := 0; pbMap.Width := 520; pbMap.Height := 420;
  pbMap.OnPaint := @MapPaint;
  pbMap.OnMouseDown := @MapMouseDown;
  pbMap.OnMouseMove := @MapMouseMove;
  pbMap.OnMouseUp := @MapMouseUp;
  pbMap.OnMouseWheel := @MapWheel;
end;

procedure TMainForm.SetupColors;
begin
  FLandColor[0]  := RGBToColor( 12, 32, 90);  // ocean (dark blue)
  FLandColor[1]  := RGBToColor(205,215,105);  // shore (yellow-green)
  FLandColor[2]  := RGBToColor( 12, 32, 90);  // lake (dark blue)
  FLandColor[3]  := RGBToColor( 45,125,230);  // river mouth (lighter blue)
  FLandColor[4]  := RGBToColor(120,200, 90);  // grassland (light green)
  FLandColor[5]  := RGBToColor( 80,140, 60);  // hill (mid green)
  FLandColor[6]  := RGBToColor(130,130,130);  // mountain (gray)
  FLandColor[7]  := RGBToColor(230,120, 20);  // volcano (orange)
  FLandColor[8]  := RGBToColor(220,200,140);  // desert (tan)
  FLandColor[9]  := RGBToColor( 80, 90, 50);  // swamp (dark olive)
  FLandColor[10] := RGBToColor(200,200,200);  // tundra (light grey)
  FLandColor[11] := RGBToColor( 45,125,230);  // river (lighter blue)
  FLandColor[12] := RGBToColor( 20,100, 40);  // forest (dark green)
  FLandColor[13] := RGBToColor(220, 30, 30);  // chaos node (red)
  FLandColor[14] := RGBToColor(120,240, 30);  // nature node (bright lime)
  FLandColor[15] := RGBToColor( 30,200,220);  // sorcery node (teal)
  FLandColor[16] := RGBToColor( 45,125,230);  // river source (lighter blue)

  FOreColor[1]  := RGBToColor(150, 90, 40);   // wild game (brown)
  FOreColor[2]  := RGBToColor(120, 40,160);   // nightshade (purple)
  FOreColor[3]  := RGBToColor(200,150,230);   // adamantium (light purple)
  FOreColor[4]  := RGBToColor(255,255,255);   // mithril (white)
  FOreColor[5]  := RGBToColor(255,150,200);   // orihalcon (pink)
  FOreColor[6]  := RGBToColor(150, 60, 30);   // iron (dark red/ochre)
  FOreColor[7]  := RGBToColor( 20, 20, 20);   // coal (black)
  FOreColor[8]  := RGBToColor(210,210,220);   // silver
  FOreColor[9]  := RGBToColor(240,200, 40);   // gold
  FOreColor[10] := RGBToColor(200,230,255);   // gems
  FOreColor[11] := RGBToColor(255,240, 60);   // crysx (bright yellow)
  FOreColor[12] := RGBToColor(120,200,255);   // quork (sky blue)

  // city owner colors (distinct per player; 15 = neutral brown)
  FWizColor[0]  := RGBToColor(230, 40, 40);
  FWizColor[1]  := RGBToColor( 40, 90,230);
  FWizColor[2]  := RGBToColor( 40,190, 70);
  FWizColor[3]  := RGBToColor(235,215, 40);
  FWizColor[4]  := RGBToColor(170, 60,210);
  FWizColor[5]  := RGBToColor(245,140, 30);
  FWizColor[6]  := RGBToColor( 30,205,205);
  FWizColor[7]  := RGBToColor(240,120,190);
  FWizColor[8]  := RGBToColor(140,235, 60);
  FWizColor[9]  := RGBToColor( 90,210,255);
  FWizColor[10] := RGBToColor(150, 30, 30);
  FWizColor[11] := RGBToColor( 30, 40,140);
  FWizColor[12] := RGBToColor(130,120, 30);
  FWizColor[13] := RGBToColor(110,110,110);
  FWizColor[14] := RGBToColor(150,100, 50);
  FWizColor[15] := RGBToColor(150,100, 50);   // neutral
end;

function TMainForm.OwnerName(ownerId: Integer): string;
begin
  if ownerId = NEUTRAL_ID then
    Result := 'Neutral'
  else if (ownerId >= 0) and (ownerId < WIZARD_COUNT) and FModel.WizardPresent(ownerId) then
    Result := FModel.WizardName(ownerId)
  else
    Result := 'player ' + IntToStr(ownerId);
end;

procedure TMainForm.BuildCityMap(plane: Integer);
var x, y, c: Integer;
begin
  for x := 1 to 200 do
    for y := 1 to 200 do FCityAt[x, y] := -1;
  if not FModel.Loaded then Exit;
  for c := 1 to 500 do
    if FModel.CityPresent(c) and (FModel.CityPlane(c) = plane) then
    begin
      x := FModel.CityX(c); y := FModel.CityY(c);
      if (x >= 1) and (x <= 200) and (y >= 1) and (y <= 200) then FCityAt[x, y] := c;
    end;
end;

function TMainForm.TileDesc(plane, x, y: Integer): string;
var land: Integer;
begin
  if FCityAt[x, y] >= 0 then
    Result := 'City: ' + FModel.CityName(FCityAt[x, y])
  else
  begin
    land := FModel.TileLand(plane, x, y);
    if (land >= 0) and (land <= High(TERRAIN_NAMES)) then Result := TERRAIN_NAMES[land] else Result := 'Unknown terrain';
  end;
end;

function TMainForm.TileColor(plane, x, y: Integer): TColor;
var ore, land: Integer;
begin
  ore := FModel.TileOre(plane, x, y);
  if (ore >= 1) and (ore <= 12) then
    Result := FOreColor[ore]
  else
  begin
    land := FModel.TileLand(plane, x, y);
    if (land >= 0) and (land <= High(FLandColor)) then Result := FLandColor[land]
    else Result := RGBToColor(70, 70, 70);   // unknown terrain -> dark gray (not black)
  end;
end;

procedure TMainForm.SetMapZoom(newScale: Integer);
var plane, w, h: Integer;
begin
  if not FModel.Loaded then Exit;
  if newScale < 4 then newScale := 4;
  if newScale > 32 then newScale := 32;
  FMapScale := newScale;
  plane := cbPlane.ItemIndex + 1;
  w := FModel.PlaneW(plane); h := FModel.PlaneH(plane);
  if (w < 1) or (w > 200) then w := 1;
  if (h < 1) or (h > 200) then h := 1;
  pbMap.Width := w * FMapScale; pbMap.Height := h * FMapScale;
  pbMap.Invalidate;
end;

procedure TMainForm.UpdateMapScale;   // pick a sensible default zoom (fit, but keep tiles readable)
var plane, w, h, fitW, fitH, fit: Integer;
begin
  if not FModel.Loaded then Exit;
  plane := cbPlane.ItemIndex + 1;
  w := FModel.PlaneW(plane); h := FModel.PlaneH(plane);
  if (w < 1) or (w > 200) then w := 1;
  if (h < 1) or (h > 200) then h := 1;
  fitW := scbMap.ClientWidth div w;
  fitH := scbMap.ClientHeight div h;
  fit := fitW; if fitH < fit then fit := fitH;
  if fit < 7 then fit := 7;     // keep tiles at least this big (scroll for large maps)
  if fit > 14 then fit := 14;   // don't blow small maps up huge
  SetMapZoom(fit);
end;

procedure TMainForm.MapZoomIn(Sender: TObject);
begin
  SetMapZoom(FMapScale + 2);
end;

procedure TMainForm.MapZoomOut(Sender: TObject);
begin
  SetMapZoom(FMapScale - 2);
end;

procedure TMainForm.PlaneChanged(Sender: TObject);
begin
  FActiveX := -1; FActiveY := -1;
  UpdateMapScale;
  BuildCityMap(cbPlane.ItemIndex + 1);
  lblActive.Caption := 'Click a tile on the map to select it.';
  pbMap.Invalidate;
end;

procedure TMainForm.MapPaint(Sender: TObject);
var plane, x, y, w, h, s: Integer;
begin
  if not FModel.Loaded then Exit;
  plane := cbPlane.ItemIndex + 1;
  w := FModel.PlaneW(plane); h := FModel.PlaneH(plane);
  if (w < 1) or (w > 200) or (h < 1) or (h > 200) then Exit;
  s := FMapScale;
  pbMap.Canvas.Pen.Style := psClear;
  for y := 1 to h do
    for x := 1 to w do
    begin
      if FCityAt[x, y] >= 0 then
      begin
        pbMap.Canvas.Brush.Color := FWizColor[FModel.CityOwner(FCityAt[x, y]) and 15];
        pbMap.Canvas.FillRect((x-1)*s, (y-1)*s, x*s, y*s);
        // dark outline so cities stand out from the terrain
        pbMap.Canvas.Pen.Style := psSolid; pbMap.Canvas.Pen.Color := clBlack; pbMap.Canvas.Pen.Width := 1;
        pbMap.Canvas.Brush.Style := bsClear;
        pbMap.Canvas.Rectangle((x-1)*s, (y-1)*s, x*s, y*s);
        pbMap.Canvas.Brush.Style := bsSolid; pbMap.Canvas.Pen.Style := psClear;
      end
      else
      begin
        pbMap.Canvas.Brush.Color := TileColor(plane, x, y);
        pbMap.Canvas.FillRect((x-1)*s, (y-1)*s, x*s, y*s);
      end;
    end;
  if (FActiveX >= 1) and (FActiveY >= 1) then
  begin
    pbMap.Canvas.Brush.Style := bsClear;
    pbMap.Canvas.Pen.Style := psSolid;
    pbMap.Canvas.Pen.Color := clYellow; pbMap.Canvas.Pen.Width := 2;
    pbMap.Canvas.Rectangle((FActiveX-1)*s, (FActiveY-1)*s, FActiveX*s, FActiveY*s);
    pbMap.Canvas.Pen.Width := 1; pbMap.Canvas.Brush.Style := bsSolid;
  end;
end;

procedure TMainForm.MapMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var plane, tx, ty, ore: Integer; desc: string;
begin
  if not FModel.Loaded then Exit;
  if Button = mbMiddle then     // middle-drag to pan
  begin
    FPanning := True;
    FPanMouse := Mouse.CursorPos;
    FPanScroll0 := Point(scbMap.HorzScrollBar.Position, scbMap.VertScrollBar.Position);
    Exit;
  end;
  if Button <> mbLeft then Exit;
  plane := cbPlane.ItemIndex + 1;
  tx := X div FMapScale + 1; ty := Y div FMapScale + 1;
  if (tx < 1) or (ty < 1) or (tx > FModel.PlaneW(plane)) or (ty > FModel.PlaneH(plane)) then Exit;
  FActiveX := tx; FActiveY := ty;
  ore := FModel.TileOre(plane, tx, ty);
  FUpdating := True;
  try
    if (ore >= 0) and (ore <= High(ORE_NAMES)) then cbOre.ItemIndex := ore else cbOre.ItemIndex := 0;
    chkCorrupt.Checked := FModel.TileCorrupt(plane, tx, ty);
  finally
    FUpdating := False;
  end;
  desc := TileDesc(plane, tx, ty);
  if FCityAt[tx, ty] >= 0 then desc := desc + ', owner: ' + OwnerName(FModel.CityOwner(FCityAt[tx, ty]));
  if (ore >= 1) and (ore <= 12) then desc := desc + ' — ' + ORE_NAMES[ore];
  if FModel.TileCorrupt(plane, tx, ty) then desc := desc + ' (Corrupted)';
  lblActive.Caption := Format('Tile (%d, %d): %s', [tx, ty, desc]);
  pbMap.Invalidate;
end;

procedure TMainForm.CorruptChanged(Sender: TObject);
begin
  if FUpdating or not FModel.Loaded or (FActiveX < 1) then Exit;
  FModel.SetTileCorrupt(cbPlane.ItemIndex + 1, FActiveX, FActiveY, chkCorrupt.Checked);
  SetStatus('Set corruption on a map tile (not saved yet).');
end;

procedure TMainForm.FormShown(Sender: TObject);
begin
  if FStartupShown then Exit;
  FStartupShown := True;
  if StartupMessage <> '' then
    Application.QueueAsyncCall(@ShowStartupMsg, 0);   // after the window has painted
end;

procedure TMainForm.ShowStartupMsg(Data: PtrInt);
begin
  ShowMessage(StartupMessage);
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if not (FModel.Loaded and FModel.Dirty) then Exit;
  case MessageDlg('Unsaved changes',
    'You have unsaved changes to ' + FSlot + '.' + LineEnding + 'Save before exiting?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:    begin DoSave(nil); CanClose := True; end;
    mrNo:     CanClose := True;
    mrCancel: CanClose := False;
  end;
end;

procedure TMainForm.SetStatus(const s: string);
begin
  memStatus.Lines.Add(s);
  while memStatus.Lines.Count > 200 do memStatus.Lines.Delete(0);
  // scroll to the newest line
  memStatus.SelStart := Length(memStatus.Text);
  memStatus.SelLength := 0;
end;

procedure TMainForm.LoadSaveDescriptions;
var b: TBytes; fs: TFileStream; i, off, len, j: Integer; s, fn: string;
begin
  for i := 1 to 14 do FSaveDesc[i] := '';
  fn := GameDir + '\COM.set';                 // 31-byte text field per slot (in-game save names)
  if not FileExists(fn) then Exit;
  try
    fs := TFileStream.Create(fn, fmOpenRead or fmShareDenyNone);
    try
      SetLength(b, fs.Size);
      if fs.Size > 0 then fs.ReadBuffer(b[0], fs.Size);
    finally
      fs.Free;
    end;
  except
    Exit;
  end;
  for i := 1 to 14 do
  begin
    off := (i - 1) * 31;
    if off >= Length(b) then Break;
    len := b[off];
    if (len >= 1) and (len <= 30) and (off + len < Length(b)) then
    begin
      s := '';
      for j := 1 to len do
        if (b[off + j] >= 32) and (b[off + j] <= 126) then s := s + Chr(b[off + j]);
      FSaveDesc[i] := Trim(s);
    end;
  end;
end;

procedure TMainForm.ListSaves;
var sr: TSearchRec; fname, disp: string; n: Integer;
begin
  LoadSaveDescriptions;
  cbSave.Items.Clear;
  FSaveFiles.Clear;
  if FindFirst(GameDir + '\*.SAV', faAnyFile, sr) = 0 then
  begin
    repeat
      if (sr.Attr and faDirectory) = 0 then
      begin
        fname := sr.Name;
        disp := fname;
        n := SlotNumber(fname);
        if (n >= 1) and (n <= 14) and (FSaveDesc[n] <> '') then
          disp := fname + '   "' + FSaveDesc[n] + '"';
        FSaveFiles.Add(fname);
        cbSave.Items.Add(disp);
      end;
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  if cbSave.Items.Count > 0 then cbSave.ItemIndex := 0;
end;

procedure TMainForm.DoLoad(Sender: TObject);
var w, c: Integer;
begin
  if cbSave.ItemIndex < 0 then begin SetStatus('Pick a save first.'); Exit; end;
  FSlot := FSaveFiles[cbSave.ItemIndex];
  if not FModel.Load(GameDir + '\' + FSlot) then
  begin SetStatus('Failed to read ' + FSlot); Exit; end;

  // safety: make sure this save matches the game version CoMWedit was built for
  if FModel.DataSize <> EXPECTED_SAVE_SIZE then
    if MessageDlg('Different game version?',
        'This save does not match the Caster of Magic version CoMWedit was built for, '
        + 'so the editable values may be in different places.' + LineEnding + LineEnding
        + 'Editing it could corrupt the save. Open it anyway?',
        mtWarning, [mbYes, mbNo], 0) <> mrYes then
    begin
      SetStatus('Did not open ' + FSlot + ' (looks like a different game version).');
      Exit;
    end;

  cbWiz.Items.Clear;
  for w := 0 to WIZARD_COUNT - 1 do
    if FModel.WizardPresent(w) then
      cbWiz.Items.AddObject(FModel.WizardName(w) + IfThen(w = 0, ' (You)', ''), TObject(PtrInt(w)));
  if cbWiz.Items.Count > 0 then
  begin
    cbWiz.ItemIndex := 0;
    WizSelected(nil);
  end;

  // cities
  PopulateOwnerList;
  cbCity.Items.Clear;
  FCurCity := -1;
  for c := 1 to 500 do
    if FModel.CityPresent(c) then
      cbCity.Items.AddObject(FModel.CityName(c), TObject(PtrInt(c)));
  if cbCity.Items.Count > 0 then begin cbCity.ItemIndex := 0; CitySelected(nil); end;

  // map
  FActiveX := -1; FActiveY := -1;
  cbPlane.ItemIndex := 0;
  UpdateMapScale;
  BuildCityMap(1);
  lblActive.Caption := 'Click a tile on the map to select it.';
  pbMap.Invalidate;

  // heroes
  cbHWiz.Items.Clear; FHWiz := -1;
  for w := 0 to WIZARD_COUNT - 1 do
    if FModel.WizardPresent(w) then
      cbHWiz.Items.AddObject(FModel.WizardName(w) + IfThen(w = 0, ' (You)', ''), TObject(PtrInt(w)));
  if cbHWiz.Items.Count > 0 then cbHWiz.ItemIndex := 0;
  HeroRefresh(nil);

  btnSave.Enabled := True;
  btnSaveAs.Enabled := True;
  SetStatus(Format('Loaded %s — %d wizards, %d cities.', [FSlot, cbWiz.Items.Count, cbCity.Items.Count]));
end;

procedure TMainForm.DoSave(Sender: TObject);
var path, bak: string; fs, fd: TFileStream; madeBackup: Boolean;
begin
  if not FModel.Loaded then Exit;
  path := GameDir + '\' + FSlot;
  bak := path + '.bak';
  madeBackup := False;
  // preserve the ORIGINAL save: make the backup once and never overwrite it
  if FileExists(path) and not FileExists(bak) then
    try
      fs := TFileStream.Create(path, fmOpenRead or fmShareDenyNone);
      try
        fd := TFileStream.Create(bak, fmCreate);
        try fd.CopyFrom(fs, fs.Size); finally fd.Free; end;
      finally fs.Free; end;
      madeBackup := True;
    except
    end;
  FModel.Save(path);
  if madeBackup then
    SetStatus(Format('Saved %s. Original backed up to %s.bak. Load it in the game.', [FSlot, FSlot]))
  else
    SetStatus(Format('Saved %s. (Original already backed up as %s.bak.) Load it in the game.', [FSlot, FSlot]));
end;

procedure TMainForm.DoSaveAs(Sender: TObject);
var dlg: TSaveDialog;
begin
  if not FModel.Loaded then Exit;
  dlg := TSaveDialog.Create(Self);
  try
    dlg.InitialDir := GameDir;
    dlg.Filter := 'Caster saves|*.SAV;*.sav';
    dlg.DefaultExt := 'SAV';
    dlg.FileName := FSlot;
    dlg.Options := dlg.Options + [ofOverwritePrompt];
    if dlg.Execute then
    begin
      FModel.Save(dlg.FileName);
      SetStatus('Saved as ' + ExtractFileName(dlg.FileName) + '. (Use a slot name like 1.sav to see it in-game.)');
    end;
  finally
    dlg.Free;
  end;
end;

procedure TMainForm.WizSelected(Sender: TObject);
begin
  if cbWiz.ItemIndex < 0 then Exit;
  FCurWiz := PtrInt(cbWiz.Items.Objects[cbWiz.ItemIndex]);
  LoadWizardToUI;
end;

procedure TMainForm.LoadWizardToUI;
var i: Integer;
begin
  if (FCurWiz < 0) or not FModel.Loaded then Exit;
  FUpdating := True;
  try
    seGold.Value := FModel.WizGold(FCurWiz);
    seMana.Value := FModel.WizMana(FCurWiz);
    seSP.Value   := FModel.WizSkill(FCurWiz);
    seFame.Value := FModel.WizFame(FCurWiz);
    if FCurWiz = 0 then           // your own wizard: relation-to-self is meaningless
    begin
      seRep.Value := 0; seRep.Enabled := False;
    end
    else
    begin
      seRep.Value := FModel.WizRelation(FCurWiz); seRep.Enabled := True;
    end;
    for i := 1 to 5 do seBook[i].Value := FModel.WizBook(FCurWiz, i);
    for i := 1 to 18 do chkRet[i].Checked := FModel.WizRetort(FCurWiz, i);
  finally
    FUpdating := False;
  end;
end;

procedure TMainForm.BookChanged(Sender: TObject);
begin
  if FUpdating or (FCurWiz < 0) or not FModel.Loaded then Exit;
  FModel.SetWizBook(FCurWiz, TSpinEdit(Sender).Tag, TSpinEdit(Sender).Value);
  SetStatus('Edited ' + FModel.WizardName(FCurWiz) + ' (not saved yet).');
end;

procedure TMainForm.LoadRetortData;
var ini: TIniFile; i: Integer;
begin
  for i := 1 to 18 do begin FRetortName[i] := RETORT_NAMES[i]; FRetortExcl[i] := 0; end;
  if not FileExists(GameDir + '\Data\retorts.ini') then Exit;
  ini := TIniFile.Create(GameDir + '\Data\retorts.ini');
  try
    for i := 1 to 18 do
    begin
      FRetortName[i] := ini.ReadString(IntToStr(i), 'Name', RETORT_NAMES[i]);
      FRetortExcl[i] := ini.ReadInteger(IntToStr(i), 'Exclusive', 0);
    end;
  finally
    ini.Free;
  end;
end;

procedure TMainForm.RetortChanged(Sender: TObject);
var r, i, n: Integer;
begin
  if FUpdating or (FCurWiz < 0) or not FModel.Loaded then Exit;
  r := TCheckBox(Sender).Tag;
  FModel.SetWizRetort(FCurWiz, r, chkRet[r].Checked);
  // too-many-retorts caution (Mirror advisor displays them in a fixed area and can crash)
  if chkRet[r].Checked then
  begin
    n := 0;
    for i := 1 to 18 do if chkRet[i].Checked then Inc(n);
    if n >= 4 then
    begin
      SetStatus(RETORT_WARN);
      if n = 4 then ShowMessage(RETORT_WARN);   // pop up once, when first crossing the threshold
    end;
  end;
  SetStatus('Edited ' + FModel.WizardName(FCurWiz) + ' (not saved yet).');
end;

procedure TMainForm.WizFieldChanged(Sender: TObject);
var v: Integer;
begin
  if FUpdating or (FCurWiz < 0) or not FModel.Loaded then Exit;
  v := TSpinEdit(Sender).Value;
  case TSpinEdit(Sender).Tag of
    1: FModel.SetWizGold(FCurWiz, v);
    2: FModel.SetWizMana(FCurWiz, v);
    3: FModel.SetWizSkill(FCurWiz, v);
    4: FModel.SetWizFame(FCurWiz, v);
    6: if FCurWiz <> 0 then FModel.SetWizRelation(FCurWiz, v);
  end;
  SetStatus('Edited ' + FModel.WizardName(FCurWiz) + ' (not saved yet).');
end;

procedure TMainForm.PopulateOwnerList;
var w: Integer;
begin
  cbCityOwner.Items.Clear;
  for w := 0 to WIZARD_COUNT - 1 do
    if FModel.WizardPresent(w) then
      cbCityOwner.Items.AddObject(FModel.WizardName(w), TObject(PtrInt(w)));
  cbCityOwner.Items.AddObject('Neutral', TObject(PtrInt(NEUTRAL_ID)));
end;

procedure TMainForm.CitySelected(Sender: TObject);
var ownerId, i: Integer;
begin
  if cbCity.ItemIndex < 0 then Exit;
  FCurCity := PtrInt(cbCity.Items.Objects[cbCity.ItemIndex]);
  FUpdating := True;
  try
    edCityName.Text := FModel.CityName(FCurCity);
    seCityPop.Value := FModel.CityPop(FCurCity);
    ownerId := FModel.CityOwner(FCurCity);
    cbCityOwner.ItemIndex := -1;
    for i := 0 to cbCityOwner.Items.Count - 1 do
      if PtrInt(cbCityOwner.Items.Objects[i]) = ownerId then begin cbCityOwner.ItemIndex := i; Break; end;
    if (FModel.CityRace(FCurCity) >= 0) and (FModel.CityRace(FCurCity) <= High(RACE_NAMES)) then
      cbCityRace.ItemIndex := FModel.CityRace(FCurCity)
    else
      cbCityRace.ItemIndex := -1;
  finally
    FUpdating := False;
  end;
end;

procedure TMainForm.CityFieldChanged(Sender: TObject);
begin
  if FUpdating or (FCurCity < 1) or not FModel.Loaded then Exit;
  case TComponent(Sender).Tag of
    1: if cbCityOwner.ItemIndex >= 0 then
         FModel.SetCityOwner(FCurCity, PtrInt(cbCityOwner.Items.Objects[cbCityOwner.ItemIndex]));
    2: FModel.SetCityPop(FCurCity, seCityPop.Value);
    3: if cbCityRace.ItemIndex >= 0 then FModel.SetCityRace(FCurCity, cbCityRace.ItemIndex);
  end;
  if FModel.Loaded then pbMap.Invalidate;   // owner change recolors the city on the map
  SetStatus('Edited city ' + FModel.CityName(FCurCity) + ' (not saved yet).');
end;

procedure TMainForm.CityNameDone(Sender: TObject);
var nm: string;
begin
  if FUpdating or (FCurCity < 1) or not FModel.Loaded then Exit;
  nm := Trim(edCityName.Text);
  if (nm = '') or (nm = FModel.CityName(FCurCity)) then Exit;
  FModel.SetCityName(FCurCity, nm);
  FUpdating := True;
  try
    if cbCity.ItemIndex >= 0 then          // re-insert so the sorted dropdown stays alphabetical
    begin
      cbCity.Items.Delete(cbCity.ItemIndex);
      cbCity.ItemIndex := cbCity.Items.AddObject(nm, TObject(PtrInt(FCurCity)));
    end;
  finally
    FUpdating := False;
  end;
  SetStatus('Renamed city to "' + nm + '" (not saved yet).');
end;

procedure TMainForm.MapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var cur: TPoint;
begin
  if not FPanning then Exit;
  cur := Mouse.CursorPos;
  scbMap.HorzScrollBar.Position := FPanScroll0.X - (cur.X - FPanMouse.X);
  scbMap.VertScrollBar.Position := FPanScroll0.Y - (cur.Y - FPanMouse.Y);
end;

procedure TMainForm.MapMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbMiddle then FPanning := False;
end;

procedure TMainForm.MapWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if ssCtrl in Shift then         // Ctrl + wheel = zoom; plain wheel still scrolls the box
  begin
    if WheelDelta > 0 then SetMapZoom(FMapScale + 2) else SetMapZoom(FMapScale - 2);
    Handled := True;
  end;
end;

procedure TMainForm.OreChanged(Sender: TObject);
begin
  if FUpdating or not FModel.Loaded or (FActiveX < 1) then Exit;
  FModel.SetTileOre(cbPlane.ItemIndex + 1, FActiveX, FActiveY, cbOre.ItemIndex);
  lblActive.Caption := Format('Active tile (%d, %d): %s (not saved yet).',
    [FActiveX, FActiveY, ORE_NAMES[cbOre.ItemIndex]]);
  pbMap.Invalidate;
  SetStatus('Set ' + ORE_NAMES[cbOre.ItemIndex] + ' on a map tile (not saved yet).');
end;

procedure TMainForm.LoadSpellNames;
var b: TBytes; fs: TFileStream; id, off, len, i: Integer; s: string; fn: string;
begin
  for id := 0 to MAX_SPELL_ID do begin FSpellName[id] := ''; FSpellRealm[id] := 0; end;
  fn := GameDir + '\Spells.dat';
  if not FileExists(fn) then Exit;
  fs := TFileStream.Create(fn, fmOpenRead or fmShareDenyNone);
  try
    SetLength(b, fs.Size);
    if fs.Size > 0 then fs.ReadBuffer(b[0], fs.Size);
  finally
    fs.Free;
  end;
  for id := 0 to MAX_SPELL_ID do
  begin
    off := id * SPELLDAT_STRIDE;
    if off + 56 >= Length(b) then Break;
    len := b[off];
    if (len >= 1) and (len <= 30) and (off + len < Length(b)) then
    begin
      s := '';
      for i := 1 to len do s := s + Chr(b[off + i]);
      FSpellName[id] := s;
      FSpellRealm[id] := PInteger(@b[off + 52])^;   // Realm field (1..6)
    end;
  end;
end;

procedure TLiveGrid.WMVScroll(var Msg: TLMVScroll);
begin
  if Msg.ScrollCode = SB_THUMBTRACK then
    Msg.ScrollCode := SB_THUMBPOSITION;   // treat "dragging" as "moved" -> live update
  inherited;
end;

procedure TMainForm.ShowSpellEditor(Sender: TObject);
var dlg: TForm; pnl: TPanel; grid: TStringGrid; lbl: TLabel;
    id, row, st, realm, status: Integer;
begin
  if (FCurWiz < 0) or not FModel.Loaded then Exit;
  dlg := TForm.CreateNew(Self);
  try
    dlg.Scaled := False;
    dlg.Caption := 'Spells — ' + FModel.WizardName(FCurWiz);
    dlg.Width := 480; dlg.Height := 680; dlg.Position := poScreenCenter;

    // bulk-set grid: one row per realm (+ All), three buttons (Unknown/Researchable/Known)
    pnl := TPanel.Create(dlg); pnl.Parent := dlg; pnl.Align := alTop; pnl.Height := 232;
    pnl.BevelOuter := bvNone;
    lbl := TLabel.Create(dlg); lbl.Parent := pnl; lbl.Left := 8; lbl.Top := 2; lbl.Caption := 'Set spells to:';
    for realm := 0 to 6 do
    begin
      lbl := TLabel.Create(dlg); lbl.Parent := pnl;
      lbl.Left := 8; lbl.Top := 22 + realm * 28 + 4; lbl.Caption := REALM7_NAMES[realm];
      for status := 0 to 2 do
        with TButton.Create(dlg) do
        begin
          Parent := pnl; Left := 70 + status * 132; Top := 22 + realm * 28; Width := 128; Height := 24;
          Caption := SPELL_STATUS_NAMES[status]; Tag := realm * 10 + status; OnClick := @SpellBulk;
        end;
    end;

    grid := TLiveGrid.Create(dlg); grid.Parent := dlg; grid.Align := alClient;
    grid.ColCount := 2; grid.FixedCols := 0; grid.FixedRows := 1; grid.RowCount := 1;
    grid.Cells[0, 0] := 'Spell'; grid.Cells[1, 0] := 'Status (click to change)';
    grid.ColWidths[0] := 230; grid.ColWidths[1] := 170;
    grid.Options := grid.Options - [goEditing] + [goRowSelect, goSmoothScroll];
    grid.MouseWheelOption := mwGrid;     // wheel scrolls the list instead of moving the selection
    grid.OnMouseDown := @SpellGridMouseDown;
    FSpellGrid := grid;

    row := 0;
    for id := 1 to MAX_SPELL_ID do
      if FSpellName[id] <> '' then
      begin
        Inc(row);
        grid.RowCount := row + 1;
        grid.Cells[0, row] := FSpellName[id];
        st := FModel.WizSpellStatus(FCurWiz, id);
        if (st < 0) or (st > 3) then st := 0;
        grid.Cells[1, row] := SPELL_STATUS_NAMES[st];
        grid.Objects[0, row] := TObject(PtrInt(id));
      end;

    dlg.ShowModal;
  finally
    FSpellGrid := nil;
    dlg.Free;
  end;
end;

procedure TMainForm.SpellGridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var c, r, id, st: Integer;
begin
  if FSpellGrid = nil then Exit;
  FSpellGrid.MouseToCell(X, Y, c, r);
  if (r < 1) or (c <> 1) then Exit;
  id := PtrInt(FSpellGrid.Objects[0, r]);
  if id <= 0 then Exit;
  st := FModel.WizSpellStatus(FCurWiz, id);
  case st of            // cycle Unknown -> Researchable -> Known -> Unknown
    0: st := 1;
    1: st := 2;
  else st := 0;
  end;
  FModel.SetWizSpellStatus(FCurWiz, id, st);
  FSpellGrid.Cells[1, r] := SPELL_STATUS_NAMES[st];
  SetStatus('Edited spells for ' + FModel.WizardName(FCurWiz) + ' (not saved yet).');
end;

procedure TMainForm.SpellBulk(Sender: TObject);
var btnTag, realm, status, id, r, sv: Integer;
begin
  if (FSpellGrid = nil) or (FCurWiz < 0) then Exit;
  btnTag := TComponent(Sender).Tag;
  realm := btnTag div 10;          // 0 = all realms, 1..6 = specific realm
  status := btnTag mod 10;         // 0/1/2
  for id := 1 to MAX_SPELL_ID do
    if (FSpellName[id] <> '') and ((realm = 0) or (FSpellRealm[id] = realm)) then
      FModel.SetWizSpellStatus(FCurWiz, id, status);
  // refresh the grid's status column
  for r := 1 to FSpellGrid.RowCount - 1 do
  begin
    id := PtrInt(FSpellGrid.Objects[0, r]);
    sv := FModel.WizSpellStatus(FCurWiz, id);
    if (sv < 0) or (sv > 3) then sv := 0;
    FSpellGrid.Cells[1, r] := SPELL_STATUS_NAMES[sv];
  end;
  SetStatus(Format('Set %s spells to %s for %s (not saved yet).',
    [REALM7_NAMES[realm], SPELL_STATUS_NAMES[status], FModel.WizardName(FCurWiz)]));
end;

procedure TMainForm.LoadHeroData;
var ini: TIniFile; secs: TStringList; i, ht: Integer; sec: string;
begin
  for i := 1 to MAX_HERO_TYPES do FHeroTypeName[i] := '';
  for i := 1 to MAX_HERO_ABIL do begin FAbilName[i] := ''; FAbilSuper[i] := False; end;
  FHeroTypeCount := 0; FAbilCount := 0;
  if FileExists(GameDir + '\Data\UNITS.INI') then
  begin
    ini := TIniFile.Create(GameDir + '\Data\UNITS.INI');
    secs := TStringList.Create;
    try
      ini.ReadSections(secs);
      for i := 0 to secs.Count - 1 do
      begin
        sec := secs[i];
        ht := ini.ReadInteger(sec, 'HeroType', 0);
        if (ht >= 1) and (ht <= MAX_HERO_TYPES) then
        begin
          FHeroTypeName[ht] := ini.ReadString(sec, 'Name', 'Hero ' + IntToStr(ht));
          if ht > FHeroTypeCount then FHeroTypeCount := ht;
        end;
      end;
    finally
      secs.Free; ini.Free;
    end;
  end;
  if FileExists(GameDir + '\Data\heroabil.ini') then
  begin
    ini := TIniFile.Create(GameDir + '\Data\heroabil.ini');
    try
      i := 1;
      while (i <= MAX_HERO_ABIL) and (ini.ReadString(IntToStr(i), 'Name', '') <> '') do
      begin
        FAbilName[i] := ini.ReadString(IntToStr(i), 'Name', '');
        FAbilSuper[i] := SameText(ini.ReadString(IntToStr(i), 'Super', 'No'), 'Yes');
        FAbilCount := i;
        Inc(i);
      end;
    finally
      ini.Free;
    end;
  end;
end;

procedure TMainForm.BuildHeroesTab;
var lbl: TLabel; i, col, row, x, y: Integer;
begin
  lbl := TLabel.Create(Self); lbl.Parent := tsHero; lbl.Left := 16; lbl.Top := 16; lbl.Caption := 'Wizard:';
  cbHWiz := TComboBox.Create(Self);
  cbHWiz.Parent := tsHero; cbHWiz.Left := 70; cbHWiz.Top := 12; cbHWiz.Width := 180;
  cbHWiz.Style := csDropDownList; cbHWiz.OnChange := @HeroRefresh;
  lbl := TLabel.Create(Self); lbl.Parent := tsHero; lbl.Left := 268; lbl.Top := 16; lbl.Caption := 'Hero:';
  cbHero := TComboBox.Create(Self);
  cbHero.Parent := tsHero; cbHero.Left := 308; cbHero.Top := 12; cbHero.Width := 200;
  cbHero.Style := csDropDownList; cbHero.Sorted := True; cbHero.OnChange := @HeroRefresh;
  for i := 1 to FHeroTypeCount do
    if FHeroTypeName[i] <> '' then cbHero.Items.AddObject(FHeroTypeName[i], TObject(PtrInt(i)));
  if cbHero.Items.Count > 0 then cbHero.ItemIndex := 0;

  for i := 1 to FAbilCount do
  begin
    col := (i - 1) div 12; row := (i - 1) mod 12;
    x := 16 + col * 276; y := 52 + row * 26;
    chkAbil[i] := TCheckBox.Create(Self); chkAbil[i].Parent := tsHero;
    chkAbil[i].Left := x; chkAbil[i].Top := y; chkAbil[i].Width := 168;
    chkAbil[i].Caption := FAbilName[i]; chkAbil[i].Tag := i; chkAbil[i].OnChange := @AbilChanged;
    if FAbilSuper[i] then
    begin
      chkSuper[i] := TCheckBox.Create(Self); chkSuper[i].Parent := tsHero;
      chkSuper[i].Left := x + 176; chkSuper[i].Top := y; chkSuper[i].Width := 66;
      chkSuper[i].Caption := 'Super'; chkSuper[i].Tag := i; chkSuper[i].OnChange := @SuperChanged;
    end;
  end;
end;

procedure TMainForm.HeroRefresh(Sender: TObject);
var i, lv: Integer;
begin
  if not FModel.Loaded then Exit;
  if (cbHWiz.ItemIndex < 0) or (cbHero.ItemIndex < 0) then Exit;
  FHWiz := PtrInt(cbHWiz.Items.Objects[cbHWiz.ItemIndex]);
  FHero := PtrInt(cbHero.Items.Objects[cbHero.ItemIndex]);
  FUpdating := True;
  try
    for i := 1 to FAbilCount do
    begin
      lv := FModel.HeroAbility(FHWiz, FHero, i);
      chkAbil[i].Checked := lv >= 1;
      if Assigned(chkSuper[i]) then
      begin
        chkSuper[i].Enabled := lv >= 1;
        chkSuper[i].Checked := lv = 2;
      end;
    end;
  finally
    FUpdating := False;
  end;
end;

procedure TMainForm.AbilChanged(Sender: TObject);
var i, lv: Integer;
begin
  if FUpdating or not FModel.Loaded or (FHWiz < 0) then Exit;
  i := TComponent(Sender).Tag;
  if chkAbil[i].Checked then lv := 1 else lv := 0;
  FUpdating := True;
  try
    if Assigned(chkSuper[i]) then
    begin
      chkSuper[i].Enabled := lv >= 1;
      if lv = 0 then chkSuper[i].Checked := False
      else if chkSuper[i].Checked then lv := 2;
    end;
  finally
    FUpdating := False;
  end;
  FModel.SetHeroAbility(FHWiz, FHero, i, lv);
  SetStatus('Edited hero abilities (not saved yet).');
end;

procedure TMainForm.SuperChanged(Sender: TObject);
var i, lv: Integer;
begin
  if FUpdating or not FModel.Loaded or (FHWiz < 0) then Exit;
  i := TComponent(Sender).Tag;
  if not chkAbil[i].Checked then Exit;
  if chkSuper[i].Checked then lv := 2 else lv := 1;
  FModel.SetHeroAbility(FHWiz, FHero, i, lv);
  SetStatus('Edited hero abilities (not saved yet).');
end;

begin
  Application.Scaled := False;   // code-built form: avoid font/position scaling mismatch on high-DPI
  Application.Initialize;
  MainForm := TMainForm.CreateNew(Application);
  MainForm.Show;
  Application.Run;
end.

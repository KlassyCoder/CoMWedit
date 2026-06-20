unit SaveModel;
{
  In-memory model of a loaded .SAV: holds the decompressed save.tmp bytes and exposes
  typed read/write accessors built on the verified Offsets table. No DLL needed.
  The UI edits through this; Save writes the bytes back into a .SAV zip.
}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, SaveFile, Offsets;

type
  TSaveModel = class
  private
    FData: TBytes;
    FLoaded: Boolean;
    FDirty: Boolean;
    function GetI32(off: Integer): Integer;
    procedure SetI32(off, v: Integer);
    function GetI16(off: Integer): Integer;
    procedure SetI16(off, v: Integer);
    function GetByte(off: Integer): Integer;
    procedure SetByteAt(off, v: Integer);
    function GetShortStr(off: Integer): string;
    procedure SetShortStr(off: Integer; const s: string; maxlen: Integer);
  public
    function Load(const path: string): Boolean;
    procedure Save(const path: string);
    property Loaded: Boolean read FLoaded;
    property Dirty: Boolean read FDirty;
    function DataSize: Integer;

    // --- wizards ---
    // A wizard slot is "present" if it has a non-empty name.
    function WizardPresent(w: Integer): Boolean;
    function WizardName(w: Integer): string;
    function WizGold(w: Integer): Integer;            procedure SetWizGold(w, v: Integer);
    function WizMana(w: Integer): Integer;            procedure SetWizMana(w, v: Integer);
    function WizSP(w: Integer): Integer;              procedure SetWizSP(w, v: Integer);
    // Casting skill = floor(sqrt(SP)); we let the UI edit the skill number directly.
    function WizSkill(w: Integer): Integer;           procedure SetWizSkill(w, skill: Integer);
    function WizFame(w: Integer): Integer;            procedure SetWizFame(w, v: Integer);
    function WizTax(w: Integer): Integer;             procedure SetWizTax(w, v: Integer);
    function WizRelation(w: Integer): Integer;        procedure SetWizRelation(w, v: Integer);
    function WizBook(w, realm: Integer): Integer;     procedure SetWizBook(w, realm, v: Integer);
    function WizRetort(w, r: Integer): Boolean;       procedure SetWizRetort(w, r: Integer; on_: Boolean);
    function WizSpellStatus(w, sp: Integer): Integer; procedure SetWizSpellStatus(w, sp, status: Integer);
    function HeroAbility(w, ht, ha: Integer): Integer; procedure SetHeroAbility(w, ht, ha, lv: Integer);

    // --- cities ---
    function CityName(c: Integer): string;
    procedure SetCityName(c: Integer; const s: string);
    function CityPresent(c: Integer): Boolean;
    function CityOwner(c: Integer): Integer;          procedure SetCityOwner(c, v: Integer);
    function CityPop(c: Integer): Integer;            procedure SetCityPop(c, v: Integer);
    function CityRace(c: Integer): Integer;           procedure SetCityRace(c, v: Integer);
    function CityPlane(c: Integer): Integer;
    function CityX(c: Integer): Integer;
    function CityY(c: Integer): Integer;

    // --- map ---
    function TileOre(plane, x, y: Integer): Integer;  procedure SetTileOre(plane, x, y, v: Integer);
    function TileLand(plane, x, y: Integer): Integer;
    function TileCorrupt(plane, x, y: Integer): Boolean;
    procedure SetTileCorrupt(plane, x, y: Integer; on_: Boolean);
    function PlaneW(plane: Integer): Integer;
    function PlaneH(plane: Integer): Integer;
  end;

implementation

function TSaveModel.GetI32(off: Integer): Integer; begin Result := PInteger(@FData[off])^; end;
procedure TSaveModel.SetI32(off, v: Integer); begin PInteger(@FData[off])^ := v; FDirty := True; end;
function TSaveModel.GetI16(off: Integer): Integer; begin Result := PSmallInt(@FData[off])^; end;
procedure TSaveModel.SetI16(off, v: Integer); begin PSmallInt(@FData[off])^ := SmallInt(v); FDirty := True; end;
function TSaveModel.GetByte(off: Integer): Integer; begin Result := FData[off]; end;
procedure TSaveModel.SetByteAt(off, v: Integer); begin FData[off] := Byte(v); FDirty := True; end;

function TSaveModel.GetShortStr(off: Integer): string;
var n, i: Integer;
begin
  Result := '';
  n := FData[off];
  for i := 1 to n do Result := Result + Chr(FData[off + i]);
end;

procedure TSaveModel.SetShortStr(off: Integer; const s: string; maxlen: Integer);
var n, i: Integer;
begin
  n := Length(s);
  if n > maxlen then n := maxlen;
  FData[off] := Byte(n);
  for i := 1 to n do FData[off + i] := Byte(Ord(s[i]));
  FDirty := True;
end;

function TSaveModel.Load(const path: string): Boolean;
begin
  Result := False;
  FLoaded := False;
  FData := LoadSaveTmp(path);
  FLoaded := Length(FData) > 0;
  FDirty := False;
  Result := FLoaded;
end;

procedure TSaveModel.Save(const path: string);
begin
  WriteSaveTmp(path, FData);
  FDirty := False;
end;

function TSaveModel.DataSize: Integer;
begin
  Result := Length(FData);
end;

// --- wizards ---
function TSaveModel.WizardPresent(w: Integer): Boolean;
begin
  Result := FLoaded and (w >= 0) and (w < WIZARD_COUNT) and (FData[Offsets.WizField(w, W0_NAME)] > 0);
end;

function TSaveModel.WizardName(w: Integer): string;
begin Result := GetShortStr(Offsets.WizField(w, W0_NAME)); end;

function TSaveModel.WizGold(w: Integer): Integer; begin Result := GetI32(Offsets.WizGold(w)); end;
procedure TSaveModel.SetWizGold(w, v: Integer); begin SetI32(Offsets.WizGold(w), v); end;
function TSaveModel.WizMana(w: Integer): Integer; begin Result := GetI32(Offsets.WizMana(w)); end;
procedure TSaveModel.SetWizMana(w, v: Integer); begin SetI32(Offsets.WizMana(w), v); end;
function TSaveModel.WizSP(w: Integer): Integer; begin Result := GetI32(Offsets.WizSP(w)); end;
procedure TSaveModel.SetWizSP(w, v: Integer); begin SetI32(Offsets.WizSP(w), v); end;
function TSaveModel.WizSkill(w: Integer): Integer; begin Result := Trunc(Sqrt(WizSP(w))); end;
procedure TSaveModel.SetWizSkill(w, skill: Integer);
begin
  SetWizSP(w, skill * skill);                                 // the pool -> new max skill
  SetI32(Offsets.WizField(w, W0_OVERLANDSKILL), skill);       // also give it to spend THIS turn
end;
function TSaveModel.WizFame(w: Integer): Integer; begin Result := GetI32(Offsets.WizFame(w)); end;
procedure TSaveModel.SetWizFame(w, v: Integer); begin SetI32(Offsets.WizFame(w), v); end;
function TSaveModel.WizTax(w: Integer): Integer; begin Result := GetI32(Offsets.WizField(w, W0_TAX)); end;
procedure TSaveModel.SetWizTax(w, v: Integer); begin SetI32(Offsets.WizField(w, W0_TAX), v); end;
function TSaveModel.WizRelation(w: Integer): Integer; begin Result := GetI32(Offsets.WizField(w, W0_RELATION)); end;
procedure TSaveModel.SetWizRelation(w, v: Integer);
begin
  SetI32(Offsets.WizField(w, W0_RELATION), v);        // visible relation
  SetI32(Offsets.WizField(w, W0_RELATION) + 4, v);    // hidden relation (so it doesn't drift back)
end;

function TSaveModel.WizBook(w, realm: Integer): Integer; begin Result := GetI32(Offsets.WizBook(w, realm)); end;
procedure TSaveModel.SetWizBook(w, realm, v: Integer); begin SetI32(Offsets.WizBook(w, realm), v); end;
function TSaveModel.WizRetort(w, r: Integer): Boolean; begin Result := GetByte(Offsets.WizRetort(w, r)) <> 0; end;
procedure TSaveModel.SetWizRetort(w, r: Integer; on_: Boolean);
begin if on_ then SetByteAt(Offsets.WizRetort(w, r), 1) else SetByteAt(Offsets.WizRetort(w, r), 0); end;
function TSaveModel.WizSpellStatus(w, sp: Integer): Integer; begin Result := GetI32(Offsets.WizSpell(w, sp)); end;
procedure TSaveModel.SetWizSpellStatus(w, sp, status: Integer); begin SetI32(Offsets.WizSpell(w, sp), status); end;
function TSaveModel.HeroAbility(w, ht, ha: Integer): Integer; begin Result := GetI32(Offsets.HeroAbilityPos(w, ht, ha)); end;
procedure TSaveModel.SetHeroAbility(w, ht, ha, lv: Integer); begin SetI32(Offsets.HeroAbilityPos(w, ht, ha), lv); end;

// --- cities ---
function TSaveModel.CityName(c: Integer): string; begin Result := GetShortStr(Offsets.CityFieldPos(c, C_NAME)); end;
procedure TSaveModel.SetCityName(c: Integer; const s: string); begin SetShortStr(Offsets.CityFieldPos(c, C_NAME), s, 30); end;
function TSaveModel.CityPresent(c: Integer): Boolean;
var n, base, i, ch: Integer;
begin
  Result := False;
  if not FLoaded then Exit;
  base := Offsets.CityFieldPos(c, C_NAME);
  n := FData[base];
  if (n < 1) or (n > 20) then Exit;          // empty or implausible -> not a real city
  for i := 1 to n do
  begin
    ch := FData[base + i];
    if (ch < 32) or (ch > 126) then Exit;     // non-printable -> garbage slot
  end;
  Result := True;
end;
function TSaveModel.CityOwner(c: Integer): Integer; begin Result := GetByte(Offsets.CityFieldPos(c, C_OWNER)); end;
procedure TSaveModel.SetCityOwner(c, v: Integer); begin SetByteAt(Offsets.CityFieldPos(c, C_OWNER), v); end;
function TSaveModel.CityPop(c: Integer): Integer; begin Result := GetI16(Offsets.CityFieldPos(c, C_POP)); end;
procedure TSaveModel.SetCityPop(c, v: Integer); begin SetI16(Offsets.CityFieldPos(c, C_POP), v); end;
function TSaveModel.CityRace(c: Integer): Integer; begin Result := GetByte(Offsets.CityFieldPos(c, C_RACE)); end;
procedure TSaveModel.SetCityRace(c, v: Integer); begin SetByteAt(Offsets.CityFieldPos(c, C_RACE), v); end;
function TSaveModel.CityPlane(c: Integer): Integer; begin Result := GetByte(Offsets.CityFieldPos(c, C_PLANE)); end;
function TSaveModel.CityX(c: Integer): Integer; begin Result := GetI16(Offsets.CityFieldPos(c, C_X)); end;
function TSaveModel.CityY(c: Integer): Integer; begin Result := GetI16(Offsets.CityFieldPos(c, C_Y)); end;

// --- map ore ---
function TSaveModel.TileOre(plane, x, y: Integer): Integer; begin Result := GetI32(Offsets.TileOrePos(plane, x, y)); end;
procedure TSaveModel.SetTileOre(plane, x, y, v: Integer); begin SetI32(Offsets.TileOrePos(plane, x, y), v); end;
function TSaveModel.TileLand(plane, x, y: Integer): Integer; begin Result := GetI32(Offsets.TileLandPos(plane, x, y)); end;
function TSaveModel.TileCorrupt(plane, x, y: Integer): Boolean; begin Result := GetByte(Offsets.TileCorruptPos(plane, x, y)) <> 0; end;
procedure TSaveModel.SetTileCorrupt(plane, x, y: Integer; on_: Boolean);
begin if on_ then SetByteAt(Offsets.TileCorruptPos(plane, x, y), 1) else SetByteAt(Offsets.TileCorruptPos(plane, x, y), 0); end;
function TSaveModel.PlaneW(plane: Integer): Integer; begin Result := GetI16(Offsets.MAP_PLANE_W0 + (plane - 1) * 2); end;
function TSaveModel.PlaneH(plane: Integer): Integer; begin Result := GetI16(Offsets.MAP_PLANE_H0 + (plane - 1) * 2); end;

end.

unit Offsets;
{
  Verified byte offsets into the decompressed save.tmp (a raw GameDataType dump).

  These were found EMPIRICALLY with the locator tools (protoE/F/G/H): read a field for
  all wizards via the DLL, then find the byte offset where every wizard's value matches at
  the wizard stride, intersected across multiple saves. They are checked against the real
  game binary, NOT the shipped .pas record definitions (which are a different version and
  do NOT match the binary layout).

  Convention: the W0_* constants are FILE offsets for WIZARD 0. For wizard w, add
  w * WIZARD_STRIDE. Helper functions below do this.

  Game/save version: matches CasApi.dll shipped 2023 (SharedConstants VERSION 1.05.00).
  If a save fails the gold-offset sanity check, treat it as a different layout/version.
}
{$mode delphi}

interface

const
  // The decompressed save.tmp is a fixed-size dump of GameDataType for this game version.
  // A different size means a different game build -> our offsets won't match.
  EXPECTED_SAVE_SIZE = 184755608;

  WIZARD_STRIDE = 1658040;   // sizeof(WizardT) measured from the dump
  WIZARD_COUNT  = 14;        // slots 0..13  (human player = 0, AI = 1..13)
  WIZARD0_BASE  = 8;         // file offset where wizard 0's slot begins

  // --- per-wizard field offsets (FILE offset for wizard 0; add w*WIZARD_STRIDE) ---
  W0_NAME    = 46;       // shortstring[30] : length byte then chars (slot base 8 + 38)
  W0_BOOKS   = 8;        // int32 x5  : realm r(1..5)  at  W0_BOOKS   + (r-1)*4
  W0_RETORTS = 28;       // byte  x18 : retort r(1..18) at W0_RETORTS + (r-1)  ; 0/1
  W0_SP      = 116;      // int32 : skill-points pool. Casting skill = floor(sqrt(SP)).
                         //         To set casting skill = K, store SP = K*K. (verified protoR)
  W0_MANA    = 120;      // int32
  W0_GOLD    = 124;      // int32
  W0_FAME    = 128;      // int32
  W0_TAX     = 132;      // int32 : tax rate level
  W0_PDMANA  = 136;      // int32 : power distribution % to mana
  W0_PDRES   = 140;      // int32 : power distribution % to research
  W0_PDSKILL = 144;      // int32 : power distribution % to skill
  W0_SPELLS  = 564060;   // int32 x400 : spell sp(1..N) at W0_SPELLS + (sp-1)*4 ; status 0..3
  W0_RELATION = 160;     // int32 : this wizard's relation toward the human (Diplomacy[0].Relation), -100..100
                         //         (HiddenRelation is the next int at 164; we set both so the edit sticks)
  W0_OVERLANDSKILL = 989496; // int32 : remaining overland casting skill this turn (stored)
  W0_CURRESEARCH   = 989500; // int32 : spell ID currently being researched
  W0_CURCASTING    = 989504; // int32 : spell ID currently being cast (overland)
  // NOTE: max casting skill is COMPUTED from the SP pool (W0_SP); there is no stored "max skill".

  NUM_REALMS  = 5;
  NUM_RETORTS = 18;
  MAX_SPELLS  = 400;

  // Hero abilities: WizardT.Hero[heroType][ability], int32 0/1/2 (none/normal/super).
  // array[1..85] of array[1..50] of int32 -> hero-type stride = 50*4 = 200. Verified (protoY).
  HERO_BASE        = 567280;   // Hero[1][1] slot offset
  HERO_TYPE_STRIDE = 200;

  // Spells.dat layout (separate game file): array of 180-byte records; spell name is a
  // shortstring at id*180 (length byte at id*180, text at +1). Verified vs SharedConstants S* IDs.
  SPELLDAT_STRIDE = 180;

  // spell status (SpellKnown / Spells[] values)
  SPELL_UNKNOWN      = 0;
  SPELL_RESEARCHABLE = 1;
  SPELL_KNOWN        = 2;
  SPELL_ON_LIST      = 3;

  // --- MAP / tiles (verified plane 1 & 2, 0 mismatches) ---
  // Map[plane,x,y] of 60-byte tile records; array allocated 200x200 per plane (NofPlanes=2).
  TILE_STRIDE      = 60;
  MAP_YALLOC       = 200;
  MAP_XALLOC       = 200;
  MAP_X_STRIDE     = MAP_YALLOC * TILE_STRIDE;          // 12,000
  MAP_PLANE_STRIDE = MAP_XALLOC * MAP_YALLOC * TILE_STRIDE; // 2,400,000
  MAP_LANDTYPE0    = 23212572;   // LandType(plane1,x1,y1) file offset
  TILE_ORE_DELTA   = 8;          // OreType is 8 bytes after LandType within a tile
  TILE_CORRUPT_DELTA = 4;        // Corruption (1 byte) is 4 bytes after LandType (record: Elev,Land,Corrupt,Ore)
  // PlaneSizeX/Y (smallint per plane) sit right after the 2-plane map array:
  MAP_PLANE_W0     = 23212568 + 2 * MAP_PLANE_STRIDE;       // 28,012,568 ; +(plane-1)*2
  MAP_PLANE_H0     = 23212568 + 2 * MAP_PLANE_STRIDE + 4;   // 28,012,572 ; +(plane-1)*2
  // landtype values (subset used for the minimap; SharedConstants LT*)
  LT_OCEAN=0; LT_SHORE=1; LT_LAKE=2; LT_RIVERMOUTH=3; LT_GRASS=4; LT_HILL=5; LT_MOUNTAIN=6;
  LT_VOLCANO=7; LT_DESERT=8; LT_SWAMP=9; LT_TUNDRA=10; LT_RIVER=11; LT_FOREST=12;
  LT_CHAOSNODE=13; LT_NATURENODE=14; LT_SORCERYNODE=15;
  // ore type values (data\ore.ini; SharedConstants Ore*)
  ORE_NONE = 0; ORE_WILDGAME = 1; ORE_NIGHTSHADE = 2; ORE_ADAMANTIUM = 3; ORE_MITHRIL = 4;
  ORE_ORIHALCON = 5; ORE_IRON = 6; ORE_COAL = 7; ORE_SILVER = 8; ORE_GOLD = 9;
  ORE_GEMS = 10; ORE_CRYSX = 11; ORE_QUORK = 12;

  // --- CITIES (record stride 1976; cities are 1-based: c = 1..NumberofCities) ---
  CITY_STRIDE = 1976;
  CITY1_BASE  = 182117384;   // file offset of city 1's record (Name field)
  // field offsets within a city record:
  C_NAME  = 0;    // shortstring[30]
  C_RACE  = 31;   // byte
  C_PLANE = 32;   // byte
  C_OWNER = 33;   // byte
  C_X     = 34;   // int16
  C_Y     = 36;   // int16
  C_POP   = 38;   // word (uint16)

// File-offset helpers for wizard w.
function WizGold(w: Integer): Integer;
function WizMana(w: Integer): Integer;
function WizSP(w: Integer): Integer;
function WizFame(w: Integer): Integer;
function WizBook(w, realm: Integer): Integer;     // realm  1..5
function WizRetort(w, retort: Integer): Integer;  // retort 1..18
function WizSpell(w, sp: Integer): Integer;        // spell  1..N
function WizField(w, slotOffset: Integer): Integer; // generic: any W0_* constant

// Map tile field offsets. plane 1..2, x/y 1-based.
function TileLandPos(plane, x, y: Integer): Integer;
function TileOrePos(plane, x, y: Integer): Integer;
function TileCorruptPos(plane, x, y: Integer): Integer;

// City field position. c = 1-based city id, fieldOff one of the C_* constants.
function CityFieldPos(c, fieldOff: Integer): Integer;

// Hero ability position. w wizard, ht hero type (1-based), ha ability (1-based).
function HeroAbilityPos(w, ht, ha: Integer): Integer;

implementation

function WizBase(w: Integer): Integer; inline;
begin
  Result := w * WIZARD_STRIDE;
end;

function WizGold(w: Integer): Integer;   begin Result := W0_GOLD + WizBase(w); end;
function WizMana(w: Integer): Integer;   begin Result := W0_MANA + WizBase(w); end;
function WizSP(w: Integer): Integer;     begin Result := W0_SP   + WizBase(w); end;
function WizFame(w: Integer): Integer;   begin Result := W0_FAME + WizBase(w); end;
function WizBook(w, realm: Integer): Integer;   begin Result := W0_BOOKS   + (realm  - 1) * 4 + WizBase(w); end;
function WizRetort(w, retort: Integer): Integer; begin Result := W0_RETORTS + (retort - 1)     + WizBase(w); end;
function WizSpell(w, sp: Integer): Integer;      begin Result := W0_SPELLS  + (sp     - 1) * 4 + WizBase(w); end;
function WizField(w, slotOffset: Integer): Integer; begin Result := slotOffset + WizBase(w); end;

function TileLandPos(plane, x, y: Integer): Integer;
begin
  Result := MAP_LANDTYPE0 + (plane - 1) * MAP_PLANE_STRIDE + (x - 1) * MAP_X_STRIDE + (y - 1) * TILE_STRIDE;
end;

function TileOrePos(plane, x, y: Integer): Integer;
begin
  Result := TileLandPos(plane, x, y) + TILE_ORE_DELTA;
end;

function TileCorruptPos(plane, x, y: Integer): Integer;
begin
  Result := TileLandPos(plane, x, y) + TILE_CORRUPT_DELTA;
end;

function CityFieldPos(c, fieldOff: Integer): Integer;
begin
  Result := CITY1_BASE + (c - 1) * CITY_STRIDE + fieldOff;
end;

function HeroAbilityPos(w, ht, ha: Integer): Integer;
begin
  Result := HERO_BASE + (ht - 1) * HERO_TYPE_STRIDE + (ha - 1) * 4 + w * WIZARD_STRIDE;
end;

end.

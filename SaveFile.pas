unit SaveFile;
{
  Reads/writes Caster of Magic .SAV files in Pascal (no DLL needed).

  A .SAV is a standard ZIP archive containing one entry, "save.tmp", which is a raw
  dump of the game's data record. This unit extracts that entry to a byte array (so the
  editor can patch fields at known offsets) and writes it back into a fresh .SAV zip.

  Uses FPC's built-in `zipper` unit (standard zip + deflate), which the game accepts.
}
{$mode delphi}

interface

uses
  SysUtils, Classes;

const
  SAVE_ENTRY = 'save.tmp';

// Read the "save.tmp" entry from a .SAV into a byte array.
function LoadSaveTmp(const savePath: string): TBytes;
// Write `data` as the sole "save.tmp" entry of a new .SAV at savePath (overwrites).
procedure WriteSaveTmp(const savePath: string; const data: TBytes);

implementation

uses
  zipper;

type
  // Helper to capture the decompressed entry into memory via the unzipper's stream events.
  TGrabber = class
    Data: TBytes;
    Got: Boolean;
    procedure OnCreate(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure OnDone(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
  end;

procedure TGrabber.OnCreate(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
begin
  AStream := TMemoryStream.Create;   // decompress into memory, not to a file
end;

procedure TGrabber.OnDone(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
begin
  if SameText(AItem.ArchiveFileName, SAVE_ENTRY) then
  begin
    AStream.Position := 0;
    SetLength(Data, AStream.Size);
    if AStream.Size > 0 then
      AStream.ReadBuffer(Data[0], AStream.Size);
    Got := True;
  end;
  AStream.Free;
  AStream := nil;
end;

function LoadSaveTmp(const savePath: string): TBytes;
var
  uz: TUnZipper;
  g: TGrabber;
begin
  g := TGrabber.Create;
  uz := TUnZipper.Create;
  try
    uz.FileName := savePath;
    uz.OnCreateStream := g.OnCreate;
    uz.OnDoneStream := g.OnDone;
    uz.Examine;
    uz.UnZipAllFiles;
    if not g.Got then
      raise Exception.CreateFmt('"%s" not found in %s', [SAVE_ENTRY, savePath]);
    Result := g.Data;
  finally
    uz.Free;
    g.Free;
  end;
end;

procedure WriteSaveTmp(const savePath: string; const data: TBytes);
var
  z: TZipper;
  ms: TMemoryStream;
begin
  z := TZipper.Create;
  ms := TMemoryStream.Create;
  try
    if Length(data) > 0 then
      ms.WriteBuffer(data[0], Length(data));
    ms.Position := 0;
    z.FileName := savePath;
    z.Entries.AddFileEntry(ms, SAVE_ENTRY);  // ms must stay alive until ZipAllFiles returns
    z.ZipAllFiles;
  finally
    z.Free;
    ms.Free;
  end;
end;

end.

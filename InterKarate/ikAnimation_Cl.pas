unit ikAnimation_Cl;

interface

uses
  ABL.VS.VSTypes, Generics.Collections, ABL.Core.BaseObject, Classes, Graphics, SysUtils,
  ABL.IA.IATypes;

type
  TAnimation=class(TObject)
  private
    Frames: TList<PImageDataHeader>;
    Affects: TList<PImageDataHeader>;
    function GetCount: integer;
  public
    HitScore: Word;
    constructor Create(StringList: TStringList; AHitScore: Word=0);
    function Affect(AIndex: integer): PImageDataHeader;
    function Frame(AIndex: integer): PImageDataHeader;
    function FrameWithInc(var AIndex: integer): PImageDataHeader;
    property Count: integer read GetCount;
  end;

implementation

{ TAnimation }

function TAnimation.Affect(AIndex: integer): PImageDataHeader;
begin
  result:=Affects[AIndex];
end;

constructor TAnimation.Create(StringList: TStringList; AHitScore: Word);
var
  q: integer;
  bmp: TBitmap;
  Path: TFileName;
  x,y,yOffset: integer;
  RGBArray: PRGBArray;
  ImageDataHeader: PImageDataHeader;
  ImageRGBArray: PByteArray;
  tmpDataSize: Cardinal;
  sl: TStringList;
  tmpWord: integer;
begin
  HitScore:=AHitScore;
  Frames:=TList<PImageDataHeader>.Create;
  Affects:=TList<PImageDataHeader>.Create;
  Path:=ExtractFilePath(ParamStr(0))+'Graph/';
  bmp:=TBitmap.Create;
  try
    sl:=TStringList.Create;
    try
      //цикл по списку
      for q := 0 to StringList.Count-1 do
      begin
        if StringList[q]<>'' then
        begin
          sl.Text:=StringReplace(StringList[q],';',#13#10,[rfReplaceAll]);
          bmp.LoadFromFile(Path+sl[0]+'.bmp');
          tmpDataSize:=SizeOf(TImageDataHeader)+bmp.Width*bmp.Height*3;
          GetMem(ImageDataHeader,tmpDataSize);
          FillChar(ImageDataHeader^,tmpDataSize,0);
          ImageDataHeader.TimedDataHeader.DataHeader.Magic:=16961;
          ImageDataHeader.TimedDataHeader.DataHeader.Version:=0;
          ImageDataHeader.TimedDataHeader.DataHeader.DataType:=2;
          ImageDataHeader.TimedDataHeader.DataHeader.Size:=tmpDataSize;
          ImageDataHeader.Width:=bmp.Width;
          ImageDataHeader.Height:=bmp.Height;
          if sl.Count>1 then
          begin
            tmpWord:=StrToIntDef(sl[1],0);
            ImageDataHeader.Left:=Abs(tmpWord);
            if tmpWord<0 then
              ImageDataHeader.Reserved1:=-1
            else
              ImageDataHeader.Reserved1:=1;
            if sl.Count>2 then
              ImageDataHeader.Top:=StrToIntDef(sl[2],0);
          end;
          ImageDataHeader.ImageType:=itBGR;
          ImageDataHeader.FlipMarker:=false;
          ImageRGBArray:=ImageDataHeader.Data;
          for y := 0 to bmp.Height-1 do
          begin
            RGBArray:=bmp.ScanLine[y];
            yOffset:=y*bmp.Width*3;
            for x := 0 to bmp.Width-1 do
              if (RGBArray[x].rgbtBlue<>255)or(RGBArray[x].rgbtGreen<>255)or(RGBArray[x].rgbtRed<>255) then
              begin
                if (RGBArray[x].rgbtBlue=0)or(RGBArray[x].rgbtGreen=0)or(RGBArray[x].rgbtRed=0) then
                  FillChar(ImageRGBArray[yOffset+x*3],3,1)
                else
                begin
                  ImageRGBArray[yOffset+x*3]:=RGBArray[x].rgbtBlue;
                  ImageRGBArray[yOffset+x*3+1]:=RGBArray[x].rgbtGreen;
                  ImageRGBArray[yOffset+x*3+2]:=RGBArray[x].rgbtRed;
                end;
              end;
          end;
          Frames.Add(ImageDataHeader);
          if FileExists(Path+sl[0]+'_affect.bmp') then
          begin
            bmp.LoadFromFile(Path+sl[0]+'_affect.bmp');
            tmpDataSize:=SizeOf(TImageDataHeader)+bmp.Width*bmp.Height*3;
            GetMem(ImageDataHeader,tmpDataSize);
            FillChar(ImageDataHeader^,tmpDataSize,0);
            ImageDataHeader.TimedDataHeader.DataHeader.Magic:=16961;
            ImageDataHeader.TimedDataHeader.DataHeader.Version:=0;
            ImageDataHeader.TimedDataHeader.DataHeader.DataType:=2;
            ImageDataHeader.TimedDataHeader.DataHeader.Size:=tmpDataSize;
            ImageDataHeader.Width:=bmp.Width;
            ImageDataHeader.Height:=bmp.Height;
            ImageDataHeader.ImageType:=itBGR;
            ImageDataHeader.FlipMarker:=false;
            ImageRGBArray:=ImageDataHeader.Data;
            for y := 0 to bmp.Height-1 do
              Move(bmp.ScanLine[y]^,ImageRGBArray[y*bmp.Width*3],bmp.Width*3);
            Affects.Add(ImageDataHeader);
          end
          else
            Affects.Add(nil);
        end;
      end;
    finally
      FreeAndNil(sl);
    end;
  finally
    FreeAndNil(bmp);
  end;
end;

function TAnimation.Frame(AIndex: integer): PImageDataHeader;
begin
  result:=Frames[AIndex];
end;

function TAnimation.FrameWithInc(var AIndex: integer): PImageDataHeader;
begin
  if AIndex>=Frames.Count then
    AIndex:=0;
  result:=Frames[AIndex];
  if AIndex+1>=Frames.Count then
    AIndex:=0
  else
    AIndex:=AIndex+1;
end;

function TAnimation.GetCount: integer;
begin
  result:=Frames.Count;
end;

end.

unit vsScore_Cl;

interface

uses
  ABL.Core.DirectThread, ABL.VS.VSTypes, ABL.Core.CoreTypes, SyncObjs, SysUtils;

type
  TScore=class(TDirectThread)
  private
    FPicture: PImageDataHeader;
    FScore: integer;
    function GetScore: integer;
    procedure SetScore(const Value: integer);
    function GetPicture: PImageDataHeader;
    procedure UpdateScore;
  protected
    procedure DoExecute(var AInputData: Pointer; var AResultData: Pointer); override;
  public
    constructor Create(AName: string = ''); override;
    property Score: integer read GetScore write SetScore;
    property Picture: PImageDataHeader read GetPicture;
  end;

var
  Numbers: array [0..9] of PImageDataHeader;

implementation

{ TScore }

constructor TScore.Create(AName: string);
begin
  inherited Create(AName);
  FScore:=0;
  GetMem(FPicture,Numbers[0].TimedDataHeader.DataHeader.Size*3);  //про запас
  UpdateScore;
  Start();
end;

procedure TScore.DoExecute(var AInputData, AResultData: Pointer);
begin
  FLock.Enter;
  UpdateScore;
  FLock.Leave;
end;

function TScore.GetPicture: PImageDataHeader;
begin
  FLock.Enter;
  GetMem(result,FPicture.TimedDataHeader.DataHeader.Size);
  Move(FPicture^,result^,FPicture.TimedDataHeader.DataHeader.Size);
  FLock.Leave;
end;

function TScore.GetScore: integer;
begin
  FLock.Enter;
  result:=FScore;
  FLock.Leave;
end;

procedure TScore.SetScore(const Value: integer);
var
  tmpData: PDataHeader;
begin
  FLock.Enter;
  FScore:=value;
  GetMem(tmpData,1);
  FInputQueue.Push(tmpData);
  FLock.Leave;
end;

procedure TScore.UpdateScore;
var
  CurIndex,y: integer;
  ByteFrom, ByteTo: PByteArray;
  tmpDataSize: Cardinal;
begin
  if FScore<10 then
    Move(Numbers[FScore]^,FPicture^,Numbers[FScore].TimedDataHeader.DataHeader.Size)
  else
  begin
    if FScore>99 then
      FScore:=99;
//    ByteFrom:=Numbers[FScore];
    Move(Numbers[0]^,FPicture^,SizeOf(TImageDataHeader));
    FPicture.Width:=Numbers[0].Width*2+Numbers[0].Width div 3;
    tmpDataSize:=FPicture.Width*FPicture.Height*3;
    FillChar(FPicture.Data^,tmpDataSize,0);
    FPicture.TimedDataHeader.DataHeader.Size:=tmpDataSize+SizeOf(TImageDataHeader);
    //десятки
    CurIndex:=FScore div 10;
    ByteFrom:=Numbers[CurIndex].Data;
    ByteTo:=FPicture.Data;
    for y := 0 to Numbers[CurIndex].Height-1 do
      Move(ByteFrom[y*Numbers[CurIndex].Width*3],ByteTo[y*FPicture.Width*3],Numbers[CurIndex].Width*3);
    //единицы
    CurIndex:=FScore mod 10;
    ByteFrom:=Numbers[CurIndex].Data;
    for y := 0 to Numbers[CurIndex].Height-1 do
      Move(ByteFrom[y*Numbers[CurIndex].Width*3],
          ByteTo[(y*FPicture.Width+Numbers[CurIndex].Width+Numbers[CurIndex].Width div 3)*3],
          Numbers[CurIndex].Width*3);
  end;
end;

end.

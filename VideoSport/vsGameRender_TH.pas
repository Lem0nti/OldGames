unit vsGameRender_TH;

interface

uses
  ABL.Render.TimerRender, ABL.Core.BaseQueue, Winapi.Windows, Graphics, SysUtils, ABL.VS.VSTypes, ABL.IA.IATypes,
  Types, SyncObjs, math, ABL.IO.IOTypes, vsScore_Cl;

type
  TGameRender = class(TTimerRender)
  private
    BackGround: PImageDataHeader;
    FPlayer1Score, FPlayer2Score: TScore;
    FPlayer1, FPlayer2: TRect;
    Ball: TRectF;
    BallSpeed: TPointF;
    FGameSpeed: integer;
    FLastPlayer1Move, FLastPlayer2Move: int64;
    FLastPlayer1Duration, FLastPlayer2Duration: integer;
    FHard: byte;
    function DoCheckBorders(var ARect: TRect): boolean;
    procedure DoCheckBallBorders(var ARect: TRectF);
    procedure Finish;
    function GetPlayer1Score: integer;
    function GetPlayer2Score: integer;
    procedure MoveBall;
    procedure SetPlayer1Score(const Value: integer);
    procedure SetPlayer2Score(const Value: integer);
    procedure SetHard(const Value: byte);
  protected
    procedure DoExecute; override;
    procedure DoReceive(var AInputData: Pointer); override;
  public
    constructor Create(AInputQueue: TBaseQueue; AName: string = '');
    destructor Destroy; override;
    procedure MovePlayer1(AX,AY: integer);
    procedure MovePlayer2(AX,AY: integer);
    procedure StartGame;
    property Hard: byte read FHard write SetHard;
    property Player1Score: integer read GetPlayer1Score write SetPlayer1Score;
    property Player2Score: integer read GetPlayer2Score write SetPlayer2Score;
  end;

var
  GameRender: TGameRender;

implementation

{ TGameRender }

constructor TGameRender.Create(AInputQueue: TBaseQueue; AName: string);
var
  bmp: TBitmap;
  tmpDataSize: Cardinal;
  y,q: integer;
  ByteArray: PByteArray;
  NumberImage: PImageDataHeader;
begin
  inherited Create(AInputQueue,AName);
  bmp:=TBitmap.Create;
  try
    //задний план
    bmp.LoadFromFile(ExtractFilePath(ParamStr(0))+'Field.bmp');
    tmpDataSize:=SizeOf(TImageDataHeader)+bmp.Width*bmp.Height*3;
    GetMem(BackGround,tmpDataSize);
    Move(FPicture^,BackGround^,SizeOf(TImageDataHeader));
    BackGround.Width:=bmp.Width;
    BackGround.Height:=bmp.Height;
    BackGround.TimedDataHeader.DataHeader.Size:=tmpDataSize;
    ByteArray:=BackGround.Data;
    for y := 0 to bmp.Height-1 do
      Move(bmp.ScanLine[y]^,ByteArray[y*BackGround.Width*3],BackGround.Width*3);
    SetSize(BackGround.Width,BackGround.Height);
    //изображение очков
    for q := 0 to 9 do
    begin
      bmp.LoadFromFile(ExtractFilePath(ParamStr(0))+IntToStr(q)+'.bmp');
      tmpDataSize:=SizeOf(TImageDataHeader)+bmp.Width*bmp.Height*3;
      GetMem(NumberImage,tmpDataSize);
      Move(FPicture^,NumberImage^,SizeOf(TImageDataHeader));
      NumberImage.Width:=bmp.Width;
      NumberImage.Height:=bmp.Height;
      NumberImage.TimedDataHeader.DataHeader.Size:=tmpDataSize;
      ByteArray:=NumberImage.Data;
      for y := 0 to bmp.Height-1 do
        Move(bmp.ScanLine[y]^,ByteArray[y*NumberImage.Width*3],NumberImage.Width*3);
      Numbers[q]:=NumberImage;
    end;
  finally
    FreeAndNil(bmp);
  end;
  FHard:=0;
  //игрок 1
  FPlayer1:=Rect(0,0,4,40);
  FPlayer1.Location:=Point(24,(BackGround.Height-FPlayer1.Height) div 2);
  //игрок 2
  FPlayer2:=Rect(0,0,4,40);
  FPlayer2.Location:=Point(BackGround.Width-24,(BackGround.Height-FPlayer1.Height) div 2);
  //мяч
  Ball:=Rect(0,0,4,4);
  Ball.Location:=Point((BackGround.Width div 2)-1,(BackGround.Height div 2)-1);
  BallSpeed.X:=0;
  BallSpeed.Y:=0;
  //счёт
  FPlayer1Score:=TScore.Create('Player1Score');
  FPlayer2Score:=TScore.Create('Player2Score');
  FGameSpeed:=4;
  Interval:=2;
  FLastPlayer1Duration:=0;
  FLastPlayer2Duration:=0;
  Start();
end;

destructor TGameRender.Destroy;
begin
  FreeAndNil(FPlayer1Score);
  FreeAndNil(FPlayer2Score);
  inherited;
end;

procedure TGameRender.DoCheckBallBorders(var ARect: TRectF);
const
  SpeedIncrease = 1.2;
var
  tmpVal: Extended;
  InvertX,InvertY: boolean;
  Intersect1,Intersect2: boolean;
  tmpLTimeStamp: TTimeStamp;
  tmpNow: int64;
  DirectionCoeff: integer;
begin
  InvertX:=false;
  InvertY:=false;
  //игроки отбили?
  Intersect1:=ARect.IntersectsWith(RectF(FPlayer1.Left,FPlayer1.Top,FPlayer1.Right,FPlayer1.Bottom));
  Intersect2:=ARect.IntersectsWith(RectF(FPlayer2.Left,FPlayer2.Top,FPlayer2.Right,FPlayer2.Bottom));
  if Intersect1 or Intersect2 then
  begin
    InvertX:=true;
    tmpLTimeStamp := DateTimeToTimeStamp(now);
    tmpNow:=tmpLTimeStamp.Date*Int64(MSecsPerDay)+tmpLTimeStamp.Time-UnixTimeStart;
    BallSpeed.X:=min(3,BallSpeed.X*SpeedIncrease);
    BallSpeed.Y:=min(3,BallSpeed.Y*SpeedIncrease);
    //если игрок был в движении, то изменить угол
    if (Intersect1 and ((tmpNow-FLastPlayer1Move)<60)) or (Intersect2 and ((tmpNow-FLastPlayer2Move)<60)) then
    begin
      DirectionCoeff:=round(BallSpeed.Y/abs(BallSpeed.Y));
      //если направления совпадают, то увеличить скорость
      //иначе - уменьшить
      if BallSpeed.Y*FLastPlayer1Duration>0 then
        BallSpeed.Y:=min(3,(abs(BallSpeed.Y)+0.3)*DirectionCoeff)
      else
        BallSpeed.Y:=min(3,(abs(BallSpeed.Y)-0.3)*DirectionCoeff);
      BallSpeed.X:=BallSpeed.x*0.9;
    end;
    Winapi.Windows.Beep(1350,30);
  end;

  //не вылазить за края поля
  tmpVal:=BackGround.Height-6;
  tmpVal:=ARect.Bottom-tmpVal;
  if tmpVal>0 then
  begin
    ARect.Offset(0,-tmpVal);
    InvertY:=true;
    Winapi.Windows.Beep(900,30);
  end
  else
  begin
    tmpVal:=ARect.Top-6;
    if tmpVal<0 then
    begin
      ARect.Offset(0,-tmpVal);
      InvertY:=true;
      Winapi.Windows.Beep(900,30);
    end;
  end;
  if not InvertX then
  begin
    tmpVal:=BackGround.Width-6;
    tmpVal:=ARect.Right-tmpVal;
    if tmpVal>0 then
    begin
      ARect.Offset(-tmpVal,0);
      InvertX:=true;
      Winapi.Windows.Beep(900,30);
    end
    else
    begin
      tmpVal:=ARect.Left-6;
      if tmpVal<0 then
      begin
        ARect.Offset(-tmpVal,0);
        InvertX:=true;
        Winapi.Windows.Beep(900,30);
      end;
    end;
  end;
  if InvertX then
    BallSpeed.X:=-BallSpeed.X;
  if InvertY then
    BallSpeed.Y:=-BallSpeed.Y;
end;

function TGameRender.DoCheckBorders(var ARect: TRect): boolean;
var
  tmpVal: integer;
begin
  //результат положительный тольео если не пришлось корректировать положение
  result:=true;
  //не вылазить за края поля
  tmpVal:=BackGround.Height-6;
  tmpVal:=ARect.Bottom-tmpVal;
  if tmpVal>0 then
  begin
    ARect.Offset(0,-tmpVal);
    result:=false;
  end
  else
  begin
    tmpVal:=ARect.Top-6;
    if tmpVal<0 then
    begin
      ARect.Offset(0,-tmpVal);
      result:=false;
    end;
  end;
end;

procedure TGameRender.DoExecute;
var
  y,PictureWidth: integer;
  ResultArray,SourceArray: PByteArray;
  ScorePicture: PImageDataHeader;
  tmpLeft: integer;

  procedure ShowRectElement(ARect: TRect);
  var
    q: integer;
  begin
    for q := ARect.Top to ARect.Bottom do
      FillChar(ResultArray[(q*PictureWidth+ARect.Left)*3],ARect.Width*3,255);
  end;

begin
  ResultArray:=PImageDataHeader(FPicture).Data;
  Move(BackGround.Data^,ResultArray^,BackGround.TimedDataHeader.DataHeader.Size-SizeOf(TImageDataHeader));
  //показать счёт
  PictureWidth:=PImageDataHeader(FPicture).Width;
  ScorePicture:=FPlayer1Score.Picture;
  SourceArray:=ScorePicture.Data;
  tmpLeft:=(PictureWidth div 2)-ScorePicture.Width-16;
  for y := 0 to ScorePicture.Height-1 do
    Move(SourceArray[y*ScorePicture.Width*3],ResultArray[((10+y)*PictureWidth+tmpLeft)*3],ScorePicture.Width*3);
  FreeMem(ScorePicture);

  ScorePicture:=FPlayer2Score.Picture;
  SourceArray:=ScorePicture.Data;
  tmpLeft:=(PictureWidth div 2)+16;
  for y := 0 to ScorePicture.Height-1 do
    Move(SourceArray[y*ScorePicture.Width*3],ResultArray[((10+y)*PictureWidth+tmpLeft)*3],ScorePicture.Width*3);
  FreeMem(ScorePicture);

  //игроки
  ShowRectElement(FPlayer1);
  ShowRectElement(FPlayer2);

  //мяч
  MoveBall;

  //новое положение
  ShowRectElement(Rect(Round(Ball.Left),Round(Ball.Top),Round(Ball.Right),Round(Ball.Bottom)));

  inherited DoExecute;

  //гол?
  if Ball.IntersectsWith(RectF(312,55,319,143)) then
  begin
    Winapi.Windows.Beep(1800,30);
    Player1Score:=Player1Score+1;
    if Player1Score>=10 then
      Finish
    else
      StartGame;
  end
  else if Ball.IntersectsWith(RectF(0,55,7,143)) then
  begin
    Winapi.Windows.Beep(1800,30);
    Player2Score:=Player2Score+1;
    if Player2Score>=10 then
      Finish
    else
      StartGame;
  end;
end;

procedure TGameRender.DoReceive(var AInputData: Pointer);
begin
  inherited;

end;

procedure TGameRender.Finish;
begin
  Ball.Location:=Point((BackGround.Width div 2)-2,(BackGround.Height div 2)-2);
  BallSpeed:=PointF(0,0);
end;

function TGameRender.GetPlayer1Score: integer;
begin
  result:=FPlayer1Score.Score;
end;

function TGameRender.GetPlayer2Score: integer;
begin
  result:=FPlayer2Score.Score;
end;

procedure TGameRender.MoveBall;
begin
  Ball.Offset(BallSpeed.X*FGameSpeed,BallSpeed.Y*FGameSpeed);
  DoCheckBallBorders(Ball);
end;

procedure TGameRender.MovePlayer1(AX, AY: integer);
var
  tmpLTimeStamp: TTimeStamp;
begin
  //впишется ли прямоугольник в дозволенные рамки
  FLock.Enter;
  FPlayer1.Offset(AX*FGameSpeed,AY*FGameSpeed);
  if DoCheckBorders(FPlayer1) then
  begin
    tmpLTimeStamp := DateTimeToTimeStamp(now);
    FLastPlayer1Move:=tmpLTimeStamp.Date*Int64(MSecsPerDay)+tmpLTimeStamp.Time-UnixTimeStart;
    FLastPlayer1Duration:=AY;
  end;
  FLock.Leave;
end;

procedure TGameRender.MovePlayer2(AX, AY: integer);
var
  tmpLTimeStamp: TTimeStamp;
begin
  FLock.Enter;
  FPlayer2.Offset(AX*FGameSpeed,AY*FGameSpeed);
  DoCheckBorders(FPlayer2);
  if DoCheckBorders(FPlayer2) then
  begin
    tmpLTimeStamp := DateTimeToTimeStamp(now);
    FLastPlayer2Move:=tmpLTimeStamp.Date*Int64(MSecsPerDay)+tmpLTimeStamp.Time-UnixTimeStart;
    FLastPlayer1Duration:=AY;
  end;
  FLock.Leave;
end;

procedure TGameRender.SetHard(const Value: byte);
begin
  if FHard<>Value then
  begin
    FHard:=Value;
    FPlayer1.Height:=40-FHard*3;
    FPlayer2.Height:=40-FHard*3;
  end;
end;

procedure TGameRender.SetPlayer1Score(const Value: integer);
begin
  FPlayer1Score.Score:=Value;
end;

procedure TGameRender.SetPlayer2Score(const Value: integer);
begin
  FPlayer2Score.Score:=Value;
end;

procedure TGameRender.StartGame;
var
  q: Single;
begin
  Randomize;
  BallSpeed.X:=(Random(80)+20)/100;
  BallSpeed.Y:=Random(50)/100;
  //стартовая скорость по У не должна быть больше
  if BallSpeed.Y>BallSpeed.X then
  begin
    q:=BallSpeed.X;
    BallSpeed.X:=BallSpeed.Y;
    BallSpeed.Y:=q;
  end;
  if Random(2)=1 then
    BallSpeed.X:=-BallSpeed.X;
  if Random(2)=1 then
    BallSpeed.Y:=-BallSpeed.Y;
  Ball.Location:=Point((BackGround.Width div 2)-2,(BackGround.Height div 2)-2);
end;

end.

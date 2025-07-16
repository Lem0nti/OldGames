unit vsMain_FM;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, vsGameRender_TH, ABL.Core.ThreadController, Vcl.ExtCtrls, JvComponentBase,
  JvHidControllerClass;

type
  TMainFM = class(TForm)
    Panel1: TPanel;
    Timer: TTimer;
    HidCtl: TJvHidDeviceController;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HidCtlDeviceData(HidDev: TJvHidDevice; ReportID: Byte; const Data: Pointer; Size: Word);
    function HidCtlEnumerate(HidDev: TJvHidDevice; const Idx: Integer): Boolean;
    procedure HidCtlDeviceChange(Sender: TObject);
  private
    { Private declarations }
    HidDev0,HidDev1: TJvHidDevice;
  public
    { Public declarations }
  end;

var
  MainFM: TMainFM;

implementation

{$R *.dfm}

procedure TMainFM.FormCreate(Sender: TObject);
begin
  GameRender:=TGameRender.Create(ThreadController.QueueByName('GameRenderInput'),'GameRender');
  GameRender.Handle:=Panel1.Handle;
  HidDev0:=nil;
  HidDev1:=nil;
end;

procedure TMainFM.FormDestroy(Sender: TObject);
begin
  GameRender.Handle:=0;
  FreeAndNil(GameRender);
end;

procedure TMainFM.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key=32 then
  begin
    GameRender.Player1Score:=0;
    GameRender.Player2Score:=0;
    GameRender.StartGame;
  end
  else if Key in [48..57] then
    GameRender.Hard:=Key-48;
end;

procedure TMainFM.HidCtlDeviceChange(Sender: TObject);
begin
  HidCtl.Enumerate;
end;

procedure TMainFM.HidCtlDeviceData(HidDev: TJvHidDevice; ReportID: Byte; const Data: Pointer; Size: Word);
var
  ByteArray: PByteArray;
begin
  //первый который пришлёт сигнал будет игроком 1
  if not assigned(HidDev0) then
    HidDev0:=HidDev
  else if (HidDev<>HidDev0) and (not assigned(HidDev1)) then
    HidDev1:=HidDev;
  ByteArray:=Data;
  if HidDev=HidDev0 then
  begin
    if ByteArray[0]=128 then  //едем вниз
      GameRender.MovePlayer1(0,1)
    else if ByteArray[1]=1 then  //едем вверх
      GameRender.MovePlayer1(0,-1)
  end
  else if HidDev=HidDev1 then
  begin
    if ByteArray[0]=128 then  //едем вниз
      GameRender.MovePlayer2(0,1)
    else if ByteArray[1]=1 then  //едем вверх
      GameRender.MovePlayer2(0,-1)
  end;
end;

function TMainFM.HidCtlEnumerate(HidDev: TJvHidDevice; const Idx: Integer): Boolean;
var
  Dev: TJvHidDevice;
begin
  if HidDev.ProductName='LCKEY' then
    HidCtl.CheckOutByIndex(Dev, Idx);
  result:=true;
end;

procedure TMainFM.TimerTimer(Sender: TObject);
begin
  if not (GetKeyState(81) in [0,1]) then
    GameRender.MovePlayer1(0,-1);
  if not (GetKeyState(65) in [0,1]) then
    GameRender.MovePlayer1(0,1);
  if not (GetKeyState(221) in [0,1]) then
    GameRender.MovePlayer2(0,-1);
  if not (GetKeyState(222) in [0,1]) then
    GameRender.MovePlayer2(0,1);
end;

end.

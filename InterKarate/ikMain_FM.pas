unit ikMain_FM;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, bass,
  ABL.Render.ImageRender, ABL.Core.ThreadController, ikGameRender_TH, ikComListen_TH;

type
  TMainFM = class(TForm)
    Timer: TTimer;
    pnlScreen: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    { Private declarations }
    FMainStream: HSTREAM;
  public
    { Public declarations }
  end;

var
  MainFM: TMainFM;

implementation

{$R *.dfm}

procedure TMainFM.FormCreate(Sender: TObject);
var
  q: PChar;
  w: string;
begin
  GameRender:=TGameRender.Create(ThreadController.QueueByName('GameRenderInput'),'GameRender');
  GameRender.Handle:=pnlScreen.Handle;
  GameRender.DropWins;
  GameRender.StartGame;
  BASS_Init(-1, 44100, 0, handle, nil);
  w:=ExtractFilePath(ParamStr(0))+'Sound/Main.wav';
  q:=PChar(w);
  FMainStream:=BASS_StreamCreateFile(false,q,0,0,0 {$IFDEF UNICODE} or BASS_UNICODE {$ENDIF});
  BASS_ChannelFlags(FMainStream, BASS_SAMPLE_LOOP, BASS_SAMPLE_LOOP);
  BASS_ChannelPlay(FMainStream,true);
  ComListen:=TComListen.Create;
end;

procedure TMainFM.FormDestroy(Sender: TObject);
begin
  ComListen.Terminate;
  BASS_Free;
  Timer.Enabled:=false;
  GameRender.Enabled:=false;
  //GameRender.Stop;
  FreeAndNil(GameRender);
end;

procedure TMainFM.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key=VK_F9 then
  begin
    GameRender.DropWins;
    GameRender.StartGame;
  end;
end;

procedure TMainFM.TimerTimer(Sender: TObject);
var
  State: TKeyboardState;
  UpPressed,DownPressed,LeftPressed,RightPressed,SpacePressed: boolean;
  ActionString: string;
begin
  //какие клавиши нажаты
  GetKeyboardState(State);
  UpPressed:=((State[VK_UP] and 128)<>0);
  DownPressed:=((State[VK_DOWN] and 128)<>0);
  LeftPressed:=((State[VK_LEFT] and 128)<>0);
  RightPressed:=((State[VK_RIGHT] and 128)<>0);
  SpacePressed:=((State[VK_SPACE] and 128)<>0);
  ActionString:='';
  if UpPressed then
    ActionString:='U'
  else if DownPressed then
    ActionString:='D';
  if LeftPressed then
    ActionString:=ActionString+'L'
  else if RightPressed then
    ActionString:=ActionString+'R';
  if SpacePressed then
    ActionString:=ActionString+'S';
  if ActionString<>'' then
    GameRender.DoAction1(ActionString);

  UpPressed:=((State[87] and 128)<>0);
  DownPressed:=((State[83] and 128)<>0);
  LeftPressed:=((State[65] and 128)<>0);
  RightPressed:=((State[68] and 128)<>0);
  SpacePressed:=((State[VK_CONTROL] and 128)<>0);
  ActionString:='';
  if UpPressed then
    ActionString:='U'
  else if DownPressed then
    ActionString:='D';
  if LeftPressed then
    ActionString:=ActionString+'L'
  else if RightPressed then
    ActionString:=ActionString+'R';
  if SpacePressed then
    ActionString:=ActionString+'S';
  if ActionString<>'' then
    GameRender.DoAction2(ActionString);

end;

end.

{
сценарии

приветствие Greet_0, Greet_1, Greet_0 (начало, победа)
движение Go_0, Go_1, Go_2, Go_3 [←] [→]
приседание Sit [↓]
сальто Salto_0, Salto_1, Salto_2, Salto_3, Salto_4, Salto_5 [↑→]
поворот Round_0, Round_1, Round_2 [←←]
блок стоя Block [←*]
падение назад Fall_0, Fall_1, Fall_2, Fall_3 (когда получил по голове или ногам)
прыжок Jump [↑]
сел на жопу SitFall_0, SitFall_1, SitFall_2, SitFall_3 (когда получил в живот)
дышит на руку Blow_0, Blow_1, Blow_2, Blow_1, Blow_2 [когда стукнул по голове]
падение вперёд FFall_0, FFall_1, FFall_2, FFall_3 (когда получил сзади)

удар в прыжке Jump, JumpKick, Salto_5 [↑*] [↑→*]
лоу кик Kick_0, LowKick, Kick_0 [↓→*]
кулаком в приседе LowPunch [↓*]
кулаком стоя Punch_0, Punch_1 [*]
подсечка (Sit), Undercut_0, Undercut_1, Undercut_0 [↓←*]
кик Kick_0, Kick_1, Kick_2, Kick_0 [→*]
с разворота RoundKick_0, RoundKick_1, RoundKick_2, RoundKick_3, RoundKick_4, Kick_0 [←↓*]
хай кик Kick_0, HighKick_0, HighKick_1, Kick_0 [→↑*]
}

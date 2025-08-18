unit ikGameRender_TH;

interface

uses
  ABL.Render.TimerRender, ABL.Core.BaseQueue, Winapi.Windows, Graphics, SysUtils, ABL.VS.VSTypes,
  ABL.IA.IATypes, ABL.VS.BMPSaver, MMSystem, DateUtils, ikMatchTimer_TH, ABL.Core.ThreadController,
  Types, SyncObjs, math, ABL.IO.IOTypes, ikAnimation_Cl, Generics.Collections, Classes, ABL.Core.Debug;

type
  TPlayer = record
    XPos: integer;
    CurAction: string;
    ActionPos: integer;
    Reverse: boolean;
    Animations: TDictionary<string,TAnimation>;
    Points: integer;
    HitCount: byte;
    Wins: byte;
  end;

  TGameRender = class(TTimerRender)
  private
    BackGround,StopFrame: PImageDataHeader;
    AAList: TStringList;
    Animations1: TDictionary<string,TAnimation>;
    Animations2: TDictionary<string,TAnimation>;
    ArbiterTalk: TAnimation;
    HitRect: TDictionary<string,TRect>;
    Player1,Player2: TPlayer;
    ArbiterIndex: integer;
    ArbiterTill: TDateTime;
    FloatScore: integer;
    FloatPoint: TPoint;
    FloatTill: TDateTime;
    //RoundStarted: TDateTime;
    Numbers: TList<PImageDataHeader>;
    MatchTimer: TMatchTimer;
    MatchOverTime: TDateTime;
    procedure IncWin;
    procedure Finish;
    procedure LoadNumbers;
    procedure LoadPlayerAnimation(Animations: TDictionary<string,TAnimation>; PlayerIndex: integer);
    procedure RandBackground;
    procedure SetArbiterIndex(AIndex: integer);
    procedure SetFloatNumbers(Number: integer; Point: TPoint);
  protected
    procedure DoAction(var Player: TPlayer; Action: string);
    procedure DoExecute; override;
    procedure DoReceive(var AInputData: Pointer); override;
  public
    constructor Create(AInputQueue: TBaseQueue; AName: string = '');
    destructor Destroy; override;
    procedure DropWins;
    procedure StartRound;
    procedure StartGame;
    procedure DoAction1(Action: string);
    procedure DoAction2(Action: string);
  end;

var
  GameRender: TGameRender;

const
  Arbiter_Begin = 0;
  Arbiter_White = 1;
  Arbiter_Red   = 2;
  Arbiter_Draw  = 3;
  Arbiter_Full  = 4;
  Arbiter_Over  = 5;

implementation

{ TGameRender }

constructor TGameRender.Create(AInputQueue: TBaseQueue; AName: string);
var
  sl: TStringList;
begin
  inherited Create(AInputQueue,AName);
  MatchOverTime:=0;
  StopFrame:=nil;
  //анимации игроков
  Animations1:=TDictionary<string,TAnimation>.Create;
  Animations2:=TDictionary<string,TAnimation>.Create;
  HitRect:=TDictionary<string,TRect>.Create;
  LoadPlayerAnimation(Animations1,1);
  LoadPlayerAnimation(Animations2,2);
  Player1.Animations:=Animations1;
  Player2.Animations:=Animations2;
  Interval:=100;
  Player1.XPos:=64;
  Player1.CurAction:='Stay';
  Player1.ActionPos:=0;
  Player1.Reverse:=false;

  Player2.XPos:=64;
  Player2.CurAction:='Stay';
  Player2.ActionPos:=0;
  Player2.Reverse:=true;

  AAList:=TStringList.Create;
  AAList.Add('U=Jump');
  AAList.Add('D=Sit');
  AAList.Add('F=Go');
  AAList.Add('B=GoBack');
  AAList.Add('UF=Salto');
  AAList.Add('DF=');
  AAList.Add('UB=SaltoBack');
  AAList.Add('DB=Round');
  AAList.Add('US=HighKick');
  AAList.Add('DS=LowKick');
  AAList.Add('FS=Kick');
  AAList.Add('BS=Punch');
  AAList.Add('UFS=JumpKick');
  AAList.Add('DFS=Undercut');
  AAList.Add('UBS=RoundKick');
  AAList.Add('DBS=LowPunch');

  //сообщения судьи
  sl:=TStringList.Create;
  try
    sl.Text:='Arbiter_Begin'#13#10'Arbiter_White'#13#10'Arbiter_Red'+
        #13#10'Arbiter_Draw'#13#10'Arbiter_Full'#13#10'Arbiter_Over';
    ArbiterTalk:=TAnimation.Create(sl);
  finally
    FreeAndNil(sl);
  end;
  ArbiterIndex:=-1;
  ArbiterTill:=0;
  FloatTill:=0;

  Numbers:=TList<PImageDataHeader>.Create;
  LoadNumbers;
  MatchTimer:=TMatchTimer.Create('MatchTimer');
  RandBackGround;
  Start;
end;

destructor TGameRender.Destroy;
begin
  StopReceive;
  Stop;
  FreeAndNil(MatchTimer);
  FreeAndNil(Numbers);
  FreeAndNil(AAList);
  FreeAndNil(HitRect);
  FreeAndNil(Animations1);
  FreeAndNil(Animations2);
  inherited;
end;

procedure TGameRender.DoAction(var Player: TPlayer; Action: string);
var
  tmpAction: string;

  function CanSwitch: boolean;
  begin
    result:=(Player.CurAction='Go') or (Player.CurAction='GoBack') or (Player.CurAction='Sit')
        or (Player.CurAction='Stay');
  end;

begin
  if (Action<>'')and(not MatchTimer.Paused) then
  begin
    FLock.Enter;
    //можно только если никто не лежит
    tmpAction:=Player1.CurAction+Player2.CurAction;
    if (pos('Fall',tmpAction)=0) and CanSwitch then
    begin
      if Player.Reverse then
      begin
        tmpAction:=StringReplace(Action,'R','B',[]);
        tmpAction:=StringReplace(tmpAction,'L','F',[]);
      end
      else
      begin
        tmpAction:=StringReplace(Action,'R','F',[]);
        tmpAction:=StringReplace(tmpAction,'L','B',[]);
      end;
      tmpAction:=AAList.Values[tmpAction];
      if (tmpAction<>'') and (Player.CurAction<>tmpAction) then
      begin
        Player.CurAction:=tmpAction;
        Player.ActionPos:=0;
      end;
    end;
    FLock.Leave;
  end;
end;

procedure TGameRender.DoAction1(Action: string);
begin
  DoAction(Player1,Action);
end;

procedure TGameRender.DoAction2(Action: string);
begin
  DoAction(Player2,Action);
end;

procedure TGameRender.DoExecute;
const
  PlayerY     = 192;
  TalkY       = 120;
  TalkX       = 232;
  FloatScoreY = 135;

var
  RGBArrayBG,RGBArrayPicture,RGBArrayAffectPattern: PRGBArray;
  HitRect1,HitRect2: TRect;
  AffectImage1,AffectImage2: PImageDataHeader;
  CheckY,CheckX: integer;
  NextRound,NextMatch: boolean;
  FallAction: string;
  q: integer;
  PlayerWins: byte;

  procedure CheckHitScore(var PlayerWhoHit: TPlayer; PlayerWhoFall: TPlayer);
  var
    CurHitScore,FloatX: integer;
    tmpString: string;
  begin
    if FloatTill<Now then
    begin
      CurHitScore:=PlayerWhoHit.Animations[PlayerWhoHit.CurAction].HitScore;
      FloatX:=PlayerWhoFall.XPos+15;
      if PlayerWhoFall.Reverse then
        FloatX:=320-FloatX
      else
        FloatX:=FloatX+20;
      //если падающий был в воздухе, то очки удваиваются
      tmpString:=PlayerWhoFall.CurAction;
      if (tmpString='Salto')or(tmpString='Jump')or(tmpString='JumpKick') then
        CurHitScore:=CurHitScore*2;
      if PlayerWhoHit.Reverse=PlayerWhoFall.Reverse then
        CurHitScore:=(CurHitScore div 200)*100;
      PlayerWhoHit.Points:=PlayerWhoHit.Points+CurHitScore;
      SetFloatNumbers(CurHitScore,Point(FloatX,FloatScoreY));
    end;
  end;

  procedure ShowArbiter;
  var
    TalkImage: PImageDataHeader;
    x,y,backY: integer;
  begin
    if (ArbiterIndex>-1)and(ArbiterTill>Now) then
    begin
      TalkImage:=ArbiterTalk.Frame(ArbiterIndex);
      if assigned(TalkImage) then
      begin
        RGBArrayPicture:=TalkImage.Data;
        for y := 0 to TalkImage.Height-1 do
        begin
          backY:=TalkY+y;
          for x := 0 to TalkImage.Width-1 do
            if RGBArrayPicture[y*TalkImage.Width+x].rgbtBlue>0 then
              Move(RGBArrayPicture[y*TalkImage.Width+x],RGBArrayBG[backY*BackGround.Width+TalkX+x],3);
        end;
      end;
    end;
  end;

  procedure ShowBalls;
  var
    RGBTriple: TRGBTriple;

    procedure DrawBall(Position: TPoint; Triple: TRGBTriple);
    var
      x,y: integer;
    begin
      //for y := 0 to 1 do
        for x := 2 to 5 do
          Move(Triple.rgbtBlue,RGBArrayBG[Position.Y*BackGround.Width+Position.X+x].rgbtBlue,3);

      for y := 1 to 4 do
        for x := 0 to 7 do
          Move(Triple.rgbtBlue,RGBArrayBG[(Position.Y+y)*BackGround.Width+Position.X+x].rgbtBlue,3);

      y:=5;
      for x := 2 to 5 do
        Move(Triple.rgbtBlue,RGBArrayBG[(Position.Y+y)*BackGround.Width+Position.X+x].rgbtBlue,3);

    end;

    function RedTripple: TRGBTriple;
    begin
      result.rgbtBlue:=75;
      result.rgbtGreen:=72;
      result.rgbtRed:=221;
    end;

    function WhiteTripple: TRGBTriple;
    begin
      result.rgbtBlue:=255;
      result.rgbtGreen:=255;
      result.rgbtRed:=255;
    end;

  begin
    if Player1.HitCount>=3 then
      RGBTriple:=WhiteTripple
    else
      RGBTriple:=RedTripple;
    DrawBall(Point(56,2),RGBTriple);

    if Player1.HitCount>1 then
      RGBTriple:=WhiteTripple
    else
      RGBTriple:=RedTripple;
    DrawBall(Point(64,2),RGBTriple);

    if Player1.HitCount>0 then
      RGBTriple:=WhiteTripple
    else
      RGBTriple:=RedTripple;
    DrawBall(Point(64,9),RGBTriple);

    if Player2.HitCount>=3 then
      RGBTriple:=WhiteTripple
    else
      RGBTriple:=RedTripple;
    DrawBall(Point(256,2),RGBTriple);

    if Player2.HitCount>1 then
      RGBTriple:=WhiteTripple
    else
      RGBTriple:=RedTripple;
    DrawBall(Point(264,2),RGBTriple);

    if Player2.HitCount>0 then
      RGBTriple:=WhiteTripple
    else
      RGBTriple:=RedTripple;
    DrawBall(Point(264,9),RGBTriple);

  end;

  procedure ShowNumbers(Number: integer; RightTop: TPoint);
  var
    FromX,q,x,y,backY: integer;
    strNumber: string;
    NumberImage: PImageDataHeader;
  begin
    if Numbers.Count>0 then
    begin
      strNumber:=IntToStr(Number);
      //от правого края отсчитать по 5 пикселей на каждую цифру
      FromX:=RightTop.X-Length(strNumber)*5;
      for q := 1 to Length(strNumber) do
      begin
        NumberImage:=Numbers[StrToIntDef(strNumber[q],0)];
        RGBArrayPicture:=NumberImage.Data;
        for y := 0 to NumberImage.Height-1 do
        begin
          backY:=RightTop.Y+y;
          for x := 0 to NumberImage.Width-1 do
            if RGBArrayPicture[y*NumberImage.Width+x].rgbtBlue>0 then
              Move(RGBArrayPicture[y*NumberImage.Width+x],RGBArrayBG[backY*BackGround.Width+FromX+x],3);
        end;
        FromX:=FromX+5;
      end;
    end;
  end;

  procedure ShowFloatNumbers;
  begin
    if FloatTill>Now then
      ShowNumbers(FloatScore,FloatPoint);
  end;

  procedure ShowPlayer(var APlayer: TPlayer; var AHitRect: TRect; var AAffectImage: PImageDataHeader);
  var
    PlayerImage: PImageDataHeader;
    y,x: integer;
    CurAction: string;
    ActionPos,XPos,AffectPos,backY: integer;
    Reverse: boolean;
    Animation: TAnimation;
    CurHit: TRect;
    Offset: integer;
    tmpAffectImage: PImageDataHeader;
  begin
    try
      CurAction:=APlayer.CurAction;
      ActionPos:=APlayer.ActionPos;
      XPos:=APlayer.XPos;
      Reverse:=APlayer.Reverse;
      if APlayer.Animations.ContainsKey(CurAction) then
      begin
        Animation:=APlayer.Animations[CurAction];
        //игроки
        AffectPos:=ActionPos;
        PlayerImage:=Animation.FrameWithInc(ActionPos);
        RGBArrayPicture:=PlayerImage.Data;
        XPos:=XPos+PlayerImage.Left*PlayerImage.Reserved1;
        if XPos<0 then
          XPos:=0
        else if XPos>320-PlayerImage.Width then
          XPos:=320-PlayerImage.Width;
        if Reverse then
          for y := 0 to PlayerImage.Height-1 do
          begin
            backY:=PlayerY-PlayerImage.Height+y;
            for x := 0 to PlayerImage.Width-1 do
              if RGBArrayPicture[y*PlayerImage.Width+x].rgbtBlue>0 then
                Move(RGBArrayPicture[y*PlayerImage.Width+x],RGBArrayBG[backY*BackGround.Width+320-XPos-x],3);
          end
        else
          for y := 0 to PlayerImage.Height-1 do
          begin
            backY:=PlayerY-PlayerImage.Height+y;
            for x := 0 to PlayerImage.Width-1 do
              if RGBArrayPicture[y*PlayerImage.Width+x].rgbtBlue>0 then
                Move(RGBArrayPicture[y*PlayerImage.Width+x],RGBArrayBG[backY*BackGround.Width+x+XPos],3);
          end;
        if PlayerImage.Top>0 then
        begin
          if HitRect.ContainsKey(CurAction) then
          begin
            CurHit:=HitRect[CurAction];
            AHitRect.Top:=PlayerY-PlayerImage.Height+CurHit.Top;
            AHitRect.Bottom:=PlayerY-PlayerImage.Height+CurHit.Bottom;
            if Reverse then
              AHitRect.Left:=320-XPos-CurHit.Left-1
            else
              AHitRect.Left:=XPos+CurHit.Left;
            AHitRect.Right:=AHitRect.Left+1;
          end;
        end;
        //места возможных попаданий
        tmpAffectImage:=Animation.Affect(AffectPos);
        if assigned(tmpAffectImage) then
        begin
          GetMem(AAffectImage,PImageDataHeader(FPicture).TimedDataHeader.DataHeader.Size);
          FillChar(AAffectImage^,PImageDataHeader(FPicture).TimedDataHeader.DataHeader.Size,0);
          Move(FPicture^,AAffectImage^,SizeOf(TImageDataHeader));
          RGBArrayPicture:=tmpAffectImage.Data;
          RGBArrayAffectPattern:=AAffectImage.Data;
          for y := 0 to tmpAffectImage.Height-1 do
          begin
            backY:=PlayerY-tmpAffectImage.Height+y;
            for x := 0 to tmpAffectImage.Width-1 do
              if RGBArrayPicture[y*tmpAffectImage.Width+x].rgbtBlue>0 then
              begin
                if Reverse then
                  Offset:=backY*BackGround.Width+320-XPos-x
                else
                  Offset:=backY*BackGround.Width+x+XPos;
                RGBArrayAffectPattern[Offset].rgbtBlue:=255;
              end;
          end;
        end;
        APlayer.XPos:=XPos;
        if CurAction=APlayer.CurAction then
        begin
          APlayer.ActionPos:=ActionPos;
          if APlayer.ActionPos=0 then
          begin
            if APlayer.CurAction='Round' then
            begin
              APlayer.Reverse:=not APlayer.Reverse;
              APlayer.XPos:=320-APlayer.XPos-PlayerImage.Width;
            end;
            CurAction:=APlayer.CurAction;
            if APlayer.CurAction='Fall' then
              APlayer.CurAction:='FallBack'
            else if APlayer.CurAction='FFall' then
              APlayer.CurAction:='FallFront'
            else if APlayer.CurAction='SitFall' then
              APlayer.CurAction:='SitFallFall';
            if CurAction<>APlayer.CurAction then
            begin
              //звук падения
              q:=RANDOM(5);
              PlaySound(PChar('Sound/Fall_'+IntToStr(q)+'.wav'),0,SND_NODEFAULT Or SND_ASYNC);
            end;
            if (APlayer.CurAction<>'FallBack')and(APlayer.CurAction<>'FallFront')
                and(APlayer.CurAction<>'SitFallFall') then
              APlayer.CurAction:='Stay';
          end;
        end;
      end;
    except on e: Exception do
      SendErrorMsg('TGameRender.DoExecute.ShowPlayer 275: '+e.ClassName+' - '+e.Message);
    end;
  end;

  procedure ShowWins;
  begin
    ShowNumbers(Player1.Wins,Point(120,6));
    ShowNumbers(Player2.Wins,Point(200,6));
  end;

begin
  if FTerminated then
    exit;
  if assigned(StopFrame) then
  begin
    Move(StopFrame^,FPicture^,BackGround.TimedDataHeader.DataHeader.Size);
    inherited DoExecute;
    exit;
  end;
  //фон
  RGBArrayBG:=PImageDataHeader(FPicture).Data;
  Move(BackGround.Data^,RGBArrayBG^,BackGround.TimedDataHeader.DataHeader.Size-SizeOf(TImageDataHeader));
  //показать счёт
  ShowNumbers(Player1.Points,Point(26,2));
  ShowNumbers(Player2.Points,Point(320,2));

  HitRect1.Top:=0;
  AffectImage1:=nil;
  AffectImage2:=nil;
  FLock.Enter;
  //Игорьки
  ShowPlayer(Player1,HitRect1,AffectImage1);
  HitRect2.Top:=0;
  ShowPlayer(Player2,HitRect2,AffectImage2);
  ShowArbiter;
  //плавающий счёт
  ShowFloatNumbers;
  //Таймер
  ShowNumbers(MatchTimer.Timer,Point(165,2));

  //очки попаданий
  ShowBalls;

  //счётчик побед
  ShowWins;

  inherited DoExecute;

  if FTerminated then
    exit;
  NextRound:=false;
  NextMatch:=false;
  if MatchTimer.Timer<=0 then
  begin
    MatchTimer.Paused:=true;
    if (Player1.HitCount>=3)or(Player1.Points>Player2.Points) then
      PlayerWins:=1
    else if (Player2.HitCount>=3)or(Player1.Points<Player2.Points) then
      PlayerWins:=2
    else
      PlayerWins:=0;
    if PlayerWins=1 then
    begin
      if Player1.CurAction<>'Greet' then
      begin
        Player1.CurAction:='Greet';
        Player1.ActionPos:=0;
        if Player1.HitCount<3 then
          Player1.HitCount:=3;
        SetArbiterIndex(Arbiter_White);
      end;
    end
    else if PlayerWins=2 then
    begin
      if Player2.CurAction<>'Greet' then
      begin
        Player2.CurAction:='Greet';
        Player2.ActionPos:=0;
        if Player2.HitCount<3 then
          Player2.HitCount:=3;
        SetArbiterIndex(Arbiter_Red);
      end;
    end
    else
    begin
      Player1.CurAction:='Greet';
      Player2.CurAction:='Greet';
      SetArbiterIndex(Arbiter_Draw);
    end;
    IncWin;
    if (Player1.HitCount>=3)or(Player2.HitCount>=3) then
      SetArbiterIndex(Arbiter_Full);
    NextMatch:=(Player1.CurAction='Greet')and(Player1.ActionPos+1=Player1.Animations['Greet'].Count);
    NextMatch:=NextMatch or ((Player2.CurAction='Greet')and(Player2.ActionPos+1=Player2.Animations['Greet'].Count));
  end
  else
  begin
    if Player1.Reverse=Player2.Reverse then
      FallAction:='FFall'
    else
      FallAction:='Fall';
    //попадание?
    if assigned(AffectImage2) then
    begin
      if HitRect1.Top>0 then
      begin
        q:=RANDOM(5);
        PlaySound(PChar('Sound/Hit_'+IntToStr(q)+'.wav'),0,SND_NODEFAULT Or SND_ASYNC);
        //в пузо
        if ((HitRect1.Top=156)or(HitRect1.Top=167))and(Player1.Reverse<>Player2.Reverse) then
          FallAction:='SitFall';
        //есть попадение?
        RGBArrayPicture:=AffectImage2.Data;
        for CheckY := HitRect1.Top to HitRect1.Bottom do
          for CheckX := HitRect1.Left to HitRect1.Right do
            if RGBArrayPicture[CheckY*AffectImage2.Width+CheckX].rgbtBlue>0 then
            begin
              if not MatchTimer.Paused then
                Player1.HitCount:=Player1.HitCount+1;
              MatchTimer.Paused:=true;
              CheckHitScore(Player1,Player2);
              if pos('Punch',Player1.CurAction)>0 then
                Player1.CurAction:='Blow';
              Player2.CurAction:=FallAction;
              Player2.ActionPos:=0;
              SetArbiterIndex(Arbiter_White);
              break;
            end;
      end;
      freemem(AffectImage2);
    end;
    if assigned(AffectImage1) then
    begin
      if (Player2.CurAction<>FallAction)and(HitRect2.Top>0) then
      begin
        q:=RANDOM(5);
        PlaySound(PChar('Sound/Hit_'+IntToStr(q)+'.wav'),0,SND_NODEFAULT Or SND_ASYNC);
        //в пузо
        if ((HitRect2.Top=156)or(HitRect2.Top=167))and(Player1.Reverse<>Player2.Reverse) then
          FallAction:='SitFall';
        RGBArrayPicture:=AffectImage1.Data;
        for CheckY := HitRect2.Top to HitRect2.Bottom do
          for CheckX := HitRect2.Left to HitRect2.Right do
            if RGBArrayPicture[CheckY*AffectImage1.Width+CheckX].rgbtBlue>0 then
            begin
              if not MatchTimer.Paused then
                Player2.HitCount:=Player2.HitCount+1;
              MatchTimer.Paused:=true;
              CheckHitScore(Player2,Player1);
              if pos('Punch',Player2.CurAction)>0 then
                Player2.CurAction:='Blow';
              Player1.CurAction:=FallAction;
              Player1.ActionPos:=0;
              SetArbiterIndex(Arbiter_Red);
              break;
            end;
      end;
      freemem(AffectImage1);
    end;
    if (Player2.CurAction<>'Blow') and //(ArbiterTill<Now) and
        ((Player1.CurAction='FallBack') or (Player1.CurAction='FallFront') or (Player1.CurAction='SitFallFall')) then
    begin
      Player2.CurAction:='Greet';
      //Player2.ActionPos:=0;
    end
    else if (Player1.CurAction<>'Blow') and //(ArbiterTill<Now) and
        ((Player2.CurAction='FallBack') or (Player2.CurAction='FallFront') or (Player2.CurAction='SitFallFall')) then
    begin
      Player1.CurAction:='Greet';
      //Player1.ActionPos:=0;
    end;
    NextRound:=(((Player1.CurAction='Greet')and(Player1.ActionPos+1=Player1.Animations['Greet'].Count)and
        ((Player2.CurAction='FallBack') or (Player2.CurAction='FallFront') or (Player2.CurAction='SitFallFall') ))
        or
        (((Player2.CurAction='Greet')and(Player2.ActionPos+1=Player2.Animations['Greet'].Count))and
        (Player1.CurAction='FallBack') or (Player1.CurAction='FallFront') or (Player1.CurAction='SitFallFall')));
  end;
  if (Player1.HitCount>=3)or(Player2.HitCount>=3) then
  begin
    IncWin;
    MatchTimer.Paused:=true;
    MatchTimer.Timer:=0;
  end;
  FLock.Leave;
  if (ArbiterTill<Now)or NextMatch then
  begin
    if NextRound then
      StartRound
    else if NextMatch then
    begin
      if (Player1.Wins>=2)or(Player2.Wins>=2) then
      begin
        //показать конец матча
        SetArbiterIndex(Arbiter_Over);
        ShowArbiter;
        //фотаем экран и показываем только его
        GetMem(StopFrame,BackGround.TimedDataHeader.DataHeader.Size);
        Move(FPicture^,StopFrame^,BackGround.TimedDataHeader.DataHeader.Size);
        MatchOverTime:=now;
      end
      else
        StartGame;
    end;
  end;
end;

procedure TGameRender.DoReceive(var AInputData: Pointer);
begin
  inherited;

end;

procedure TGameRender.DropWins;
begin
  Player1.Wins:=0;
  Player2.Wins:=0;
end;

procedure TGameRender.Finish;
begin

end;

procedure TGameRender.IncWin;
begin
  if Player1.HitCount=3 then
  begin
    Player1.Wins:=Player1.Wins+1;
    Player1.HitCount:=4;
  end
  else if Player2.HitCount=3 then
  begin
    Player2.Wins:=Player2.Wins+1;
    Player2.HitCount:=4;
  end;
end;

procedure TGameRender.LoadNumbers;
var
  q,y: integer;
  Path: string;
  bmp: TBitmap;
  tmpDataSize: Cardinal;
  NumberPicture: PImageDataHeader;
  ImageRGBArray: PByteArray;
begin
  Path:=ExtractFilePath(ParamStr(0))+'Graph/';
  bmp:=TBitmap.Create;
  try
    for q := 0 to 9 do
    begin
      bmp.LoadFromFile(Path+IntToStr(q)+'.bmp');
      tmpDataSize:=SizeOf(TImageDataHeader)+bmp.Width*bmp.Height*3;
      GetMem(NumberPicture,tmpDataSize);
      FillChar(NumberPicture^,tmpDataSize,0);
      NumberPicture.TimedDataHeader.DataHeader.Magic:=16961;
      NumberPicture.TimedDataHeader.DataHeader.Version:=0;
      NumberPicture.TimedDataHeader.DataHeader.DataType:=2;
      NumberPicture.TimedDataHeader.DataHeader.Size:=tmpDataSize;
      NumberPicture.Width:=bmp.Width;
      NumberPicture.Height:=bmp.Height;
      NumberPicture.ImageType:=itBGR;
      NumberPicture.FlipMarker:=false;
      ImageRGBArray:=NumberPicture.Data;
      for y := 0 to bmp.Height-1 do
        Move(bmp.ScanLine[y]^,ImageRGBArray[y*bmp.Width*3],bmp.Width*3);
      Numbers.Add(NumberPicture);
    end;
  finally
    FreeAndNil(bmp);
  end;
end;

procedure TGameRender.LoadPlayerAnimation(Animations: TDictionary<string,TAnimation>; PlayerIndex: integer);
var
  sl: TStringList;
  KeyName: string;
  Animation: TAnimation;
  ImageDataHeader: PImageDataHeader;
  q: integer;
  x,y: integer;
  RGBArray: PRGBArray;
  CurHit: TRect;
begin
  sl:=TStringList.Create;
  try
    //стоит
    sl.Text:='Stay';
    Animations.Add('Stay',TAnimation.Create(sl));
    //приветствие
    sl.Text:='Greet_0;-2'#13#10'Greet_1'#13#10'Greet_1'#13#10'Greet_1'#13#10'Greet_1'#13#10'Greet_1'#13#10+
        'Greet_0'#13#10'Stay;2'#13#10'Stay;0';
    Animations.Add('Greet',TAnimation.Create(sl));
    //движение
    sl.Text:='Go_0;10'#13#10'Go_1;10'#13#10'Go_2;6'#13#10'Go_3;6'#13#10'Stay;0';
    Animations.Add('Go',TAnimation.Create(sl));
    sl.Text:='Go_3;-2'#13#10'Go_2;-5'#13#10'Go_1;-5'#13#10'Go_0;-10'#13#10'Stay;-10';
    Animations.Add('GoBack',TAnimation.Create(sl));
    //приседание
    sl.Text:='Sit';
    Animations.Add('Sit',TAnimation.Create(sl));
    //сальто
    sl.Text:='Salto_5;7'#13#10'Salto_0;8'#13#10'Salto_1;10'#13#10'Salto_2;18'#13#10'Salto_3;16'#13#10+
        'Salto_4;15'#13#10'Salto_5;10'#13#10'Stay';
    Animations.Add('Salto',TAnimation.Create(sl));
    sl.Text:='Salto_5;-5'#13#10'Salto_4;-10'#13#10'Salto_3;-11'#13#10'Salto_2;-12'#13#10'Salto_1;-10'#13#10+
        'Salto_0;-8'#13#10'Salto_5;-7'#13#10'Stay';
    Animations.Add('SaltoBack',TAnimation.Create(sl));
    //поворот
    sl.Text:='Round_0'#13#10'Round_1'#13#10'Round_2';
    Animations.Add('Round',TAnimation.Create(sl));
    //блок стоя
    sl.Text:='Block';
    Animations.Add('Block',TAnimation.Create(sl));
    //падение назад
    sl.Text:='Fall_0;-10'#13#10'Fall_1;-19'#13#10'Fall_2;-5'#13#10'Fall_3;-5';
    Animations.Add('Fall',TAnimation.Create(sl));
    sl.Text:='Fall_3';
    Animations.Add('FallBack',TAnimation.Create(sl));

    //прыжок
    sl.Text:='Salto_5;0'#13#10'Jump;0'#13#10'Jump'#13#10'Salto_5;0'#13#10'Stay';
    Animations.Add('Jump',TAnimation.Create(sl));
    //сел на жопу
    sl.Text:='SitFall_0;-5'#13#10'SitFall_0;-5'#13#10'SitFall_1;-5'#13#10'SitFall_2;-5'#13#10'SitFall_3;-5';
    Animations.Add('SitFall',TAnimation.Create(sl));
    sl.Text:='SitFall_3';
    Animations.Add('SitFallFall',TAnimation.Create(sl));

    //дышит на руку
    sl.Text:='Stay'#13#10'Stay'#13#10'Stay'#13#10'Stay'#13#10'Stay'#13#10'Stay'#13#10'Blow_0'#13#10+
        'Blow_0'#13#10'Blow_0'#13#10'Blow_1'#13#10'Blow_2'#13#10+
        'Blow_1'#13#10'Blow_2'#13#10'Stay'#13#10'Stay'#13#10'Stay'#13#10'Stay'#13#10'Stay'#13#10'Stay';
    Animations.Add('Blow',TAnimation.Create(sl));
    //падение вперёд
    sl.Text:='FFall_0;5'#13#10'FFall_1;11'#13#10'FFall_2;14'#13#10'FFall_3;9';
    Animations.Add('FFall',TAnimation.Create(sl));
    sl.Text:='FFall_3';
    Animations.Add('FallFront',TAnimation.Create(sl));

    //удар в прыжке
    sl.Text:='Salto_5;8'#13#10'Jump;8'#13#10'JumpKick;8;1'#13#10'JumpKick;8;1'#13#10'Salto_5;8'#13#10'Stay';
    Animations.Add('JumpKick',TAnimation.Create(sl,500));
    //лоу кик
    sl.Text:='Kick_0;-12'#13#10'LowKick;0;1'#13#10'LowKick;0;1'#13#10'Kick_0'#13#10'Stay;12';
    Animations.Add('LowKick',TAnimation.Create(sl,200));
    //кулаком в приседе
    sl.Text:='Sit'#13#10'LowPunch;0;1'#13#10'LowPunch;0;1'#13#10'Sit';
    Animations.Add('LowPunch',TAnimation.Create(sl,200));
    //кулаком стоя
    sl.Text:='Punch_0;4'#13#10'Punch_1;0;1'#13#10'Punch_1;0;1'#13#10'Punch_0'#13#10'Stay;-4';
    Animations.Add('Punch',TAnimation.Create(sl,400));
    //подсечка
    sl.Text:='Sit'#13#10'Undercut_0'#13#10'Undercut_1;0;1'#13#10'Undercut_1;0;1'#13#10'Undercut_0'#13#10'Sit';
    Animations.Add('Undercut',TAnimation.Create(sl,200));
    //кик
    sl.Text:='Kick_0;-10'#13#10'Kick_1;-12'#13#10'Kick_2;-4;1'#13#10'Kick_2;0;1'#13#10'Kick_0;14'#13#10'Stay;12';
    Animations.Add('Kick',TAnimation.Create(sl,200));
    //с разворота
    sl.Text:='RoundKick_0;5'#13#10'RoundKick_1;-2'#13#10'RoundKick_2'#13#10'RoundKick_3;14'#13#10+
        'RoundKick_4;-22;1'#13#10'RoundKick_4;0;1'#13#10'Kick_0;4'#13#10'Stay;1';
    Animations.Add('RoundKick',TAnimation.Create(sl,500));
    //хай кик
    sl.Text:='Kick_0;-10'#13#10'HighKick_0;-12'#13#10'HighKick_1;0;1'#13#10'HighKick_1;0;1'#13#10'Kick_0;12'#13#10+
        'Stay;10';
    Animations.Add('HighKick',TAnimation.Create(sl,400));
  finally
    FreeAndNil(sl);
  end;
  //покрасить в нужные цвета
  for KeyName in Animations.Keys do
  begin
    Animation:=Animations[KeyName];
    for q := 0 to Animation.Count-1 do
    begin
      ImageDataHeader:=Animation.Frame(q);
      RGBArray:=ImageDataHeader.Data;
      for y := 0 to ImageDataHeader.Height-1 do
        for x := 0 to ImageDataHeader.Width-1 do
          if RGBArray[y*ImageDataHeader.Width+x].rgbtRed=221 then
          begin
            if PlayerIndex=1 then
            begin
              RGBArray[y*ImageDataHeader.Width+x].rgbtBlue:=255;
              RGBArray[y*ImageDataHeader.Width+x].rgbtGreen:=255;
              RGBArray[y*ImageDataHeader.Width+x].rgbtRed:=255;
            end
            else
            begin
              RGBArray[y*ImageDataHeader.Width+x].rgbtBlue:=19;
              RGBArray[y*ImageDataHeader.Width+x].rgbtGreen:=92;
              RGBArray[y*ImageDataHeader.Width+x].rgbtRed:=194;
            end;
          end;
      //заполняем зоны ударов
      if (PlayerIndex=1)and(ImageDataHeader.Top>0)and(not HitRect.ContainsKey(KeyName)) then
      begin
        CurHit.Left:=ImageDataHeader.Width-2;
        CurHit.Right:=ImageDataHeader.Width;
        //прямоугольник формируемый розовым цветом в самых правых двух рядах
        for y := 0 to ImageDataHeader.Height-1 do
          if RGBArray[y*ImageDataHeader.Width+CurHit.Left].rgbtRed=253 then
          begin
            CurHit.Top:=y;
            break;
          end;
        for y := ImageDataHeader.Height-1 downto 0 do
          if RGBArray[y*ImageDataHeader.Width+CurHit.Left].rgbtRed=253 then
          begin
            CurHit.Bottom:=y;
            break;
          end;
        HitRect.Add(KeyName,CurHit);
        //SendErrorMsg('TGameRender.LoadPlayerAnimation 387: '+IntToStr(ImageDataHeader.Height-CurHit.Top)+':'+
        //    IntToStr(ImageDataHeader.Height-CurHit.Bottom));
      end;
    end;
  end;
end;

procedure TGameRender.RandBackground;
var
  bmp: TBitmap;
  tmpDataSize: Cardinal;
  ByteArray: PByteArray;
  y,x: integer;
begin
  //загрузка случайного фона
  bmp:=TBitmap.Create;
  try
    x:=RANDOM(9);
    bmp.LoadFromFile(ExtractFilePath(ParamStr(0))+'\Graph\BG_'+IntToStr(x)+'.bmp');
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
  finally
    FreeAndNil(bmp);
  end;
end;

procedure TGameRender.SetArbiterIndex(AIndex: integer);
begin
  ArbiterIndex:=AIndex;
  ArbiterTill:=IncSecond(Now,1);
end;

procedure TGameRender.SetFloatNumbers(Number: integer; Point: TPoint);
begin
  FloatScore:=Number;
  FloatPoint:=Point;
  FloatTill:=IncSecond(Now,2);
end;

procedure TGameRender.StartGame;
begin
  if IncSecond(MatchOverTime,3)>now then
    Sleep(3000);
  if assigned(StopFrame) then
    FreeMem(StopFrame);
  StopFrame:=nil;
  FLock.Enter;
  //фон
  RandBackGround;
  FLock.Leave;
  Player1.Points:=0;
  Player2.Points:=0;
  MatchTimer.Timer:=30;
  MatchTimer.Paused:=true;
  Player1.HitCount:=0;
  Player2.HitCount:=0;
  StartRound;
end;

procedure TGameRender.StartRound;
begin
  FLock.Enter;
  //Игорьки
  Player1.CurAction:='Greet';
  Player1.ActionPos:=0;
  Player1.XPos:=64;
  Player1.Reverse:=false;
  Player2.CurAction:='Greet';
  Player2.ActionPos:=0;
  Player2.XPos:=64;
  Player2.Reverse:=true;
  SetArbiterIndex(Arbiter_Begin);
  FloatTill:=0;
  MatchTimer.Paused:=false;
  FLock.Leave;
end;

end.

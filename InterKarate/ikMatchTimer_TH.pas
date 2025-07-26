unit ikMatchTimer_TH;

interface

uses
  ABL.Core.TimerThread;

type
  TMatchTimer=class(TTimerThread)
  private
    FTimer: integer;
    FPaused: boolean;
    function GetPaused: boolean;
    function GetTimer: integer;
    procedure SetPaused(const Value: boolean);
    procedure SetTimer(ATimer: integer);
  protected
    procedure DoExecute; override;
  public
    constructor Create(AName: string = ''); override;
    property Paused: boolean read GetPaused write SetPaused;
    property Timer: integer read GetTimer write SetTimer;
  end;

implementation

{ TMatchTimer }

constructor TMatchTimer.Create(AName: string);
begin
  inherited Create(AName);
  Start;
end;

procedure TMatchTimer.DoExecute;
begin
  FLock.Enter;
  if not FPaused then
    FTimer:=FTimer-1;
  FLock.Leave;
end;

function TMatchTimer.GetPaused: boolean;
begin
  FLock.Enter;
  result:=FPaused;
  FLock.Leave;
end;

function TMatchTimer.GetTimer: integer;
begin
  FLock.Enter;
  result:=FTimer;
  FLock.Leave;
end;

procedure TMatchTimer.SetPaused(const Value: boolean);
begin
  FLock.Enter;
  FPaused:=Value;
  FLock.Leave;
end;

procedure TMatchTimer.SetTimer(ATimer: integer);
begin
  FLock.Enter;
  FTimer:=ATimer;
  FLock.Leave;
end;

end.

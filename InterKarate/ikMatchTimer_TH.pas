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
    destructor Destroy; override;
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

destructor TMatchTimer.Destroy;
begin
  Enabled:=false;
  StopReceive;
  Stop;
  inherited;
end;

procedure TMatchTimer.DoExecute;
begin
  FBaseThreadLock.Enter;
  if not FPaused then
    FTimer:=FTimer-1;
  FBaseThreadLock.Leave;
end;

function TMatchTimer.GetPaused: boolean;
begin
  FBaseThreadLock.Enter;
  result:=FPaused;
  FBaseThreadLock.Leave;
end;

function TMatchTimer.GetTimer: integer;
begin
  FBaseThreadLock.Enter;
  result:=FTimer;
  FBaseThreadLock.Leave;
end;

procedure TMatchTimer.SetPaused(const Value: boolean);
begin
  FBaseThreadLock.Enter;
  FPaused:=Value;
  FBaseThreadLock.Leave;
end;

procedure TMatchTimer.SetTimer(ATimer: integer);
begin
  FBaseThreadLock.Enter;
  FTimer:=ATimer;
  FBaseThreadLock.Leave;
end;

end.

unit periodic_timers;

interface

uses
  SysUtils, Classes, Vcl.ExtCtrls,
  mormot.core.collections;

type
  TTimerCallback = TNotifyEvent;
  TPeriodicTimer = class
  private
    FTimer: TTimer;
    FCallback: TTimerCallback;
  public
    constructor Create(AInterval: Integer; ACallback: TTimerCallback);
    destructor Destroy; override;
  end;

  TPeriodicTimers = class
  private
    FTimers: IList<TPeriodicTimer>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddTimer(AInterval: Integer; ACallback: TTimerCallback);
    procedure StartTimers;
    procedure StopTimers;
  end;

implementation

{ TPeriodicTimer }

constructor TPeriodicTimer.Create(AInterval: Integer; ACallback: TTimerCallback);
begin
  inherited Create;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := AInterval;
  FTimer.OnTimer := ACallback;
  FCallback := ACallback;
end;

destructor TPeriodicTimer.Destroy;
begin
  FTimer.Free;
  inherited;
end;

{ TPeriodicTimers }

constructor TPeriodicTimers.Create;
begin
  inherited;
  FTimers := Collections.NewList<TPeriodicTimer>;
end;

destructor TPeriodicTimers.Destroy;
var
  timer: TPeriodicTimer;
begin
  try
    for timer in FTimers do
      timer.Free;    
  finally
    FTimers.Clear;
  end;
  
  inherited;
end;

procedure TPeriodicTimers.AddTimer(AInterval: Integer; ACallback: TTimerCallback);
begin
  FTimers.Add(TPeriodicTimer.Create(AInterval, ACallback));
end;

procedure TPeriodicTimers.StartTimers;
var
  Timer: TPeriodicTimer;
begin
  for Timer in FTimers do
    Timer.FTimer.Enabled := True;
end;

procedure TPeriodicTimers.StopTimers;
var
  Timer: TPeriodicTimer;
begin
  for Timer in FTimers do
    Timer.FTimer.Enabled := False;
end;

end.


unit callbacks;

interface

uses
  SysUtils, Classes, Rtti, TypInfo,
  mormot.core.collections;

type
  TCallbacks = class
  private
    FBeforeSubscribe: IList<TProc>;
    FAfterSubscribe: IList<TProc>;
    FBeforeUnsubscribe: IList<TProc>;
    FAfterUnsubscribe: IList<TProc>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddBeforeSubscribeCallback(ACallback: TProc);
    procedure AddAfterSubscribeCallback(ACallback: TProc);
    procedure AddBeforeUnsubscribeCallback(ACallback: TProc);
    procedure AddAfterUnsubscribeCallback(ACallback: TProc);
    procedure RunBeforeSubscribeCallbacks;
    procedure RunAfterSubscribeCallbacks;
    procedure RunBeforeUnsubscribeCallbacks;
    procedure RunAfterUnsubscribeCallbacks;
  end;

implementation

constructor TCallbacks.Create;
begin
  inherited;
  FBeforeSubscribe := Collections.NewList<TProc>;
  FAfterSubscribe := Collections.NewList<TProc>;
  FBeforeUnsubscribe := Collections.NewList<TProc>;
  FAfterUnsubscribe := Collections.NewList<TProc>;
end;

destructor TCallbacks.Destroy;
begin
  FBeforeSubscribe.Clear;
  FAfterSubscribe.Clear;
  FBeforeUnsubscribe.Clear;
  FAfterUnsubscribe.Clear;
  inherited;
end;

procedure TCallbacks.AddBeforeSubscribeCallback(ACallback: TProc);
begin
  FBeforeSubscribe.Add(ACallback);
end;

procedure TCallbacks.AddAfterSubscribeCallback(ACallback: TProc);
begin
  FAfterSubscribe.Add(ACallback);
end;

procedure TCallbacks.AddBeforeUnsubscribeCallback(ACallback: TProc);
begin
  FBeforeUnsubscribe.Add(ACallback);
end;

procedure TCallbacks.AddAfterUnsubscribeCallback(ACallback: TProc);
begin
  FAfterUnsubscribe.Add(ACallback);
end;

procedure TCallbacks.RunBeforeSubscribeCallbacks;
var
  Callback: TProc;
begin
  for Callback in FBeforeSubscribe do
    Callback();
end;

procedure TCallbacks.RunAfterSubscribeCallbacks;
var
  Callback: TProc;
begin
  for Callback in FAfterSubscribe do
    Callback();
end;

procedure TCallbacks.RunBeforeUnsubscribeCallbacks;
var
  Callback: TProc;
begin
  for Callback in FBeforeUnsubscribe do
    Callback();
end;
      
procedure TCallbacks.RunAfterUnsubscribeCallbacks;
var
  Callback: TProc;
begin
  for Callback in FAfterUnsubscribe do
    Callback();
end;

end.

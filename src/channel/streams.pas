unit streams;

interface

uses
  SysUtils, Classes,
  mormot.core.collections;

type
  TStreamHandler = reference to procedure(const pmcMessage: string);

  TStreams = class
  private
    FStreams: IKeyValue<string, TStreamHandler>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure StreamFrom(const pmcBroadcasting: string; AHandler: TStreamHandler);
    procedure StopStreamFrom(const pmcBroadcasting: string);
    procedure StopAllStreams;
    procedure Broadcast(const pmcBroadcasting, pmcMessage: string);
  end;

implementation

constructor TStreams.Create;
begin
  inherited;
  FStreams := Collections.NewKeyValue<string, TStreamHandler>;
end;

destructor TStreams.Destroy;
begin
  FStreams.Clear;
  inherited;
end;

procedure TStreams.StreamFrom(const pmcBroadcasting: string; AHandler: TStreamHandler);
begin
  FStreams.TryAdd(pmcBroadcasting, AHandler);
end;

procedure TStreams.StopStreamFrom(const pmcBroadcasting: string);
begin
  FStreams.Remove(pmcBroadcasting);
end;

procedure TStreams.StopAllStreams;
begin
  FStreams.Clear;
end;

procedure TStreams.Broadcast(const pmcBroadcasting, pmcMessage: string);
var
  Handler: TStreamHandler;
begin
  if FStreams.TryGetValue(pmcBroadcasting, Handler) then
    Handler(pmcMessage);
end;

end.


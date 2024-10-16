unit broadcasting;

interface

uses
  SysUtils,
  mormot.core.base,
  mormot.core.text,
  mormot.net.ws.server,
  init,
  base;

type
  TChannelBroadcasting = class
  public
    class procedure BroadcastTo(Model: TObject; const Message: RawUtf8);
    class function BroadcastingFor(Model: TObject): RawUtf8;
  private
    class function SerializeBroadcasting(pmcObject: TObject): RawUtf8;
  end;

implementation

{ TChannelBroadcasting }

class procedure TChannelBroadcasting.BroadcastTo(Model: TObject; const Message: RawUtf8);
begin
  TActionCable.Broadcast(BroadcastingFor(Model), Message);
end;

class function TChannelBroadcasting.BroadcastingFor(Model: TObject): RawUtf8;
begin
  Result := SerializeBroadcasting(Model);
end;

class function TChannelBroadcasting.SerializeBroadcasting(pmcObject: TObject): RawUtf8;
begin
  if pmcObject is TClass then
    Result := (pmcObject as TClass).ClassName
  else
    Result := pmcObject.ClassName;
end;

end.

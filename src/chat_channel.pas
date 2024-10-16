unit chat_channel;

interface

uses
  mormot.core.base,
  mormot.core.collections, 
  channel_base;

type
  TChatChannel = class(TChannelBase)
  public
    procedure PerformAction(const Action: string; const Data: IKeyValue<RawUtf8, Variant>); override;
  end;

implementation

uses
  System.SysUtils;

procedure TChatChannel.PerformAction(const Action: string; const Data: IKeyValue<RawUtf8, Variant>);
begin
  Writeln('[debug] ', Data.Data.SaveToJson);

  if Action = 'send_message' then
  begin
    // Example of sending a message
    Writeln(Format('Sending message: %s', [Data['message']]));    
  end
  else if Action = 'join' then
  begin
    // Example of joining a chat room
    Writeln(Format('User %s joined the chat', [Data['user']]));
  end
  else if Action = 'subscribe' then
  begin
    // Example of joining a chat room
    Writeln(Format('User %s subscribed', [Data['user']]));
  end
  else
  begin
    Writeln('Unknown action: ' + Action);
  end;
end;

end.


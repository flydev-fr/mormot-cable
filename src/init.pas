unit init;

interface

uses
  sysutils,
  variants,
  contnrs,
  mormot.core.base,
  mormot.core.os,
  mormot.core.text,
  mormot.net.ws.core,
  cable_server;

type
  TActionCable = class
  private
    class var FServer: TActionCableServer;
  public
    const
      INTERNAL_MESSAGE_TYPES: array[0..4] of string = (
        'welcome', 'disconnect', 'ping', 'confirm_subscription', 
        'reject_subscription');
      INTERNAL_DISCONNECT_REASONS: array[0..3] of string = (
        'unauthorized', 'invalid_request', 'server_restart', 'remote');
      DEFAULT_MOUNT_PATH = '/cable';
      PROTOCOLS: array[0..1] of string = ('actioncable-v1-json', 
        'actioncable-unsupported');
    class function Server: TActionCableServer; // Singleton instance of the server
    class procedure Broadcast(const Channel, Message: RawUtf8);    
  end;

implementation

class function TActionCable.Server: TActionCableServer;
begin
  {$I-}
  
  if FServer = nil then
    FServer := TActionCableServer.Create;
      
  Result := FServer;
  
  writeln;
  TextColor(ccLightGreen);
  writeln(FServer.HttpServer.ClassName, ' running on localhost:8082'#10);
  TextColor(ccWhite);
  writeln('try curl http://localhost:8082/cable'#10);
  TextColor(ccLightGray);
  writeln('Press [Enter] to quit'#10);
  TextColor(ccCyan);
  
  FServer.Start;
  
  ConsoleWaitForEnterKey;
  writeln(ObjectToJson(FServer.HttpServer.Server, [woHumanReadable]));
  TextColor(ccLightGray);
  {$ifdef FPC_X64MM}
  WriteHeapStatus(' ', 16, 8, {compileflags=}true);
  {$endif FPC_X64MM}               
end;
    
class procedure TActionCable.Broadcast(const Channel, Message: RawUtf8);
begin
  Server.HttpServer.Broadcast(Channel, Message);
end;

initialization
  TActionCable.Server;

finalization
  TActionCable.FServer.Free;

end.


unit ws_const;

interface

const
  USERNAME_GUEST = 'Guest';

const
  WsMsg_cmd_toUserMsg    = 'ToUserMsg';
  WsMsg_cmd_ServerNotify = 'ServerNotify';
  WsMsg_cmd_WsUserIDGet  = 'WsUserIDGet';
  
type
  TWsMsg = class
  private
    // Message ID
    FMsgID: string;
    //
    FControllerRoot: string; // Sender ConnectionID, '-1' for outgoing, base value for incoming message.
    // ConnectionID of the sender, '-1' means outgoing, base value means incoming.
    FFromUserID: string; // FControllerRoot: string; // ConnectionID of the sender.
    FFromUserName: string; // ConnectionID of the receiver.
    // ConnectionID of the receiver
    FToUserID: string; // ConnectionID of the receiver.
    // Message Success Failure Code
    FMsgCode: string; // Message Command
    // Message command
    FMsgCmd: string; // Message Command; // Message Success Failure Code
    // message
    FMsgData: string; // message time; // message time
    // Message time
    FMsgTime: string; // message time
  published
    property MsgID: string read FMsgID write FMsgID;
    property ControllerRoot: string read FControllerRoot write FControllerRoot;
    property FromUserID: string read FFromUserID write FFromUserID;
    property FromUserName: string read FFromUserName write FFromUserName;
    property ToUserID: string read FToUserID write FToUserID;
    property MsgCode: string read FMsgCode write FMsgCode;
    property MsgCmd: string read FMsgCmd write FMsgCmd;
    property MsgData: string read FMsgData write FMsgData;
    property MsgTime: string read FMsgTime write FMsgTime;
  end;
  

implementation

end.

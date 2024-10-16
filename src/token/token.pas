unit token;

// Token management
// When a client connects, it generates a GUID tokenID to identify itself, and 
// then submits the tokenID to secure the user's identity.

interface

uses
  mormot.core.base;

type
  // Role permissions 
  //   - noneRegister: access to the lowest level without registration
  //   - noneRole: accessed by anyone
  //   - userRole: accessible by users
  //   - sysUserRole: System user
  //   - sysAdminRole: System user who is an administrator.
  //   - superRole: superAdmin
  //   - platformRole: platform administrator
  TTokenRole = (noneRegister, noneRole, userRole, sysUserRole, sysAdminRole, 
    superRole, platformRole);

  TWsToken = class
  private
    FWsUserID: RawUtf8;
    FConnectionID: Int64;
    FOneTokenID: RawUtf8; // TTokenItem
    FUserName: RawUtf8;
  public
    function Copy(): TWsToken;
  published
    property WsUserID: RawUtf8 read FWsUserID write FWsUserID;
    property ConnectionID: Int64 read FConnectionID write FConnectionID;
    property OneTokenID: RawUtf8 read FOneTokenID write FOneTokenID;
    property UserName: RawUtf8 read FUserName write FUserName;
  end;

  PWsToken = ^TWsToken;
  
implementation

{ TWsToken }

function TWsToken.Copy(): TWsToken;
begin
  Result := TWsToken.Create;
  Result.FWsUserID := self.FWsUserID;
  // Result.FConnectionID := self.FConnectionID;
  // Result := self.FTokenID;
  Result.FUserName := self.FUserName;
end;

end.

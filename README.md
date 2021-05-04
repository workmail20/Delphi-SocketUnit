# Delphi-SocketUnit
Base Delphi Socket Unit for client-server projects


```delphi
var
    client_free: Boolean = true;
    server: tserversocket;

function comSERVER(sc: TClientSocket): string;
var
    t: string;
    res: DWORD;
begin
    t := sc.ReceiveString;
    //do something
    res := sc.SendString('good');

    sc.Disconnect;
    sc.Destroy;
end;

function workSERVER(sc: TClientSocket): Boolean;
var
    SockCon: TClientSocket;
begin
    client_free := false;
    SockCon := tserversocket(sc).Accept;
    client_free := true;
    SockCon.set_timeout(10000);

    comSERVER(SockCon);
end;

function start_server(): Boolean;
var
    SockCon: TClientSocket;
    thredID: Cardinal;
    threadh: DWORD;
    usedport: integer;
begin
    while true do
    begin
        usedport := 80;
        server := tserversocket.Create;
        if server <> nil then
        begin
            server.Listen(usedport);
            if server.Listening then
            begin
                while true do
                begin
                    while client_free = false do
                    begin
                        Sleep(10);
                    end;

                    client_free := false;
                    threadh := BeginThread(nil, 0, @workSERVER, Pointer(server),
                      0, thredID);
                    CloseHandle(threadh);
                end;
            end
            else
            begin
                server.Disconnect;
                server.Destroy;
                server := nil;
            end;
        end;
    end;
end;

procedure startserver;
var
  thredID:dword;
begin
  BeginThread(nil, 0, @start_server, 0, 0, thredID);
end;

```


```delphi

function sendHTTPsocket(url: string; data: string): string;
type
  sinfo = record
    url: string;
    data: string;
    answ: string;
    s: TClientSocket;
  end;
  psinfo = ^sinfo;

  function sendrecive(info: psinfo): Boolean;
  var
    s1, s2, s3, domain, path: string;
  begin
    info^.answ := '';
    domain := info^.url;
    domain := Copy(domain, Pos('//', domain) + 2, MaxInt);

    path := '/';
    if Pos('/', domain) <> 0 then
      path := Copy(domain, Pos('/', domain), MaxInt);

    if Pos('/', domain) <> 0 then
      domain := Copy(domain, 1, Pos('/', domain) - 1);

    info^.s.Connect(domain, 80);
    if info^.s.Connected = True then begin
      if info^.data = '' then
        info^.s.SendString('GET ' + path + ' HTTP/1.1' + #13#10 + 'Host: ' + domain + #13#10 + 'User-Agent: '+ #13#10 + 'Connection: close' + #13#10 + #13#10) else
        info^.s.SendString('POST ' + path + ' HTTP/1.1' + #13#10 + 'Host: ' + domain + #13#10 + 'User-Agent: ' + #13#10 + 'Connection: close' + #13#10 + 'Content-Type: application/x-www-form-urlencoded' +
          #13#10 + 'Content-Length: ' + inttostr(length(info^.data)) + #13#10 + #13#10 + info^.data);

      s1 := info^.s.ReceiveString;
      if s1 <> '' then
        info^.answ := s1;

      info^.s.Disconnect;
    end;
    info^.s.Destroy;
  end;

var
  i: sinfo;
  threadh, thredID: DWORD;
begin
  result := '';
  i.answ := '';
  i.s := TClientSocket.Create;
  i.url := url;
  i.data := data;
  if i.s <> nil then begin
    threadh := BeginThread(nil, 0, @sendrecive, Pointer(@i), 0, thredID);
    if WaitForSingleObject(threadh, 60000) = WAIT_TIMEOUT then begin
      if i.s <> nil then begin
        i.s.Disconnect;
      end;
    end else begin
      result := i.answ;
    end;
  end;
end;

procedure sendHTTP;
var
  s:string;
begin
  s:=sendHTTPsocket('http://127.0.0.1','') ;

end;
```

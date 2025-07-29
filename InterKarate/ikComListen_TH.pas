unit ikComListen_TH;

interface

uses
  Classes, Windows, ikGameRender_TH, IniFiles, SysUtils;

type
  TComListen=class(TThread)
  private
    strForSend: string;
    procedure SendAction;
  protected
    procedure Execute; override;
  end;

var
  ComListen: TComListen;


implementation

uses
  ikMain_FM;

{ TComListen }

procedure TComListen.Execute;
var
  hPort: THandle;
  comPort: string;
  dcb: TDCB;
  bytesRead: DWORD;
  bufferRead,bufferCommand: array[0..31] of Byte;
  CommandPosition: integer;
  q: integer;
  tmpByte: byte;
begin
  with TIniFile.Create(ChangeFileExt(ParamStr(0),'.ini')) do
    try
      comPort:=ReadString('MAIN','COM','COM3');
    finally
      Free;
    end;
//  comPort := 'COM3'; // Укажем COM-порт, который вы хотите открыть

  hPort := CreateFile(
    PChar('\\.\' + comPort),
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0
  );

  if hPort <> INVALID_HANDLE_VALUE then
  begin
    // COM-порт успешно открыт
    // Получить текущие настройки
    GetCommState(hPort, dcb);

    // Configure the desired settings
    dcb.BaudRate := CBR_9600; // Установите скорость передачи данных = 9600
    dcb.Parity := NOPARITY;   // No parity bit
    dcb.ByteSize := 8;        // 8 data bits
    dcb.StopBits := ONESTOPBIT; // 1 stop bit

    // Примените новые настройки
    SetCommState(hPort, dcb);
    FillChar(bufferCommand[0],32,0);
    CommandPosition:=0;
    while not Terminated do
    begin
      ReadFile(hPort, bufferRead, SizeOf(bufferRead), bytesRead, nil);
      if bytesRead>0 then
      begin
        Move(bufferRead[0],bufferCommand[CommandPosition],bytesRead);
        CommandPosition:=CommandPosition+bytesRead;
        if CommandPosition>=8 then
        begin
          for q := CommandPosition-1 downto 0 do
            if (bufferCommand[q]=10)and(q>=7) then
            begin
              strForSend:='';
              tmpByte:=bufferCommand[q-3]-48; //ось Y
              if tmpByte=1 then
                strForSend:='U'
              else if tmpByte=2 then
                strForSend:='D';
              tmpByte:=bufferCommand[q-2]-48; //ось X
              if tmpByte=1 then
                strForSend:=strForSend+'L'
              else if tmpByte=2 then
                strForSend:=strForSend+'R';
              tmpByte:=bufferCommand[q-4]-48; //кнопка
              if tmpByte=2 then
                strForSend:=strForSend+'S';
              if strForSend<>'' then
                GameRender.DoAction2(strForSend);

              strForSend:='';
              tmpByte:=bufferCommand[q-6]-48; //ось Y
              if tmpByte=1 then
                strForSend:='U'
              else if tmpByte=2 then
                strForSend:='D';
              tmpByte:=bufferCommand[q-5]-48; //ось X
              if tmpByte=1 then
                strForSend:=strForSend+'L'
              else if tmpByte=2 then
                strForSend:=strForSend+'R';
              tmpByte:=bufferCommand[q-7]-48; //кнопка
              if tmpByte=2 then
                strForSend:=strForSend+'S';
              if strForSend<>'' then
                GameRender.DoAction1(strForSend);
              CommandPosition:=0;
              FillChar(bufferCommand[0],16,0);

              break;
            end;
        end;
      end;
    end;
  end;
end;

procedure TComListen.SendAction;
begin
  if assigned(MainFM) then
  
end;

end.

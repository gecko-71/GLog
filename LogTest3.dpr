{ ***************************************************************************
  GLogger - High-Performance Thread-Safe Logger for Delphi
  Copyright (c) 2025 GLogger Contributors
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
*************************************************************************** }
program LogTest3;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Threading,
  GLog in 'GLog.pas';

begin
  try
    GLogger.WriteInfoLogLn('Application started');
    GLogger.WriteDebugLogLn('Processing data...');
    GLogger.WriteWarningLogLn('Low memory warning');
    GLogger.WriteErrorLogLn('Connection failed');
    TTask.Run(
      procedure
      begin
        GLogger.WriteInfoLogLn('Task 1 completed');
      end
    );
    TTask.Run(
      procedure
      begin
        GLogger.WriteInfoLogLn('Task 2 completed');
      end
    );
    Sleep(500);
    GLogger.WriteInfoLogLn('Application finished');
  except
    on E: Exception do
      GLogger.WriteErrorLogLn('Error: %s', [E.Message]);
  end;
  Sleep(100);
end.

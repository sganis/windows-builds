:: Golddrive
:: 03/22/2020, sganis
::
:: Build dependencies
:: 1. OpenSSL
:: 2. Zlib
:: 3. LibSSH
:: 4. LibSSH2


@echo off
setlocal
 
:: this script directory
set DIR=%~dp0
set DIR=%DIR:~0,-1%

set build_ossl=1
set build_zlib=1
set build_ssh1=1
set build_ssh2=1

::set with_zlib=0
:: run vsvars[64|32].bat and set platform
::set PLATFORM=x64
::set CONFIGURATION=Release
set "GENERATOR=Visual Studio 16 2019"

if "%APPVEYOR_BUILD_WORKER_IMAGE%"=="Visual Studio 2019" ( set "GENERATOR=Visual Studio 16 2019" )
if "%APPVEYOR_BUILD_WORKER_IMAGE%"=="Visual Studio 2017" ( set "GENERATOR=Visual Studio 15 2017" )

set CURDIR=%CD%
set TARGET=%CD%\lib
mkdir %TARGET%

set ZLIB=zlib1211
set ZLIBF=zlib-1.2.11
set OPENSSL=OpenSSL_1_1_1f
set LIBSSH=libssh-0.9.3
set LIBSSH2=libssh2-1.9.0

set CACHE=C:\cache
dir /b %CACHE% || mkdir %CACHE%

:: openssl : 	https://github.com/openssl/openssl/archive/OpenSSL_1_1_1e.zip 
:: zlib: 		http://zlib.net/zlib1211.zip
:: libssh: 		https://www.libssh.org/files/0.9/libssh-0.9.3.tar.xz
:: libssh2: 	https://github.com/libssh2/libssh2/releases/download/libssh2-1.9.0/libssh2-1.9.0.tar.gz

set OPENSSL_URL=https://github.com/openssl/openssl/archive/%OPENSSL%.zip
set ZLIB_URL=http://zlib.net/%ZLIB%.zip
set LIBSSH_URL=https://www.libssh.org/files/0.9/%LIBSSH%.tar.xz
set LIBSSH2_URL=https://www.libssh2.org/download/%LIBSSH2%.tar.gz

cd %CACHE%
if not exist openssl-%OPENSSL%.zip 	powershell -Command "Invoke-WebRequest %OPENSSL_URL% -OutFile openssl-%OPENSSL%.zip"
if not exist %ZLIB%.zip 			powershell -Command "Invoke-WebRequest %ZLIB_URL% -OutFile %ZLIB%.zip"
if not exist %LIBSSH%.tar.xz 		powershell -Command "Invoke-WebRequest %LIBSSH_URL% -OutFile %LIBSSH%.tar.xz"
if not exist %LIBSSH2%.tar.gz 		powershell -Command "Invoke-WebRequest %LIBSSH2_URL% -OutFile %LIBSSH2%.tar.gz"
cd %CURDIR%

set ARCH=x64
set OARCH=WIN64A
set DASH_X64=-x64
if %PLATFORM%==x86 (
	set ARCH=Win32
	set OARCH=WIN32
	set DASH_X64=
)

:: openssl
set PREFIX=%CD%\prefix\openssl-%PLATFORM%
set OPENSSLDIR=%PREFIX:\=/%
if %build_ossl% neq 1 goto zlib
if exist openssl-%OPENSSL% rd /s /q openssl-%OPENSSL%
%DIR%\7za.exe x %CACHE%\openssl-%OPENSSL%.zip -y >nul || goto fail
cd openssl-%OPENSSL%
mkdir build && cd build || goto fail

perl ..\Configure 						^
	no-shared 		 					^
	no-stdio 							^
	no-sock 							^
	VC-%OARCH% 							^
	--prefix=%PREFIX% 					^
	--openssldir=%PREFIX%

rem	no-engine no-hw no-comp				

nmake build_libs >nul
nmake install_dev >nul

xcopy %PREFIX%\include %TARGET%\openssl\include /y /s /i >nul
xcopy %PREFIX%\lib\libcrypto.lib* %TARGET%\openssl\lib\%PLATFORM% /y /s /i 
cd %CURDIR%
dir /b %TARGET%\openssl\include >nul || goto fail
dir /b %TARGET%\openssl\lib\%PLATFORM%\libcrypto.lib >nul || goto fail


:zlib
set PREFIX=%CD%\prefix\zlib-%PLATFORM%
set ZLIBDIR=%PREFIX:\=/%
if %build_zlib% neq 1 goto libssh
if exist %ZLIBF% rd /s /q %ZLIBF%
%DIR%\7za.exe x %CACHE%\%ZLIB%.zip >nul || goto fail
cd %ZLIBF%
mkdir build && cd build || goto fail

cmake ..                                         		^
	-A %ARCH% 									 		^
	-G"%GENERATOR%"                                		^
	-DCMAKE_INSTALL_PREFIX=%PREFIX%  					^
	-DBUILD_SHARED_LIBS=OFF     						

cmake --build . --config %CONFIGURATION% --target install  -- /clp:ErrorsOnly 
xcopy %PREFIX%\lib\zlibstatic.lib* %TARGET%\zlib\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\include %TARGET%\zlib\include /y /s /i
cd %CURDIR%
dir /b %TARGET%\zlib\include >nul || goto fail
dir /b %TARGET%\zlib\lib\%PLATFORM%\zlibstatic.lib >nul || goto fail


:: always shared
:libssh
set PREFIX=%CD%\prefix\libssh-%PLATFORM%
if %build_ssh1% neq 1 goto libssh2
if exist %LIBSSH% rd /s /q %LIBSSH%
%DIR%\7za.exe e %CACHE%\%LIBSSH%.tar.xz -y 				^
	&& %DIR%\7za.exe x %LIBSSH%.tar -y >nul || goto fail
cd %LIBSSH%
mkdir build && cd build || goto fail

rem set "STDLIBS=crypt32.lib ws2_32.lib kernel32.lib user32.lib"
rem set "STDLIBS=%STDLIBS% gdi32.lib winspool.lib shell32.lib ole32.lib"
rem set "STDLIBS=%STDLIBS% oleaut32.lib uuid.lib comdlg32.lib advapi32.lib"

cmake .. 												^
	-A %ARCH%  											^
	-G"%GENERATOR%"                        				^
	-DCMAKE_INSTALL_PREFIX=%PREFIX% 			      	^
	-DCMAKE_BUILD_TYPE=Release 							^
	-DBUILD_SHARED_LIBS=ON          					^
	-DOPENSSL_ROOT_DIR=%OPENSSLDIR%       				^
	-DBUILD_SHARED_LIBS=ON         						^
	-DWITH_ZLIB=OFF 									^
	-DWITH_SERVER=OFF 									^
	-DWITH_PCAP=OFF										^
	-DWITH_EXAMPLES=OFF

rem	-DCMAKE_C_STANDARD_LIBRARIES="%STDLIBS%" 			

cmake --build . --config %CONFIGURATION% --target install -- /clp:ErrorsOnly 

xcopy %PREFIX%\lib\ssh.lib* %TARGET%\libssh\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\bin\ssh.dll* %TARGET%\libssh\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\include %TARGET%\libssh\include /y /s /i
cd %CURDIR%
dir /b %TARGET%\libssh\include >nul || goto fail
dir /b %TARGET%\libssh\lib\%PLATFORM%\ssh.lib >nul || goto fail
dir /b %TARGET%\libssh\lib\%PLATFORM%\ssh.dll >nul || goto fail


:libssh2
set PREFIX=%CD%\prefix\libssh2-%PLATFORM%
if %build_ssh2% neq 1 goto end
if exist %LIBSSH2% rd /s /q %LIBSSH2%
%DIR%\7za.exe e %CACHE%\%LIBSSH2%.tar.gz -y 			^
	&& %DIR%\7za.exe x %LIBSSH2%.tar -y >nul || goto fail
cd %LIBSSH2%
mkdir build && cd build 

rem set CL=/DOPENSSL_NO_ENGINE=1 %CL%

cmake .. 												^
	-A %ARCH%  											^
	-G"%GENERATOR%"                        				^
	-DBUILD_SHARED_LIBS=OFF  							^
	-DCMAKE_INSTALL_PREFIX=%PREFIX%				      	^
 	-DCRYPTO_BACKEND=OpenSSL               				^
	-DOPENSSL_ROOT_DIR=%OPENSSLDIR%			        	^
	-DBUILD_TESTING=OFF 								^
	-DBUILD_EXAMPLES=OFF        						^
	-DENABLE_ZLIB_COMPRESSION=OFF 						^
	-DENABLE_CRYPT_NONE=ON

rem -DZLIB_LIBRARY=%ZLIBDIR%/lib/zlibstatic.lib
rem -DZLIB_INCLUDE_DIR=%ZLIBDIR%/include

cmake --build . --config %CONFIGURATION% --target install -- /clp:ErrorsOnly

rem xcopy %PREFIX%\bin\libssh2.dll* %TARGET%\libssh2\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\lib\libssh2.lib* %TARGET%\libssh2\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\include %TARGET%\libssh2\include /y /s /i
cd %CURDIR%
dir /b %TARGET%\libssh2\include || goto fail
dir /b %TARGET%\libssh2\lib\%PLATFORM%\libssh2.lib || goto fail

:end
echo PASSED
goto :eof

:fail
echo FAILED
exit /b 1


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

set STATIC=0

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
set OPENSSL=OpenSSL_1_1_1e
::set OPENSSL=OpenSSL_1_0_2u
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
set LIBSSH2_URL=https://github.com/libssh2/libssh2/archive/%LIBSSH2%.zip

cd %CACHE%
if not exist openssl-%OPENSSL%.zip 	powershell -Command "Invoke-WebRequest %OPENSSL_URL% -OutFile openssl-%OPENSSL%.zip"
if not exist %ZLIB%.zip 			powershell -Command "Invoke-WebRequest %ZLIB_URL% -OutFile %ZLIB%.zip"
if not exist %LIBSSH%.tar.xz 		powershell -Command "Invoke-WebRequest %LIBSSH_URL% -OutFile %LIBSSH%.tar.xz"
if not exist libssh2-%LIBSSH2%.zip 	powershell -Command "Invoke-WebRequest %LIBSSH2_URL% -OutFile libssh2-%LIBSSH2%.zip"
cd %CURDIR%

set ARCH=x64
set OARCH=WIN64A
set DASH_X64=-x64
if %PLATFORM%==x86 (
	set ARCH=Win32
	set OARCH=WIN32
	set DASH_X64=
) 
set DASH_D=
set D=
if %CONFIGURATION%==Debug (
	set DASH_D=--debug
	set D=d
) 

set ossl_static=
if %STATIC% equ 1 (
	set "ossl_static=no-shared"
)

:: openssl
set PREFIX=%CD%\prefix\openssl-%CONFIGURATION%-%PLATFORM%
set OPENSSLDIR=%PREFIX:\=/%
if %build_ossl% neq 1 goto zlib
if exist openssl-%OPENSSL% rd /s /q openssl-%OPENSSL%
%DIR%\7za.exe x %CACHE%\openssl-%OPENSSL%.zip -y >nul || goto fail
cd openssl-%OPENSSL%
mkdir build && cd build || goto fail
perl ..\Configure %ossl_static% no-stdio no-sock 				^
	VC-%OARCH% --prefix=%PREFIX% --openssldir=%PREFIX% %DASH_D%
nmake >nul 2>&1
nmake install >nul 2>&1
xcopy %PREFIX%\include %TARGET%\openssl\include /y /s /i >nul
xcopy %PREFIX%\lib\libcrypto.lib* %TARGET%\openssl\lib\%CONFIGURATION%\%PLATFORM% /y /s /i 
xcopy %PREFIX%\bin\libcrypto-1_1%DASH_X64%.dll* %TARGET%\openssl\lib\%CONFIGURATION%\%PLATFORM% /y /s /i 
cd %CURDIR%
dir /b %TARGET%\openssl\include >nul || goto fail
dir /b %TARGET%\openssl\lib\%CONFIGURATION%\%PLATFORM%\libcrypto.lib >nul || goto fail


:zlib
set PREFIX=%CD%\prefix\zlib-%CONFIGURATION%-%PLATFORM%
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
	-DBUILD_SHARED_LIBS=ON 	 							^
	|| goto fail
cmake --build . --config %CONFIGURATION% --target install  -- /clp:ErrorsOnly || goto fail
xcopy %PREFIX%\bin\zlib* %TARGET%\zlib\lib\%CONFIGURATION%\%PLATFORM% /y /s /i
xcopy %PREFIX%\lib\zlib* %TARGET%\zlib\lib\%CONFIGURATION%\%PLATFORM% /y /s /i
xcopy %PREFIX%\include %TARGET%\zlib\include /y /s /i
cd %CURDIR%
dir /b %TARGET%\zlib\include >nul || goto fail
dir /b %TARGET%\zlib\lib\%CONFIGURATION%\%PLATFORM%\zlibstatic.lib >nul || goto fail


:libssh
set PREFIX=%CD%\prefix\libssh-%CONFIGURATION%-%PLATFORM%
if %build_ssh1% neq 1 goto libssh2
if exist %LIBSSH% rd /s /q %LIBSSH%
%DIR%\7za.exe e %CACHE%\%LIBSSH%.tar.xz -y 						^
	&& %DIR%\7za.exe x %LIBSSH%.tar -y >nul || goto fail
cd %LIBSSH%
mkdir build && cd build || goto fail
cmake .. 												^
	-A %ARCH%  											^
	-G"%GENERATOR%"                        				^
	-DCMAKE_INSTALL_PREFIX=%PREFIX% 			      	^
	-DOPENSSL_ROOT_DIR=%OPENSSLDIR% 		        	^
	-DZLIB_LIBRARY=%ZLIBDIR%/lib/zlib%D%.lib 	  		^
	-DZLIB_INCLUDE_DIR=%ZLIBDIR%/include     			^
	-DBUILD_SHARED_LIBS=ON ^
	-DWITH_SERVER=OFF ^
	|| goto fail
::	-DOPENSSL_MSVC_STATIC_RT=TRUE 						^
::	-DOPENSSL_USE_STATIC_LIBS=TRUE						^
::	-DWITH_ZLIB=OFF 
cmake --build . --config %CONFIGURATION% --target install -- /clp:ErrorsOnly 
xcopy %PREFIX%\lib\ssh.lib* %TARGET%\libssh\lib\%CONFIGURATION%\%PLATFORM% /y /s /i
xcopy %PREFIX%\bin\ssh.dll* %TARGET%\libssh\lib\%CONFIGURATION%\%PLATFORM% /y /s /i
xcopy %PREFIX%\include %TARGET%\libssh\include /y /s /i
cd %CURDIR%
dir /b %TARGET%\libssh\include >nul || goto fail
dir /b %TARGET%\libssh\lib\%CONFIGURATION%\%PLATFORM%\ssh.lib >nul || goto fail
dir /b %TARGET%\libssh\lib\%CONFIGURATION%\%PLATFORM%\ssh.dll >nul || goto fail


:libssh2
set PREFIX=%CD%\prefix\libssh2-%CONFIGURATION%-%PLATFORM%
if %build_ssh2% neq 1 goto end
if exist libssh2-%LIBSSH2% rd /s /q libssh2-%LIBSSH2%
%DIR%\7za.exe x %CACHE%\libssh2-%LIBSSH2%.zip -y >nul || goto fail
cd libssh2-%LIBSSH2%
mkdir build && cd build 
cmake .. 												^
	-A %ARCH%  											^
	-G"%GENERATOR%"                        				^
	-DBUILD_SHARED_LIBS=ON  							^
	-DCMAKE_INSTALL_PREFIX=%PREFIX%				      	^
 	-DCRYPTO_BACKEND=OpenSSL               				^
	-DOPENSSL_ROOT_DIR=%OPENSSLDIR%			        	^
	-DENABLE_ZLIB_COMPRESSION=ON 						^
	-DZLIB_LIBRARY=%ZLIBDIR%/lib/zlib.lib       		^
	-DZLIB_INCLUDE_DIR=%ZLIBDIR%/include 			    ^
	-DBUILD_TESTING=OFF 								^
	-DBUILD_EXAMPLES=OFF

rem	-DOPENSSL_MSVC_STATIC_RT=TRUE 						
rem	-DOPENSSL_USE_STATIC_LIBS=TRUE						

cmake --build . --config %CONFIGURATION% --target install -- /clp:ErrorsOnly

xcopy %PREFIX%\bin\libssh2.dll* %TARGET%\libssh2\lib\%CONFIGURATION%\%PLATFORM% /y /s /i
xcopy %PREFIX%\lib\libssh2.lib* %TARGET%\libssh2\lib\%CONFIGURATION%\%PLATFORM% /y /s /i
xcopy %PREFIX%\include %TARGET%\libssh2\include /y /s /i
cd %CURDIR%
dir /b %TARGET%\libssh2\include || goto fail
dir /b %TARGET%\libssh2\lib\%CONFIGURATION%\%PLATFORM%\libssh2.lib || goto fail

:end
echo PASSED
goto :eof

:fail
echo FAILED
exit /b 1


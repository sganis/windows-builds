:: Golddrive
:: 03/22/2020, San
:: 04/28/2024, upgraded to latest libs
::
:: Visual Studio 2022 script to build:
:: 1. OpenSSL
:: 2. Zlib
:: 3. LibSSH
:: 4. LibSSH2
:: 5. OpenSSH

@echo off
setlocal

:: this script directory
set DIR=%~dp0
set DIR=%DIR:~0,-1%

set build_ossl=1
set build_zlib=1
set build_ssh1=1
set build_ssh2=1
set build_ossh=1

::set PLATFORM=x64
::set CONFIGURATION=Release
set "GENERATOR=Visual Studio 17 2022"

if "%APPVEYOR_BUILD_WORKER_IMAGE%"=="Visual Studio 2019" ( set "GENERATOR=Visual Studio 16 2019" )
if "%APPVEYOR_BUILD_WORKER_IMAGE%"=="Visual Studio 2017" ( set "GENERATOR=Visual Studio 15 2017" )

set CURDIR=%CD%
set TARGET=%CD%\vendor
rem if exist %TARGET% rd /s /q %TARGET%
rem mkdir %TARGET%

set OPENSSH=9.5.0.0
set OPENSSL=openssl-3.3.0
set ZLIB=zlib131
set ZLIBF=zlib-1.3.1
set LIBSSH=libssh-0.10.6
set LIBSSH2=libssh2-1.11.0

set CACHE=C:\cache
dir /b %CACHE% || mkdir %CACHE%

:: openssh : https://github.com/PowerShell/openssh-portable/archive/refs/tags/v9.5.0.0.zip
:: openssl : https://github.com/openssl/openssl/archive/refs/tags/openssl-3.3.0.zip
:: zlib    : http://zlib.net/zlib131.zip
:: libssh  : https://www.libssh.org/files/0.10/libssh-0.10.6.tar.xz
:: libssh2 : https://github.com/libssh2/libssh2/archive/refs/tags/libssh2-1.11.0.tar.gz

set OPENSSH_URL=https://github.com/PowerShell/openssh-portable/archive/refs/tags/v%OPENSSH%.zip
set OPENSSL_URL=https://github.com/openssl/openssl/archive/refs/tags/%OPENSSL%.zip
set ZLIB_URL=http://zlib.net/%ZLIB%.zip
set LIBSSH_URL=https://www.libssh.org/files/0.10/%LIBSSH%.tar.xz
set LIBSSH2_URL=https://github.com/libssh2/libssh2/archive/refs/tags/%LIBSSH2%.tar.gz

cd %CACHE%
if not exist openssh-portable-%OPENSSH%.zip powershell -Command "Invoke-WebRequest %OPENSSH_URL% -OutFile openssh-portable-%OPENSSH%.zip"
if not exist openssl-%OPENSSL%.zip          powershell -Command "Invoke-WebRequest %OPENSSL_URL% -OutFile openssl-%OPENSSL%.zip"
if not exist %ZLIB%.zip                     powershell -Command "Invoke-WebRequest %ZLIB_URL% -OutFile %ZLIB%.zip"
if not exist %LIBSSH%.tar.xz                powershell -Command "Invoke-WebRequest %LIBSSH_URL% -OutFile %LIBSSH%.tar.xz"
if not exist %LIBSSH2%.tar.gz               powershell -Command "Invoke-WebRequest %LIBSSH2_URL% -OutFile %LIBSSH2%.tar.gz"
cd %CURDIR%

set ARCH=x64
set OARCH=WIN64A
set DASH_X64=-x64
set DOMS=do_win64a.bat
if %PLATFORM%==x86 (
	set ARCH=Win32
	set OARCH=WIN32
	set DOMS=do_ms.bat
	set DASH_X64=
)

:openssl
set PREFIX=%CD%\prefix\openssl-%PLATFORM%
set OPENSSLDIR=%PREFIX:\=/%
if %build_ossl% neq 1 goto zlib
if exist openssl-%OPENSSL% rd /s /q openssl-%OPENSSL%
%DIR%\7za.exe x %CACHE%\openssl-%OPENSSL%.zip -y >nul || goto fail
cd openssl-%OPENSSL%

perl Configure 				^
	VC-%OARCH% 				^
	--prefix=%PREFIX% 		^
	--openssldir=%PREFIX%
nmake >nul
nmake install >nul

xcopy %PREFIX%\include %TARGET%\openssl\include /y /s /i >nul || goto fail
xcopy %PREFIX%\lib\*.* %TARGET%\openssl\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\bin\*.* %TARGET%\openssl\lib\%PLATFORM% /y /s /i
cd %CURDIR%
dir /b %TARGET%\openssl\include >nul || goto fail
dir /b %TARGET%\openssl\lib\%PLATFORM%\*.lib >nul || goto fail


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
	-DCMAKE_C_FLAGS_RELEASE="/MT /O2 /Ob2 /D NDEBUG"	^
	-DBUILD_SHARED_LIBS=OFF

cmake --build . --config %CONFIGURATION% --target install -- /clp:ErrorsOnly

xcopy %PREFIX%\lib\zlibstatic.lib* %TARGET%\zlib\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\include %TARGET%\zlib\include /y /s /i
cd %CURDIR%
dir /b %TARGET%\zlib\include >nul || goto fail
dir /b %TARGET%\zlib\lib\%PLATFORM%\zlibstatic.lib >nul || goto fail


:libssh
set PREFIX=%CD%\prefix\libssh-%PLATFORM%
if %build_ssh1% neq 1 goto libssh2
if exist %LIBSSH% rd /s /q %LIBSSH%
%DIR%\7za.exe e %CACHE%\%LIBSSH%.tar.xz -y 				^
	&& %DIR%\7za.exe x %LIBSSH%.tar -y >nul || goto fail
cd %LIBSSH%
mkdir build && cd build || goto fail

cmake .. 												^
	-A %ARCH%  											^
	-G"%GENERATOR%"                        				^
	-DCMAKE_INSTALL_PREFIX=%PREFIX% 			      	^
	-DCMAKE_BUILD_TYPE=Release 							^
	-DBUILD_SHARED_LIBS=ON          					^
	-DOPENSSL_ROOT_DIR=%OPENSSLDIR%       				^
	-DWITH_SERVER=OFF 									^
	-DWITH_PCAP=OFF										^
 	-DWITH_SERVER=OFF 									^
 	-DWITH_EXAMPLES=OFF 								^
 	-DWITH_ZLIB=OFF

rem -DWITH_ZLIB=ON 										^
rem -DZLIB_INCLUDE_DIR="%ZLIBDIR%/include" 				^
rem -DZLIB_LIBRARY="%ZLIBDIR%/lib/zlib.lib"

cmake --build . --config %CONFIGURATION% --target ssh -- /clp:ErrorsOnly
cmake -P cmake_install.cmake

xcopy %PREFIX%\lib\ssh.lib* %TARGET%\libssh\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\bin\ssh.dll* %TARGET%\libssh\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\include %TARGET%\libssh\include /y /s /i
cd %CURDIR%
dir /b %TARGET%\libssh\include >nul || goto fail
dir /b %TARGET%\libssh\lib\%PLATFORM%\ssh.lib >nul || goto fail
dir /b %TARGET%\libssh\lib\%PLATFORM%\ssh.dll >nul || goto fail


:libssh2
set PREFIX=%CD%\prefix\libssh2-%PLATFORM%
if %build_ssh2% neq 1 goto openssh
if exist %LIBSSH2% rd /s /q %LIBSSH2%
%DIR%\7za.exe e %CACHE%\%LIBSSH2%.tar.gz -y 			^
	&& %DIR%\7za.exe x %LIBSSH2%.tar -y >nul || goto fail
cd %LIBSSH2%
mkdir build && cd build

cmake .. 												^
	-A %ARCH%  											^
	-G"%GENERATOR%"                        				^
	-DCMAKE_INSTALL_PREFIX=%PREFIX%				      	^
	-DBUILD_SHARED_LIBS=OFF  							^
	-DCMAKE_C_FLAGS_RELEASE="/MT /O2 /Ob2 /D NDEBUG"	^
 	-DCRYPTO_BACKEND=OpenSSL               				^
	-DOPENSSL_ROOT_DIR=%OPENSSLDIR%			        	^
	-DBUILD_TESTING=ON  								^
	-DBUILD_EXAMPLES=OFF        						^
	-DENABLE_ZLIB_COMPRESSION=OFF 						^
 	-DENABLE_CRYPT_NONE=ON								^
 	-DCLEAR_MEMORY=OFF

rem -DZLIB_LIBRARY=%ZLIBDIR%/lib/zlib.lib 		 		^
rem -DZLIB_INCLUDE_DIR=%ZLIBDIR%/include

cmake --build . --config %CONFIGURATION% --target libssh2 -- /clp:ErrorsOnly
cmake -P cmake_install.cmake

xcopy %PREFIX%\lib\libssh2.lib* %TARGET%\libssh2\lib\%PLATFORM% /y /s /i
rem xcopy %PREFIX%\bin\libssh2.dll* %TARGET%\libssh2\lib\%PLATFORM% /y /s /i
xcopy %PREFIX%\include %TARGET%\libssh2\include /y /s /i
cd %CURDIR%
dir /b %TARGET%\libssh2\include || goto fail
dir /b %TARGET%\libssh2\lib\%PLATFORM%\libssh2.lib || goto fail


:openssh
if %build_ossh% neq 1 goto end
set OSSH=openssh-portable-%OPENSSH%
if exist %OSSH% rd /s /q %OSSH%
%DIR%\7za.exe x %CACHE%\%OSSH%.zip -y >nul || goto fail
cd %OSSH%

python ..\patch_openssh.py || goto fail

set "ARGS=-p:Configuration=Release -m -v:quiet -t:rebuild /p:PlatformToolset=v143"
msbuild contrib\win32\openssh\config.vcxproj %ARGS%
msbuild contrib\win32\openssh\win32iocompat.vcxproj %ARGS%
msbuild contrib\win32\openssh\openbsd_compat.vcxproj %ARGS%
msbuild contrib\win32\openssh\libssh.vcxproj %ARGS%
msbuild contrib\win32\openssh\keygen.vcxproj %ARGS%
msbuild contrib\win32\openssh\ssh.vcxproj %ARGS%
msbuild contrib\win32\openssh\sftp.vcxproj %ARGS%

xcopy bin\%ARCH%\Release\*.exe %TARGET%\openssh\%PLATFORM% /y /s /i >nul
xcopy %TARGET%\openssl\lib\%PLATFORM%\*.dll* %TARGET%\openssh\%PLATFORM% /y /s /i >nul
cd %CURDIR%
dir /b %TARGET%\openssh\%PLATFORM%\ssh-keygen.exe >nul || goto fail
dir /b %TARGET%\openssh\%PLATFORM%\ssh.exe >nul || goto fail
dir /b %TARGET%\openssh\%PLATFORM%\sftp.exe >nul || goto fail


:end
echo PASSED
goto :eof

:fail
echo FAILED
exit /b 1

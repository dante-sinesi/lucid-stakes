@echo off
rem Arma la extension de Godot del solucionador de salas (docs\solver_extension.md): extension\bin\libsolver.windows.template_debug.x86_64.dll (el editor y las partidas de desarrollo) y la de release (la exportacion).
rem Hace falta g++ (el de MSYS2 en C:\msys64\mingw64\bin: va al final del PATH para que "python" siga siendo el de Windows), Python con SCons (pip install scons) y git. La primera vez baja godot-cpp a native\godot-cpp (no se versiona).
setlocal
cd /d "%~dp0.."
set PATH=%PATH%;C:\msys64\mingw64\bin
if not exist native\godot-cpp git clone --depth 1 https://github.com/godotengine/godot-cpp native\godot-cpp
if errorlevel 1 exit /b 1
if not exist extension\bin mkdir extension\bin
pushd native\extension
python -m SCons platform=windows use_mingw=yes arch=x86_64 target=template_debug disable_exceptions=no -j8
if errorlevel 1 (popd & exit /b 1)
python -m SCons platform=windows use_mingw=yes arch=x86_64 target=template_release disable_exceptions=no -j8
if errorlevel 1 (popd & exit /b 1)
popd
endlocal

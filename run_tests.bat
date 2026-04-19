@echo off
REM Script de execução de testes do BarberOS para Windows
REM Uso: run_tests.bat [opção]

echo ========================================
echo   BarberOS - Execução de Testes
echo ========================================

REM Função para mostrar ajuda
if "%1"=="help" goto show_help
if "%1"=="-h" goto show_help
if "%1"=="--help" goto show_help

REM Verifica se Flutter está instalado
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ERRO: Flutter não encontrado. Por favor, instale o Flutter.
    exit /b 1
)

echo Flutter encontrado
flutter --version

REM Prepara ambiente
echo Preparando ambiente...
call flutter pub get

REM Verifica se precisa gerar arquivos de build
findstr /C:"build_runner" pubspec.yaml >nul
if %errorlevel% equ 0 (
    echo Gerando arquivos de build...
    call flutter pub run build_runner build --delete-conflicting-outputs
)

REM Processa argumentos
if "%1"=="" goto run_all
if "%1"=="all" goto run_all
if "%1"=="widget" goto run_widget
if "%1"=="unit" goto run_unit
if "%1"=="integration" goto run_integration
if "%1"=="coverage" goto run_coverage
if "%1"=="analyze" goto run_analyze
if "%1"=="clean" goto clean_project

echo Opção desconhecida: %1
goto show_help

:run_all
echo Executando todos os testes...
call flutter test
goto :end

:run_widget
echo Executando testes de widget...
call flutter test test\barberos_widget_test.dart
goto :end

:run_unit
echo Executando testes unitários...
call flutter test test\barberos_unit_test.dart
goto :end

:run_integration
echo Executando testes de integração...
call flutter test test\barberos_integration_test.dart
goto :end

:run_coverage
echo Executando testes com cobertura...
call flutter test --coverage
echo.
echo Para gerar relatório HTML, instale lcov e execute:
echo genhtml coverage\lcov.info -o coverage\html
goto :end

:run_analyze
echo Executando análise estática...
call flutter analyze
goto :end

:clean_project
echo Limpando projeto...
call flutter clean
if exist build rmdir /s /q build
if exist coverage rmdir /s /q coverage
if exist .dart_tool rmdir /s /q .dart_tool
if exist .packages del .packages
if exist .flutter-plugins del .flutter-plugins
call flutter pub get
echo Projeto limpo
goto :end

:show_help
echo Uso: run_tests.bat [opção]
echo.
echo Opções:
echo   all           Executa todos os testes (padrão)
echo   widget        Executa apenas testes de widget
echo   unit          Executa apenas testes unitários
echo   integration   Executa apenas testes de integração
echo   coverage      Executa testes com cobertura
echo   analyze       Executa análise estática (flutter analyze)
echo   clean         Limpa build e dependências
echo   help          Mostra esta ajuda
echo.
echo Exemplos:
echo   run_tests.bat           ^> Executa todos os testes
echo   run_tests.bat widget    ^> Executa testes de widget
echo   run_tests.bat coverage  ^> Executa testes com cobertura
goto :end

:end
echo ========================================
echo Concluído!
echo ========================================
pause
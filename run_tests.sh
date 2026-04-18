#!/bin/bash

# Script de execução de testes do BarberOS
# Uso: ./run_tests.sh [opção]

set -e  # Sai no primeiro erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  BarberOS - Execução de Testes        ${NC}"
echo -e "${BLUE}========================================${NC}"

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 [opção]"
    echo ""
    echo "Opções:"
    echo "  all           Executa todos os testes (padrão)"
    echo "  widget        Executa apenas testes de widget"
    echo "  unit          Executa apenas testes unitários"
    echo "  integration   Executa apenas testes de integração"
    echo "  coverage      Executa testes com cobertura"
    echo "  analyze       Executa análise estática (flutter analyze)"
    echo "  clean         Limpa build e dependências"
    echo "  help          Mostra esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0              # Executa todos os testes"
    echo "  $0 widget       # Executa testes de widget"
    echo "  $0 coverage     # Executa testes com cobertura"
}

# Função para executar comandos com tratamento de erro
run_command() {
    echo -e "${YELLOW}Executando: $1${NC}"
    if eval "$1"; then
        echo -e "${GREEN}✓ Sucesso${NC}"
    else
        echo -e "${RED}✗ Falhou${NC}"
        return 1
    fi
}

# Verifica se Flutter está instalado
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}Flutter não encontrado. Por favor, instale o Flutter.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Flutter encontrado${NC}"
    flutter --version
}

# Prepara ambiente
prepare_environment() {
    echo -e "${YELLOW}Preparando ambiente...${NC}"

    # Obtém dependências
    run_command "flutter pub get"

    # Gera arquivos de build se necessário
    if [ -f "pubspec.yaml" ] && grep -q "build_runner" pubspec.yaml; then
        echo -e "${YELLOW}Gerando arquivos de build...${NC}"
        run_command "flutter pub run build_runner build --delete-conflicting-outputs" || true
    fi
}

# Executa todos os testes
run_all_tests() {
    echo -e "${BLUE}Executando todos os testes...${NC}"
    run_command "flutter test"
}

# Executa testes de widget
run_widget_tests() {
    echo -e "${BLUE}Executando testes de widget...${NC}"
    run_command "flutter test test/barberos_widget_test.dart"
}

# Executa testes unitários
run_unit_tests() {
    echo -e "${BLUE}Executando testes unitários...${NC}"
    run_command "flutter test test/barberos_unit_test.dart"
}

# Executa testes de integração
run_integration_tests() {
    echo -e "${BLUE}Executando testes de integração...${NC}"
    run_command "flutter test test/barberos_integration_test.dart"
}

# Executa testes com cobertura
run_coverage_tests() {
    echo -e "${BLUE}Executando testes com cobertura...${NC}"

    # Executa testes com cobertura
    run_command "flutter test --coverage"

    # Verifica se lcov está instalado para gerar relatório HTML
    if command -v lcov &> /dev/null && command -v genhtml &> /dev/null; then
        echo -e "${YELLOW}Gerando relatório de cobertura HTML...${NC}"

        # Converte lcov.info para formato legível
        if [ -f "coverage/lcov.info" ]; then
            mkdir -p coverage/html
            genhtml coverage/lcov.info -o coverage/html --quiet
            echo -e "${GREEN}Relatório HTML gerado em: coverage/html/index.html${NC}"
        else
            echo -e "${YELLOW}Arquivo lcov.info não encontrado${NC}"
        fi
    else
        echo -e "${YELLOW}lcov/genhtml não encontrado. Instale para gerar relatório HTML.${NC}"
        echo "Ubuntu/Debian: sudo apt-get install lcov"
        echo "macOS: brew install lcov"
    fi
}

# Executa análise estática
run_analyze() {
    echo -e "${BLUE}Executando análise estática...${NC}"
    run_command "flutter analyze"
}

# Limpa projeto
clean_project() {
    echo -e "${BLUE}Limpando projeto...${NC}"

    # Limpa build do Flutter
    run_command "flutter clean"

    # Remove pastas de build
    rm -rf build/ coverage/ .dart_tool/ .packages .flutter-plugins

    # Obtém dependências novamente
    run_command "flutter pub get"

    echo -e "${GREEN}Projeto limpo${NC}"
}

# Processa argumentos
case "${1:-all}" in
    "all")
        check_flutter
        prepare_environment
        run_all_tests
        ;;
    "widget")
        check_flutter
        prepare_environment
        run_widget_tests
        ;;
    "unit")
        check_flutter
        prepare_environment
        run_unit_tests
        ;;
    "integration")
        check_flutter
        prepare_environment
        run_integration_tests
        ;;
    "coverage")
        check_flutter
        prepare_environment
        run_coverage_tests
        ;;
    "analyze")
        check_flutter
        prepare_environment
        run_analyze
        ;;
    "clean")
        clean_project
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo -e "${RED}Opção desconhecida: $1${NC}"
        show_help
        exit 1
        ;;
esac

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Concluído!${NC}"
echo -e "${BLUE}========================================${NC}"